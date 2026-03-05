#[cfg(test)]
mod api_drift_tests {
    use actix_web::{App, HttpServer};
    use std::io;
    use std::process::Command;
    use std::time::Duration;
    use shipping::shipping_service::{get_quote, ship_order};

    /// Helper function to run Drift and validate API contract
    fn run_drift_validation(server_url: &str) -> io::Result<bool> {
        println!("\n📋 Running Drift API contract validation...\n");

        let output = Command::new("drift")
            .args(&[
                "verifier",
                "--test-files",
                "drift.yaml",
                "--server-url",
                server_url,
                "--log-level",
                "info",
                "--output-dir",
                "output",
                // comment out the below tags to see a test failure
                "--tags",
                "test",
            ])
            .output()?;

        let exit_code = output.status.code().unwrap_or(1);
        let stdout = String::from_utf8_lossy(&output.stdout);
        let stderr = String::from_utf8_lossy(&output.stderr);

        if !stdout.is_empty() {
            println!("{}", stdout);
        }
        if !stderr.is_empty() {
            eprintln!("{}", stderr);
        }

        Ok(exit_code == 0)
    }

    /// Wait for server to be ready by checking if port is responding
    async fn wait_for_server(host: &str, port: u16, max_attempts: u32, delay_ms: u64) -> bool {
        for attempt in 1..=max_attempts {
            match tokio::net::TcpStream::connect(format!("{}:{}", host, port)).await {
                Ok(_) => {
                    println!("✓ Server is ready (attempt {})", attempt);
                    return true;
                }
                Err(_) => {
                    if attempt < max_attempts {
                        println!("⏳ Waiting for server... (attempt {}/{})", attempt, max_attempts);
                        tokio::time::sleep(Duration::from_millis(delay_ms)).await;
                    }
                }
            }
        }
        false
    }

    #[tokio::test]
    async fn test_api_contract_with_drift() {
        // This test:
        // 1. Starts the shipping service in a background task
        // 2. Waits for it to be ready
        // 3. Runs Drift contract validation
        // 4. Cleans up

        let server_url = "http://127.0.0.1:8000";
        let host = "127.0.0.1";
        let port = 8000u16;

        println!("\n🚀 Starting shipping service in background...");

        // Spawn the server in a background task
        let server_handle = tokio::spawn(async move {
            let server = HttpServer::new(|| {
                App::new()
                    .service(get_quote)
                    .service(ship_order)
            })
            .bind(format!("{}:{}", host, port))
            .expect("Failed to bind server")
            .run();

            println!("✓ Server bound to {}:{}", host, port);

            // Run the server - this will keep it alive
            if let Err(e) = server.await {
                eprintln!("❌ Server error: {}", e);
            }
        });

        println!("   Expected to find Drift config at: ./drift.yaml");
        println!("   Expected server URL: {}\n", server_url);

        // Wait for server to be ready (max 10 seconds with 500ms checks)
        if !wait_for_server(host, port, 20, 500).await {
            eprintln!("❌ Server failed to start within timeout");
            server_handle.abort();
            panic!("Server startup timeout");
        }

        // Give extra time for full initialization
        tokio::time::sleep(Duration::from_millis(500)).await;

        // Run Drift validation
        match run_drift_validation(server_url) {
            Ok(passed) => {
                if passed {
                    println!("✅ Drift validation passed - API conforms to OpenAPI spec");
                } else {
                    println!("❌ Drift validation failed - API does not conform to OpenAPI spec");
                    server_handle.abort();
                    panic!("Drift validation failed");
                }
            }
            Err(e) => {
                eprintln!("⚠️  Could not run Drift: {}", e);
                eprintln!("   Make sure Drift is installed: npm install -g @apitools/drift");
                eprintln!("   Or visit: https://www.drift.dev/");
                server_handle.abort();
                panic!("Failed to run Drift: {}", e);
            }
        }

        // Cleanup
        server_handle.abort();
        println!("✓ Server stopped");
    }
}

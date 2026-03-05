
<?php

use PHPUnit\Framework\TestCase;
// namespace Quote\Test;


class ApiTest extends TestCase
{

  public static function setUpBeforeClass(): void
  {
    // Start PHP built-in server
    $command = 'cd ' . __DIR__ . '/../ && QUOTE_PORT=9393 php public/index.php';
    proc_open($command, [1 => STDOUT, 2 => STDERR], $pipes);
    sleep(1);
    echo "✓ Quote server started on http://localhost:9393\n";
  }

  public static function tearDownAfterClass(): void
  {
    shell_exec('pkill -f "php public/index.php"');
  }

  public function testValidatesApiConformsToOpenApiSpecification(): void
  {
    $exitCode = $this->runDrift(
      testFile: './drift.yaml',
      serverUrl: 'http://0.0.0.0:9393',
      logLevel: 'debug'
    );

    $this->assertEquals(0, $exitCode);
  }

  private function runDrift(string $testFile, string $serverUrl, string $logLevel): int
  {
    $command = "drift verifier --test-files {$testFile} --server-url {$serverUrl} --log-level {$logLevel}";
    $process = proc_open($command, [1 => STDOUT, 2 => STDERR], $pipes);
    $exitCode = proc_close($process);
    return $exitCode; }
}

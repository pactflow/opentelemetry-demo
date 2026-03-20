<?php

function run_drift($options = []) {
  $test_file = $options['test_file'] ?? './drift.yaml';
  $server_url = $options['server_url'] ?? 'http://localhost:8080';
  $output_dir = $options['output_dir'] ?? './output';
  $log_level = $options['log_level'] ?? 'info';

  echo "\n📋 Running Drift tests from: {$test_file}\n";

  $cmd = [
    'drift',
    'verify',
    '--test-files', $test_file,
    '--server-url', $server_url,
    '--log-level', $log_level,
    '--output-dir', $output_dir
  ];

  $process = proc_open(
    implode(' ', array_map('escapeshellarg', $cmd)),
    [1 => ['pipe', 'w']],
    $pipes
  );

  if (is_resource($process)) {
    while (!feof($pipes[1])) {
      echo fgets($pipes[1]);
    }
    fclose($pipes[1]);
    return proc_close($process);
  }

  return 1;
}

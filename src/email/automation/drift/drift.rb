require 'open3'
require 'pathname'

def run_drift(options = {})
  test_file = options[:test_file] || './drift.yaml'
  server_url = options[:server_url] || 'http://localhost:8080'
  output_dir = options[:output_dir] || './output'
  log_level = options[:log_level] || 'info'

  puts "\n📋 Running Drift tests from: #{test_file}\n"

  cmd = [
    'drift',
    'verifier',
    '--test-files', test_file,
    '--server-url', server_url,
    '--log-level', log_level,
    '--output-dir', output_dir
  ]

  Open3.popen3(*cmd) do |_stdin, stdout, _stderr, wait_thr|
    stdout.each { |line| puts line }
    return wait_thr.value.exitstatus
  end
end

# frozen_string_literal: true

require_relative '../email_server'
require_relative '../automation/drift/drift'

RSpec.describe 'Verify Email Service Implementation', :pact_v2 do
  # let(:app) { EmailServer }

  before(:all) do
    @app = Thread.new { EmailServer.run! }
    sleep(1) # Give server time to start
    puts '✓ Email server started on http://localhost:9292'
  end
  after(:all) do
    @app.kill
  end

  it 'Validates API conforms to OpenAPI specification' do
    exit_code = run_drift(
      test_file: './drift.yaml',
      server_url: 'http://localhost:9292',
      log_level: 'debug'
    )

    expect(exit_code).to eq(0)
  end
end

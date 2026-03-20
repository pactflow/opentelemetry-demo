# frozen_string_literal: true

require 'combustion'
begin
  Combustion.initialize! :action_controller do
    config.log_level = :fatal if ENV['LOG'].to_s.empty?
  end
rescue StandardError => e
  # Fail fast if application couldn't be loaded
  warn "💥 Failed to load the app: #{e.message}\n#{e.backtrace.join("\n")}"
  exit(1)
end
require_relative '../../../email_server'
app_to_verify = EmailServer.new

require 'pact'
require 'pact/v2/rspec'
RSpec.describe 'Verify consumers for Email Service', :pact_v2 do
  http_pact_provider 'email-service', opts: {
    app: app_to_verify,
    http_port: 9393,
    provider_setup_port: 9003,
    log_level: :info,
    fail_if_no_pacts_found: true,
    # pact_uri: File.expand_path("../../../../checkout/pacts/checkout-email-service.json", __dir__),
    pact_uri: File.expand_path("../../pacts/pact.json", __dir__),
    # broker_url: 'http://localhost:9292', # can be set via PACT_BROKER_URL env var
    enable_pending: true,
    include_wip_pacts_since: '2026-01-01',
    publish_verification_results: ENV['PACT_PUBLISH_VERIFICATION_RESULTS'] == 'true',
    provider_version: `git rev-parse HEAD`.strip,
    provider_version_branch: `git rev-parse --abbrev-ref HEAD`.strip

  }
end

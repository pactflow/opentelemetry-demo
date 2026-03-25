# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
# SPDX-License-Identifier: Apache-2.0

require 'ostruct'
require 'pony'
require 'sinatra'
require 'open_feature/sdk'
require 'openfeature/flagd/provider'

require 'opentelemetry/sdk'
require 'opentelemetry-logs-sdk'
require 'opentelemetry-metrics-sdk'
require 'opentelemetry/exporter/otlp'
require 'opentelemetry-exporter-otlp-logs'
require 'opentelemetry-exporter-otlp-metrics'
require 'opentelemetry/instrumentation/sinatra'
disable :run
class EmailServer < Sinatra::Base
  set :port, ENV['EMAIL_PORT']

  # Initialize OpenFeature SDK with flagd provider
  flagd_client = OpenFeature::Flagd::Provider.build_client
  flagd_client.configure do |config|
    config.host = ENV.fetch('FLAGD_HOST', 'localhost')
    config.port = ENV.fetch('FLAGD_PORT', 8013).to_i
    config.tls = ENV.fetch('FLAGD_TLS', 'false') == 'true'
  end

  OpenFeature::SDK.configure do |config|
    config.set_provider(flagd_client)
  end

  OpenTelemetry::SDK.configure do |c|
    c.use 'OpenTelemetry::Instrumentation::Sinatra'
  end

  @@logger = OpenTelemetry.logger_provider.logger(name: 'email')

  otlp_metric_exporter = OpenTelemetry::Exporter::OTLP::Metrics::MetricsExporter.new
  OpenTelemetry.meter_provider.add_metric_reader(otlp_metric_exporter)
  meter = OpenTelemetry.meter_provider.meter('email')
  @@confirmation_counter = meter.create_counter(
    'app.confirmation.counter',
    unit: '1',
    description: 'Counts the number of order confirmation emails sent'
  )

  post '/send_order_confirmation' do
    data = JSON.parse(request.body.read, object_class: OpenStruct)
    puts data
    current_span = OpenTelemetry::Trace.current_span
    current_span.add_attributes({
                                  'app.order.id' => data.order.order_id
                                })

    @@confirmation_counter.add(1)
    send_email(data)
  end

  error do
    OpenTelemetry::Trace.current_span.record_exception(env['sinatra.error'])
  end

  # private

  def send_email(data)
    tracer = OpenTelemetry.tracer_provider.tracer('email')
    tracer.in_span('send_email') do |span|
      client = OpenFeature::SDK.build_client
      memory_leak_multiplier = client.fetch_number_value(
        flag_key: 'emailMemoryLeak',
        default_value: 0
      )

      confirmation_content = erb(:confirmation, locals: { order: data.order })
      whitespace_length = [0, confirmation_content.length * (memory_leak_multiplier - 1)].max

      Pony.mail(
        to: data.email,
        from: 'noreply@example.com',
        subject: 'Your confirmation email',
        body: confirmation_content + (' ' * whitespace_length),
        via: :test
      )

      Mail::TestMailer.deliveries.clear if memory_leak_multiplier < 1

      span.set_attribute('app.email.recipient', data.email)
      @@logger.on_emit(
        timestamp: Time.now,
        severity_text: 'INFO',
        body: 'Order confirmation email sent',
        attributes: { 'app.email.recipient' => data.email }
      )

      puts "Order confirmation email sent to: #{data.email}"
    end
  end
end
EmailServer.run! if __FILE__ == $PROGRAM_NAME

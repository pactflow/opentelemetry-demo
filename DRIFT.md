# API Testing

Samples of API testing

- API Implementation / Documentation Divergence Testing (API Drift Testing)
- Consumer Contract Testing (Pact)

## Getting Started

- [Install drift](https://pactflow.github.io/drift-docs/docs/how-to/install)
  - `npm install -g @pactflow/drift`

## Consumers

- checkout service (go)
  - Pact Consumer Contract Tests (w/ Email Service)
    - [pact test](./src/checkout/main_test.go)
    - [pact sample](./src/checkout/pacts/checkout-email-service.json)

```sh
go install github.com/pact-foundation/pact-go/v2
# pact-go will be installed into $GOPATH/bin, which is $HOME/go/bin by default.
# download and install the required libraries.
pact-go -l DEBUG install
cd src/checkout
go test -v
```

## Providers

- email service (ruby)
  - [OpenAPI Definition](./src/email/openapi.yaml)
  - API Drift Testing
    - [drift wrapper](./src/email/automation/drift/drift.rb)
    - [drift test](./src/email/spec/api.test.rb)
    - [drift test suite](./src/email/drift.yaml)

```sh
cd src/email
bundle install
bundle exec rspec spec/api.test.rb
```

- Pact (Consumer Contract) Verification Tests
  - [pact test](./src/email/spec/pact/consumers/email_consumer.spec.rb)
  - [pact sample](./src/email/spec/pacts/pact.json)

```sh
cd src/email
bundle install
bundle exec rspec spec/pact/consumers/email_consumer.spec.rb --tag pact_v2
```

- quote service (php)
  - [OpenAPI Definition](./src/quote/openapi.yaml)
  - API Drift Testing
    - [drift wrapper + test](./src/quote/test/ApiTest.php)
    - [drift test suite](./src/quote/drift.yaml)

```sh
cd src/quote
composer install
composer test
```

- shipping service (rust)
  - [OpenAPI Definition](./src/shipping/openapi.yaml)
  - API Drift Testing
    - [drift wrapper + test](src/shipping/tests/api_drift.rs)
    - [drift test suite](./src/shipping/drift.yaml)

```sh
cd src/shipping
cargo test
```

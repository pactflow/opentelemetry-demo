package main

import (
	"context"
	"fmt"
	"net/http"
	"testing"

	pb "github.com/open-telemetry/opentelemetry-demo/src/checkout/genproto/oteldemo"
	"github.com/pact-foundation/pact-go/v2/consumer"
	"github.com/pact-foundation/pact-go/v2/matchers"
	"github.com/stretchr/testify/assert"
)

type S = matchers.S
type Map = matchers.MapMatcher

var ArrayMinLike = matchers.ArrayMinLike
var Integer = matchers.Integer

func TestSendOrderConfirmationContract(t *testing.T) {
	mockProvider, err := consumer.NewV4Pact(consumer.MockHTTPProviderConfig{
		Consumer: "checkout",
		Provider: "email-service",
		Host:     "127.0.0.1",
	})
	assert.NoError(t, err)

	err = mockProvider.
		AddInteraction().
		Given("email service is available").
		UponReceiving("a request to send order confirmation").
		WithRequest("POST", "/send_order_confirmation", func(b *consumer.V4RequestBuilder) {
			b.
				Header("Content-Type", S("application/json")).
				JSONBody(Map{
					"email": S("customer@example.com"),
					"order": matchers.Like(Map{
						"order_id":             S("100"),
						"shipping_tracking_id": S("TRACK123456"),
						"shipping_cost": matchers.Like(Map{
							"currency_code": S("USD"),
							"units":         Integer(10),
							"nanos":         Integer(500000000),
						}),
						"shipping_address": matchers.Like(Map{
							"street_address": S("123 Main St"),
							// "street_address_2": S("Apt 4B"),
							"city":             S("San Francisco"),
							"country":          S("USA"),
							"zip_code":         S("94105"),
						}),
						"items": ArrayMinLike(Map{
							"item": matchers.Like(Map{
								"product_id": S("PROD001"),
								"quantity":   Integer(2),
							}),
							"cost": matchers.Like(Map{
								"currency_code": S("USD"),
								"units":         Integer(25),
								"nanos":         Integer(0),
							}),
						}, 1),
					}),
				})
		}).
		WillRespondWith(200, func(b *consumer.V4ResponseBuilder) {
			b.Header("Content-Type", S("text/html"))
		}).
		ExecuteTest(t, func(config consumer.MockServerConfig) error {
			t.Logf("Port: %d", config.Port)
			cs := &checkout{
				emailSvcAddr: fmt.Sprintf("http://%s:%d", config.Host, config.Port),
				httpClient:   &http.Client{},
			}
			orderResult := &pb.OrderResult{
				OrderId:            "100",
				ShippingTrackingId: "TRACK123456",
				ShippingCost:       &pb.Money{CurrencyCode: "USD", Units: 10, Nanos: 500000000},
				ShippingAddress: &pb.Address{
					StreetAddress: "123 Main St",
					City:            "San Francisco",
					Country:         "USA",
					ZipCode:         "94105",
				},
				Items: []*pb.OrderItem{
					{
						Item: &pb.CartItem{
							ProductId: "PROD001",
							Quantity:  2,
						},
						Cost: &pb.Money{CurrencyCode: "USD", Units: 25, Nanos: 1},
					},
				},
			}
			return cs.sendOrderConfirmation(context.Background(), "customer@example.com", orderResult)
		})
	assert.NoError(t, err)
}

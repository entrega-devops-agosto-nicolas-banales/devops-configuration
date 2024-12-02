#!/bin/sh

PAYMENTS_SERVICE_URL=${PAYMENTS_SERVICE_URL:-"http://payments-service-alb-1611589606.us-east-1.elb.amazonaws.com"}
SHIPPING_SERVICE_URL=${SHIPPING_SERVICE_URL:-"http://shipping-service-alb-15976227.us-east-1.elb.amazonaws.com"}
PRODUCTS_SERVICE_URL=${PRODUCTS_SERVICE_URL:-"http://products-service-alb-110946858.us-east-1.elb.amazonaws.com"}

java -jar /app.jar "$PAYMENTS_SERVICE_URL" "$SHIPPING_SERVICE_URL" "$PRODUCTS_SERVICE_URL"

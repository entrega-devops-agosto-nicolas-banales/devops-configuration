#!/bin/sh
java -jar /app.jar "http://products-service-alb-110946858.us-east-1.elb.amazonaws.com" "http://shipping-service-alb-15976227.us-east-1.elb.amazonaws.com" "http://payments-service-alb-1611589606.us-east-1.elb.amazonaws.com"


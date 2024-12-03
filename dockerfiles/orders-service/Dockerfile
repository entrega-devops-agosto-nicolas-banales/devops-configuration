FROM openjdk:11-jdk-slim

WORKDIR /app

COPY target/orders-service-example-0.0.1-SNAPSHOT-spring-boot.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app.jar", \
    "http://payments-service-alb-1611589606.us-east-1.elb.amazonaws.com", \
    "http://shipping-service-alb-15976227.us-east-1.elb.amazonaws.com", \
    "http://products-service-alb-110946858.us-east-1.elb.amazonaws.com"]

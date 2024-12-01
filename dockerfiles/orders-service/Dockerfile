# Base image
FROM openjdk:11-jdk-slim

WORKDIR /app

COPY target/orders-service-example-0.0.1-SNAPSHOT-spring-boot.jar app.jar

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8080

ENV PAYMENTS_SERVICE_ENDPOINT=""
ENV SHIPPING_SERVICE_ENDPOINT=""
ENV PRODUCTS_SERVICE_ENDPOINT=""

ENTRYPOINT ["/start.sh"]

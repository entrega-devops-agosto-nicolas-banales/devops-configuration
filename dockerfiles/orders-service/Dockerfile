# Imagen base
FROM openjdk:11-jdk-slim

# Directorio
WORKDIR /app

# Jar luego de compilar
COPY target/orders-service-example-0.0.1-SNAPSHOT-spring-boot.jar app.jar

# Puerto
EXPOSE 8080

# Argumentos para ECS
ENV PAYMENTS_SERVICE_ENDPOINT=""
ENV PRODUCTS_SERVICE_ENDPOINT=""
ENV SHIPPING_SERVICE_ENDPOINT=""

# Punto de entrada
ENTRYPOINT java -jar /app.jar \
  "$PAYMENTS_SERVICE_ENDPOINT" \
  "$PRODUCTS_SERVICE_ENDPOINT" \
  "$SHIPPING_SERVICE_ENDPOINT"
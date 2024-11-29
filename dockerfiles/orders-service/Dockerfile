# Imagen base
FROM openjdk:11-jdk-slim

# Directorio
WORKDIR /app

# Jar luego de compilar
COPY target/orders-service-example-0.0.1-SNAPSHOT-spring-boot.jar app.jar

# Puerto
EXPOSE 8080

# Punto de entrada
ENTRYPOINT ["java", "-jar", "/app.jar"]

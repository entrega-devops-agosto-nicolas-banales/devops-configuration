# Base image
FROM openjdk:11-jdk-slim

WORKDIR /app

COPY target/orders-service-example-0.0.1-SNAPSHOT-spring-boot.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app.jar"]

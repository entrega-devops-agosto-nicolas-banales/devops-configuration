FROM openjdk:11-jdk-slim

WORKDIR /app

COPY target/shipping-service-example-0.0.1-SNAPSHOT-spring-boot.jar app.jar

EXPOSE 8080

CMD ["java", "-jar", "app.jar"]

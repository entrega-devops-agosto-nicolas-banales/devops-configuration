FROM openjdk:11-jdk-slim

ARG JAR_FILE=orders-service-example-0.0.1-SNAPSHOT.jar

COPY target/${JAR_FILE} app.jar

CMD java -jar /app.jar $APP_ARGS

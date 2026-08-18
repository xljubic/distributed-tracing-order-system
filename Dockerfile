FROM maven:3.9.9-eclipse-temurin-17 AS build

WORKDIR /workspace

COPY . .

ARG MODULE

RUN mvn -B -pl "${MODULE}" -am clean package -DskipTests


FROM alpine:3.21 AS otel-agent

ARG OTEL_VERSION=2.25.0

RUN wget -q     "https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v${OTEL_VERSION}/opentelemetry-javaagent.jar"     -O /opentelemetry-javaagent.jar


FROM eclipse-temurin:17-jre

WORKDIR /app

ARG MODULE

COPY --from=build /workspace/${MODULE}/target/${MODULE}-0.0.1-SNAPSHOT.jar /app/app.jar
COPY --from=otel-agent /opentelemetry-javaagent.jar /otel/opentelemetry-javaagent.jar

ENTRYPOINT ["java", "-jar", "/app/app.jar"]

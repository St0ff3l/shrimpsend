FROM eclipse-temurin:17-jdk-alpine AS build
WORKDIR /app
COPY . .
RUN ./gradlew bootJar --no-daemon

FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=build /app/build/libs/ultrasend-backend-*.jar app.jar
EXPOSE 9000
ENTRYPOINT ["java", "-jar", "app.jar"]

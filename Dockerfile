# Stage 1: Build the application
FROM maven:3.9-eclipse-temurin-21 AS build

# Set the working directory
WORKDIR /app

# Copy the pom.xml file first to leverage Docker cache
COPY pom.xml .

# Download dependencies - this layer will be cached unless pom.xml changes
RUN mvn dependency:go-offline -B

# Copy the source code
COPY src ./src

# Build the application
RUN mvn clean compile package -DskipTests

# Stage 2: Create the runtime image
FROM eclipse-temurin:21-jre-alpine

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Create a non-root user to run the application
RUN addgroup -g 1000 java && adduser -u 1000 -G java -s /bin/sh -D java

# Set the working directory
WORKDIR /app

# Copy the compiled classes and dependencies
COPY --from=build /app/target/classes ./classes
COPY --from=build /app/target/dependency ./lib

# Copy the JAR file if building as JAR
COPY --from=build /app/target/*.jar ./app.jar

# Change ownership of the application files
RUN chown -R java:java /app

# Switch to the non-root user
USER java:java

# Expose the port your app runs on
ENV PORT=8080
EXPOSE $PORT

# Use dumb-init to run the application
ENTRYPOINT ["dumb-init", "--"]

# Run the Java application with Java 21 optimizations
# Option 1: If running from JAR file
CMD ["java", "-XX:+UseZGC", "-XX:MaxRAMPercentage=75.0", "-jar", "app.jar"]
# Option 2: If running from classes (uncomment and modify main class)
# CMD ["java", "-XX:+UseZGC", "-XX:MaxRAMPercentage=75.0", "-cp", "classes:lib/*", "com.example.Main"]

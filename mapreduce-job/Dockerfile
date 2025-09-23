FROM maven:3.8-openjdk-8-slim

WORKDIR /app

# Copiar pom.xml primero para aprovechar la cache de Docker
COPY pom.xml .

# Descargar dependencias
RUN mvn dependency:go-offline

# Copiar código fuente
COPY src ./src

# Compilar por defecto
CMD ["mvn", "clean", "package"]

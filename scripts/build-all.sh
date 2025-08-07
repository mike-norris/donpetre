#!/bin/bash
# scripts/build-all.sh - SIMPLE VERSION

echo "🔨 Building DonPetre Platform..."

# Build parent
mvn clean install -N

# Build gateway (uses existing code)
cd donpetre-gateway
mvn clean package -DskipTests
cd ..

# Build ingestion (new service)
cd donpetre-knowledge-ingestion  
mvn clean package -DskipTests
cd ..

# Build management service
cd donpetre-management-service
mvn clean package -DskipTests
cd ..

# Build UI (React.js)
cd donpetre-ui
mvn clean package -DskipTests
cd ..

echo "✅ Build complete!"

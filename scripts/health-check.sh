#!/bin/bash
# Health check script for all services

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_service() {
    local service_name=$1
    local url=$2
    local timeout=${3:-10}
    
    echo -n "Checking $service_name... "
    
    if curl -f -s --max-time $timeout "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Healthy${NC}"
        return 0
    else
        echo -e "${RED}✗ Unhealthy${NC}"
        return 1
    fi
}

echo "🏥 DonPetre Services Health Check"
echo "================================="

# Check database
echo -n "Checking PostgreSQL... "
if docker-compose exec -T postgresql pg_isready -U donpetre > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Connected${NC}"
else
    echo -e "${RED}✗ Not responding${NC}"
fi

# Check Redis
echo -n "Checking Redis... "
if docker-compose exec -T redis redis-cli ping > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Connected${NC}"
else
    echo -e "${RED}✗ Not responding${NC}"
fi

# Check services
check_service "API Gateway" "http://localhost:8080/actuator/health"
check_service "Knowledge Ingestion" "http://localhost:8081/actuator/health"

echo ""
echo "📊 Container Status:"
docker-compose ps

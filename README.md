# DonPetre Knowledge Platform

A comprehensive knowledge management platform that integrates with external services (GitHub, GitLab, JIRA) to automatically collect, analyze, and provide insights from development data. Built as a microservices architecture using Spring Boot and reactive programming.

## 🚀 Quick Start

### Prerequisites
- Java 17+
- Docker & Docker Compose
- Git
- curl (for health checks)

### Initial Setup
```bash
# 1. Clone and navigate to project
cd donpetre

# 2. Initial setup (creates scripts, secrets, Maven wrapper)
make setup

# 3. Generate security secrets
make secrets

# 4. Start development environment
make dev
```

The platform will be available at:
- **Web UI**: http://localhost:8084
- **API Gateway**: http://localhost:8080
- **Knowledge Ingestion**: http://localhost:8081  
- **Management Service**: http://localhost:8082
- **Search Service**: http://localhost:8083
- **Database**: PostgreSQL on port 5432
- **Cache**: Redis on port 6379

### Default Credentials
- **Username**: `admin`
- **Password**: `password123`

**⚠️ Change default credentials immediately in production!**

## 🏗️ Architecture

### Microservices
- **API Gateway** (Port 8080): Authentication, routing, rate limiting with Spring Cloud Gateway
- **Knowledge Ingestion** (Port 8081): Data ingestion from external APIs (GitHub, JIRA)
- **Management Service** (Port 8082): CRUD operations, tagging, user management
- **Search Service** (Port 8083): Python Flask/FastAPI service with Elasticsearch/PostgreSQL full-text search
- **Web UI** (Port 8084): Next.js frontend with responsive design

### Technology Stack
- **Java 17**, Spring Boot 3.5.3, Spring Cloud 2025.0.0
- **Spring WebFlux** (reactive), **Spring Security**, **Spring Cloud Gateway**
- **PostgreSQL** with R2DBC (reactive database access)
- **Redis** for caching and session management
- **External APIs**: GitHub API, GitLab4J, JIRA REST Client
- **Circuit breakers** with Resilience4j
- **JWT authentication** with JJWT library
- **Docker** containerization

## 🛠️ Development Commands

### Primary Commands (Use Makefile)
```bash
make help          # Show all available commands
make setup         # Initial project setup with Maven wrapper and scripts
make build         # Build all services (calls scripts/build-all.sh)
make test          # Run all tests (mvn test)
make start         # Start all services with Docker Compose
make dev           # Complete development setup (secrets + start + health check)
make stop          # Stop all services
make restart       # Restart all services (stop + start)
make clean         # Clean build artifacts and containers
make logs          # Show logs for all services
make health        # Check all service health endpoints
make monitor       # Show resource usage
```

### Service-Specific Commands
```bash
make logs-gateway     # Show gateway logs
make logs-ingestion   # Show ingestion service logs
make shell-gateway    # Shell into gateway container
make shell-ingestion  # Shell into ingestion container
make shell-db         # Shell into PostgreSQL database
```

### Maven Commands
```bash
# Build entire project
mvn clean install

# Build specific module
cd donpetre-gateway && mvn clean package

# Run tests
mvn test                    # Unit tests only
mvn verify                  # Integration tests
mvn test -Dtest='*UnitTest' # Quick unit tests only

# Profiles
mvn clean package -Pprod            # Production build
mvn clean package -DskipTests       # Skip tests
mvn clean package -Pintegration-tests # Run integration tests
```

### Docker Operations
```bash
docker-compose up -d --build    # Start all services
docker-compose logs -f          # View logs
docker-compose down             # Stop services
docker-compose ps               # Check service status
```

## 🗄️ Database Operations

### Database Schema
PostgreSQL with reactive R2DBC access. Key entities:
- **Users, Roles, RefreshTokens** (authentication)
- **KnowledgeSources, KnowledgeItems** (content management)
- **ConnectorConfigs, IngestionJobs** (data ingestion)
- **Full-text search** with tsvector and triggers

### Database Access
```bash
# Direct database access
make shell-db

# Or via Docker
docker exec -it donpetre-postgres psql -U donpetre -d donpetre

# Common queries
SELECT * FROM users;
SELECT * FROM knowledge_items LIMIT 10;
SELECT * FROM knowledge_sources WHERE is_active = true;
```

## 🔐 Security & Authentication

### JWT Configuration
- **Algorithm**: RS256 with rotating keys
- **Access tokens**: 24 hours expiry
- **Refresh tokens**: 7 days expiry with rotation
- **Secrets**: Stored in `secrets/` directory (gitignored)

### Security Implementation
- JWT tokens with RS256 algorithm
- Refresh token rotation
- Role-based access control (ADMIN, USER)
- Circuit breakers on external calls
- BCrypt password hashing (strength 12)

### Secrets Management
```bash
# Generate new secrets
make secrets

# Or manually
./scripts/generate-secrets.sh

# Validate existing secrets
./scripts/generate-secrets.sh --validate
```

Generated secrets are stored in:
- `secrets/jwt_secret.txt`
- `secrets/db_password.txt`
- `secrets/redis_password.txt`
- `secrets/encryption_key.txt`

## 🔗 API Documentation & Swagger

### Swagger/OpenAPI Endpoints
- **API Gateway**: http://localhost:8080/swagger-ui.html
- **Knowledge Ingestion**: http://localhost:8081/swagger-ui.html
- **Management Service**: http://localhost:8082/swagger-ui.html

### Key API Endpoints
```bash
# Authentication
POST /api/auth/authenticate    # Login
POST /api/auth/register       # Register new user
POST /api/auth/refresh-token  # Refresh JWT token
GET  /api/auth/me            # Get current user info

# Knowledge Management
GET    /api/knowledge/items         # List knowledge items
POST   /api/knowledge/items         # Create knowledge item
GET    /api/knowledge/items/{id}    # Get specific item
PUT    /api/knowledge/items/{id}    # Update knowledge item
DELETE /api/knowledge/items/{id}    # Delete knowledge item

# Data Ingestion
GET    /api/ingestion/sources       # List knowledge sources
POST   /api/ingestion/sources       # Create new source
POST   /api/ingestion/sync/{id}     # Trigger manual sync
GET    /api/ingestion/jobs          # List ingestion jobs

# Search
GET    /api/search/items            # Full-text search
GET    /api/search/analytics        # Search analytics

# Health & Monitoring
GET    /actuator/health            # Service health
GET    /actuator/metrics           # Application metrics
GET    /actuator/info              # Application info
```

### Sample API Usage
```bash
# Login
curl -X POST http://localhost:8080/api/auth/authenticate \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"password123"}'

# Use the returned access token for authenticated requests
TOKEN="eyJhbGciOiJIUzUxMiJ9..."

# Get knowledge items
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8080/api/knowledge/items

# Create a knowledge item
curl -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"Test Item","content":"Test content"}' \
  http://localhost:8080/api/knowledge/items
```

## 🔄 External Integrations

### GitHub Integration
1. Create GitHub Personal Access Token with `repo` permissions
2. Configure in Knowledge Sources via API:
   ```bash
   curl -X POST -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "name": "My Repo",
       "type": "github",
       "configuration": {
         "token": "ghp_...",
         "owner": "username", 
         "repo": "repository"
       }
     }' \
     http://localhost:8081/api/sources
   ```

### JIRA Integration
1. Get JIRA API credentials
2. Configure via API:
   ```bash
   curl -X POST -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "name": "JIRA Project",
       "type": "jira",
       "configuration": {
         "url": "https://company.atlassian.net",
         "username": "email@company.com",
         "token": "api_token"
       }
     }' \
     http://localhost:8081/api/sources
   ```

## 📊 Monitoring & Health Checks

### Health Endpoints
```bash
# Check all services
make health

# Individual health checks
curl http://localhost:8080/actuator/health  # Gateway
curl http://localhost:8081/actuator/health  # Ingestion
curl http://localhost:8082/actuator/health  # Management
curl http://localhost:8083/health/live      # Search Service
```

### Logging
- **Service logs**: `logs/` directory
- **Docker logs**: `docker-compose logs -f [service]`
- **Log levels**: Configurable via `application.yml`

### Performance Monitoring
```bash
# Resource usage
make monitor

# Container stats
docker stats

# Database connections
docker exec -it donpetre-postgres psql -U donpetre -d donpetre -c "SELECT count(*) FROM pg_stat_activity;"
```

## 🧪 Testing

### Test Types
- **Unit tests**: `*Test.java` files
- **Integration tests**: `*IntegrationTest.java` or `*IT.java` files
- **TestContainers**: Used for integration testing with real databases

### Running Tests
```bash
# All tests
make test

# Unit tests only
mvn test

# Integration tests
mvn verify

# Quick unit tests
make quick-test

# Specific test pattern
mvn test -Dtest='*ConnectorTest'

# With coverage
mvn test jacoco:report
```

## 🚨 Troubleshooting

### Common Issues

#### Authentication Not Working
```bash
# Check if gateway is healthy
curl http://localhost:8080/actuator/health

# Check database connection
make shell-db

# Verify user exists
SELECT * FROM users WHERE username = 'admin';

# Check application logs
make logs-gateway
```

#### Services Not Starting
```bash
# Check all service status
docker-compose ps

# Check individual service logs
make logs-gateway
make logs-ingestion

# Restart services
make restart

# Clean restart
make clean
make dev
```

#### Database Issues
```bash
# Connect to database
make shell-db

# Check database size
SELECT pg_database_size('donpetre');

# Check active connections
SELECT count(*) FROM pg_stat_activity;

# Reset database (DESTRUCTIVE)
make clean
make dev
```

### Environment Reset

#### Complete Environment Wipe
```bash
# Stop all services and remove everything
make clean

# Remove all Docker data (DESTRUCTIVE)
docker system prune -a --volumes

# Remove generated secrets
rm -rf secrets/

# Start fresh
make setup
make dev
```

#### Quick Restart
```bash
# Restart just application containers
make quick-restart

# Or restart everything
make restart
```

## 🔧 Development Workflow

### Code Standards
- **Java**: Follow Spring Boot conventions
- **Testing**: Minimum 85% code coverage
- **Documentation**: Update README and API docs
- **Security**: Never commit secrets, use proper authentication

### Build Process
```bash
# Development build
make build

# Production build
make prod-build

# Quick build (skip tests)
make quick-build

# Format code
make format

# Security check
make security-check
```

## 📈 Resource Requirements

### Development Environment
- **CPU**: 4+ cores recommended
- **Memory**: 8GB+ RAM recommended
- **Storage**: 10GB+ available space
- **Network**: Internet connection for external API calls

### Production Recommendations
- **CPU**: 8+ cores
- **Memory**: 16GB+ RAM
- **Storage**: 100GB+ SSD
- **Database**: Dedicated PostgreSQL instance
- **Load Balancer**: For API Gateway clustering
- **Monitoring**: APM solution (New Relic, DataDog, etc.)

### Container Resource Limits
```yaml
# Current Docker resource allocations
api-gateway:        CPU: 2 cores, Memory: 1GB
knowledge-ingestion: CPU: 1 core,  Memory: 768MB
management-service:  CPU: 1 core,  Memory: 768MB
search-service:      CPU: 1 core,  Memory: 512MB
postgresql:          CPU: 2 cores, Memory: 1GB
redis:               CPU: 0.5 core, Memory: 256MB
```

## 📝 Configuration Files

### Key Configuration Files
- **Gateway**: `donpetre-gateway/src/main/resources/application.yml`
- **Ingestion**: `donpetre-knowledge-ingestion/src/main/resources/application.yml`
- **Database init**: `donpetre-gateway/init-scripts/01-init-schema.sql`
- **Docker**: `docker-compose.yml`
- **Build**: `Makefile`, `pom.xml`

### Environment Variables
Key environment variables in `.env`:
```bash
DB_USER=donpetre
DB_PASSWORD=<generated>
REDIS_PASSWORD=<generated>
JWT_SECRET_KEY=<generated>
JWT_BACKUP_SECRET=<generated>
ENCRYPTION_SECRET_KEY=<generated>
GITHUB_TOKEN=<optional>
JIRA_URL=<optional>
JIRA_USERNAME=<optional>
JIRA_TOKEN=<optional>
```

## 🤝 Contributing

### Development Process
1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes following code standards
4. Run tests: `make test`
5. Update documentation as needed
6. Submit a pull request

### Code Review Checklist
- [ ] Tests pass (`make test`)
- [ ] Code follows project conventions
- [ ] Documentation updated
- [ ] No secrets in commits
- [ ] Security considerations addressed
- [ ] Performance impact assessed

## 📄 License

Copyright © 2025 OpenRange Labs. All rights reserved.

---

## 📞 Support

For questions, issues, or support:
- Create an issue in the repository
- Contact the development team
- Check the troubleshooting section above

**Last Updated**: January 2025
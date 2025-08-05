# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DonPetre is a knowledge management platform that integrates with external services (GitHub, GitLab, JIRA) to automatically collect, analyze, and provide insights from development data. It's built as a microservices architecture using Spring Boot.

## Architecture

### Multi-Module Maven Project
- **Root POM** (`pom.xml`): Manages dependencies and build configuration for all modules
- **donpetre-gateway**: API Gateway service (Port 8080) - Authentication, routing, rate limiting with Spring Cloud Gateway
- **donpetre-knowledge-ingestion**: Data ingestion service (Port 8081) - Collects data from external APIs (GitHub, JIRA)
- **donpetre-management-service**: Knowledge Management Service (Port 8082) - CRUD operations for knowledge items, Tagging and categorization, User management and permissions
- **donpetre-search-service**: Search Service (Port 8083) - Python Flask/FastAPI service, Elasticsearch or PostgreSQL full-text search, NLP processing (spaCy/NLTK), Semantic similarity scoring
- **donpetre-ui**: Web UI Service (Port 8084) - React frontend or Thymeleaf templates, Knowledge browsing and search interface, Admin dashboard

### Technology Stack
- Java 17, Spring Boot 3.5.3, Spring Cloud 2025.0.0
- Spring WebFlux (reactive), Spring Security, Spring Cloud Gateway
- PostgreSQL with R2DBC (reactive database access)
- Redis for caching and session management
- External APIs: GitHub API, GitLab4J, JIRA REST Client
- Circuit breakers with Resilience4j
- JWT authentication with JJWT library
- Docker containerization

### Key Patterns
- Reactive programming with WebFlux throughout
- Circuit breaker pattern for external service calls
- JWT-based authentication with refresh tokens
- Database schema with full-text search capabilities
- Microservice communication through API Gateway

## Build and Development Commands

### Primary Commands (use Makefile)
```bash
make help          # Show all available commands
make setup         # Initial project setup with Maven wrapper and scripts
make build         # Build all services (calls scripts/build-all.sh)
make test          # Run all tests (mvn test)
make start         # Start all services with Docker Compose
make dev           # Complete development setup (secrets + start + health check)
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
```

### Development Scripts
- `scripts/build-all.sh`: Builds parent POM and all modules
- `scripts/dev-setup.sh`: Complete development environment setup
- `scripts/generate-secrets.sh`: Generates secure JWT and database secrets
- `scripts/health-check.sh`: Checks all service health endpoints

## Key Configuration Files

### Application Configuration
- Gateway: `donpetre-gateway/src/main/resources/application.yml`
- Ingestion: `donpetre-knowledge-ingestion/src/main/resources/application.yml`
- Database init: `donpetre-gateway/init-scripts/01-init-schema.sql`

### Security
- JWT configuration in `JwtSecurityConfig.java` and `JwtService.java`
- Circuit breaker config in `CircuitBreakerConfiguration.java`
- Generated secrets stored in `secrets/` directory (gitignored)

## Database Schema

PostgreSQL with reactive R2DBC access. Key entities:
- Users, Roles, RefreshTokens (authentication)
- KnowledgeSources, KnowledgeItems (content management) 
- ConnectorConfigs, IngestionJobs (data ingestion)
- Full-text search with tsvector and triggers

## External Integrations

### GitHub Integration
- Uses `org.kohsuke:github-api` library
- Implemented in `GitHubConnector.java`
- Requires `GITHUB_TOKEN` environment variable

### JIRA Integration  
- Uses Atlassian JIRA REST client
- Configuration stored encrypted in database
- Supports credential management through REST APIs

## Testing Strategy

### Test Types
- Unit tests: `*Test.java` files
- Integration tests: `*IntegrationTest.java` or `*IT.java` files
- TestContainers used for integration testing

### Running Tests
```bash
mvn test                           # Unit tests only
mvn verify                         # All tests including integration
mvn test -Dtest='*ConnectorTest'   # Specific test pattern
```

## Common Development Patterns

### Service Layer Structure
Each service follows standard Spring patterns:
- `@RestController` for API endpoints
- `@Service` for business logic  
- `@Repository` for data access (R2DBC reactive)
- DTOs for request/response mapping
- Global exception handling with `@ControllerAdvice`

### Reactive Programming
All database and external API calls use reactive types:
- `Mono<T>` for single values
- `Flux<T>` for multiple values
- R2DBC for reactive database access
- WebClient for external HTTP calls

### Security Implementation
- JWT tokens with RS256 algorithm
- Refresh token rotation
- Role-based access control
- Circuit breakers on external calls

## Monitoring and Health

### Health Endpoints
- Gateway: `http://localhost:8080/actuator/health`
- Ingestion: `http://localhost:8081/actuator/health`
- Custom health indicators for circuit breakers

### Logging
- Centralized logging configuration
- Service-specific log files in `logs/` directory
- Docker Compose aggregated logging

## Environment Setup

1. **Initial Setup**: Run `make setup` to create Maven wrapper and development scripts
2. **Secrets**: Run `make secrets` to generate JWT and database passwords  
3. **Development**: Run `make dev` for complete development environment
4. **Health Check**: Use `make health` to verify all services are running

The platform follows a Saturday/Sunday development schedule with deep work on Saturdays and integration/testing on Sundays.
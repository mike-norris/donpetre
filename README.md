# DonPetre Knowledge Platform

A comprehensive knowledge management platform that integrates with GitLab, GitHub, and JIRA to automatically generate documentation, analytics, and reports.

## 🚀 Quick Start

### Prerequisites
- Java 17+
- Docker & Docker Compose
- Git

### Setup and Run
```bash
# 1. Clone and setup
git clone <repository-url>
cd donpetre
make setup

# 2. Start services
make dev

# 3. Check health
make health
```

The platform will be available at:
- API Gateway: http://localhost:8080
- Knowledge Ingestion: http://localhost:8081
- Database: PostgreSQL on port 5432
- Cache: Redis on port 6379

## 🏗️ Architecture

### Microservices
- **API Gateway** (Port 8080): Authentication, routing, rate limiting
- **Knowledge Ingestion** (Port 8081): Data collection from external sources
- **Knowledge Management** (Port 8082): CRUD operations and business logic
- **Search Service** (Port 8083): Full-text search and analytics

### Technology Stack
- **Backend**: Spring Boot 3.5.3, Java 17
- **Database**: PostgreSQL 15+ with full-text search
- **Cache**: Redis for session management and caching
- **Message Queue**: Redis for async processing
- **Containerization**: Docker & Docker Compose

## 🛠️ Development

### Available Commands
```bash
make help          # Show all available commands
make setup         # Initial project setup
make build         # Build all services
make test          # Run tests
make start         # Start all services
make stop          # Stop all services
make clean         # Clean build artifacts
make logs          # Show service logs
make health        # Check service health
```

### Development Workflow
1. **Saturday (6 hours)**: Deep development work
2. **Sunday (4 hours)**: Testing, integration, documentation
3. **Weekdays**: Planning and quick fixes

### Configuration
Edit `.env` file to configure:
- Database credentials
- External service API tokens (GitHub, JIRA)
- JWT secrets
- Service endpoints

## 🔐 Security

### Secrets Management
```bash
# Generate new secrets
./scripts/generate-secrets.sh

# Validate existing secrets
./scripts/generate-secrets.sh --validate
```

### Default Credentials
- **Admin User**: admin@donpetre.com / admin123
- **Database**: donpetre / (generated password in secrets/)

**⚠️ Change default credentials immediately in production!**

## 📊 Monitoring

### Health Checks
```bash
# Check all services
make health

# Individual service logs
make logs-gateway
make logs-ingestion

# Resource usage
make monitor
```

### Endpoints
- Gateway Health: http://localhost:8080/actuator/health
- Ingestion Health: http://localhost:8081/actuator/health
- Metrics: http://localhost:8080/actuator/metrics

## 🔄 Integration

### GitHub Integration
1. Create GitHub Personal Access Token
2. Add to `.env`: `GITHUB_TOKEN=your_token_here`
3. Configure repositories in Knowledge Sources

### JIRA Integration
1. Get JIRA API credentials
2. Add to `.env`:
   ```
   JIRA_URL=https://your-domain.atlassian.net
   JIRA_USERNAME=your_email
   JIRA_TOKEN=your_api_token
   ```

## 📈 Features

### Current
- ✅ User authentication and authorization
- ✅ GitHub repository scanning
- ✅ JIRA issue tracking
- ✅ Full-text search
- ✅ RESTful APIs
- ✅ Docker containerization

### Roadmap
- 🔄 Advanced analytics and reporting
- 🔄 Risk assessment and compliance checking
- 🔄 Developer performance metrics
- 🔄 Automated documentation generation
- 🔄 ML-powered insights

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `make test`
5. Submit a pull request

## 📝 License

Copyright © 2025 OpenRange Labs. All rights reserved.

---

For questions or support, contact the development team.

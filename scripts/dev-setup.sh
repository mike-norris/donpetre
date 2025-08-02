#!/bin/bash
# scripts/dev-setup.sh - Development environment setup

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}🔧 DonPetre Development Environment Setup${NC}"

# Function to create Maven wrapper if it doesn't exist
setup_maven_wrapper() {
    echo -e "${BLUE}Setting up Maven wrapper...${NC}"
    
    if [ ! -f "mvnw" ]; then
        if command -v mvn >/dev/null 2>&1; then
            mvn wrapper:wrapper
        else
            echo -e "${YELLOW}⚠️ Maven not found. Downloading wrapper manually...${NC}"
            
            # Create .mvn directory
            mkdir -p .mvn/wrapper
            
            # Download Maven wrapper files
            curl -o .mvn/wrapper/maven-wrapper.properties \
                https://repo.maven.apache.org/maven2/org/apache/maven/wrapper/maven-wrapper/3.2.0/maven-wrapper-3.2.0.pom
            
            curl -o .mvn/wrapper/maven-wrapper.jar \
                https://repo.maven.apache.org/maven2/org/apache/maven/wrapper/maven-wrapper/3.2.0/maven-wrapper-3.2.0.jar
            
            curl -o mvnw \
                https://raw.githubusercontent.com/apache/maven/master/maven-wrapper/src/main/resources/mvnw
            
            curl -o mvnw.cmd \
                https://raw.githubusercontent.com/apache/maven/master/maven-wrapper/src/main/resources/mvnw.cmd
            
            chmod +x mvnw
        fi
    fi
    
    echo -e "${GREEN}✓ Maven wrapper ready${NC}"
}

# Function to create database initialization script
create_db_init_script() {
    echo -e "${BLUE}Creating database initialization script...${NC}"
    
    mkdir -p scripts
    
    cat > scripts/init-db.sql << 'EOF'
-- DonPetre Knowledge Platform Database Schema
-- Initialize core tables for the platform

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    is_admin BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create roles table
CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create user_roles junction table
CREATE TABLE IF NOT EXISTS user_roles (
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    role_id UUID REFERENCES roles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, role_id)
);

-- Create refresh_tokens table
CREATE TABLE IF NOT EXISTS refresh_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    token VARCHAR(255) UNIQUE NOT NULL,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    expires_at TIMESTAMP NOT NULL,
    is_revoked BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create knowledge_sources table
CREATE TABLE IF NOT EXISTS knowledge_sources (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL, -- 'github', 'jira', 'slack', etc.
    configuration JSONB NOT NULL, -- API keys, repo URLs, etc.
    last_sync TIMESTAMP,
    sync_frequency_minutes INTEGER DEFAULT 60,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create knowledge_items table
CREATE TABLE IF NOT EXISTS knowledge_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(500) NOT NULL,
    content TEXT,
    summary TEXT,
    source_id UUID REFERENCES knowledge_sources(id) ON DELETE CASCADE,
    source_reference VARCHAR(255), -- GitHub commit hash, Jira ticket ID, etc.
    source_url TEXT,
    author VARCHAR(100),
    item_type VARCHAR(50), -- 'commit', 'issue', 'comment', 'document'
    status VARCHAR(50) DEFAULT 'active',
    metadata JSONB, -- Additional structured data
    search_vector tsvector, -- PostgreSQL full-text search
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create tags table
CREATE TABLE IF NOT EXISTS tags (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) UNIQUE NOT NULL,
    color VARCHAR(7) DEFAULT '#007bff', -- hex color code
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create knowledge_item_tags junction table
CREATE TABLE IF NOT EXISTS knowledge_item_tags (
    knowledge_item_id UUID REFERENCES knowledge_items(id) ON DELETE CASCADE,
    tag_id UUID REFERENCES tags(id) ON DELETE CASCADE,
    confidence_score DECIMAL(3,2) DEFAULT 1.0, -- For ML-generated tags
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (knowledge_item_id, tag_id)
);

-- Create sync_jobs table for tracking ingestion jobs
CREATE TABLE IF NOT EXISTS sync_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_id UUID REFERENCES knowledge_sources(id) ON DELETE CASCADE,
    status VARCHAR(50) DEFAULT 'pending', -- 'pending', 'running', 'completed', 'failed'
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    items_processed INTEGER DEFAULT 0,
    items_created INTEGER DEFAULT 0,
    items_updated INTEGER DEFAULT 0,
    error_message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_knowledge_items_source ON knowledge_items(source_id);
CREATE INDEX IF NOT EXISTS idx_knowledge_items_type ON knowledge_items(item_type);
CREATE INDEX IF NOT EXISTS idx_knowledge_items_created ON knowledge_items(created_at);
CREATE INDEX IF NOT EXISTS idx_knowledge_items_search ON knowledge_items USING gin(search_vector);
CREATE INDEX IF NOT EXISTS idx_knowledge_sources_type ON knowledge_sources(type);
CREATE INDEX IF NOT EXISTS idx_sync_jobs_status ON sync_jobs(status);
CREATE INDEX IF NOT EXISTS idx_sync_jobs_source ON sync_jobs(source_id);

-- Create function to update search vector
CREATE OR REPLACE FUNCTION update_search_vector() RETURNS trigger AS $$
BEGIN
    NEW.search_vector := 
        setweight(to_tsvector('english', COALESCE(NEW.title, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(NEW.summary, '')), 'B') ||
        setweight(to_tsvector('english', COALESCE(NEW.content, '')), 'C') ||
        setweight(to_tsvector('english', COALESCE(NEW.author, '')), 'D');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update search vector
DROP TRIGGER IF EXISTS trigger_update_search_vector ON knowledge_items;
CREATE TRIGGER trigger_update_search_vector
    BEFORE INSERT OR UPDATE ON knowledge_items
    FOR EACH ROW EXECUTE FUNCTION update_search_vector();

-- Insert default roles
INSERT INTO roles (name, description) VALUES 
    ('ADMIN', 'System administrator with full access'),
    ('USER', 'Regular user with read access'),
    ('MANAGER', 'Team manager with write access to team resources')
ON CONFLICT (name) DO NOTHING;

-- Insert default tags
INSERT INTO tags (name, color, description) VALUES 
    ('bug', '#dc3545', 'Bug reports and fixes'),
    ('feature', '#28a745', 'New features and enhancements'),
    ('documentation', '#17a2b8', 'Documentation updates'),
    ('urgent', '#ffc107', 'High priority items'),
    ('backend', '#6f42c1', 'Backend development'),
    ('frontend', '#e83e8c', 'Frontend development'),
    ('api', '#fd7e14', 'API related changes'),
    ('security', '#6c757d', 'Security related items')
ON CONFLICT (name) DO NOTHING;

-- Create a default admin user (password: admin123)
-- Note: In production, this should be changed immediately
INSERT INTO users (username, email, password_hash, first_name, last_name, is_admin) VALUES 
    ('admin', 'admin@donpetre.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Admin', 'User', true)
ON CONFLICT (username) DO NOTHING;

-- Assign admin role to admin user
INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id 
FROM users u, roles r 
WHERE u.username = 'admin' AND r.name = 'ADMIN'
ON CONFLICT DO NOTHING;

COMMIT;
EOF

    echo -e "${GREEN}✓ Database initialization script created${NC}"
}

# Function to create health check script
create_health_check_script() {
    echo -e "${BLUE}Creating health check script...${NC}"
    
    cat > scripts/health-check.sh << 'EOF'
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
EOF

    chmod +x scripts/health-check.sh
    echo -e "${GREEN}✓ Health check script created${NC}"
}

# Function to create secret generation script
create_secret_generation_script() {
    echo -e "${BLUE}Creating secret generation script...${NC}"
    
    cat > scripts/generate-secrets.sh << 'EOF'
#!/bin/bash
# Secret generation script for DonPetre platform

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SECRETS_DIR="./secrets"

# Function to generate a secure random string
generate_secret() {
    local length=${1:-88}
    openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
}

# Function to validate secret strength
validate_secret() {
    local secret=$1
    local min_length=${2:-64}
    
    if [ ${#secret} -lt $min_length ]; then
        echo -e "${RED}✗ Secret too short (minimum $min_length characters)${NC}"
        return 1
    fi
    
    if [[ ! "$secret" =~ [A-Z] ]] || [[ ! "$secret" =~ [a-z] ]] || [[ ! "$secret" =~ [0-9] ]]; then
        echo -e "${YELLOW}⚠️ Secret may not be complex enough${NC}"
        return 0
    fi
    
    echo -e "${GREEN}✓ Secret strength OK${NC}"
    return 0
}

# Create secrets directory
mkdir -p "$SECRETS_DIR"

echo -e "${GREEN}🔐 Generating security secrets for DonPetre...${NC}"

# Generate JWT secrets
echo "Generating JWT primary secret..."
JWT_SECRET=$(generate_secret 88)
echo "$JWT_SECRET" > "$SECRETS_DIR/jwt_secret.txt"
validate_secret "$JWT_SECRET"

echo "Generating JWT backup secret..."
JWT_BACKUP=$(generate_secret 88)
echo "$JWT_BACKUP" > "$SECRETS_DIR/jwt_backup_secret.txt"
validate_secret "$JWT_BACKUP"

# Generate database password
echo "Generating database password..."
DB_PASSWORD=$(generate_secret 32)
echo "$DB_PASSWORD" > "$SECRETS_DIR/db_password.txt"
validate_secret "$DB_PASSWORD" 16

# Generate Redis password
echo "Generating Redis password..."
REDIS_PASSWORD=$(generate_secret 32)
echo "$REDIS_PASSWORD" > "$SECRETS_DIR/redis_password.txt"
validate_secret "$REDIS_PASSWORD" 16

# Generate encryption key for sensitive data
echo "Generating data encryption key..."
ENCRYPTION_KEY=$(generate_secret 44)
echo "$ENCRYPTION_KEY" > "$SECRETS_DIR/encryption_key.txt"
validate_secret "$ENCRYPTION_KEY" 32

# Set appropriate permissions
chmod 600 "$SECRETS_DIR"/*.txt

echo -e "${GREEN}✅ All secrets generated successfully!${NC}"
echo -e "${YELLOW}📁 Secrets saved to: $SECRETS_DIR/${NC}"
echo -e "${YELLOW}🔒 File permissions set to 600 (owner read/write only)${NC}"

# Validation mode
if [ "${1:-}" = "--validate" ]; then
    echo -e "\n${GREEN}🔍 Validating existing secrets...${NC}"
    
    for secret_file in "$SECRETS_DIR"/*.txt; do
        if [ -f "$secret_file" ]; then
            filename=$(basename "$secret_file")
            echo -n "Validating $filename... "
            secret_content=$(cat "$secret_file")
            validate_secret "$secret_content"
        fi
    done
fi

echo -e "\n${GREEN}🛡️ Security Notes:${NC}"
echo "• Never commit these files to version control"
echo "• Rotate secrets regularly in production"
echo "• Use proper secret management in production (Azure Key Vault, HashiCorp Vault, etc.)"
echo "• Monitor for unauthorized access to secret files"
EOF

    chmod +x scripts/generate-secrets.sh
    echo -e "${GREEN}✓ Secret generation script created${NC}"
}

# Function to create git configuration
create_git_config() {
    echo -e "${BLUE}Setting up Git configuration...${NC}"
    
    # Create .gitignore if it doesn't exist
    if [ ! -f ".gitignore" ]; then
        cat > .gitignore << 'EOF'
# Compiled class files
*.class

# Log files
*.log

# BlueJ files
*.ctxt

# Mobile Tools for Java (J2ME)
.mtj.tmp/

# Package Files
*.jar
*.war
*.nar
*.ear
*.zip
*.tar.gz
*.rar

# Virtual machine crash logs
hs_err_pid*
replay_pid*

# Maven
target/
pom.xml.tag
pom.xml.releaseBackup
pom.xml.versionsBackup
pom.xml.next
release.properties
dependency-reduced-pom.xml
buildNumber.properties
.mvn/timing.properties
.mvn/wrapper/maven-wrapper.jar

# Gradle
.gradle/
build/
!**/src/main/**/build/
!**/src/test/**/build/

# IDEs
.idea/
*.iws
*.iml
*.ipr
out/
.apt_generated
.classpath
.factorypath
.project
.settings
.springBeans
.sts4-cache
bin/
/nbproject/private/
/nbbuild/
/dist/
/nbdist/
/.nb-gradle/
.vscode/

# OS specific
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db
*~
.fuse_hidden*
.directory
.Trash-*
.nfs*

# Application specific
logs/
*.log.*
application-local.yml
application-local.properties

# Docker
.dockerignore
docker-compose.override.yml

# Secrets and environment
.env
.env.local
.env.production
secrets/
*.pem
*.key
*.crt

# Database
*.h2.db
*.trace.db
*.lock.db

# Spring Boot
*.original
EOF
        echo -e "${GREEN}✓ .gitignore created${NC}"
    fi
    
    # Create .gitattributes for proper line endings
    cat > .gitattributes << 'EOF'
# Auto detect text files and perform LF normalization
* text=auto

# Java files
*.java text diff=java
*.gradle text diff=java
*.kt text diff=kotlin

# Config files
*.properties text
*.yml text
*.yaml text
*.xml text
*.json text

# Scripts
*.sh text eol=lf
*.bat text eol=crlf
*.cmd text eol=crlf
*.ps1 text eol=crlf

# Documentation
*.md text
*.txt text
*.adoc text

# Docker files
Dockerfile text
.dockerignore text

# Build files
Makefile text
*.mk text

# Exclude from archives
.gitattributes export-ignore
.gitignore export-ignore
.github/ export-ignore
EOF
    
    echo -e "${GREEN}✓ .gitattributes created${NC}"
}

# Function to create README
create_readme() {
    echo -e "${BLUE}Creating project README...${NC}"
    
    cat > README.md << 'EOF'
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
EOF
    
    echo -e "${GREEN}✓ README.md created${NC}"
}

# Main setup function
main() {
    echo -e "${GREEN}🔧 Setting up DonPetre development environment...${NC}"
    
    setup_maven_wrapper
    create_db_init_script
    create_health_check_script
    create_secret_generation_script
    create_git_config
    create_readme
    
    # Make all scripts executable
    chmod +x scripts/*.sh
    
    echo -e "\n${GREEN}✅ Development environment setup complete!${NC}"
    echo -e "${BLUE}Next steps:${NC}"
    echo -e "  1. Run: ${YELLOW}./scripts/build-all.sh${NC}"
    echo -e "  2. Edit .env file with your API credentials"
    echo -e "  3. Run: ${YELLOW}make dev${NC}"
    echo -e "  4. Check: ${YELLOW}make health${NC}"
}

main "$@"

#!/bin/bash

echo "🔐 Generating DonPetre secrets..."

# Create secrets directory
mkdir -p secrets

# Generate JWT secrets (base64 encoded, 64+ bytes for HS512)
JWT_SECRET=$(openssl rand -base64 64)
JWT_BACKUP_SECRET=$(openssl rand -base64 64)

# Generate database password
DB_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)

# Generate Redis password
REDIS_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)

# Generate encryption key for credentials (32-byte secret for text encryption)
ENCRYPTION_SECRET_KEY=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)

# Create .env file
cat > .env << EOF
# Database Configuration
DB_USER=donpetre
DB_PASSWORD=${DB_PASSWORD}

# Redis Configuration
REDIS_PASSWORD=${REDIS_PASSWORD}

# JWT Configuration
JWT_SECRET_KEY="${JWT_SECRET}"
JWT_BACKUP_SECRET="${JWT_BACKUP_SECRET}"

# Credential Encryption
ENCRYPTION_SECRET_KEY=${ENCRYPTION_SECRET_KEY}

# External Service Tokens (configure these manually)
GITHUB_TOKEN=
JIRA_URL=
JIRA_USERNAME=
JIRA_TOKEN=
EOF

echo "✅ Secrets generated successfully!"
echo "📁 Secrets saved to .env file"
echo "⚠️  Please configure external service tokens in .env file"
echo ""
echo "Generated secrets:"
echo "- Database password: ${DB_PASSWORD}"
echo "- Redis password: ${REDIS_PASSWORD}"
echo "- JWT secret keys: Generated (64+ bytes)"
echo "- Credential encryption key: Generated (32 bytes)"
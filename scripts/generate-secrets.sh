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

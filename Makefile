.PHONY: help setup build test start stop clean logs health

# Colors
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

help: ## Show this help message
	@echo "DonPetre Knowledge Platform - Development Commands"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup: ## Initial project setup
	@echo "$(GREEN)🚀 Setting up DonPetre Knowledge Platform...$(NC)"
	@chmod +x scripts/*.sh
	@./scripts/dev-setup.sh

secrets: ## Generate security secrets
	@echo "$(GREEN)🔐 Generating secrets...$(NC)"
	@./scripts/generate-secrets.sh

build: ## Build all services
	@echo "$(GREEN)🔨 Building all services...$(NC)"
	@./scripts/build-all.sh

test: ## Run tests for all services
	@echo "$(GREEN)🧪 Running tests...$(NC)"
	@mvn test

start: ## Start all services
	@echo "$(GREEN)🐳 Starting all services...$(NC)"
	@docker-compose up -d --build
	@echo "$(YELLOW)⏳ Waiting for services to be ready...$(NC)"
	@sleep 30
	@$(MAKE) health

stop: ## Stop all services
	@echo "$(YELLOW)🛑 Stopping all services...$(NC)"
	@docker-compose down

restart: stop start ## Restart all services

clean: ## Clean build artifacts and containers
	@echo "$(RED)🧹 Cleaning up...$(NC)"
	@docker-compose down --rmi all --volumes --remove-orphans 2>/dev/null || true
	@mvn clean
	@docker system prune -f

logs: ## Show logs for all services
	@docker-compose logs -f

logs-gateway: ## Show gateway logs
	@docker-compose logs -f api-gateway

logs-ingestion: ## Show ingestion service logs
	@docker-compose logs -f knowledge-ingestion

health: ## Check service health
	@echo "$(GREEN)🏥 Checking service health...$(NC)"
	@./scripts/health-check.sh

shell-gateway: ## Shell into gateway container
	@docker-compose exec api-gateway sh

shell-ingestion: ## Shell into ingestion container
	@docker-compose exec knowledge-ingestion sh

shell-db: ## Shell into database
	@docker-compose exec postgresql psql -U donpetre -d donpetre

dev: ## Start development environment
	@echo "$(GREEN)🔧 Starting development environment...$(NC)"
	@$(MAKE) secrets
	@$(MAKE) start
	@echo "$(GREEN)✅ Development environment ready!$(NC)"
	@echo "Gateway: http://localhost:8080"
	@echo "Ingestion: http://localhost:8081"

prod-build: ## Build for production
	@echo "$(GREEN)🏭 Building for production...$(NC)"
	@mvn clean package -Pprod -DskipTests
	@docker-compose build

# Database operations
db-migrate: ## Run database migrations
	@echo "$(GREEN)🗄️ Running database migrations...$(NC)"
	@docker-compose exec postgresql psql -U donpetre -d donpetre -f /scripts/migrate.sql

db-seed: ## Seed database with test data
	@echo "$(GREEN)🌱 Seeding database...$(NC)"
	@docker-compose exec postgresql psql -U donpetre -d donpetre -f /scripts/seed.sql

# Monitoring
monitor: ## Show resource usage
	@echo "$(GREEN)📊 Resource usage:$(NC)"
	@docker stats --no-stream donpetre-gateway donpetre-knowledge-ingestion donpetre-postgres donpetre-redis

# Development tools
format: ## Format code
	@echo "$(GREEN)✨ Formatting code...$(NC)"
	@mvn spotless:apply

lint: ## Lint code
	@echo "$(GREEN)🔍 Linting code...$(NC)"
	@mvn spotless:check

security-check: ## Run security checks
	@echo "$(GREEN)🔒 Running security checks...$(NC)"
	@mvn org.owasp:dependency-check-maven:check

# Quick development commands
quick-test: ## Quick test (unit tests only)
	@mvn test -Dtest='*UnitTest'

quick-build: ## Quick build (skip tests)
	@mvn clean package -DskipTests

quick-restart: ## Quick restart of application containers only
	@docker-compose restart api-gateway knowledge-ingestion

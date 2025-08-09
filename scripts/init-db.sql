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

-- Create a default admin user (password: password123)
-- Note: In production, this should be changed immediately
INSERT INTO users (username, email, password_hash, first_name, last_name, is_admin) VALUES 
    ('admin', 'admin@donpetre.com', '$2a$12$.SiNRaCuL/8jt.3i4Kt1hOfRc9shFqfJ8yaBaTcrAvMhYto9FxEDm', 'Admin', 'User', true)
ON CONFLICT (username) DO NOTHING;

-- Assign admin role to admin user
INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id 
FROM users u, roles r 
WHERE u.username = 'admin' AND r.name = 'ADMIN'
ON CONFLICT DO NOTHING;

COMMIT;

#!/bin/bash
# Frontend Deployment Script for Chatbot Integration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SERVER_PROJECT_DIR="/home/deploy/chatbot-integration"

echo "🎨 Frontend Deployment"
echo "====================="
echo "📁 Project: auth-frontend"
echo "🕐 Started: $(date)"

# Function to check if we're on server
check_environment() {
    if [ -f "$SERVER_PROJECT_DIR/.env.prod" ]; then
        echo "🖥️  Running on server"
        return 0
    else
        echo "💻 Running locally - please run this on the server"
        echo ""
        echo "To deploy to server:"
        echo "1. ssh deploy@172.104.173.81"
        echo "2. cd /home/deploy/chatbot-integration/frontend"
        echo "3. ./scripts/deploy.sh"
        exit 1
    fi
}

# Load environment variables
load_environment() {
    if [ -f "$SERVER_PROJECT_DIR/.env.prod" ]; then
        echo "📋 Loading environment variables..."
        set -a
        source "$SERVER_PROJECT_DIR/.env.prod"
        set +a
        
        # Set frontend-specific environment variables
        export NEXT_PUBLIC_API_URL="https://api.${DOMAIN}"
        
        echo "✅ Environment loaded"
        echo "🔗 API URL: $NEXT_PUBLIC_API_URL"
    else
        echo "❌ Environment file not found: $SERVER_PROJECT_DIR/.env.prod"
        exit 1
    fi
}

# Pull latest code
update_code() {
    echo "📥 Updating frontend code..."
    cd "$PROJECT_DIR"
    
    git fetch origin
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse origin/main)
    
    if [ "$LOCAL" != "$REMOTE" ]; then
        echo "📦 New changes detected, pulling..."
        git pull origin main
        echo "✅ Updated to commit: $(git rev-parse --short HEAD)"
    else
        echo "✅ Already up to date: $(git rev-parse --short HEAD)"
    fi
    
    # Verify required files
    if [ ! -f "Dockerfile.prod" ]; then
        echo "❌ Dockerfile.prod not found!"
        exit 1
    fi
    
    if [ ! -f "docker-compose.prod.yml" ]; then
        echo "❌ docker-compose.prod.yml not found!"
        exit 1
    fi
}

# Deploy frontend
deploy_frontend() {
    echo "🎨 Deploying frontend service..."
    cd "$PROJECT_DIR"
    
    # Stop existing frontend
    echo "⏹️  Stopping existing frontend..."
    docker-compose -f docker-compose.prod.yml down 2>/dev/null || true
    
    # Remove old image to force rebuild
    echo "🗑️  Removing old frontend image..."
    docker rmi chatbot-integration/frontend:latest 2>/dev/null || true
    
    # Build and start frontend
    echo "🔨 Building and starting frontend..."
    docker-compose -f docker-compose.prod.yml up -d --build
    
    # Wait for frontend to be ready
    echo "⏳ Waiting for frontend to be ready..."
    for i in {1..30}; do
        if curl -s http://localhost:3000 > /dev/null 2>&1; then
            echo "✅ Frontend is ready!"
            break
        fi
        if [ $i -eq 30 ]; then
            echo "❌ Frontend failed to start within 60 seconds"
            echo "📜 Frontend logs:"
            docker-compose -f docker-compose.prod.yml logs --tail=30 frontend
            echo ""
            echo "🔍 Container status:"
            docker ps -a --filter "name=chatbot_frontend"
            exit 1
        fi
        echo "   Attempt $i/30..."
        sleep 2
    done
}

# Health check
health_check() {
    echo "🔍 Frontend health check:"
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000)
    if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "307" ]; then
        echo "✅ Frontend is responding (HTTP $HTTP_STATUS)"
    else
        echo "❌ Frontend health check failed (HTTP $HTTP_STATUS)"
        exit 1
    fi
}

# Main execution
main() {
    check_environment
    load_environment
    update_code
    deploy_frontend
    health_check
    
    echo ""
    echo "🎉 Frontend deployed successfully!"
    echo "🔗 Frontend URL: https://chatbot-integration.xyz"
    echo "📝 Git commit: $(git rev-parse --short HEAD)"
    echo "🕐 Completed: $(date)"
}

# Run main function
main "$@"
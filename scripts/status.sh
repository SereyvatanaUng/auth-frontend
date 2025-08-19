#!/bin/bash
# Frontend Status Check

echo "🎨 Frontend Service Status"
echo "=========================="
echo "🕐 $(date)"

# Check if frontend container is running
echo ""
echo "📊 Frontend Container:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" --filter "name=chatbot_frontend"

echo ""
echo "🔍 Health Check:"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null)
if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "307" ]; then
    echo "✅ Frontend is healthy (HTTP $HTTP_STATUS)"
else
    echo "❌ Frontend is unhealthy (HTTP $HTTP_STATUS)"
    echo ""
    echo "📜 Recent logs:"
    docker logs chatbot_frontend --tail=10 2>/dev/null || echo "Container not found"
fi

echo ""
echo "💾 Resource Usage:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" chatbot_frontend 2>/dev/null || echo "Frontend container not running"

echo ""
echo "📝 Git Info:"
echo "Commit: $(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
echo "Branch: $(git branch --show-current 2>/dev/null || echo 'unknown')"
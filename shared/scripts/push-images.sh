#!/bin/bash
# Script to tag and push NSReady images to GHCR
# Usage: ./scripts/push-images.sh <github-org>

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <github-org>"
    echo "Example: $0 nirajdesai"
    exit 1
fi

GITHUB_ORG=$1
REGISTRY="ghcr.io"

echo "Tagging and pushing images to ${REGISTRY}/${GITHUB_ORG}/..."

# Tag images
echo "Tagging admin-tool..."
docker tag nsready-admin-tool:latest ${REGISTRY}/${GITHUB_ORG}/nsready-admin-tool:latest

echo "Tagging collector-service..."
docker tag nsready-collector-service:latest ${REGISTRY}/${GITHUB_ORG}/nsready-collector-service:latest

# Check if authenticated
if ! docker info | grep -q "Username"; then
    echo ""
    echo "⚠️  Not authenticated to ${REGISTRY}"
    echo "Please authenticate first:"
    echo "  echo \$GITHUB_TOKEN | docker login ${REGISTRY} -u USERNAME --password-stdin"
    echo ""
    echo "Or create a Personal Access Token (PAT) with 'write:packages' permission"
    echo "at: https://github.com/settings/tokens"
    echo ""
    read -p "Press Enter to continue with push (will fail if not authenticated)..."
fi

# Push images
echo ""
echo "Pushing admin-tool..."
docker push ${REGISTRY}/${GITHUB_ORG}/nsready-admin-tool:latest

echo ""
echo "Pushing collector-service..."
docker push ${REGISTRY}/${GITHUB_ORG}/nsready-collector-service:latest

echo ""
echo "✅ Images pushed successfully!"
echo ""
echo "Update your Kubernetes deployments to use:"
echo "  - ${REGISTRY}/${GITHUB_ORG}/nsready-admin-tool:latest"
echo "  - ${REGISTRY}/${GITHUB_ORG}/nsready-collector-service:latest"



#!/bin/bash
# Build NexHelper Docker Image
# Usage: ./build-image.sh [tag]

set -e

TAG="${1:-latest}"
IMAGE_NAME="nexhelper"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🐳 Building NexHelper Docker Image"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Image: nexhelper:${TAG}"
echo ""

# Check if in correct directory
if [ ! -f "Dockerfile" ]; then
    echo "❌ Error: Dockerfile not found"
    echo "   Run this script from the NexWorker-Repo root directory"
    exit 1
fi

# Build image
echo "📦 Building image..."
docker build -t "${IMAGE_NAME}:${TAG}" .

# Tag as latest if not specified
if [ "$TAG" != "latest" ]; then
    docker tag "${IMAGE_NAME}:${TAG}" "${IMAGE_NAME}:latest"
fi

# Show image info
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Build Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
docker images "${IMAGE_NAME}"
echo ""
echo "📝 Next steps:"
echo "   1. Push to registry:"
echo "      docker tag nexhelper:${TAG} your-registry/nexhelper:${TAG}"
echo "      docker push your-registry/nexhelper:${TAG}"
echo ""
echo "   2. Or use locally:"
echo "      ./provision-customer.sh 001 'Test Kunde'"
echo ""
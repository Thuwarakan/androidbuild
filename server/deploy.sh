#!/bin/bash

# Deployment script for mobile proxy server
# Target: root@139.59.22.1

VPS_HOST="139.59.22.1"
VPS_USER="root"
REMOTE_DIR="/opt/mobileProxy"
LOCAL_DIR="."

echo "🚀 Deploying Mobile Proxy Server to VPS..."
echo "Target: $VPS_USER@$VPS_HOST"
echo ""

# Create remote directory
echo "📁 Creating remote directory..."
ssh $VPS_USER@$VPS_HOST "mkdir -p $REMOTE_DIR"

# Copy server files
echo "📤 Uploading server files..."
scp index.js package.json package-lock.json $VPS_USER@$VPS_HOST:$REMOTE_DIR/

# Install dependencies and setup PM2
echo "📦 Installing dependencies on VPS..."
ssh $VPS_USER@$VPS_HOST << 'ENDSSH'
cd /opt/mobileProxy

# Install Node.js if not present
if ! command -v node &> /dev/null; then
    echo "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
fi

# Install dependencies
npm install

# Install PM2 globally if not present
if ! command -v pm2 &> /dev/null; then
    echo "Installing PM2..."
    npm install -g pm2
fi

# Stop existing process if running
pm2 stop mobileProxy 2>/dev/null || true
pm2 delete mobileProxy 2>/dev/null || true

# Start the server with PM2
echo "Starting server with PM2..."
pm2 start index.js --name mobileProxy

# Save PM2 configuration
pm2 save

# Setup PM2 to start on boot
pm2 startup systemd -u root --hp /root

echo ""
echo "✅ Deployment complete!"
echo ""
echo "Server is running on:"
echo "  - WebSocket (Control): ws://139.59.22.1:8080"
echo "  - Data Tunnel: 139.59.22.1:8081"
echo "  - HTTP/HTTPS Proxy: 139.59.22.1:1080"
echo ""
echo "Useful PM2 commands:"
echo "  pm2 status          - Check server status"
echo "  pm2 logs mobileProxy - View logs"
echo "  pm2 restart mobileProxy - Restart server"
echo "  pm2 stop mobileProxy - Stop server"
ENDSSH

echo ""
echo "🎉 Deployment finished successfully!"

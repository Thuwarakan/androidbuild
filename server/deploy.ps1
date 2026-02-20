# PowerShell Deployment Script for Mobile Proxy Server
# Target: root@139.59.22.1

$VPS_HOST = "139.59.22.1"
$VPS_USER = "root"
$REMOTE_DIR = "/opt/mobileProxy"

Write-Host "🚀 Deploying Mobile Proxy Server to VPS..." -ForegroundColor Cyan
Write-Host "Target: $VPS_USER@$VPS_HOST" -ForegroundColor Yellow
Write-Host ""

# Prompt for password
Write-Host "Please enter the VPS password when prompted..." -ForegroundColor Green
Write-Host ""

# Create remote directory
Write-Host "📁 Creating remote directory..." -ForegroundColor Cyan
ssh "$VPS_USER@$VPS_HOST" "mkdir -p $REMOTE_DIR"

# Copy server files
Write-Host "📤 Uploading server files..." -ForegroundColor Cyan
scp index.js package.json package-lock.json "$VPS_USER@${VPS_HOST}:$REMOTE_DIR/"

# Create setup script
$setupScript = @'
cd /opt/mobileProxy

# Install Node.js if not present
if ! command -v node &> /dev/null; then
    echo "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
fi

# Install dependencies
echo "Installing npm dependencies..."
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
'@

# Install dependencies and setup PM2
Write-Host "📦 Installing dependencies on VPS..." -ForegroundColor Cyan
$setupScript | ssh "$VPS_USER@$VPS_HOST" "bash -s"

Write-Host ""
Write-Host "🎉 Deployment finished successfully!" -ForegroundColor Green

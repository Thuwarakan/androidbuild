# Mobile Proxy Server

A high-performance proxy server that routes traffic through mobile devices, enabling applications to use mobile IP addresses for web requests.

## 🚀 Features

- **WebSocket Control Channel**: Real-time communication with mobile clients
- **Dynamic Device Selection**: Automatically routes traffic through the lowest-latency device
- **Auto-Reconnection**: Mobile clients automatically reconnect if disconnected
- **HTTP/HTTPS Support**: Handles both standard HTTP and CONNECT tunneling
- **Process Management**: PM2 integration for automatic restarts and monitoring
- **Security**: Proxy port bound to localhost only, preventing unauthorized external access
- **Latency Monitoring**: Continuous ping/pong to measure device performance
- **Dead Peer Detection**: Automatic cleanup of disconnected devices

## 📋 Architecture

The system consists of three main components:

1. **WebSocket Server (Port 8080)**: Manages mobile device connections and control messages
2. **Data Tunnel Server (Port 8081)**: Handles actual data transfer between proxy and mobile devices
3. **HTTP/HTTPS Proxy (Port 1080)**: Accepts proxy requests from local applications (localhost only)

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed diagrams and flow charts.

## 🔒 Security

- **Port 1080 (Proxy)**: Bound to `127.0.0.1` - only accessible from localhost
- **Port 8080 (WebSocket)**: Accessible externally for mobile client connections
- **Port 8081 (Data Tunnel)**: Accessible externally for data transfer

This configuration prevents unauthorized external users from using your proxy while allowing legitimate mobile clients to connect.

See [SECURITY.md](SECURITY.md) for detailed security information.

## 📦 Installation

### Prerequisites

- Node.js 18+ (LTS recommended)
- npm or yarn
- PM2 (for production deployment)

### Local Development

```bash
# Install dependencies
npm install

# Start the server
npm start
```

### Production Deployment

See [DEPLOYMENT.md](DEPLOYMENT.md) for complete deployment instructions.

Quick deployment to VPS:

```bash
# Upload files
scp index.js package.json package-lock.json root@YOUR_VPS_IP:/opt/mobileProxy/

# SSH into VPS and setup
ssh root@YOUR_VPS_IP
cd /opt/mobileProxy
npm install
npm install -g pm2
pm2 start index.js --name mobileProxy
pm2 save
pm2 startup
```

## 🎯 Usage

### Starting the Server

**Local Development:**
```bash
node index.js
```

**Production (PM2):**
```bash
pm2 start mobileProxy
pm2 logs mobileProxy
pm2 status
```

### Using the Proxy

From applications running on the same server:

```bash
# Using curl
curl -x http://127.0.0.1:1080 https://api.example.com

# Using wget
export http_proxy=http://127.0.0.1:1080
export https_proxy=http://127.0.0.1:1080
wget https://example.com

# Using Python requests
import requests
proxies = {
    'http': 'http://127.0.0.1:1080',
    'https': 'http://127.0.0.1:1080'
}
response = requests.get('https://api.example.com', proxies=proxies)
```

### Mobile Client Configuration

Configure your mobile client app with:
- **Server IP**: Your VPS IP address
- **Port**: 8080

## 📊 Monitoring

### Check Server Status

```bash
pm2 status
```

### View Logs

```bash
# Real-time logs
pm2 logs mobileProxy

# Last 100 lines
pm2 logs mobileProxy --lines 100

# Filter logs
pm2 logs mobileProxy | grep "CONNECT"
```

### Check Port Bindings

```bash
netstat -tulpn | grep -E '8080|8081|1080'
```

Expected output:
```
tcp  0.0.0.0:8080   LISTEN  (WebSocket - External)
tcp  0.0.0.0:8081   LISTEN  (Data Tunnel - External)
tcp  127.0.0.1:1080 LISTEN  (Proxy - Localhost Only)
```

### Verify Security

Run the security verification script:

```bash
bash verify-security.sh
```

## 🔧 Configuration

Edit the `CONFIG` object in `index.js`:

```javascript
const CONFIG = {
    WS_PORT: 8080,      // WebSocket control port
    DATA_PORT: 8081,    // Data tunnel port
    SOCKS_PORT: 1080    // Proxy port (localhost only)
};
```

## 🛠️ Management Commands

### PM2 Commands

```bash
# Start server
pm2 start mobileProxy

# Stop server
pm2 stop mobileProxy

# Restart server
pm2 restart mobileProxy

# Delete from PM2
pm2 delete mobileProxy

# View detailed info
pm2 show mobileProxy

# Monitor resources
pm2 monit
```

### Update Deployment

```bash
# Upload new version
scp index.js root@YOUR_VPS_IP:/opt/mobileProxy/

# Restart server
ssh root@YOUR_VPS_IP "pm2 restart mobileProxy"
```

## 📁 Project Structure

```
mobileProxy/
├── server/
│   ├── index.js              # Main server code
│   ├── package.json          # Dependencies
│   ├── deploy.sh             # Deployment script (Linux)
│   ├── deploy.ps1            # Deployment script (Windows)
│   └── verify-security.sh    # Security verification script
├── client/                   # Flutter mobile client
│   └── lib/
│       ├── main.dart
│       ├── tunnel_logic.dart
│       └── background_service.dart
├── ARCHITECTURE.md           # Architecture documentation
├── DEPLOYMENT.md             # Deployment guide
├── SECURITY.md               # Security documentation
├── QUICKREF.txt              # Quick reference card
└── README.md                 # This file
```

## 🔍 Troubleshooting

### Server Not Starting

```bash
# Check if ports are already in use
netstat -tulpn | grep -E '8080|8081|1080'

# Check PM2 logs for errors
pm2 logs mobileProxy --err

# Restart PM2
pm2 restart mobileProxy
```

### Mobile Client Can't Connect

1. Verify server is running: `pm2 status`
2. Check firewall allows ports 8080 and 8081
3. Verify WebSocket port is accessible: `telnet YOUR_VPS_IP 8080`
4. Check server logs: `pm2 logs mobileProxy`

### Proxy Not Working

1. Verify you're connecting from localhost (same server)
2. Check if mobile devices are connected: Look for "Device connected" in logs
3. Verify port 1080 is listening on localhost: `netstat -tulpn | grep 1080`

### High Memory Usage

```bash
# Check memory usage
pm2 monit

# Restart server to clear memory
pm2 restart mobileProxy

# Set memory limit (optional)
pm2 start index.js --name mobileProxy --max-memory-restart 500M
```

## 🔐 Security Best Practices

1. ✅ **Proxy on localhost only** (Default configuration)
2. ✅ **Use PM2 for process management** (Recommended)
3. ⏭️ **Set up SSH key authentication**
4. ⏭️ **Disable password SSH login**
5. ⏭️ **Enable UFW firewall**
6. ⏭️ **Regular security updates**
7. ⏭️ **Monitor logs for suspicious activity**

See [SECURITY.md](SECURITY.md) for detailed security recommendations.

## 📝 License

ISC

## 👥 Support

For issues and questions:
1. Check the troubleshooting section above
2. Review the logs: `pm2 logs mobileProxy`
3. Check the documentation files in this repository

## 📚 Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture and diagrams
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Deployment instructions
- **[SECURITY.md](SECURITY.md)** - Security configuration and best practices
- **[QUICKREF.txt](QUICKREF.txt)** - Quick reference card

## 🎯 Quick Reference

| Component | Port | Access | Purpose |
|-----------|------|--------|---------|
| WebSocket | 8080 | External | Mobile client control |
| Data Tunnel | 8081 | External | Data transfer |
| Proxy | 1080 | Localhost | HTTP/HTTPS proxy |

**Production Server**: 139.59.22.1

**Connect to VPS**: `ssh root@139.59.22.1`

**View Logs**: `pm2 logs mobileProxy`

**Restart Server**: `pm2 restart mobileProxy`

---

**Version**: 1.0.0  
**Last Updated**: 2026-02-08  
**Status**: Production Ready ✅

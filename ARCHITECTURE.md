# Mobile Proxy Server - Architecture & Security

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         INTERNET                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        │                     │                     │
   ┌────▼────┐          ┌─────▼─────┐         ┌────▼────┐
   │ Mobile  │          │    VPS    │         │ Random  │
   │ Client  │          │139.59.22.1│         │  User   │
   │ (Phone) │          │           │         │         │
   └────┬────┘          └─────┬─────┘         └────┬────┘
        │                     │                     │
        │  WebSocket :8080    │                     │
        ├────────────────────►│                     │
        │                     │                     │
        │  Data Tunnel :8081  │                     │
        ├────────────────────►│                     │
        │                     │                     │
        │                     │  Proxy :1080        │
        │                     │  ❌ BLOCKED         │
        │                     │◄────────────────────┤
        │                     │  (localhost only)   │
        │                     │                     │
        └─────────────────────┴─────────────────────┘
```

## Port Security Configuration

### External Ports (0.0.0.0 - All Interfaces)

**Port 8080 - WebSocket Control**
- ✅ Accessible from Internet
- Purpose: Mobile client control channel
- Protocol: WebSocket (ws://)
- Used for: Device registration, ping/pong, tunnel commands

**Port 8081 - Data Tunnel**
- ✅ Accessible from Internet
- Purpose: Actual data tunneling
- Protocol: TCP
- Used for: Proxying HTTP/HTTPS traffic through mobile devices

### Internal Port (127.0.0.1 - Localhost Only)

**Port 1080 - HTTP/HTTPS Proxy**
- 🔒 **NOT** accessible from Internet
- ✅ Only accessible from VPS localhost
- Purpose: Proxy endpoint for VPS applications
- Protocol: HTTP/HTTPS Proxy
- Security: Prevents unauthorized external proxy usage

## Traffic Flow

### 1. Mobile Client Connection
```
Mobile App → ws://139.59.22.1:8080 → WebSocket Server
          → Registers device
          → Receives tunnel commands
```

### 2. VPS Application Using Proxy
```
VPS App → http://127.0.0.1:1080 → Proxy Server
        → Selects best mobile device
        → Sends CONNECT command via WebSocket
        → Mobile creates tunnel to 139.59.22.1:8081
        → Data flows: VPS ↔ Mobile ↔ Internet
```

### 3. External User Attempt (BLOCKED)
```
Random User → http://139.59.22.1:1080 → ❌ Connection Refused
            → Port is bound to localhost only
```

## Security Benefits

### 1. **Prevents Proxy Abuse**
- External users cannot use your proxy
- Only authorized VPS applications can access it
- Reduces bandwidth theft risk

### 2. **Reduces Attack Surface**
- One less port exposed to the internet
- Minimizes potential DDoS vectors
- Limits unauthorized access attempts

### 3. **Controlled Access**
- Only applications you run on the VPS can use the proxy
- Full control over what traffic goes through mobile devices
- Easy to monitor and audit

## Use Cases

### ✅ Correct Usage (Localhost)
```bash
# On the VPS, applications can use the proxy
ssh root@139.59.22.1

# Use curl through mobile proxy
curl -x http://127.0.0.1:1080 https://api.example.com

# Use wget through mobile proxy
export http_proxy=http://127.0.0.1:1080
wget https://example.com

# Run a script that needs mobile IP
python3 scraper.py --proxy http://127.0.0.1:1080
```

### ❌ Blocked Usage (External)
```bash
# From your laptop or another server
curl -x http://139.59.22.1:1080 https://example.com
# ❌ Connection refused - port not accessible externally
```

## Component Responsibilities

### WebSocket Server (Port 8080)
- Maintains persistent connections with mobile clients
- Sends ping/pong for latency monitoring
- Routes tunnel requests to best available device
- Handles device registration and disconnection

### Data Tunnel Server (Port 8081)
- Accepts incoming tunnel connections from mobile devices
- Matches stream IDs with pending proxy requests
- Pipes data between proxy clients and mobile tunnels
- Handles connection cleanup

### Proxy Server (Port 1080)
- Accepts HTTP/HTTPS proxy requests (localhost only)
- Parses CONNECT and HTTP requests
- Creates stream IDs for tunnel matching
- Manages connection timeouts

## Network Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                    VPS (139.59.22.1)                         │
│                                                              │
│  ┌────────────────────────────────────────────────────┐     │
│  │  Node.js Server Process (PM2: mobileProxy)         │     │
│  │                                                     │     │
│  │  ┌─────────────────┐  ┌──────────────────┐        │     │
│  │  │ WebSocket :8080 │  │ Data Tunnel :8081│        │     │
│  │  │ (0.0.0.0)       │  │ (0.0.0.0)        │        │     │
│  │  │ ✅ External     │  │ ✅ External      │        │     │
│  │  └────────┬────────┘  └────────┬─────────┘        │     │
│  │           │                    │                   │     │
│  │           └──────┬─────────────┘                   │     │
│  │                  │                                 │     │
│  │           ┌──────▼──────────┐                      │     │
│  │           │  Proxy :1080    │                      │     │
│  │           │  (127.0.0.1)    │                      │     │
│  │           │  🔒 Localhost   │                      │     │
│  │           └──────▲──────────┘                      │     │
│  │                  │                                 │     │
│  └──────────────────┼─────────────────────────────────┘     │
│                     │                                       │
│  ┌──────────────────┴─────────────────────────────────┐    │
│  │  VPS Applications (curl, wget, scripts, etc.)      │    │
│  │  ✅ Can access http://127.0.0.1:1080               │    │
│  └────────────────────────────────────────────────────┘    │
│                                                             │
└──────────────────────────────────────────────────────────────┘
         ▲                                    ▲
         │ :8080 WebSocket                    │ :8081 Tunnel
         │                                    │
    ┌────┴────┐                          ┌────┴────┐
    │ Mobile  │                          │ Mobile  │
    │ Client  │                          │ Client  │
    │    1    │                          │    2    │
    └─────────┘                          └─────────┘
```

## Monitoring & Logs

### Check Active Connections
```bash
# On VPS
ssh root@139.59.22.1

# See all listening ports
netstat -tulpn | grep node

# Expected output:
# tcp  0.0.0.0:8080   LISTEN  (WebSocket - External)
# tcp  0.0.0.0:8081   LISTEN  (Data Tunnel - External)
# tcp  127.0.0.1:1080 LISTEN  (Proxy - Localhost Only) ← SECURE
```

### View Server Logs
```bash
# Real-time logs
pm2 logs mobileProxy

# Last 100 lines
pm2 logs mobileProxy --lines 100

# Filter for specific events
pm2 logs mobileProxy | grep "CONNECT"
```

## Firewall Rules

### UFW Configuration
```bash
# Enable firewall
ufw enable

# Allow SSH (important - don't lock yourself out!)
ufw allow 22/tcp

# Allow WebSocket and Data Tunnel
ufw allow 8080/tcp
ufw allow 8081/tcp

# Port 1080 does NOT need to be opened
# It's localhost-only, so firewall rules don't matter

# Check status
ufw status numbered
```

### Expected UFW Output
```
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere
8080/tcp                   ALLOW       Anywhere
8081/tcp                   ALLOW       Anywhere
```

## Performance Considerations

### Device Selection
- Server selects device with lowest latency
- Ping/pong every 5 seconds to measure latency
- Dead peer detection (15 second timeout)
- Automatic failover to next best device

### Connection Limits
- No hard limit on concurrent tunnels
- Limited by mobile device capabilities
- Limited by VPS resources (memory, CPU)
- Each tunnel = 2 socket connections

### Optimization Tips
1. Keep mobile devices on stable networks
2. Monitor PM2 memory usage: `pm2 monit`
3. Restart server periodically if needed
4. Use multiple mobile devices for load balancing

---

**Architecture Version**: 2.0
**Security Level**: Enhanced 🔒
**Last Updated**: 2026-02-08

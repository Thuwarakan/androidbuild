# Mobile Proxy Server - Production Deployment

## 🎉 Deployment Successful!

The mobile proxy server has been successfully deployed to your VPS.

### Server Details
- **VPS IP**: `139.59.22.1`
- **User**: `root`
- **Installation Path**: `/opt/mobileProxy`

### Service Ports
- **WebSocket (Control)**: `8080`
- **Data Tunnel**: `8081`
- **HTTP/HTTPS Proxy**: `1080`

### Connection URLs
- **WebSocket**: `ws://139.59.22.1:8080`
- **Proxy**: `139.59.22.1:1080`

## Android Client Configuration

Update your Android client to connect to the production server:
- **Server IP**: `139.59.22.1`
- **Port**: `8080`

## Server Management (PM2)

The server is running under PM2 process manager for automatic restarts and monitoring.

### Useful Commands

Connect to your VPS:
```bash
ssh root@139.59.22.1
```

Check server status:
```bash
pm2 status
```

View real-time logs:
```bash
pm2 logs mobileProxy
```

View last 100 log lines:
```bash
pm2 logs mobileProxy --lines 100
```

Restart server:
```bash
pm2 restart mobileProxy
```

Stop server:
```bash
pm2 stop mobileProxy
```

Start server:
```bash
pm2 start mobileProxy
```

Monitor server resources:
```bash
pm2 monit
```

## Auto-Start Configuration

The server is configured to automatically start on system boot using PM2's startup script.

## Firewall Configuration

Make sure the following ports are open on your VPS firewall:
- Port 8080 (WebSocket)
- Port 8081 (Data Tunnel)
- Port 1080 (Proxy)

If using UFW (Ubuntu Firewall):
```bash
ufw allow 8080/tcp
ufw allow 8081/tcp
ufw allow 1080/tcp
```

## Testing the Deployment

1. **Test WebSocket Connection**:
   ```bash
   curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: test" http://139.59.22.1:8080
   ```

2. **Connect Android Client**:
   - Open the SkyHub Backup Support app
   - Enter Server IP: `139.59.22.1`
   - Enter Port: `8080`
   - Click Connect

3. **Test Proxy**:
   Configure your browser or application to use proxy:
   - Proxy Host: `139.59.22.1`
   - Proxy Port: `1080`
   - Type: HTTP/HTTPS

## Updating the Server

To deploy updates:

1. Make changes to your local server files
2. Run the deployment commands:
   ```bash
   scp index.js package.json root@139.59.22.1:/opt/mobileProxy/
   ssh root@139.59.22.1 "cd /opt/mobileProxy && npm install && pm2 restart mobileProxy"
   ```

## Troubleshooting

### Server not responding
```bash
ssh root@139.59.22.1
pm2 logs mobileProxy --lines 50
```

### Restart server
```bash
ssh root@139.59.22.1 "pm2 restart mobileProxy"
```

### Check if ports are listening
```bash
ssh root@139.59.22.1 "netstat -tulpn | grep -E '8080|8081|1080'"
```

## Security Recommendations

1. **Change SSH Port**: Consider changing the default SSH port (22) to a non-standard port
2. **SSH Key Authentication**: Set up SSH key-based authentication and disable password login
3. **Firewall**: Only open necessary ports
4. **Regular Updates**: Keep the system and Node.js updated
5. **Monitoring**: Set up monitoring and alerts for server health

## Next Steps

1. ✅ Server deployed and running
2. ⏭️ Update Android client with production server IP
3. ⏭️ Test connection from mobile device
4. ⏭️ Configure firewall rules if needed
5. ⏭️ Set up SSL/TLS for secure connections (optional)

---

**Deployment Date**: 2026-02-08
**Server Version**: 1.0.0
**PM2 Process Name**: mobileProxy

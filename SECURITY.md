# Mobile Proxy Server - Security Configuration

## 🔒 Security Update Applied

The proxy server has been configured with enhanced security settings.

### Port Configuration

| Port | Service | Binding | Access |
|------|---------|---------|--------|
| 8080 | WebSocket (Control) | 0.0.0.0 | External (Required for mobile clients) |
| 8081 | Data Tunnel | 0.0.0.0 | External (Required for mobile clients) |
| 1080 | HTTP/HTTPS Proxy | 127.0.0.1 | **Internal Only** (Localhost) |

### Why Port 1080 is Localhost Only

The proxy port (1080) is now bound to `127.0.0.1` (localhost) instead of `0.0.0.0` (all interfaces). This means:

✅ **Benefits:**
- The proxy is **NOT exposed** to the internet
- Only applications running on the VPS can use the proxy
- Prevents unauthorized external access to your proxy
- Reduces attack surface

🔐 **Security:**
- Mobile clients connect via WebSocket (8080) and Data Tunnel (8081)
- The proxy (1080) is used internally on the VPS for applications that need to route through mobile devices
- No one can directly connect to your proxy from the internet

### How It Works

```
Internet User → ❌ Cannot access port 1080 directly

Mobile Client → ✅ Connects to port 8080 (WebSocket)
              → ✅ Creates tunnels via port 8081 (Data)

VPS Application → ✅ Uses localhost:1080 as proxy
                → Routes through mobile client tunnels
```

### Using the Proxy on VPS

Applications running on the VPS can use the proxy:

```bash
# Example: curl through the proxy
curl -x http://127.0.0.1:1080 https://example.com

# Example: wget through the proxy
export http_proxy=http://127.0.0.1:1080
export https_proxy=http://127.0.0.1:1080
wget https://example.com
```

### Firewall Configuration

You only need to allow external access to ports 8080 and 8081:

```bash
# Allow WebSocket and Data Tunnel
ufw allow 8080/tcp
ufw allow 8081/tcp

# Port 1080 does NOT need to be opened (localhost only)
# ufw allow 1080/tcp  ← NOT NEEDED
```

### Verification

To verify the security configuration, SSH into your VPS and check:

```bash
# Check which ports are listening and on which interfaces
netstat -tulpn | grep -E '8080|8081|1080'

# Expected output:
# tcp  0.0.0.0:8080  (listening on all interfaces)
# tcp  0.0.0.0:8081  (listening on all interfaces)
# tcp  127.0.0.1:1080  (listening on localhost only) ← SECURE
```

### Testing External Access

From an external machine, you should:

✅ **Be able to connect to:**
- Port 8080 (WebSocket)
- Port 8081 (Data Tunnel)

❌ **NOT be able to connect to:**
- Port 1080 (Proxy) - Connection should be refused

### Rollback (If Needed)

If you need to expose the proxy externally (not recommended), edit `/opt/mobileProxy/index.js`:

```javascript
// Change this line:
proxyServer.listen(CONFIG.SOCKS_PORT, '127.0.0.1', () => {

// To this:
proxyServer.listen(CONFIG.SOCKS_PORT, () => {
```

Then restart: `pm2 restart mobileProxy`

---

## Security Best Practices

1. ✅ **Proxy on localhost only** (Current configuration)
2. ✅ **Use PM2 for process management**
3. ⏭️ **Set up SSH key authentication** (Recommended)
4. ⏭️ **Disable password SSH login** (Recommended)
5. ⏭️ **Enable UFW firewall** (Recommended)
6. ⏭️ **Regular security updates** (Recommended)
7. ⏭️ **Monitor logs for suspicious activity** (Recommended)

### Additional Security Commands

```bash
# Enable UFW firewall
ufw enable

# Allow only necessary ports
ufw allow 22/tcp   # SSH
ufw allow 8080/tcp # WebSocket
ufw allow 8081/tcp # Data Tunnel

# Check firewall status
ufw status

# Monitor server logs
pm2 logs mobileProxy

# Check for failed login attempts
grep "Failed password" /var/log/auth.log
```

---

**Last Updated**: 2026-02-08
**Security Level**: Enhanced ✅

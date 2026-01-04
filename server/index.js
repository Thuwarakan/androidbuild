const WebSocket = require('ws');
const net = require('net');

const CONFIG = {
    WS_PORT: 8080,
    DATA_PORT: 8081,
    SOCKS_PORT: 1080
};

// Store connected devices: deviceId -> { ws, latency }
const devices = new Map();
// Store pending data streams: streamId -> { clientSocket, targetHost, targetPort, initialData? }
const pendingStreams = new Map();

// --- 1. Control Server (WebSocket) ---
const wss = new WebSocket.Server({ port: CONFIG.WS_PORT });

wss.on('connection', (ws, req) => {
    const deviceId = req.headers['sec-websocket-key'];
    const clientIp = req.socket.remoteAddress;

    console.log(`[WS] Device connected: ${deviceId} (${clientIp})`);

    devices.set(deviceId, { ws, latency: 0, lastSeen: Date.now() });

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);
            if (data.type === 'PONG') {
                const latency = Date.now() - data.timestamp;
                const device = devices.get(deviceId);
                if (device) {
                    device.latency = latency;
                    device.lastSeen = Date.now();
                }
            }
        } catch (e) {
            console.error('[WS] Error parsing message:', e.message);
        }
    });

    ws.on('close', () => {
        console.log(`[WS] Device disconnected: ${deviceId}`);
        devices.delete(deviceId);
    });

    ws.on('error', (e) => console.error('[WS] Error:', e.message));
});

// Latency Monitor & Dead Peer Detection
setInterval(() => {
    const now = Date.now();
    for (const [id, device] of devices.entries()) {
        if (device.ws.readyState === WebSocket.OPEN) {
            // Check for timeout (e.g., 15 seconds)
            if (now - device.lastSeen > 15000) {
                console.log(`[WS] Device timed out: ${id}`);
                device.ws.terminate();
                devices.delete(id);
                continue;
            }
            device.ws.send(JSON.stringify({ type: 'PING', timestamp: now }));
        }
    }
}, 5000);

// --- 2. Data Tunnel Server (TCP) ---
const dataServer = net.createServer((deviceSocket) => {
    deviceSocket.on('error', (err) => console.error('[DATA] Connection error:', err.message));

    let streamId = '';
    let isHeaderParsed = false;
    let initialBuffer = Buffer.alloc(0);

    deviceSocket.on('data', (chunk) => {
        if (!isHeaderParsed) {
            initialBuffer = Buffer.concat([initialBuffer, chunk]);

            // Expecting newline terminated ID: "streamId\n"
            const newlineIndex = initialBuffer.indexOf('\n');
            if (newlineIndex !== -1) {
                const streamId = initialBuffer.slice(0, newlineIndex).toString().trim();
                const remainder = initialBuffer.slice(newlineIndex + 1);

                isHeaderParsed = true;

                handleDataStream(streamId, deviceSocket, remainder);
            }
        }
    });
});

function handleDataStream(streamId, deviceSocket, head) {
    if (pendingStreams.has(streamId)) {
        const { clientSocket, initialData } = pendingStreams.get(streamId);

        console.log(`[DATA] Tunnel established for Stream ${streamId}`);

        // Write any head data from device handshake (if any remains)
        if (head.length > 0) {
            clientSocket.write(head);
        }

        // Write buffer from client (HTTP request) if it exists
        if (initialData) {
            deviceSocket.write(initialData);
        }

        // Pipe sockets
        deviceSocket.pipe(clientSocket);
        clientSocket.pipe(deviceSocket);

        deviceSocket.on('error', (err) => console.error(`[DATA] Device socket error ${streamId}:`, err.message));
        clientSocket.on('error', (err) => console.error(`[DATA] Client socket error ${streamId}:`, err.message));

        deviceSocket.on('close', () => {
            pendingStreams.delete(streamId);
            clientSocket.destroy();
        });
        clientSocket.on('close', () => {
            pendingStreams.delete(streamId);
            deviceSocket.destroy();
        });

        pendingStreams.delete(streamId);

    } else {
        console.error(`[DATA] Unknown stream ID: ${streamId}`);
        deviceSocket.end();
    }
}

dataServer.listen(CONFIG.DATA_PORT, () => {
    console.log(`[DATA] Tunnel Server listening on port ${CONFIG.DATA_PORT}`);
});

// --- 3. HTTP/HTTPS Proxy Server ---
const proxyServer = net.createServer((socket) => {
    socket.on('error', (err) => console.error('[PROXY] Client connection error:', err.message));

    socket.once('data', (data) => {
        const str = data.toString();
        let dstAddr, dstPort, initialData = null;

        // 1. HTTPS Tunneling (CONNECT)
        if (str.startsWith('CONNECT')) {
            const match = str.match(/CONNECT ([^:]+):(\d+) HTTP/);
            if (!match) {
                socket.end();
                return;
            }
            dstAddr = match[1];
            dstPort = parseInt(match[2], 10);

            // Send 200 Connection Established to client
            socket.write('HTTP/1.1 200 Connection Established\r\n\r\n');
        }
        // 2. Standard HTTP Proxy (GET, POST, etc.)
        else if (/^[A-Z]+ http:\/\//.test(str) || str.indexOf('Host: ') !== -1) {
            const hostMatch = str.match(/Host: ([^:\r\n]+)(:(\d+))?/i);
            if (!hostMatch) {
                console.error('[PROXY] No Host header found in HTTP request');
                socket.end();
                return;
            }
            dstAddr = hostMatch[1];
            dstPort = hostMatch[3] ? parseInt(hostMatch[3], 10) : 80;

            // For HTTP, we must forward the original data packet to the target
            initialData = data;
        }
        else {
            console.log('[PROXY] Unknown protocol, closing.');
            socket.end();
            return;
        }

        const bestDevice = getBestDevice();

        if (!bestDevice) {
            console.error('[PROXY] No device connected, closing connection immediately.');
            if (!str.startsWith('CONNECT')) {
                socket.write('HTTP/1.1 503 Service Unavailable\r\n\r\nNo mobile agents connected.\r\n');
            }
            socket.destroy();
            return;
        }

        if (bestDevice.ws.readyState === WebSocket.OPEN) {
            const streamId = Math.random().toString(36).substring(7);

            // Storing pending stream with initialData
            socket.pause();
            pendingStreams.set(streamId, { clientSocket: socket, targetHost: dstAddr, targetPort: dstPort, initialData: initialData });

            // Send instruction to device
            bestDevice.ws.send(JSON.stringify({
                type: 'CONNECT',
                id: streamId,
                host: dstAddr,
                port: dstPort
            }));

            console.log(`[PROXY] Request connect to ${dstAddr}:${dstPort}`);

            // 30s Timeout
            setTimeout(() => {
                if (pendingStreams.has(streamId)) {
                    console.log(`[PROXY] Timeout for ${streamId}`);
                    socket.destroy();
                    pendingStreams.delete(streamId);
                }
            }, 30000);
        } else {
            socket.end();
        }
    });
});

function getBestDevice() {
    let best = null;
    let minLatency = Infinity;

    for (const device of devices.values()) {
        if (device.ws.readyState === WebSocket.OPEN) {
            if (device.latency < minLatency) {
                minLatency = device.latency;
                best = device;
            }
        }
    }
    // console.log(`[ROUTING] Selected best device with latency: ${minLatency}ms`);
    return best;
}

proxyServer.listen(CONFIG.SOCKS_PORT, () => {
    console.log(`[PROXY] Server listening on port ${CONFIG.SOCKS_PORT}`);
    console.log(`[INFO] Control Port: ${CONFIG.WS_PORT}, Data Port: ${CONFIG.DATA_PORT}`);
});

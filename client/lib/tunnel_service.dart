import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class TunnelService with ChangeNotifier {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  String _logs = "";
  final List<String> _activeTunnels = [];
  bool _isManualDisconnect = false;
  String? _savedIp;
  String? _savedPort;
  Timer? _reconnectTimer;

  bool get isConnected => _isConnected;
  String get logs => _logs;
  List<String> get activeTunnels => _activeTunnels;

  void log(String message) {
    final time =
        DateTime.now().toIso8601String().split('T').last.split('.').first;
    _logs = "[$time] $message\n$_logs";
    if (_logs.length > 10000) _logs = _logs.substring(0, 10000); // Limit logs
    notifyListeners();
  }

  Future<void> connect(String serverIp, String port) async {
    if (_isConnected) return;

    _savedIp = serverIp;
    _savedPort = port;
    _isManualDisconnect = false;
    _reconnectTimer?.cancel();

    final wsUrl = Uri.parse('ws://$serverIp:$port');
    log("Connecting to $wsUrl...");

    try {
      _channel = WebSocketChannel.connect(wsUrl);

      _isConnected = true;
      notifyListeners();
      log("Connected to Control Server");

      _channel!.stream.listen(
        (message) {
          _handleMessage(message, serverIp);
        },
        onDone: () {
          log("Disconnected from server.");
          disconnect(manual: false);
        },
        onError: (error) {
          log("WS Error: $error");
          disconnect(manual: false);
        },
      );
    } catch (e) {
      log("Connection failed: $e");
      disconnect(manual: false);
    }
  }

  void disconnect({bool manual = true}) {
    _isConnected = false;
    _channel?.sink.close(status.goingAway);
    _channel = null;
    notifyListeners();

    if (manual) {
      _isManualDisconnect = true;
      _reconnectTimer?.cancel();
      log("Disconnected manually.");
    } else {
      _attemptReconnect();
    }
  }

  void _attemptReconnect() {
    if (_isManualDisconnect) return;

    log("Reconnecting in 5 seconds...");
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected && _savedIp != null && _savedPort != null) {
        connect(_savedIp!, _savedPort!);
      }
    });
  }

  void _handleMessage(dynamic message, String serverIp) async {
    try {
      final data = jsonDecode(message);

      if (data['type'] == 'PING') {
        // Reply PONG
        _send({'type': 'PONG', 'timestamp': data['timestamp']});
      } else if (data['type'] == 'CONNECT') {
        final String targetHost = data['host'];
        final int targetPort = data['port'];
        final String streamId = data['id'];

        log("New Request -> $targetHost:$targetPort (ID: $streamId)");
        _createTunnel(serverIp, 8081, targetHost, targetPort, streamId);
      }
    } catch (e) {
      log("Error parsing message: $e");
    }
  }

  void _send(Map<String, dynamic> data) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  Future<void> _createTunnel(
    String serverIp,
    int serverDataPort,
    String targetHost,
    int targetPort,
    String streamId,
  ) async {
    Socket? targetSocket;
    Socket? tunnelSocket;
    final tunnelKey = "$targetHost:$targetPort ($streamId)";

    _activeTunnels.add(tunnelKey);
    notifyListeners();

    try {
      // 1. Connect to Target
      targetSocket = await Socket.connect(
        targetHost,
        targetPort,
        timeout: const Duration(seconds: 10),
      );

      // 2. Connect to Server Tunnel Port
      tunnelSocket = await Socket.connect(
        serverIp,
        serverDataPort,
        timeout: const Duration(seconds: 10),
      );

      // 3. Send Stream ID Header to Server
      tunnelSocket.add(utf8.encode("$streamId\n"));
      await tunnelSocket.flush();

      // 4. Pipe Data
      // Target -> Tunnel
      targetSocket.listen(
        (Uint8List data) {
          tunnelSocket?.add(data);
        },
        onDone: () {
          tunnelSocket?.destroy();
          targetSocket?.destroy();
          _removeTunnel(tunnelKey);
        },
        onError: (e) {
          _removeTunnel(tunnelKey);
          tunnelSocket?.destroy();
        },
      );

      // Tunnel -> Target
      tunnelSocket.listen(
        (Uint8List data) {
          targetSocket?.add(data);
        },
        onDone: () {
          targetSocket?.destroy();
          tunnelSocket?.destroy();
          _removeTunnel(tunnelKey);
        },
        onError: (e) {
          _removeTunnel(tunnelKey);
          targetSocket?.destroy();
        },
      );
    } catch (e) {
      log("Tunnel Error ($targetHost): $e");
      targetSocket?.destroy();
      tunnelSocket?.destroy();
      _removeTunnel(tunnelKey);
    }
  }

  void _removeTunnel(String key) {
    if (_activeTunnels.contains(key)) {
      _activeTunnels.remove(key);
      notifyListeners();
      log("Tunnel closed: $key");
    }
  }
}

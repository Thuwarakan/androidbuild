import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'tunnel_logic.dart';

class TunnelService with ChangeNotifier {
  bool _isConnected = false;
  String _logs = "";
  List<String> _activeTunnels = [];
  TunnelLogic? _tunnelLogic; // New for Desktop support

  bool get isConnected => _isConnected;
  String get logs => _logs;
  List<String> get activeTunnels => _activeTunnels;

  TunnelService() {
    if (Platform.isAndroid || Platform.isIOS) {
      _initServiceListener();
    } else {
      _initDesktopLogic();
    }
  }

  void _initDesktopLogic() {
    _tunnelLogic = TunnelLogic();
    _tunnelLogic!.onLog = (msg) => _log(msg);
    _tunnelLogic!.onStatusChange = (status) {
      _isConnected = status;
      notifyListeners();
    };
    _tunnelLogic!.onTunnelsChange = (tunnels) {
      _activeTunnels = List<String>.from(tunnels);
      notifyListeners();
    };
  }

  void _initServiceListener() async {
    final service = FlutterBackgroundService();

    // Check current status on load
    if (await service.isRunning()) {
      _isConnected = true;
      notifyListeners();
    }

    service.on('log').listen((event) {
      if (event != null && event['message'] != null) {
        _log(event['message']);
      }
    });

    service.on('status').listen((event) {
      if (event != null) {
        _isConnected = event['isConnected'] ?? false;
        notifyListeners();
      }
    });

    service.on('tunnels').listen((event) {
      if (event != null && event['tunnels'] != null) {
        _activeTunnels = List<String>.from(event['tunnels']);
        notifyListeners();
      }
    });
  }

  void _log(String message) {
    final time =
        DateTime.now().toIso8601String().split('T').last.split('.').first;
    _logs = "[$time] $message\n$_logs";
    if (_logs.length > 10000) _logs = _logs.substring(0, 10000);
    notifyListeners();
  }

  Future<void> connect(String serverIp, String port) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final service = FlutterBackgroundService();
      if (!await service.isRunning()) {
        await service.startService();
      }
      service.invoke('connect', {
        'ip': serverIp,
        'port': port,
      });
    } else {
      _tunnelLogic?.connect(serverIp, port);
    }
  }

  void disconnect() {
    if (Platform.isAndroid || Platform.isIOS) {
      final service = FlutterBackgroundService();
      service.invoke('disconnect');
    } else {
      _tunnelLogic?.disconnect();
    }
  }
}

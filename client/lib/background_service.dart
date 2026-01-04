import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'tunnel_logic.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  // Android Notification Channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground', // id
    'Mobile Proxy Service', // title
    description: 'This channel is used for important notifications.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'Mobile Proxy',
      initialNotificationContent: 'Ready to connect',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Helper to update notification
  void updateNotification(String text) {
    flutterLocalNotificationsPlugin.show(
      888,
      'Mobile Proxy Active',
      text,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'my_foreground',
          'Mobile Proxy Service',
          icon: '@mipmap/ic_launcher',
          ongoing: true,
        ),
      ),
    );
  }

  final tunnelLogic = TunnelLogic();

  tunnelLogic.onLog = (String log) {
    print("BG LOG: $log");
    service.invoke('log', {'message': log});
  };

  tunnelLogic.onStatusChange = (bool isConnected) {
    service.invoke('status', {'isConnected': isConnected});
    updateNotification(isConnected ? "Connected to Server" : "Disconnected");
  };

  tunnelLogic.onTunnelsChange = (List<String> tunnels) {
    service.invoke('tunnels', {'tunnels': tunnels});
    if (tunnels.isNotEmpty) {
      updateNotification("Active Tunnels: ${tunnels.length}");
    }
  };

  // Commands from UI
  service.on('connect').listen((event) {
    if (event != null) {
      final ip = event['ip'];
      final port = event['port'];
      tunnelLogic.connect(ip, port);
    }
  });

  service.on('disconnect').listen((event) {
    tunnelLogic.disconnect(manual: true);
    service.stopSelf();
  });

  service.on('stopService').listen((event) {
    tunnelLogic.disconnect(manual: true);
    service.stopSelf();
  });
}

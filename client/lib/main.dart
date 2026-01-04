import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tunnel_service.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => TunnelService())],
      child: const MobileProxyApp(),
    ),
  );
}

class MobileProxyApp extends StatelessWidget {
  const MobileProxyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mobile Proxy',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController(
    text: "8080",
  );

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ipController.text = prefs.getString('server_ip') ?? "192.168.1.100";
    });
  }

  void _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_ip', _ipController.text);
  }

  @override
  Widget build(BuildContext context) {
    final tunnelService = Provider.of<TunnelService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Mobile Reverse Proxy")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Connection Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _ipController,
                      decoration: const InputDecoration(labelText: "Server IP"),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _portController,
                      decoration: const InputDecoration(
                        labelText: "Control Port",
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: tunnelService.isConnected
                            ? () => tunnelService.disconnect()
                            : () {
                                _saveSettings();
                                tunnelService.connect(
                                  _ipController.text,
                                  _portController.text,
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tunnelService.isConnected
                              ? Colors.red
                              : Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: Text(
                          tunnelService.isConnected ? "DISCONNECT" : "CONNECT",
                        ),
                      ),
                    ),
                    if (tunnelService.isConnected)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: const Text(
                          "Status: Connected via WebSocket",
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Active Tunnels
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Active Tunnels",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            SizedBox(
              height: 100,
              child: tunnelService.activeTunnels.isEmpty
                  ? const Center(child: Text("No active traffic"))
                  : ListView.builder(
                      itemCount: tunnelService.activeTunnels.length,
                      itemBuilder: (ctx, i) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.compare_arrows, size: 16),
                        title: Text(tunnelService.activeTunnels[i]),
                      ),
                    ),
            ),

            const Divider(),

            // Logs
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Logs",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  reverse: true,
                  child: Text(
                    tunnelService.logs,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

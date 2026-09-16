import 'package:core/udp.dart';
import 'package:flutter/material.dart';
import 'package:mobile_client/udp_server.dart';

void main() {
  runApp(const SteeringWheelClientApp());
}

class SteeringWheelClientApp extends StatelessWidget {
  const SteeringWheelClientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Steering Wheel Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const DeviceListScreen(),
    );
  }
}

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  UDPServer? _udpServer;
  bool _isInitializing = true;
  String? _initError;

  final List<UDPClient> _devices = [];
  UDPClient? _connectingDevice;

  @override
  void initState() {
    super.initState();
    _initServer();
  }

  Future<void> _initServer() async {
    setState(() {
      _isInitializing = true;
      _initError = null;
    });

    final server = await UDPServer.create();
    if (!mounted) return;

    if (server == null) {
      setState(() {
        _isInitializing = false;
        _initError = 'Failed to bind UDP socket on port 5000.';
      });
      return;
    }

    _udpServer = server;
    _udpServer!.onDisconnected = _handleRemoteDisconnect;

    setState(() {
      _isInitializing = false;
    });

    _startScanning();
  }

  void _handleRemoteDisconnect() {
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Disconnected by remote host')),
    );
  }

  void _startScanning() {
    final server = _udpServer;
    if (server == null) return;

    setState(() {
      _devices.clear();
    });

    server.startClientSearch((client) {
      if (!mounted) return;
      setState(() {
        if (!_devices.any((d) => d.id == client.id)) {
          _devices.add(client);
        }
      });
    });
  }

  void _stopScanning() {
    _udpServer?.stopClientSearch();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _connect(UDPClient device) async {
    final server = _udpServer;
    if (server == null) return;

    setState(() {
      _connectingDevice = device;
    });

    final success = await server.connectClient(device);
    if (!mounted) return;

    setState(() {
      _connectingDevice = null;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to ${device.deviceName}!'),
          backgroundColor: Colors.green.shade800,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect to ${device.deviceName}'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  Future<void> _disconnect() async {
    final server = _udpServer;
    if (server == null) return;

    await server.disconnectClient();
    if (!mounted) return;

    setState(() {});
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Disconnected')));
  }

  @override
  void dispose() {
    _udpServer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final server = _udpServer;
    final isConnected = server?.isConnected ?? false;
    final connectedClient = server?.connectedClient;
    final isSearching = server?.isSearching ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Available PC Hosts'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isSearching ? Icons.stop : Icons.refresh),
            tooltip: isSearching ? 'Stop Scanning' : 'Scan for PCs',
            onPressed: _isInitializing
                ? null
                : () {
                    if (isSearching) {
                      _stopScanning();
                    } else {
                      _startScanning();
                    }
                  },
          ),
        ],
      ),
      body: _buildBody(isConnected, connectedClient, isSearching),
    );
  }

  Widget _buildBody(
    bool isConnected,
    ConnectedClient? connectedClient,
    bool isSearching,
  ) {
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing UDP listener...'),
          ],
        ),
      );
    }

    if (_initError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(
                _initError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _initServer,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (isConnected && connectedClient != null)
          _buildConnectedBanner(connectedClient)
        else if (isSearching)
          const LinearProgressIndicator(),
        Expanded(
          child: _devices.isEmpty
              ? _buildEmptyState(isSearching)
              : _buildDeviceList(connectedClient),
        ),
      ],
    );
  }

  Widget _buildConnectedBanner(ConnectedClient client) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.green.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connected to ${client.deviceName}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${client.address.address}:${client.port} • Session: ${client.sessionId}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: _disconnect,
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isSearching) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSearching ? Icons.radar : Icons.devices_other,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              isSearching ? 'Searching for PC hosts...' : 'No PC hosts found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'Make sure the PC controller application is running on the same network.'
                  : 'Tap Scan to search for running PC controller servers.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            if (!isSearching)
              FilledButton.icon(
                onPressed: _startScanning,
                icon: const Icon(Icons.refresh),
                label: const Text('Scan Now'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList(ConnectedClient? connectedClient) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _devices.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final device = _devices[index];
        final isThisConnected = connectedClient?.id == device.id;
        final isThisConnecting = _connectingDevice?.id == device.id;

        return Card(
          elevation: isThisConnected ? 3 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isThisConnected
                ? BorderSide(color: Colors.green.shade400, width: 1.5)
                : BorderSide.none,
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isThisConnected
                  ? Colors.green.withValues(alpha: 0.2)
                  : Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.computer,
                color: isThisConnected
                    ? Colors.green
                    : Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            title: Text(
              device.deviceName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('${device.address.address}:${device.port}'),
            trailing: isThisConnecting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : isThisConnected
                ? const Chip(
                    label: Text('Connected'),
                    backgroundColor: Colors.green,
                    labelStyle: TextStyle(color: Colors.white),
                    padding: EdgeInsets.zero,
                  )
                : FilledButton(
                    onPressed: _connectingDevice != null
                        ? null
                        : () => _connect(device),
                    child: const Text('Connect'),
                  ),
          ),
        );
      },
    );
  }
}

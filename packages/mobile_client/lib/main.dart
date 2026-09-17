import 'package:core/udp.dart';
import 'package:flutter/material.dart';
import 'package:mobile_client/services/app_udp_server.dart';
import 'package:mobile_client/services/udp_server.dart';
import 'package:signals/signals_flutter.dart';

void main() {
  initUdpServer();
  runApp(MaterialApp(home: DeviceListScreen()));
}

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  UDPClient? _connectingDevice;
  void Function()? _serverReadySubscription;

  @override
  void initState() {
    super.initState();

    // Subscribe to appUDPServer state.
    _serverReadySubscription = appUdpServer.subscribe((state) {
      final server = state.value;
      if (server != null) {
        server.onDisconnected = _handleRemoteDisconnect;

        // Start client search when UDPServer is initialized.
        server.startClientSearch();
      }
    });
  }

  @override
  void dispose() {
    _serverReadySubscription?.call();
    super.dispose();
  }

  void _handleRemoteDisconnect() {
    if (!mounted) return;
    _notify('Disconnected by remote host');
  }

  Future<void> _connect(UDPServer server, UDPClient device) async {
    setState(() => _connectingDevice = device);
    final success = await server.connectClient(device);
    if (!mounted) return;
    setState(() => _connectingDevice = null);

    _notify(
      success
          ? 'Connected to ${device.deviceName}!'
          : 'Failed to connect to ${device.deviceName}',
      backgroundColor: success ? Colors.green.shade800 : Colors.red.shade800,
    );
  }

  Future<void> _disconnect(UDPServer server) async {
    await server.disconnectClient();
    if (!mounted) return;
    _notify('Disconnected');
  }

  void _notify(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final state = appUdpServer.value;
        final server = state.value;
        final isSearching = server?.isSearching.value ?? false;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Available PC Hosts'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(isSearching ? Icons.stop : Icons.refresh),
                tooltip: isSearching ? 'Stop Scanning' : 'Scan for PCs',
                onPressed: server == null
                    ? null
                    : () {
                        if (isSearching) {
                          server.stopClientSearch();
                        } else {
                          server.startClientSearch();
                        }
                      },
              ),
            ],
          ),
          body: server != null
              ? _buildConnectedContent(server)
              : _buildInitOrError(state.error),
        );
      },
    );
  }

  Widget _buildInitOrError(Object? error) {
    if (error != null) {
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
                error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: initUdpServer,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

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

  Widget _buildConnectedContent(UDPServer server) {
    final connectedClient = server.connectedClient.value;
    final isConnected = server.isConnected.value;
    final isSearching = server.isSearching.value;
    final devices = server.discoveredClients;

    return Column(
      children: [
        if (isConnected && connectedClient != null)
          _buildConnectedBanner(connectedClient, server)
        else if (isSearching)
          const LinearProgressIndicator(),
        Expanded(
          child: devices.isEmpty
              ? _buildEmptyState(isSearching, server)
              : _buildDeviceList(devices, connectedClient, server),
        ),
      ],
    );
  }

  Widget _buildConnectedBanner(ConnectedClient client, UDPServer server) {
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
            onPressed: () => _disconnect(server),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isSearching, UDPServer server) {
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
                onPressed: server.startClientSearch,
                icon: const Icon(Icons.refresh),
                label: const Text('Scan Now'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList(
    List<UDPClient> devices,
    ConnectedClient? connectedClient,
    UDPServer server,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: devices.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final device = devices[index];
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
                        : () => _connect(server, device),
                    child: const Text('Connect'),
                  ),
          ),
        );
      },
    );
  }
}

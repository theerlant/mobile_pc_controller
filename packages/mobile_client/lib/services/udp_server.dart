import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:core/udp.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_client/utils/generate_session_id.dart';
import 'package:signals/signals_flutter.dart';

class UDPServer {
  final RawDatagramSocket _socket;
  final int _port;

  final connectedClient = signal<ConnectedClient?>(
    null,
    options: SignalOptions(name: "[UDPServer] connectedClient"),
  );
  late final FlutterComputed<bool> isConnected;

  int get port => _port;

  final isSearching = signal<bool>(
    false,
    options: SignalOptions(name: "[UDPServer] isSearching"),
  );

  final discoveredClients = listSignal<UDPClient>(
    [],
    options: ListSignalOptions(name: "[UDPServer] discoveredClients"),
  );
  final Map<String, UDPClient> _cachedClients = HashMap();

  Completer<ConnectResponsePacket>? _connectCompleter;
  int? _pendingSessionId;
  InternetAddress? _pendingTargetAddress;

  Timer? _heartbeatTimer;
  StreamSubscription<RawSocketEvent>? _socketSubscription;

  /// Optional callback invoked when the connected remote host initiates a disconnect.
  void Function()? onDisconnected;

  UDPServer._internal(this._socket, this._port) {
    isConnected = computed(
      () => connectedClient.value != null,
      options: ComputedOptions(name: '[UDPServer] isConnected'),
    );

    _socketSubscription = _socket.listen(
      _onSocketEvent,
      onError: (error) {
        print("[UDPServer] Socket error: $error");
      },
      onDone: () {
        print("[UDPServer] Socket closed");
      },
    );
  }

  /// Creates and binds a new [UDPServer] socket on the specified [port].
  static Future<UDPServer> create([int port = 5000]) async {
    try {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        port,
        reuseAddress: true,
      );
      socket.broadcastEnabled = true;
      return UDPServer._internal(socket, port);
    } catch (error) {
      print("[UDPServer] unable to bind to port $port: $error");
      throw Exception('Failed to bind UDP socket on port $port.');
    }
  }

  /// Handles incoming socket events and drains all queued datagrams.
  void _onSocketEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;

    while (true) {
      final dg = _socket.receive();
      if (dg == null) break;

      _processDatagram(dg);
    }
  }

  /// Safely parses and dispatches incoming UDP datagrams.
  void _processDatagram(Datagram dg) {
    final PacketData packet;
    try {
      packet = PacketParser.parse(dg.data);
    } catch (_) {
      // Safely ignore malformed or unrelated UDP packets from the network
      return;
    }

    switch (packet) {
      case BroadcastPacket():
        _handleBroadcastPacket(packet, dg.address, dg.port);

      case ConnectResponsePacket():
        _handleConnectResponse(packet, dg.address);

      case DisconnectRequestPacket():
        _handleDisconnectRequest(packet);

      case HeartbeatPacket():
        // Keep-alive acknowledgment, connection remains healthy
        break;

      case ConnectRequestPacket():
      case DataPacket():
      case UUIDRefreshPacket():
      case UndefinedPacket():
        break;
    }
  }

  void _handleBroadcastPacket(
    BroadcastPacket packet,
    InternetAddress remoteAddress,
    int remotePort,
  ) {
    if (!isSearching.value) return;

    final receivedClient = UDPClient(
      id: packet.id,
      address: remoteAddress,
      port: remotePort,
      deviceName: packet.deviceName,
    );

    final existingClient = _cachedClients[receivedClient.id];

    if (existingClient != null) {
      // If UUID matches an existing client but from a different IP and name, request UUID refresh
      if (existingClient.address.address != receivedClient.address.address &&
          existingClient.deviceName != receivedClient.deviceName) {
        print(
          "[UDPServer] A client UUID matches existing cache but from different address & name. Received: $receivedClient",
        );
        final uuidRefreshPayload = PacketBuilder.uuidRefresh();
        _socket.send(uuidRefreshPayload, remoteAddress, remotePort);
      }
      return;
    }

    _cachedClients[receivedClient.id] = receivedClient;
    discoveredClients.add(receivedClient);
  }

  void _handleConnectResponse(
    ConnectResponsePacket packet,
    InternetAddress remoteAddress,
  ) {
    final completer = _connectCompleter;
    if (completer != null && !completer.isCompleted) {
      if (packet.sessionId == _pendingSessionId &&
          remoteAddress.address == _pendingTargetAddress?.address) {
        completer.complete(packet);
      }
    }
  }

  void _handleDisconnectRequest(DisconnectRequestPacket packet) {
    final client = connectedClient.value;
    if (client != null && packet.sessionId == client.sessionId) {
      print("[UDPServer] Connected host terminated the session.");
      _stopHeartbeat();
      connectedClient.value = null;
      onDisconnected?.call();
    }
  }

  /// Starts listening for broadcast packets from PCs.
  void startClientSearch() {
    _cachedClients.clear();
    discoveredClients.clear();
    isSearching.value = true;
  }

  /// Stops searching for broadcast packets.
  void stopClientSearch() {
    isSearching.value = false;
  }

  /// Attempts to establish a connection with [target].
  Future<bool> connectClient(
    UDPClient target, {
    int maxRetries = 5,
    Duration timeoutPerTry = const Duration(seconds: 2),
  }) async {
    // Gracefully disconnect from any existing connection
    if (connectedClient.value != null) {
      await disconnectClient();
    }

    final sessionId = generateSessionId();
    _pendingSessionId = sessionId;
    _pendingTargetAddress = target.address;

    final request = PacketBuilder.connectRequest(sessionId);

    try {
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        print(
          "[UDPServer] Trying to connect to ${target.deviceName} (Attempt $attempt/$maxRetries)",
        );
        _connectCompleter = Completer<ConnectResponsePacket>();

        _socket.send(request, target.address, target.port);

        try {
          final response = await _connectCompleter!.future.timeout(
            timeoutPerTry,
          );

          if (response.connectionAccepted) {
            connectedClient.value = target.toConnectedClient(sessionId);
            _startHeartbeat();
            print(
              "[UDPServer] Connected successfully to ${target.deviceName} with session $sessionId",
            );
            return true;
          } else {
            print(
              "[UDPServer] Connection was rejected by ${target.deviceName}",
            );
            return false;
          }
        } on TimeoutException {
          print(
            "[UDPServer] Connection attempt $attempt timed out. Retrying...",
          );
        }
      }
    } finally {
      _pendingSessionId = null;
      _pendingTargetAddress = null;
      _connectCompleter = null;
    }

    print(
      "[UDPServer] Failed to connect to ${target.deviceName} after $maxRetries attempts.",
    );
    return false;
  }

  /// Sends steering wheel/controller input data to the connected PC.
  bool sendData(Map<String, dynamic> appData) {
    final client = connectedClient.value;
    if (client == null) return false;

    final dataBytes = PacketBuilder.data(client.sessionId, appData);
    final bytesSent = _socket.send(dataBytes, client.address, client.port);
    return bytesSent > 0;
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final client = connectedClient.value;
      if (client == null) {
        _stopHeartbeat();
        return;
      }
      final heartbeatBytes = PacketBuilder.heartbeat(client.sessionId);
      _socket.send(heartbeatBytes, client.address, client.port);
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Disconnects from the current PC host.
  Future<void> disconnectClient() async {
    _stopHeartbeat();

    final client = connectedClient.value;
    if (client != null) {
      try {
        final disconnectBytes = PacketBuilder.disconnectRequest(
          client.sessionId,
        );
        _socket.send(disconnectBytes, client.address, client.port);
      } catch (e) {
        print("[UDPServer] Error sending disconnect packet: $e");
      }
      connectedClient.value = null;
    }
  }

  /// Releases all socket and timer resources.
  Future<void> dispose() async {
    stopClientSearch();
    await disconnectClient();
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    _socket.close();
  }
}

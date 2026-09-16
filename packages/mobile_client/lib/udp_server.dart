import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:core/udp.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_client/utils/generate_session_id.dart';

class UDPServer {
  final RawDatagramSocket _socket;
  final int _port;

  ConnectedClient? _connectedClient;
  ConnectedClient? get connectedClient => _connectedClient;
  bool get isConnected => _connectedClient != null;

  int get port => _port;

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  void Function(UDPClient client)? _onNewClientDetected;
  final Map<String, UDPClient> _cachedClients = HashMap();

  Completer<ConnectResponsePacket>? _connectCompleter;
  int? _pendingSessionId;
  InternetAddress? _pendingTargetAddress;

  Timer? _heartbeatTimer;
  StreamSubscription<RawSocketEvent>? _socketSubscription;

  /// Optional callback invoked when the connected remote host initiates a disconnect.
  void Function()? onDisconnected;

  UDPServer._internal(this._socket, this._port) {
    _socketSubscription = _socket.listen(
      _onSocketEvent,
      onError: (error) {
        debugPrint("[UDPServer] Socket error: $error");
      },
      onDone: () {
        debugPrint("[UDPServer] Socket closed");
      },
    );
  }

  /// Creates and binds a new [UDPServer] socket on the specified [port].
  static Future<UDPServer?> create([int port = 5000]) async {
    try {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        port,
        reuseAddress: true,
      );
      socket.broadcastEnabled = true;
      return UDPServer._internal(socket, port);
    } catch (error) {
      debugPrint("[UDPServer] unable to bind to port $port: $error");
      return null;
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
    if (!_isSearching) return;

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
        debugPrint(
          "[UDPServer] A client UUID matches existing cache but from different address & name. Received: $receivedClient",
        );
        final uuidRefreshPayload = PacketBuilder.uuidRefresh();
        _socket.send(uuidRefreshPayload, remoteAddress, remotePort);
      }
      return;
    }

    _cachedClients[receivedClient.id] = receivedClient;
    _onNewClientDetected?.call(receivedClient);
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
    final client = _connectedClient;
    if (client != null && packet.sessionId == client.sessionId) {
      debugPrint("[UDPServer] Connected host terminated the session.");
      _stopHeartbeat();
      _connectedClient = null;
      onDisconnected?.call();
    }
  }

  /// Starts listening for broadcast packets from PCs.
  void startClientSearch(void Function(UDPClient client) onNewClientDetected) {
    _cachedClients.clear();
    _onNewClientDetected = onNewClientDetected;
    _isSearching = true;
  }

  /// Stops searching for broadcast packets.
  void stopClientSearch() {
    _isSearching = false;
    _onNewClientDetected = null;
  }

  /// Attempts to establish a connection with [target].
  Future<bool> connectClient(
    UDPClient target, {
    int maxRetries = 5,
    Duration timeoutPerTry = const Duration(seconds: 2),
  }) async {
    // Gracefully disconnect from any existing connection
    if (_connectedClient != null) {
      await disconnectClient();
    }

    final sessionId = generateSessionId();
    _pendingSessionId = sessionId;
    _pendingTargetAddress = target.address;

    final request = PacketBuilder.connectRequest(sessionId);

    try {
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        debugPrint(
          "[UDPServer] Trying to connect to ${target.deviceName} (Attempt $attempt/$maxRetries)",
        );
        _connectCompleter = Completer<ConnectResponsePacket>();

        _socket.send(request, target.address, target.port);

        try {
          final response =
              await _connectCompleter!.future.timeout(timeoutPerTry);

          if (response.connectionAccepted) {
            _connectedClient = target.toConnectedClient(sessionId);
            _startHeartbeat();
            debugPrint(
              "[UDPServer] Connected successfully to ${target.deviceName} with session $sessionId",
            );
            return true;
          } else {
            debugPrint(
              "[UDPServer] Connection was rejected by ${target.deviceName}",
            );
            return false;
          }
        } on TimeoutException {
          debugPrint(
            "[UDPServer] Connection attempt $attempt timed out. Retrying...",
          );
        }
      }
    } finally {
      _pendingSessionId = null;
      _pendingTargetAddress = null;
      _connectCompleter = null;
    }

    debugPrint(
      "[UDPServer] Failed to connect to ${target.deviceName} after $maxRetries attempts.",
    );
    return false;
  }

  /// Sends steering wheel/controller input data to the connected PC.
  bool sendData(Map<String, dynamic> appData) {
    final client = _connectedClient;
    if (client == null) return false;

    final dataBytes = PacketBuilder.data(client.sessionId, appData);
    final bytesSent = _socket.send(dataBytes, client.address, client.port);
    return bytesSent > 0;
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final client = _connectedClient;
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

    final client = _connectedClient;
    if (client != null) {
      try {
        final disconnectBytes =
            PacketBuilder.disconnectRequest(client.sessionId);
        _socket.send(disconnectBytes, client.address, client.port);
      } catch (e) {
        debugPrint("[UDPServer] Error sending disconnect packet: $e");
      }
      _connectedClient = null;
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

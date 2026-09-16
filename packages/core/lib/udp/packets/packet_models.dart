import 'packet_constants.dart';
import 'packet_type.dart';

/// Sealed class hierarchy representing type-safe UDP packets.
sealed class PacketData {
  final PacketType packetType;

  const PacketData(this.packetType);
}

final class BroadcastPacket extends PacketData {
  final String id;
  final String deviceName;

  const BroadcastPacket({required this.id, required this.deviceName})
    : super(PacketType.broadcast);

  @override
  String toString() => 'BroadcastPacket(deviceName: $deviceName)';
}

final class ConnectRequestPacket extends PacketData {
  final int protocolVersion;
  final int sessionId;

  ConnectRequestPacket({required this.protocolVersion, required this.sessionId})
    : super(PacketType.connectRequest) {
    verifySessionId(sessionId);
  }

  @override
  String toString() =>
      'ConnectRequestPacket(protocolVersion: $protocolVersion, sessionId: $sessionId)';
}

final class ConnectResponsePacket extends PacketData {
  final bool connectionAccepted;
  final int sessionId;

  ConnectResponsePacket({
    required this.connectionAccepted,
    required this.sessionId,
  }) : super(PacketType.connectResponse) {
    verifySessionId(sessionId);
  }

  @override
  String toString() =>
      'ConnectResponsePacket(connectionAccepted: $connectionAccepted, sessionId: $sessionId)';
}

final class DisconnectRequestPacket extends PacketData {
  final int sessionId;

  DisconnectRequestPacket({required this.sessionId})
    : super(PacketType.disconnectRequest) {
    verifySessionId(sessionId);
  }
}

final class DataPacket extends PacketData {
  final int sessionId;
  final Map<String, dynamic> appData;

  DataPacket({required this.sessionId, required this.appData})
    : super(PacketType.data) {
    verifySessionId(sessionId);
  }

  @override
  String toString() => 'DataPacket(sessionId: $sessionId, appData: $appData)';
}

final class HeartbeatPacket extends PacketData {
  final int sessionId;

  HeartbeatPacket({required this.sessionId}) : super(PacketType.heartbeat) {
    verifySessionId(sessionId);
  }

  @override
  String toString() => 'HeartbeatPacket(sessionId: $sessionId)';
}

final class UUIDRefreshPacket extends PacketData {
  UUIDRefreshPacket() : super(PacketType.uuidRefreshRequest);
}

final class UndefinedPacket extends PacketData {
  const UndefinedPacket() : super(PacketType.undefined);

  @override
  String toString() => 'UndefinedPacket()';
}

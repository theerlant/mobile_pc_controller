import 'dart:io';

// Define a UDP Client
class UDPClient {
  final String id;
  InternetAddress address;
  int port;
  final String deviceName;

  UDPClient({
    required this.id,
    required this.address,
    required this.port,
    required this.deviceName,
  });

  ConnectedClient toConnectedClient(int sessionId) {
    return ConnectedClient(
      id: id,
      address: address,
      port: port,
      deviceName: deviceName,
      sessionId: sessionId,
    );
  }

  void updateEndpoint(InternetAddress newAddress, int newPort) {
    address = newAddress;
    port = newPort;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UDPClient &&
          other.runtimeType == runtimeType &&
          other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'UDPClient(id: $id, name: $deviceName, endpoint ${address.address}:$port)';
}

class ConnectedClient extends UDPClient {
  int sessionId;
  int? _sequenceId;

  ConnectedClient({
    required super.id,
    required super.address,
    required super.port,
    required super.deviceName,
    required this.sessionId,
  });

  // Sent sequence Id must be higher than current Id, but not enforcing exact match to allow data loss.
  bool verifyDataSequence(int receivedId) {
    if (_sequenceId == null) {
      _sequenceId = receivedId;
      return true;
    }

    if (receivedId <= _sequenceId!) {
      return false;
    }

    _sequenceId = receivedId;
    return true;
  }

  @override
  bool operator ==(Object other) =>
      (identical(this, other)) ||
      (other is ConnectedClient && other.sessionId == sessionId);

  @override
  int get hashCode => sessionId.hashCode;

  @override
  String toString() =>
      'ConnectedClient(sessionId: $sessionId, ${super.toString()})';
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:core/udp/udp_data.dart';

import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

void main() {
  final String deviceName = "Computer 3000 Super Mega";
  final int protocolVersion = 100;

  late final Uint8List broadcastPacket;
  late final Uint8List connectRequestPacket;
  late final Uint8List connectAcceptPacket;
  late final Uint8List connectDenyPacket;
  late final Uint8List heartbeatPacket;

  test('build broadcast package, ensure correct bytes length, parse it into [BroadcastPacket]', () {
    final uuid = Uuid().v1();
    broadcastPacket = PacketBuilder.broadcast(uuid, deviceName);

    expect(
      broadcastPacket.lengthInBytes,
      1 +
          1 +
          magicStringLength +
          36 +
          1 +
          utf8.encode(deviceName.toString()).lengthInBytes,
    );

    var packetData = PacketParser.parse(broadcastPacket);
    expect(packetData.packetType, PacketType.broadcast);
    expect(packetData is BroadcastPacket, true);
    final broadcast = packetData as BroadcastPacket;
    expect(broadcast.id, uuid);
    expect(broadcast.deviceName, deviceName);
  });

  test(
    'build connect request package, parse it into [ConnectRequestPacket]',
    () {
      final int sessionId = 12345678;
      connectRequestPacket = PacketBuilder.connectRequest(sessionId);

      expect(connectRequestPacket.lengthInBytes, 1 + 4 + 4);

      final packetData = PacketParser.parse(connectRequestPacket);
      expect(packetData.packetType, PacketType.connectRequest);
      expect(packetData is ConnectRequestPacket, true);
      final request = packetData as ConnectRequestPacket;
      expect(request.protocolVersion, protocolVersion);
      expect(request.sessionId, sessionId);
    },
  );

  test('building package with non 8 digit sessionID, expect ArgumentError', () {
    // Less than 8 digits (< 10000000)
    expect(() => PacketBuilder.connectRequest(9999999), throwsArgumentError);
    expect(() => PacketBuilder.connectRequest(0), throwsArgumentError);
    expect(() => PacketBuilder.connectRequest(-12345678), throwsArgumentError);

    // More than 8 digits (> 99999999)
    expect(() => PacketBuilder.connectRequest(100000000), throwsArgumentError);

    // Verify other builders also enforce 8-digit session ID
    expect(
      () => PacketBuilder.connectResponse(1234567, true),
      throwsArgumentError,
    );
    expect(
      () => PacketBuilder.connectResponse(100000000, false),
      throwsArgumentError,
    );
    expect(() => PacketBuilder.disconnectRequest(9999999), throwsArgumentError);
    expect(() => PacketBuilder.data(1234567, {'test': 1}), throwsArgumentError);
    expect(() => PacketBuilder.heartbeat(9999999), throwsArgumentError);
  });

  test(
    'build connect response package, parse it into [ConnectResponsePacket]',
    () {
      final int sessionId = 87654321;

      // Connect Accept
      connectAcceptPacket = PacketBuilder.connectResponse(sessionId, true);
      expect(connectAcceptPacket.lengthInBytes, 1 + 1 + 4);

      final acceptData = PacketParser.parse(connectAcceptPacket);
      expect(acceptData.packetType, PacketType.connectResponse);
      expect(acceptData is ConnectResponsePacket, true);
      final acceptPacket = acceptData as ConnectResponsePacket;
      expect(acceptPacket.connectionAccepted, true);
      expect(acceptPacket.sessionId, sessionId);

      // Connect Deny
      connectDenyPacket = PacketBuilder.connectResponse(sessionId, false);
      expect(connectDenyPacket.lengthInBytes, 1 + 1 + 4);

      final denyData = PacketParser.parse(connectDenyPacket);
      expect(denyData.packetType, PacketType.connectResponse);
      expect(denyData is ConnectResponsePacket, true);
      final denyPacket = denyData as ConnectResponsePacket;
      expect(denyPacket.connectionAccepted, false);
      expect(denyPacket.sessionId, sessionId);
    },
  );

  test(
    'build data package, parse it into [DataPackage], ensure data validity',
    () {
      final int sessionId = 12345678;
      final Map<String, dynamic> appData = {
        'steering': 0.75,
        'throttle': 1.0,
        'brake': 0.0,
        'handbrake': false,
        'gear': 'D',
        'buttons': [1, 2, 3],
      };

      final dataPacketBytes = PacketBuilder.data(sessionId, appData);
      final expectedPayloadBytes = utf8.encode(jsonEncode(appData));
      expect(
        dataPacketBytes.lengthInBytes,
        1 + 4 + expectedPayloadBytes.lengthInBytes,
      );

      final packetData = PacketParser.parse(dataPacketBytes);
      expect(packetData.packetType, PacketType.data);
      expect(packetData is DataPacket, true);
      final dataPacket = packetData as DataPacket;
      expect(dataPacket.sessionId, sessionId);
      expect(dataPacket.appData, equals(appData));
      expect(dataPacket.appData['steering'], 0.75);
      expect(dataPacket.appData['throttle'], 1.0);
      expect(dataPacket.appData['brake'], 0.0);
      expect(dataPacket.appData['handbrake'], false);
      expect(dataPacket.appData['gear'], 'D');
      expect(dataPacket.appData['buttons'], [1, 2, 3]);
    },
  );

  test('build heartbeat package, parse it into [HeartbeatPackage]', () {
    final int sessionId = 12345678;
    heartbeatPacket = PacketBuilder.heartbeat(sessionId);

    expect(heartbeatPacket.lengthInBytes, 1 + 4);

    final packetData = PacketParser.parse(heartbeatPacket);
    expect(packetData.packetType, PacketType.heartbeat);
    expect(packetData is HeartbeatPacket, true);
    final heartbeat = packetData as HeartbeatPacket;
    expect(heartbeat.sessionId, sessionId);
  });

  test(
    'build disconnect request package, parse it into [DisconnectRequestPacket]',
    () {
      final int sessionId = 12345678;
      final disconnectPacket = PacketBuilder.disconnectRequest(sessionId);

      expect(disconnectPacket.lengthInBytes, 1 + 4);

      final packetData = PacketParser.parse(disconnectPacket);
      expect(packetData.packetType, PacketType.disconnectRequest);
      expect(packetData is DisconnectRequestPacket, true);
      final disconnect = packetData as DisconnectRequestPacket;
      expect(disconnect.sessionId, sessionId);
    },
  );

  test('build uuid refresh package, parse it into [UUIDRefreshPacket]', () {
    final uuidRefreshPacket = PacketBuilder.uuidRefresh();

    expect(uuidRefreshPacket.lengthInBytes, 1 + 1 + magicStringLength);

    final packetData = PacketParser.parse(uuidRefreshPacket);
    expect(packetData.packetType, PacketType.uuidRefreshRequest);
    expect(packetData is UUIDRefreshPacket, true);
  });

  test('parse empty packet into [UndefinedPacket]', () {
    final packetData = PacketParser.parse(Uint8List(0));
    expect(packetData.packetType, PacketType.undefined);
    expect(packetData is UndefinedPacket, true);
  });

  test('build broadcast with invalid UUID throws ArgumentError', () {
    expect(
      () => PacketBuilder.broadcast('invalid-uuid-format', deviceName),
      throwsArgumentError,
    );
  });

  test('parsing invalid packet type or malformed data throws exception', () {
    // Invalid packet type
    expect(
      () => PacketParser.parse(Uint8List.fromList([255])),
      throwsA(isA<FormatException>()),
    );

    // Truncated connect request packet
    expect(
      () => PacketParser.parse(
        Uint8List.fromList([PacketType.connectRequest.value, 1, 2, 3]),
      ),
      throwsA(isA<FormatException>()),
    );

    // Truncated heartbeat packet
    expect(
      () => PacketParser.parse(
        Uint8List.fromList([PacketType.heartbeat.value, 1, 2]),
      ),
      throwsA(isA<FormatException>()),
    );

    // Broadcast packet with wrong magic string
    final badMagicBytes = Uint8List.fromList([
      PacketType.broadcast.value,
      4,
      ...utf8.encode("FAIL"),
      ...utf8.encode(Uuid().v1()),
      4,
      ...utf8.encode("test"),
    ]);
    expect(() => PacketParser.parse(badMagicBytes), throwsA(isA<StateError>()));
  });
}

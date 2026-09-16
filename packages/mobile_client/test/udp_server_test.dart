import 'dart:io';
import 'package:core/udp.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_client/udp_server.dart';
import 'package:mobile_client/utils/generate_session_id.dart';

void main() {
  group('generateSessionId', () {
    test('generates valid 8-digit session IDs within [10000000, 99999999]', () {
      for (int i = 0; i < 1000; i++) {
        final id = generateSessionId();
        expect(id >= 10000000, isTrue);
        expect(id <= 99999999, isTrue);
        expect(() => verifySessionId(id), returnsNormally);
      }
    });
  });

  group('UDPServer', () {
    late UDPServer server;
    late RawDatagramSocket mockPcSocket;
    const int serverPort = 55100;
    const int pcPort = 55101;

    setUp(() async {
      mockPcSocket = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        pcPort,
        reuseAddress: true,
      );
      final created = await UDPServer.create(serverPort);
      expect(created, isNotNull);
      server = created!;
    });

    tearDown(() async {
      await server.dispose();
      mockPcSocket.close();
    });

    test('discovers simulated PC sending broadcast packet', () async {
      const pcUuid = '123e4567-e89b-12d3-a456-426614174000';
      const pcName = 'Gaming PC Alpha';

      final broadcastBytes = PacketBuilder.broadcast(pcUuid, pcName);

      UDPClient? discovered;
      server.startClientSearch((client) {
        discovered = client;
      });

      // Mock PC sends broadcast to UDPServer
      mockPcSocket.send(
        broadcastBytes,
        InternetAddress.loopbackIPv4,
        serverPort,
      );

      await expectLater(
        Future.doWhile(() async {
          if (discovered != null) return false;
          await Future.delayed(const Duration(milliseconds: 20));
          return true;
        }).timeout(const Duration(seconds: 2)),
        completes,
      );

      expect(discovered, isNotNull);
      expect(discovered!.id, pcUuid);
      expect(discovered!.deviceName, pcName);
      expect(discovered!.address.address, InternetAddress.loopbackIPv4.address);

      server.stopClientSearch();
      expect(server.isSearching, isFalse);
    });

    test('connectClient succeeds when PC accepts connection', () async {
      const pcUuid = '123e4567-e89b-12d3-a456-426614174001';
      const pcName = 'Simulated Rig';
      final target = UDPClient(
        id: pcUuid,
        address: InternetAddress.loopbackIPv4,
        port: pcPort,
        deviceName: pcName,
      );

      // Listen on mock PC to reply to connectRequest
      mockPcSocket.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = mockPcSocket.receive();
          if (dg != null) {
            try {
              final packet = PacketParser.parse(dg.data);
              if (packet is ConnectRequestPacket) {
                final responseBytes = PacketBuilder.connectResponse(
                  packet.sessionId,
                  true,
                );
                mockPcSocket.send(responseBytes, dg.address, dg.port);
              }
            } catch (_) {}
          }
        }
      });

      final connected = await server.connectClient(target);
      expect(connected, isTrue);
      expect(server.isConnected, isTrue);
      expect(server.connectedClient, isNotNull);
      expect(server.connectedClient!.deviceName, pcName);

      // Test sending controller data
      final dataSent = server.sendData({
        'steering': 0.25,
        'throttle': 0.8,
        'brake': 0.0,
      });
      expect(dataSent, isTrue);

      await server.disconnectClient();
      expect(server.isConnected, isFalse);
    });

    test('connectClient fails when PC rejects connection', () async {
      const pcUuid = '123e4567-e89b-12d3-a456-426614174002';
      final target = UDPClient(
        id: pcUuid,
        address: InternetAddress.loopbackIPv4,
        port: pcPort,
        deviceName: 'Busy PC',
      );

      mockPcSocket.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = mockPcSocket.receive();
          if (dg != null) {
            try {
              final packet = PacketParser.parse(dg.data);
              if (packet is ConnectRequestPacket) {
                final responseBytes = PacketBuilder.connectResponse(
                  packet.sessionId,
                  false, // Reject
                );
                mockPcSocket.send(responseBytes, dg.address, dg.port);
              }
            } catch (_) {}
          }
        }
      });

      final connected = await server.connectClient(target);
      expect(connected, isFalse);
      expect(server.isConnected, isFalse);
    });
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'packet_constants.dart';
import 'packet_models.dart';
import 'packet_type.dart';

abstract final class PacketParser {
  /// Parses raw incoming UDP bytes into a strongly-typed [PacketData] packet.
  static PacketData parse(Uint8List packet) {
    if (packet.isEmpty) {
      return const UndefinedPacket();
    }

    final Uint8List bytes = packet;
    final ByteData reader = bytes.buffer.asByteData(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );

    int currentOffset = 0;
    final rawType = reader.getUint8(currentOffset++);
    final PacketType type = PacketType.fromValue(rawType);

    switch (type) {
      case PacketType.broadcast:
        if (bytes.length < currentOffset + 1) {
          throw const FormatException(
            "Truncated broadcast packet: missing magic length",
          );
        }

        final magicStringLength = reader.getUint8(currentOffset++);
        if (bytes.length < currentOffset + magicStringLength) {
          throw const FormatException(
            "Truncated broadcast packet: insufficient bytes for magic string",
          );
        }
        final magicStringBytes = bytes.sublist(
          currentOffset,
          currentOffset + magicStringLength,
        );
        currentOffset += magicStringLength;

        final decodedMagicString = utf8.decode(magicStringBytes);
        if (decodedMagicString != magicString) {
          throw StateError(
            "Invalid Magic String fetched. Expected: $magicString, Get: $decodedMagicString",
          );
        }

        if (bytes.length < currentOffset + 1) {
          throw const FormatException(
            "Truncated broadcast packet: missing uuid",
          );
        }

        final uuidBytes = bytes.sublist(
          currentOffset,
          currentOffset + 36,
        ); // UUID length
        final decodedUuid = utf8.decode(uuidBytes);

        if (!Uuid.isValidUUID(fromString: decodedUuid)) {
          throw const FormatException(
            "Broadcast packet: UUID format is invalid",
          );
        }

        currentOffset += 36;

        if (bytes.length < currentOffset + 1) {
          throw const FormatException(
            "Truncated broadcast packet: missing device name length",
          );
        }

        final deviceNameLength = reader.getUint8(currentOffset++);
        if (bytes.length < currentOffset + deviceNameLength) {
          throw const FormatException(
            "Truncated broadcast packet: insufficient bytes for device name",
          );
        }
        final deviceName = utf8.decode(
          bytes.sublist(currentOffset, currentOffset + deviceNameLength),
        );

        return BroadcastPacket(id: decodedUuid, deviceName: deviceName);

      case PacketType.connectRequest:
        if (bytes.length < 9) {
          throw FormatException(
            "Truncated connectRequest packet: expected 9 bytes, got ${bytes.length}",
          );
        }
        final protocolVersion = reader.getUint32(currentOffset, Endian.big);
        currentOffset += 4;
        final sessionId = reader.getUint32(currentOffset, Endian.big);

        return ConnectRequestPacket(
          protocolVersion: protocolVersion,
          sessionId: sessionId,
        );

      case PacketType.connectResponse:
        if (bytes.length < 6) {
          throw FormatException(
            "Truncated connectResponse packet: expected 6 bytes, got ${bytes.length}",
          );
        }
        final responseInt = reader.getUint8(currentOffset++);
        final connectionAccepted = responseInt == 0;
        final sessionId = reader.getUint32(currentOffset, Endian.big);

        return ConnectResponsePacket(
          connectionAccepted: connectionAccepted,
          sessionId: sessionId,
        );

      case PacketType.disconnectRequest:
        if (bytes.length < 5) {
          throw FormatException(
            "Truncated disconnectRequest packet: expected 5 bytes, got ${bytes.length}",
          );
        }
        final sessionId = reader.getUint32(currentOffset, Endian.big);

        return DisconnectRequestPacket(sessionId: sessionId);

      case PacketType.data:
        if (bytes.length < 5) {
          throw FormatException(
            "Truncated data packet: expected at least 5 bytes, got ${bytes.length}",
          );
        }
        final sessionId = reader.getUint32(currentOffset, Endian.big);
        currentOffset += 4;

        final dataBytes = bytes.sublist(currentOffset);
        final dynamic decodedJson = jsonDecode(utf8.decode(dataBytes));
        final Map<String, dynamic> dataMap = decodedJson is Map<String, dynamic>
            ? decodedJson
            : Map<String, dynamic>.from(decodedJson as Map);

        return DataPacket(sessionId: sessionId, appData: dataMap);

      case PacketType.heartbeat:
        if (bytes.length < 5) {
          throw FormatException(
            "Truncated heartbeat packet: expected 5 bytes, got ${bytes.length}",
          );
        }
        final sessionId = reader.getUint32(currentOffset, Endian.big);

        return HeartbeatPacket(sessionId: sessionId);

      case PacketType.uuidRefreshRequest:
        if (bytes.length < currentOffset + 1) {
          throw const FormatException(
            "Truncated uuidRefresh packet: missing magic length",
          );
        }

        final magicStringLength = reader.getUint8(currentOffset++);
        if (bytes.length < currentOffset + magicStringLength) {
          throw const FormatException(
            "Truncated broadcast packet: insufficient bytes for magic string",
          );
        }

        final magicStringBytes = bytes.sublist(
          currentOffset,
          currentOffset + magicStringLength,
        );
        currentOffset += magicStringLength;

        final decodedMagicString = utf8.decode(magicStringBytes);
        if (decodedMagicString != magicString) {
          throw StateError(
            "Invalid Magic String fetched. Expected: $magicString, Get: $decodedMagicString",
          );
        }

        return UUIDRefreshPacket();

      case PacketType.undefined:
        return const UndefinedPacket();
    }
  }
}

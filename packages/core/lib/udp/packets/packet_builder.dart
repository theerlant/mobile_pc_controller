import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'packet_constants.dart';
import 'packet_type.dart';

abstract final class PacketBuilder {
  /// Generates broadcast packet bytes.
  /// Format (in Bytes): [PacketType, MagicStringLength, [MagicStringBytes], DeviceNameLength, [DeviceNameBytes]]
  static Uint8List broadcast(String id, String deviceName) {
    if (!Uuid.isValidUUID(fromString: id)) {
      throw ArgumentError.value(id, "id", "ID is not a valid UUID!");
    }
    var encodedId = utf8.encode(id);

    var encodedName = utf8.encode(deviceName);
    if (encodedName.length > 255) {
      // Safely truncate deviceName so UTF-8 encoded bytes fit into 1 byte (<= 255 bytes)
      while (encodedName.length > 255) {
        deviceName = deviceName.substring(0, deviceName.length - 1);
        encodedName = utf8.encode(deviceName);
      }
    }
    final encodedNameLength = encodedName.length;

    final builder = BytesBuilder(copy: false);
    builder.addByte(PacketType.broadcast.value);
    builder.addByte(magicStringLength);
    builder.add(magicStringBytes);
    builder.add(encodedId); // UUID standard is 36 ASCII chars -> 36 bytes.
    builder.addByte(encodedNameLength);
    builder.add(encodedName);

    return builder.takeBytes();
  }

  /// Generates connectRequest packet bytes.
  static Uint8List connectRequest(int sessionId) {
    verifySessionId(sessionId);

    const bufferSize =
        1 + // PacketType
        4 + // ProtocolVersion
        4; // SessionID

    final data = Uint8List(bufferSize);
    final byteData = ByteData.view(data.buffer);
    byteData.setUint8(0, PacketType.connectRequest.value);
    byteData.setUint32(1, protocolVersion, Endian.big);
    byteData.setUint32(5, sessionId, Endian.big);

    return data;
  }

  /// Generates connectResponse packet bytes.
  static Uint8List connectResponse(int sessionId, bool acceptConnection) {
    verifySessionId(sessionId);

    const bufferSize =
        1 + // PacketType
        1 + // Status code (0 ACC / 1 DENY)
        4; // SessionID

    final data = Uint8List(bufferSize);
    final byteData = ByteData.view(data.buffer);
    byteData.setUint8(0, PacketType.connectResponse.value);
    byteData.setUint8(1, acceptConnection ? 0 : 1);
    byteData.setUint32(2, sessionId, Endian.big);

    return data;
  }

  /// Generate disconnectRequest packet bytes without confirmation.
  static Uint8List disconnectRequest(int sessionId) {
    verifySessionId(sessionId);

    const bufferSize = 1 + 4;

    final data = Uint8List(bufferSize);
    final byteData = ByteData.view(data.buffer);
    byteData.setUint8(0, PacketType.disconnectRequest.value);
    byteData.setUint32(1, sessionId, Endian.big);

    return data;
  }

  /// Generates data packet bytes with JSON payload.
  static Uint8List data(int sessionId, Map<String, dynamic> appData) {
    verifySessionId(sessionId);

    const headerSize =
        1 + // PacketType
        4; // SessionId
    final header = Uint8List(headerSize);
    final headerView = ByteData.view(header.buffer);

    headerView.setUint8(0, PacketType.data.value);
    headerView.setUint32(1, sessionId, Endian.big);

    final dataBytes = utf8.encode(jsonEncode(appData));

    final builder = BytesBuilder(copy: false);
    builder.add(header);
    builder.add(dataBytes);

    return builder.takeBytes();
  }

  /// Generates heartbeat packet bytes.
  static Uint8List heartbeat(int sessionId) {
    verifySessionId(sessionId);

    const dataSize = 1 + 4; // 1 PacketType + 4 SessionId

    final data = Uint8List(dataSize);
    final byteData = ByteData.view(data.buffer);
    byteData.setUint8(0, PacketType.heartbeat.value);
    byteData.setUint32(1, sessionId, Endian.big);

    return data;
  }

  static Uint8List uuidRefresh() {
    final builder = BytesBuilder(copy: false);
    builder.addByte(PacketType.uuidRefreshRequest.value);
    builder.addByte(magicStringLength);
    builder.add(magicStringBytes);

    return builder.takeBytes();
  }
}

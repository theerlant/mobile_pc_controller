import 'dart:convert';
import 'dart:typed_data';

import 'package:core/udp/udp_packet/udp_packet.dart';
import 'package:core/udp/udp_packet/packet_types.dart';

const int byte32Bit = 4;

class BroadcastPacket extends UdpPacket {
  /// 8 digits identifier on 32 bit integer
  final int deviceId;

  /// Human readable Device name
  final String deviceName;

  const BroadcastPacket(this.deviceId, this.deviceName)
    : super(packetTypeBroadcast);

  @override
  Uint8List toBuffer() {
    final header = super.toBuffer();
    final deviceNameBuffer = utf8.encode(deviceName);

    final builder = BytesBuilder();

    // Add the header bytes
    builder.add(header);

    // Add the 32-bit deviceId
    final idBytes = ByteData(4)..setInt32(0, deviceId, Endian.big);
    builder.add(idBytes.buffer.asUint8List());

    // Add the 8-bit integer (1 byte) for the device name length
    builder.addByte(deviceNameBuffer.length);

    // Add the UTF-8 device name bytes
    builder.add(deviceNameBuffer);

    return builder.takeBytes();
  }
}

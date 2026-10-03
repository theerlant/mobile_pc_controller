import 'package:flutter/foundation.dart';

abstract class UdpPacket {
  /// Packet type identifier
  final int packetType;

  /// Hard-coded app protocol versioning
  final int version = 100;

  const UdpPacket(this.packetType);

  @mustCallSuper
  Uint8List toBuffer() {
    final data = ByteData(2);
    data.setUint8(0, packetType);
    data.setUint8(1, version);

    return data.buffer.asUint8List();
  }
}

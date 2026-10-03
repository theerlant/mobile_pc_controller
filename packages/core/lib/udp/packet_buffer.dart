import 'dart:collection';
import 'dart:io';

import 'package:core/udp/udp_packet/udp_packet.dart';

typedef PacketBuffer = ({UdpPacket packet, InternetAddress address, int port});

class PacketBufferQueue {
  final Queue<PacketBuffer> _buffer = Queue();

  bool get isBufferNotEmpty => _buffer.isNotEmpty;
  bool get isBufferEmpty => _buffer.isEmpty;

  /// Drop all [UdpPacket] inside the buffer.
  void drop() => _buffer.clear();

  /// Add buffer to the back of the queue.
  void add(
    UdpPacket packet, {
    required InternetAddress address,
    required int port,
  }) => _buffer.addLast((packet: packet, address: address, port: port));

  /// Return the oldest buffer or `null` if empty.
  PacketBuffer? get() {
    if (_buffer.isEmpty) return null;

    return _buffer.removeFirst();
  }

  /// Drain buffers to be handled by [onBuffer] callback.
  /// It will pass buffer sequentially from the oldest one.
  void drain(Function(PacketBuffer buffer) onBuffer) {
    while (_buffer.isNotEmpty) {
      onBuffer(_buffer.removeFirst());
    }
  }
}

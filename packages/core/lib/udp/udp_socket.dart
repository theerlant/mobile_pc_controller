import 'dart:io';

import 'package:core/udp/packet_buffer.dart';
import 'package:core/udp/udp_packet/internal/udp_packet.dart';
import 'package:core/udp/udp_packet/packets.dart';

final _broadcastIPv4 = InternetAddress("255.255.255.255");

class UdpSocket {
  final RawDatagramSocket _socket;
  final int _port;
  int get port => _port;

  bool _writeReady = false;

  /// Whether the socket is ready to write.
  /// Calling [send] or [broadcast] when this is `false` might cause them to fail.
  bool get isWriteReady => _writeReady;

  Function(PacketBuffer buffer)? _receiveCallback;
  Function()? _writeReadyCallback;

  final PacketBufferQueue _receivedBuffers = PacketBufferQueue();

  UdpSocket._(this._socket, this._port) {
    _socket.listen((event) {
      if (event == RawSocketEvent.read) {
        // Drain the socket buffer.
        while (true) {
          Datagram? datagram = _socket.receive();

          if (datagram == null) break;

          // TODO: Run packet resolver API. Only callback if packet is correct.
          final placeholder = BroadcastPacket(0, "Null");

          if (_receiveCallback != null) {
            _receiveCallback!.call((
              packet: placeholder,
              address: datagram.address,
              port: datagram.port,
            ));
          } else {
            _receivedBuffers.add(
              placeholder,
              address: datagram.address,
              port: datagram.port,
            );
          }
        }
      } else if (event == RawSocketEvent.write) {
        _writeReady = true;

        _writeReadyCallback?.call();
      }
    });
  }

  /// Create a UDPSocket instance for all local networks and bind it to the selected port.
  static Future<UdpSocket> create([int port = 5000]) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);

    socket.broadcastEnabled = true;

    return UdpSocket._(socket, port);
  }

  void dispose() {
    _socket.close();
  }

  /// Immediately send [packet] data to [targetAddress] on [targetPort].
  /// If [targetPort] is ommited, it will use the binding [port].
  ///
  /// Return `true` if the send request is passed to the operating system, but does not indicate the packet is successfully sent to the target.
  bool send(
    UdpPacket packet, {
    required InternetAddress targetAddress,
    int? targetPort,
  }) {
    final buffer = packet.toBuffer();

    final success =
        _socket.send(buffer, targetAddress, targetPort ?? _port) ==
        buffer.length;

    // Also assign _writeReady
    if (!success) _writeReady = false;

    return success;
  }

  /// Immediately broadcast [packet] data to all local address on [targetPort].
  /// If [targetPort] is ommited, it will use the binding [port].
  ///
  /// Return `true` if the send request is passed to the operating system, but does not indicate the packet is successfully broadcasted.
  bool broadcast(UdpPacket packet, {int? targetPort}) {
    return send(packet, targetAddress: _broadcastIPv4, targetPort: targetPort);
  }

  /// Assign a listener to [onReceive] event, and optionally [onWriteReady] event.
  ///
  /// Immediately after assigning a listener it will call [onReceive] callback until the buffer is drained, except
  /// if expicitly disabled by setting [drainBuffer].
  /// In the case that [drainBuffer] is `false`, the buffer will be stuck unmanaged even on new [onReceive] event which only drain the OS socket buffer.
  ///
  /// If [onWriteReady] callback is ommited, [isWriteReady] can still be used to assert the socket is ready to send data.
  void listen(
    Function(PacketBuffer buffer) onReceive, {
    Function()? onWriteReady,
    bool drainBuffer = true,
  }) {
    _receiveCallback = onReceive;
    _writeReadyCallback = onWriteReady;

    if (drainBuffer == false) return;

    _receivedBuffers.drain((buffer) => onReceive(buffer));
  }

  /// Immediately clear received data buffer without handling them.
  void dropReceivedBuffers() {
    _receivedBuffers.drop();
  }

  /// Clear received data buffer by passing them to [onBuffer] callback to be handled.
  void drainReceivedBuffers(
    Function(UdpPacket packet, InternetAddress address, int port) onBuffer,
  ) {
    _receivedBuffers.drain(
      (data) => onBuffer(data.packet, data.address, data.port),
    );
  }
}

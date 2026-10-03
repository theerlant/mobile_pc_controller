enum PacketType {
  undefined(0),
  broadcast(1),
  connectRequest(2),
  connectResponse(3),
  disconnectRequest(4),
  data(5),
  heartbeat(6),
  uuidRefreshRequest(7);

  final int value;
  const PacketType(this.value);

  static PacketType fromValue(int value) {
    return PacketType.values.firstWhere(
      (e) => e.value == value,
      orElse: () =>
          throw FormatException("Invalid PacketType byte fetched: $value"),
    );
  }
}

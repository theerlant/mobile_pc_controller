import 'package:mobile_client/services/udp_server.dart';
import 'package:signals/signals_flutter.dart';

UDPServer? _current;

final appUdpServer = futureSignal<UDPServer>(() async {
  return await untracked(() async {
    await _current?.dispose();
    final server = await UDPServer.create();
    _current = server;
    return server;
  });
}, options: AsyncSignalOptions(name: "appUDPServer instance"));

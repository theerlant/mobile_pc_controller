import 'package:mobile_client/services/udp_server.dart';
import 'package:signals/signals_flutter.dart';

UDPServer? _current;

// Hold the server state in a standard signal, starting as Loading
final appUdpServer = signal<AsyncState<UDPServer>>(
  const AsyncLoading(),
  options: SignalOptions(name: "appUDPServer instance"),
);

// Imperative initialization function
Future<void> initUdpServer() async {
  appUdpServer.value = const AsyncLoading();
  try {
    await _current?.dispose();
    final server = await UDPServer.create();
    _current = server;

    appUdpServer.value = AsyncData(server);
  } catch (e, s) {
    appUdpServer.value = AsyncError(e, s);
  }
}

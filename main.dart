import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

/// Custom Dart Frog entrypoint.
///
/// Without this file, the generated server binds [InternetAddress.anyIPv6]
/// (`::`) unconditionally. On a host with IPv6 disabled — which is the default
/// in many container runtimes — that fails at startup with
/// `SocketException: Address family not supported by protocol (errno 97)`
/// and the process never listens at all.
///
/// Binding is therefore driven by `HOST`, defaulting to `0.0.0.0` so the
/// server is reachable from other devices on the network (a phone on the same
/// Wi-Fi, say) rather than only from the machine it runs on. Set `HOST=::` to
/// bind IPv6 where it is available, or `HOST=127.0.0.1` to restrict to
/// loopback.
Future<HttpServer> run(Handler handler, InternetAddress ip, int port) {
  return serve(handler, _address(), port);
}

InternetAddress _address() {
  final host = Platform.environment['HOST'];
  if (host == null || host.isEmpty) return InternetAddress.anyIPv4;

  return switch (host) {
    '0.0.0.0' => InternetAddress.anyIPv4,
    '::' => InternetAddress.anyIPv6,
    _ => InternetAddress.tryParse(host) ?? InternetAddress.anyIPv4,
  };
}

// Conditional export: web impl on browser, stub on mobile/desktop.
export 'ethereum_bridge_web.dart'
    if (dart.library.io) 'ethereum_bridge_stub.dart';

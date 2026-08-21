/// Abstraction over the Tor daemon so the rest of the app can bring Tor up and
/// down without caring about the platform.
abstract class TorService {
  /// Whether the daemon process is currently running.
  bool get isRunning;

  /// The SOCKS5 proxy port Tor exposes for outgoing connections (this device
  /// reaching friends). Connections to it are routed through the Tor network.
  int get socksPort;

  /// This device's own onion address once Tor is running, e.g. the 56-char v3
  /// address (without the `.onion` suffix).
  Future<String> onionAddress();

  /// The onion address when known, or null before Tor has published one.
  String? get onion;

  /// Starts the daemon. Must be called before [onionAddress]/[socksPort] are
  /// useful.
  Future<void> start();

  /// Stops the daemon and tears down the onion service.
  Future<void> stop();
}
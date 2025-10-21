import 'package:shuttle_tracker/services/globals.dart' as globals;
import 'package:shuttle_tracker/services/location_stomp_client.dart';
import 'package:flutter/foundation.dart';

// High-level singleton service that configures and exposes the LocationStompClient
// using values from globals.dart. Adjust globals to match your server.
class LocationWsService {
  static final LocationWsService _instance = LocationWsService._internal();
  factory LocationWsService() => _instance;
  LocationWsService._internal();

  LocationStompClient? _client;

  Map<String, String>? _connHeaders() {
    if (globals.authToken.trim().isEmpty) return null;
    return {'Authorization': 'Bearer ${globals.authToken}'};
  }

  LocationStompClient _ensureClient() {
    if (_client == null) {
      final wsUrl = LocationStompClient.buildWebSocketUrl(
        globals.apiBaseUrl,
        globals.wsEndpointPath, // e.g. '/ws' or '/stomp'
      );
      // Log the final websocket URL for debugging (helps diagnose 404 / upgrade errors)
      debugPrint('LocationWsService: connecting to websocket URL -> $wsUrl');
      _client = LocationStompClient(
        websocketUrl: wsUrl,
        appPrefix: globals.appDestinationPrefix,
        topicPrefix: globals.topicDestinationPrefix,
        connectionHeaders: _connHeaders(),
      );
    }
    return _client!;
  }

  bool get isConnected => _client?.isConnected == true;

  void _setClient(LocationStompClient c) {
    // replace existing client and clear previous
    try {
      _client?.disconnect();
    } catch (_) {}
    _client = c;
  }

  void connect({
    void Function(dynamic frame)? onConnected,
    void Function(Object error)? onError,
  }) {
    // Build candidate URLs to try (primary + fallbacks)
    final primary = LocationStompClient.buildWebSocketUrl(globals.apiBaseUrl, globals.wsEndpointPath);

    // derive host-only base (strip any path from apiBaseUrl)
    Uri? parsed;
    try {
      parsed = Uri.parse(globals.apiBaseUrl);
    } catch (_) {
      parsed = null;
    }
    final hostOnly = (parsed == null)
        ? null
        : Uri(scheme: parsed.scheme, host: parsed.host, port: parsed.hasPort ? parsed.port : null).toString();

    final alt1 = (hostOnly != null) ? LocationStompClient.buildWebSocketUrl(hostOnly, globals.wsEndpointPath) : null;
    // also try '/websocket' suffix common with SockJS setups
    final alt2 = (hostOnly != null) ? LocationStompClient.buildWebSocketUrl(hostOnly, '${globals.wsEndpointPath}/websocket') : null;
    final alt3 = LocationStompClient.buildWebSocketUrl(globals.apiBaseUrl, '${globals.wsEndpointPath}/websocket');

    final candidates = <String>[];
    void addIf(String? u) {
      if (u == null) return;
      if (!candidates.contains(u)) candidates.add(u);
    }

    addIf(primary);
    addIf(alt1);
    addIf(alt2);
    addIf(alt3);

    int idx = 0;
    Object? lastErr;

    void tryNext() {
      if (idx >= candidates.length) {
        // All attempts failed
        if (onError != null) onError(lastErr ?? Exception('Failed to connect to any websocket endpoint'));
        return;
      }
      final url = candidates[idx++];
      debugPrint('LocationWsService: attempting websocket connect -> $url');
      final client = LocationStompClient(
        websocketUrl: url,
        appPrefix: globals.appDestinationPrefix,
        topicPrefix: globals.topicDestinationPrefix,
        connectionHeaders: _connHeaders(),
      );

      bool handled = false;
      client.connect(onConnected: (frame) {
        handled = true;
        // adopt this client
        _setClient(client);
        debugPrint('LocationWsService: connected via -> $url');
        onConnected?.call(frame);
      }, onError: (err, [st]) {
        if (handled) return; // ignore errors after connected
        lastErr = err;
        debugPrint('LocationWsService: connect failed for $url -> $err');
        // try next candidate
        tryNext();
      });
    }

    tryNext();
  }

  void disconnect() {
    _client?.disconnect();
    _client = null;
  }

  void subscribeToLocations(void Function(LocationMessageDto msg) onMessage) {
    _ensureClient().subscribeToLocations(onMessage);
  }

  void sendLocationUpdate({
    required String driverId,
    required String shuttleId,
    required double latitude,
    required double longitude,
    String? timestampIso8601,
    String? status,
  }) {
    _ensureClient().sendLocationUpdate(
          driverId: driverId,
          shuttleId: shuttleId,
          latitude: latitude,
          longitude: longitude,
          timestampIso8601: timestampIso8601,
          status: status,
        );
  }
}

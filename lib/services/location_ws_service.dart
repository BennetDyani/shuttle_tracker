import 'package:shuttle_tracker/services/globals.dart' as globals;
import 'package:shuttle_tracker/services/location_stomp_client.dart';

// High-level singleton service that configures and exposes the LocationStompClient
// using values from globals.dart. Adjust globals to match your server.
class LocationWsService {
  static final LocationWsService _instance = LocationWsService._internal();
  factory LocationWsService() => _instance;
  LocationWsService._internal();

  LocationStompClient? _client;

  LocationStompClient _ensureClient() {
    if (_client == null) {
      final wsUrl = LocationStompClient.buildWebSocketUrl(
        globals.apiBaseUrl,
        globals.wsEndpointPath, // e.g. '/ws' or '/stomp'
      );
      _client = LocationStompClient(
        websocketUrl: wsUrl,
        appPrefix: globals.appDestinationPrefix,
        topicPrefix: globals.topicDestinationPrefix,
      );
    }
    return _client!;
  }

  bool get isConnected => _client?.isConnected == true;

  void connect({
    void Function(dynamic frame)? onConnected,
    void Function(Object error)? onError,
  }) {
    final client = _ensureClient();
    client.connect(
      onConnected: (frame) => onConnected?.call(frame),
      onError: (error, [st]) => onError?.call(error),
    );
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
  }) {
    _ensureClient().sendLocationUpdate(
          driverId: driverId,
          shuttleId: shuttleId,
          latitude: latitude,
          longitude: longitude,
          timestampIso8601: timestampIso8601,
        );
  }
}

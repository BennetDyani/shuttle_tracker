// A reusable STOMP-over-WebSocket client for location updates and broadcasts.
// It sends payloads matching LocationMessageDTO: driverId, shuttleId, latitude,
// longitude, and optional ISO-8601 timestamp string.

import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

class LocationMessageDto {
  final String driverId;
  final String shuttleId;
  final double latitude;
  final double longitude;
  final String? timestamp; // ISO-8601, optional when sending

  LocationMessageDto({
    required this.driverId,
    required this.shuttleId,
    required this.latitude,
    required this.longitude,
    this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'driverId': driverId,
        'shuttleId': shuttleId,
        'latitude': latitude,
        'longitude': longitude,
        if (timestamp != null) 'timestamp': timestamp,
      };

  factory LocationMessageDto.fromJson(Map<String, dynamic> json) =>
      LocationMessageDto(
        driverId: json['driverId']?.toString() ?? '',
        shuttleId: json['shuttleId']?.toString() ?? '',
        latitude: (json['latitude'] is num)
            ? (json['latitude'] as num).toDouble()
            : double.tryParse(json['latitude']?.toString() ?? '') ?? 0.0,
        longitude: (json['longitude'] is num)
            ? (json['longitude'] as num).toDouble()
            : double.tryParse(json['longitude']?.toString() ?? '') ?? 0.0,
        timestamp: json['timestamp']?.toString(),
      );
}

class LocationStompClient {
  final String websocketUrl; // e.g. ws://host:8080/ws
  final String appPrefix; // typically '/app'
  final String topicPrefix; // typically '/topic'
  final Map<String, String>? connectionHeaders; // e.g. auth headers

  StompClient? _client;

  LocationStompClient({
    required this.websocketUrl,
    this.appPrefix = '/app',
    this.topicPrefix = '/topic',
    this.connectionHeaders,
  });

  // Builds a ws/wss URL from an http/https base and a websocket endpoint path.
  // Example: http://10.0.2.2:8080 + "/ws" => ws://10.0.2.2:8080/ws
  static String buildWebSocketUrl(String httpBaseUrl, String wsPath) {
    final uri = Uri.parse(httpBaseUrl);
    final scheme = (uri.scheme == 'https') ? 'wss' : 'ws';
    final normalizedPath = wsPath.startsWith('/') ? wsPath : '/$wsPath';
    return Uri(
      scheme: scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: normalizedPath,
    ).toString();
  }

  void connect({
    void Function(StompFrame frame)? onConnected,
    void Function(Object error, [StackTrace? st])? onError,
    Duration reconnectDelay = const Duration(seconds: 5),
  }) {
    if (_client?.connected == true) {
      return; // already connected
    }

    _client = StompClient(
      config: StompConfig(
        url: websocketUrl,
        onConnect: (frame) {
          onConnected?.call(frame);
        },
        onWebSocketError: (dynamic err) {
          onError?.call(err is Object ? err : Exception(err.toString()));
        },
        onStompError: (frame) {
          onError?.call(Exception('STOMP error: ${frame.body ?? frame.toString()}'));
        },
        stompConnectHeaders: connectionHeaders,
        webSocketConnectHeaders: connectionHeaders,
        heartbeatIncoming: const Duration(seconds: 0),
        heartbeatOutgoing: const Duration(seconds: 20),
        reconnectDelay: reconnectDelay,
      ),
    );

    _client!.activate();
  }

  void disconnect() {
    _client?.deactivate();
    _client = null;
  }

  bool get isConnected => _client?.connected == true;

  // Subscribe to /topic/locations broadcasts.
  // The server is expected to send back LocationMessageDTOs, including timestamp set.
  void subscribeToLocations(void Function(LocationMessageDto msg) onMessage) {
    final destination = '$topicPrefix/locations';
    _client?.subscribe(
      destination: destination,
      callback: (StompFrame frame) {
        final body = frame.body;
        if (body == null || body.isEmpty) return;
        try {
          final decoded = json.decode(body);
          if (decoded is Map<String, dynamic>) {
            onMessage(LocationMessageDto.fromJson(decoded));
          } else if (decoded is List) {
            // handle batch messages (optional)
            for (final item in decoded) {
              if (item is Map<String, dynamic>) {
                onMessage(LocationMessageDto.fromJson(item));
              }
            }
          }
        } catch (_) {
          // ignore parse errors
        }
      },
    );
  }

  // Send a location update to /app/update-location. Timestamp is optional and should be ISO-8601.
  void sendLocationUpdate({
    required String driverId,
    required String shuttleId,
    required double latitude,
    required double longitude,
    String? timestampIso8601,
    Map<String, String>? headers,
  }) {
    final destination = '$appPrefix/update-location';
    final payload = LocationMessageDto(
      driverId: driverId,
      shuttleId: shuttleId,
      latitude: latitude,
      longitude: longitude,
      timestamp: timestampIso8601,
    ).toJson();

    _client?.send(
      destination: destination,
      body: json.encode(payload),
      headers: {
        'content-type': 'application/json',
        if (headers != null) ...headers,
      },
    );
  }
}

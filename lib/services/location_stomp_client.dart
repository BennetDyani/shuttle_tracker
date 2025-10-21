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
  final String? status; // optional status string (e.g., AT_CAMPUS)

  LocationMessageDto({
    required this.driverId,
    required this.shuttleId,
    required this.latitude,
    required this.longitude,
    this.timestamp,
    this.status,
  });

  Map<String, dynamic> toJson() => {
        'driverId': driverId,
        'shuttleId': shuttleId,
        'latitude': latitude,
        'longitude': longitude,
        if (timestamp != null) 'timestamp': timestamp,
        if (status != null) 'status': status,
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
        status: json['status']?.toString(),
      );
}

class LocationStompClient {
  final String websocketUrl; // e.g. ws://host:8080/ws
  final String appPrefix; // typically '/app'
  final String topicPrefix; // typically '/topic'
  final Map<String, String>? connectionHeaders; // e.g. auth headers

  StompClient? _client;

  // Pending subscribers registered before the client is activated.
  final List<void Function(LocationMessageDto msg)> _pendingLocationSubscribers = [];

  LocationStompClient({
    required this.websocketUrl,
    this.appPrefix = '/app',
    this.topicPrefix = '/topic',
    this.connectionHeaders,
  });

  // Builds a ws/wss URL from an http/https base and a websocket endpoint path.
  // Example: http://10.0.2.2:8080 + "/ws" => ws://10.0.2.2:8080/ws
  static String buildWebSocketUrl(String httpBaseUrl, String wsPath) {
    try {
      // If caller already passed a full ws/wss URL, return it as-is
      if (wsPath.startsWith('ws://') || wsPath.startsWith('wss://')) return wsPath;

      final uri = Uri.parse(httpBaseUrl);
      final scheme = (uri.scheme == 'https') ? 'wss' : 'ws';
      final normalizedPath = wsPath.startsWith('/') ? wsPath : '/$wsPath';
      // Preserve any base path present in apiBaseUrl (e.g., '/api')
      final basePath = (uri.path == null || uri.path == '' || uri.path == '/') ? '' : uri.path;
      final combined = ('$basePath$normalizedPath').replaceAll('//', '/');
      return Uri(
        scheme: scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
        path: combined,
      ).toString();
    } catch (_) {
      // Fallback: try simple join
      final scheme = httpBaseUrl.startsWith('https') ? 'wss' : 'ws';
      final normalizedPath = wsPath.startsWith('/') ? wsPath : '/$wsPath';
      try {
        final u = Uri.parse(httpBaseUrl);
        return Uri(scheme: scheme, host: u.host, port: u.hasPort ? u.port : null, path: normalizedPath).toString();
      } catch (_) {
        return '${scheme}://${httpBaseUrl}${wsPath}';
      }
    }
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
          // Flush pending subscribers now that the client is active
          try {
            for (final sub in List<void Function(LocationMessageDto)>.from(_pendingLocationSubscribers)) {
              try {
                // Use the regular subscribe path which will call _client!.subscribe
                _client?.subscribe(
                  destination: '$topicPrefix/locations',
                  callback: (StompFrame frame) {
                    final body = frame.body;
                    if (body == null || body.isEmpty) return;
                    try {
                      final decoded = json.decode(body);
                      if (decoded is Map<String, dynamic>) {
                        sub(LocationMessageDto.fromJson(decoded));
                      } else if (decoded is List) {
                        for (final item in decoded) {
                          if (item is Map<String, dynamic>) {
                            sub(LocationMessageDto.fromJson(item));
                          }
                        }
                      }
                    } catch (_) {}
                  },
                );
              } catch (_) {}
            }
          } finally {
            _pendingLocationSubscribers.clear();
          }

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
    _pendingLocationSubscribers.clear();
  }

  bool get isConnected => _client?.connected == true;

  // Subscribe to /topic/locations broadcasts.
  // The server is expected to send back LocationMessageDTOs, including timestamp set.
  void subscribeToLocations(void Function(LocationMessageDto msg) onMessage) {
    final destination = '$topicPrefix/locations';
    // If client not yet active, queue the subscriber and it will be flushed on connect
    if (_client == null || _client?.connected != true) {
      _pendingLocationSubscribers.add(onMessage);
      return;
    }

    _client!.subscribe(
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
    String? status,
    Map<String, String>? headers,
  }) {
    final destination = '$appPrefix/update-location';
    final payload = LocationMessageDto(
      driverId: driverId,
      shuttleId: shuttleId,
      latitude: latitude,
      longitude: longitude,
      timestamp: timestampIso8601,
      status: status,
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

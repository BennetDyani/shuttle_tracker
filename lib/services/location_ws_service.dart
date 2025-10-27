import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../utils/platform_utils_stub.dart' if (dart.library.io) '../utils/platform_utils_io.dart';

class LocationWebSocketService {
  StompClient? _stompClient;
  Timer? _locationTimer;
  bool _isConnected = false;
  int? _currentDriverId;
  int? _currentShuttleId;

  // WebSocket URL (adjust based on your backend)
  String get _wsUrl {
    final host = (PlatformUtils.isAndroid && !kIsWeb) ? '10.0.2.2' : 'localhost';
    return 'ws://$host:8080/ws';
  }

  bool get isConnected => _isConnected;

  // Connect to WebSocket and start broadcasting location
  void connect(int driverId, int shuttleId) {
    if (_isConnected) {
      debugPrint('[LocationWS] Already connected');
      return;
    }

    _currentDriverId = driverId;
    _currentShuttleId = shuttleId;

    debugPrint('[LocationWS] Connecting to $_wsUrl');

    _stompClient = StompClient(
      config: StompConfig.sockJS(
        url: _wsUrl,
        onConnect: _onConnect,
        onWebSocketError: (dynamic error) {
          debugPrint('[LocationWS] WebSocket Error: $error');
          _isConnected = false;
        },
        onStompError: (StompFrame frame) {
          debugPrint('[LocationWS] STOMP Error: ${frame.body}');
        },
        onDisconnect: (frame) {
          debugPrint('[LocationWS] Disconnected');
          _isConnected = false;
          _stopLocationBroadcast();
        },
      ),
    );

    _stompClient!.activate();
  }

  // Called when WebSocket connection is established
  void _onConnect(StompFrame frame) {
    debugPrint('[LocationWS] Connected successfully');
    _isConnected = true;

    // Start broadcasting location every 5 seconds
    _startLocationBroadcast();
  }

  // Start periodic location updates
  void _startLocationBroadcast() {
    _stopLocationBroadcast(); // Stop any existing timer

    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        // Get current location
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        // Send location update
        _sendLocationUpdate(
          _currentDriverId!,
          _currentShuttleId!,
          position.latitude,
          position.longitude,
        );
      } catch (e) {
        debugPrint('[LocationWS] Error getting location: $e');
      }
    });

    debugPrint('[LocationWS] Location broadcasting started');
  }

  // Stop location broadcasting
  void _stopLocationBroadcast() {
    if (_locationTimer != null) {
      _locationTimer!.cancel();
      _locationTimer = null;
      debugPrint('[LocationWS] Location broadcasting stopped');
    }
  }

  // Send location update to server
  void _sendLocationUpdate(int driverId, int shuttleId, double latitude, double longitude) {
    if (!_isConnected || _stompClient == null) {
      debugPrint('[LocationWS] Not connected, cannot send location');
      return;
    }

    final message = jsonEncode({
      'driverId': driverId,
      'shuttleId': shuttleId,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now().toIso8601String(),
    });

    try {
      _stompClient!.send(
        destination: '/app/location',
        body: message,
      );

      debugPrint('[LocationWS] Location sent: lat=$latitude, lng=$longitude');
    } catch (e) {
      debugPrint('[LocationWS] Error sending location: $e');
    }
  }

  // Send status update (leaving, almost there, arrived, etc.)
  void sendStatusUpdate(int driverId, int shuttleId, double latitude, double longitude, String status) {
    if (!_isConnected || _stompClient == null) {
      debugPrint('[LocationWS] Not connected, cannot send status');
      return;
    }

    final message = jsonEncode({
      'driverId': driverId,
      'shuttleId': shuttleId,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'timestamp': DateTime.now().toIso8601String(),
    });

    try {
      _stompClient!.send(
        destination: '/app/status',
        body: message,
      );

      debugPrint('[LocationWS] Status update sent: $status');
    } catch (e) {
      debugPrint('[LocationWS] Error sending status: $e');
    }
  }

  // Disconnect from WebSocket
  void disconnect() {
    debugPrint('[LocationWS] Disconnecting...');

    _stopLocationBroadcast();

    if (_stompClient != null) {
      _stompClient!.deactivate();
      _stompClient = null;
    }

    _isConnected = false;
    _currentDriverId = null;
    _currentShuttleId = null;

    debugPrint('[LocationWS] Disconnected');
  }

  // Subscribe to location updates (for students)
  void subscribeToShuttleLocation(int shuttleId, Function(Map<String, dynamic>) onLocationUpdate) {
    if (!_isConnected || _stompClient == null) {
      debugPrint('[LocationWS] Not connected, cannot subscribe');
      return;
    }

    _stompClient!.subscribe(
      destination: '/topic/shuttle/$shuttleId',
      callback: (StompFrame frame) {
        if (frame.body != null) {
          try {
            final data = jsonDecode(frame.body!);
            onLocationUpdate(data);
          } catch (e) {
            debugPrint('[LocationWS] Error parsing location update: $e');
          }
        }
      },
    );

    debugPrint('[LocationWS] Subscribed to shuttle $shuttleId updates');
  }

  // Subscribe to status updates (for students)
  void subscribeToShuttleStatus(int shuttleId, Function(Map<String, dynamic>) onStatusUpdate) {
    if (!_isConnected || _stompClient == null) {
      debugPrint('[LocationWS] Not connected, cannot subscribe');
      return;
    }

    _stompClient!.subscribe(
      destination: '/topic/shuttle/$shuttleId/status',
      callback: (StompFrame frame) {
        if (frame.body != null) {
          try {
            final data = jsonDecode(frame.body!);
            onStatusUpdate(data);
          } catch (e) {
            debugPrint('[LocationWS] Error parsing status update: $e');
          }
        }
      },
    );

    debugPrint('[LocationWS] Subscribed to shuttle $shuttleId status updates');
  }
}


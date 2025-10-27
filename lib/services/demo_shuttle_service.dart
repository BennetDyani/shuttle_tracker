import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DemoShuttleService {
  Timer? _demoTimer;
  bool _isRunning = false;
  int _currentPointIndex = 0;
  List<Map<String, dynamic>> _routePoints = [];

  // Callback for location updates
  Function(double lat, double lng, String status)? onLocationUpdate;

  // Starting point: CPUT District 6 shuttle point
  static const Map<String, dynamic> _startPoint = {
    'lat': -33.9329,
    'lng': 18.4242,
    'status': 'AT_START',
    'name': 'CPUT District 6 Shuttle Point'
  };

  // Known stop coordinates (you can expand this list)
  static final Map<String, Map<String, double>> _stopCoordinates = {
    'CPUT District 6 Shuttle Point': {'lat': -33.9329, 'lng': 18.4242},
    'Cape Town City Centre': {'lat': -33.9281, 'lng': 18.4261},
    'CPUT Bellville Campus': {'lat': -33.8825, 'lng': 18.6394},
    'Bellville Station': {'lat': -33.8921, 'lng': 18.6298},
    'Observatory': {'lat': -33.9270, 'lng': 18.4600},
    'Woodstock': {'lat': -33.9260, 'lng': 18.4800},
    'Salt River': {'lat': -33.9250, 'lng': 18.5500},
    'Mowbray': {'lat': -33.9420, 'lng': 18.4710},
    'Rondebosch': {'lat': -33.9580, 'lng': 18.4740},
    'Claremont': {'lat': -33.9840, 'lng': 18.4650},
    'Wynberg': {'lat': -34.0020, 'lng': 18.4620},
    'Parow': {'lat': -33.9000, 'lng': 18.5800},
    'Goodwood': {'lat': -33.9120, 'lng': 18.5500},
    'Sea Point': {'lat': -33.9230, 'lng': 18.3780},
    'Green Point': {'lat': -33.9080, 'lng': 18.4090},
    'V&A Waterfront': {'lat': -33.9030, 'lng': 18.4190},
    'Athlone': {'lat': -33.9600, 'lng': 18.5100},
    'Mitchell\'s Plain': {'lat': -34.0530, 'lng': 18.6290},
    'Khayelitsha': {'lat': -34.0360, 'lng': 18.6670},
  };

  bool get isRunning => _isRunning;
  int get totalPoints => _routePoints.length;
  int get currentPointIndex => _currentPointIndex;
  String get currentLocationName =>
      _routePoints.isNotEmpty ? _routePoints[_currentPointIndex]['name'] : 'Unknown';

  // Build route based on subscribed stops
  Future<void> _buildRouteFromSubscriptions(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'subscribed_stops_$userId';
      final List<String>? subscribedStops = prefs.getStringList(key);

      debugPrint('[DemoShuttle] Building route for user: $userId');
      debugPrint('[DemoShuttle] Subscribed stops: $subscribedStops');

      _routePoints = [_startPoint]; // Always start at District 6

      if (subscribedStops != null && subscribedStops.isNotEmpty) {
        // Add subscribed stops to route
        for (final stopName in subscribedStops) {
          if (_stopCoordinates.containsKey(stopName)) {
            final coords = _stopCoordinates[stopName]!;

            // Add intermediate points for smooth animation
            final lastPoint = _routePoints.last;
            final intermediatePoints = _generateIntermediatePoints(
              lastPoint['lat'] as double,
              lastPoint['lng'] as double,
              coords['lat']!,
              coords['lng']!,
              stopName,
            );
            _routePoints.addAll(intermediatePoints);

            // Add the stop itself
            _routePoints.add({
              'lat': coords['lat']!,
              'lng': coords['lng']!,
              'status': 'ARRIVED',
              'name': stopName,
            });

            // Pause at stop
            _routePoints.add({
              'lat': coords['lat']!,
              'lng': coords['lng']!,
              'status': 'ARRIVED',
              'name': stopName,
            });
          } else {
            debugPrint('[DemoShuttle] Warning: Unknown stop "$stopName"');
          }
        }

        // Return to start point
        if (_routePoints.length > 1) {
          final lastPoint = _routePoints.last;
          final returnPoints = _generateIntermediatePoints(
            lastPoint['lat'] as double,
            lastPoint['lng'] as double,
            _startPoint['lat'] as double,
            _startPoint['lng'] as double,
            'CPUT District 6 Shuttle Point',
          );
          _routePoints.addAll(returnPoints);
          _routePoints.add(_startPoint);
        }
      } else {
        // Default route if no subscriptions
        debugPrint('[DemoShuttle] No subscriptions found, using default route');
        _routePoints = _getDefaultRoute();
      }

      debugPrint('[DemoShuttle] Route built with ${_routePoints.length} points');
    } catch (e) {
      debugPrint('[DemoShuttle] Error building route: $e');
      _routePoints = _getDefaultRoute();
    }
  }

  // Generate intermediate points between two coordinates
  List<Map<String, dynamic>> _generateIntermediatePoints(
    double startLat, double startLng,
    double endLat, double endLng,
    String destination,
  ) {
    final points = <Map<String, dynamic>>[];
    const steps = 5; // Number of intermediate points

    for (int i = 1; i <= steps; i++) {
      final ratio = i / (steps + 1);
      final lat = startLat + (endLat - startLat) * ratio;
      final lng = startLng + (endLng - startLng) * ratio;

      String status;
      if (ratio < 0.3) {
        status = 'LEAVING';
      } else if (ratio < 0.8) {
        status = 'EN_ROUTE';
      } else {
        status = 'ALMOST_THERE';
      }

      points.add({
        'lat': lat,
        'lng': lng,
        'status': status,
        'name': 'En route to $destination',
      });
    }

    return points;
  }

  // Default route if no subscriptions
  List<Map<String, dynamic>> _getDefaultRoute() {
    return [
      _startPoint,
      {'lat': -33.9300, 'lng': 18.4270, 'status': 'LEAVING', 'name': 'Leaving District 6'},
      {'lat': -33.9281, 'lng': 18.4261, 'status': 'EN_ROUTE', 'name': 'City Centre'},
      {'lat': -33.9281, 'lng': 18.4261, 'status': 'ARRIVED', 'name': 'City Centre'},
      {'lat': -33.9270, 'lng': 18.4600, 'status': 'EN_ROUTE', 'name': 'Observatory'},
      {'lat': -33.9270, 'lng': 18.4600, 'status': 'ARRIVED', 'name': 'Observatory'},
      {'lat': -33.9300, 'lng': 18.4270, 'status': 'HEADING_BACK', 'name': 'Heading back'},
      _startPoint,
    ];
  }

  // Start demo shuttle movement
  Future<void> startDemo({
    required String userId,
    Function(double lat, double lng, String status)? onUpdate,
  }) async {
    if (_isRunning) {
      debugPrint('[DemoShuttle] Already running');
      return;
    }

    // Build route based on user's subscribed stops
    await _buildRouteFromSubscriptions(userId);

    if (_routePoints.isEmpty) {
      debugPrint('[DemoShuttle] No route points available');
      return;
    }

    onLocationUpdate = onUpdate;
    _isRunning = true;
    _currentPointIndex = 0;

    debugPrint('[DemoShuttle] Starting demo shuttle from District 6');
    debugPrint('[DemoShuttle] Route has ${_routePoints.length} points');

    // Send initial location
    _sendCurrentLocation();

    // Move to next point every 3 seconds
    _demoTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _moveToNextPoint();
    });
  }

  // Stop demo shuttle
  void stopDemo() {
    if (_demoTimer != null) {
      _demoTimer!.cancel();
      _demoTimer = null;
    }
    _isRunning = false;
    _currentPointIndex = 0;
    debugPrint('[DemoShuttle] Demo stopped');
  }

  // Move to next point in route
  void _moveToNextPoint() {
    if (!_isRunning) return;

    _currentPointIndex++;

    // Loop back to start when reaching end
    if (_currentPointIndex >= _routePoints.length) {
      _currentPointIndex = 0;
      debugPrint('[DemoShuttle] Completed full route, looping back to start');
    }

    _sendCurrentLocation();
  }

  // Send current location to callback
  void _sendCurrentLocation() {
    final point = _routePoints[_currentPointIndex];
    final lat = point['lat'] as double;
    final lng = point['lng'] as double;
    final status = point['status'] as String;
    final name = point['name'] as String;

    debugPrint('[DemoShuttle] Point ${_currentPointIndex + 1}/${_routePoints.length}: $name');
    debugPrint('[DemoShuttle] Location: $lat, $lng - Status: $status');

    if (onLocationUpdate != null) {
      onLocationUpdate!(lat, lng, status);
    }
  }

  // Get current location
  LatLng getCurrentLocation() {
    final point = _routePoints[_currentPointIndex];
    return LatLng(point['lat'] as double, point['lng'] as double);
  }

  // Get current status
  String getCurrentStatus() {
    return _routePoints[_currentPointIndex]['status'] as String;
  }

  // Get all route points for displaying on map
  List<LatLng> getAllRoutePoints() {
    return _routePoints.map((point) {
      return LatLng(point['lat'] as double, point['lng'] as double);
    }).toList();
  }

  // Jump to specific point (for testing)
  void jumpToPoint(int index) {
    if (index >= 0 && index < _routePoints.length) {
      _currentPointIndex = index;
      _sendCurrentLocation();
    }
  }

  // Reset to start
  void reset() {
    _currentPointIndex = 0;
    _sendCurrentLocation();
  }
}


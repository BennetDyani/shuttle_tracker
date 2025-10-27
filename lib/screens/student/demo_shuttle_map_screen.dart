import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/demo_shuttle_service.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class DemoShuttleMapScreen extends StatefulWidget {
  const DemoShuttleMapScreen({super.key});

  @override
  State<DemoShuttleMapScreen> createState() => _DemoShuttleMapScreenState();
}

class _DemoShuttleMapScreenState extends State<DemoShuttleMapScreen> {
  final DemoShuttleService _demoService = DemoShuttleService();
  final MapController _mapController = MapController();

  LatLng _currentLocation = const LatLng(-33.9329, 18.4242); // CPUT District 6
  String _currentStatus = 'AT_START';
  bool _isRunning = false;
  bool _followShuttle = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _demoService.stopDemo();
    super.dispose();
  }

  Future<void> _startDemo() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.userId ?? 'unknown';

    setState(() => _isRunning = true);

    await _demoService.startDemo(
      userId: userId,
      onUpdate: (lat, lng, status) {
        if (mounted) {
          setState(() {
            _currentLocation = LatLng(lat, lng);
            _currentStatus = status;
          });

          // Auto-follow shuttle on map if enabled
          if (_followShuttle) {
            _mapController.move(_currentLocation, _mapController.camera.zoom);
          }
        }
      },
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo shuttle started from District 6! Following your subscribed stops.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _stopDemo() {
    _demoService.stopDemo();
    setState(() => _isRunning = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Demo shuttle stopped.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'AT_START':
        return 'At District 6 Start Point';
      case 'AT_CAMPUS':
        return 'At Campus';
      case 'LEAVING':
        return 'Leaving';
      case 'EN_ROUTE':
        return 'En Route';
      case 'ALMOST_THERE':
        return 'Almost There';
      case 'ARRIVED':
        return 'Arrived at Stop';
      case 'HEADING_BACK':
        return 'Heading Back';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'AT_START':
      case 'AT_CAMPUS':
        return Colors.grey;
      case 'LEAVING':
        return Colors.orange;
      case 'EN_ROUTE':
        return Colors.blue;
      case 'ALMOST_THERE':
        return Colors.lightBlue;
      case 'ARRIVED':
        return Colors.green;
      case 'HEADING_BACK':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'AT_CAMPUS':
        return Icons.home;
      case 'LEAVING':
        return Icons.logout;
      case 'EN_ROUTE':
        return Icons.directions_bus;
      case 'ALMOST_THERE':
        return Icons.near_me;
      case 'ARRIVED':
        return Icons.location_on;
      case 'HEADING_BACK':
        return Icons.keyboard_return;
      default:
        return Icons.help;
    }
  }

  Widget _buildShuttleIcon() {
    return Transform.rotate(
      angle: _isRunning ? math.pi / 4 : 0, // Slight tilt when moving
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.directions_bus,
          color: _getStatusColor(_currentStatus),
          size: 30,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo Shuttle Tracker'),
        actions: [
          // Follow shuttle toggle
          IconButton(
            icon: Icon(_followShuttle ? Icons.my_location : Icons.location_disabled),
            onPressed: () {
              setState(() => _followShuttle = !_followShuttle);
              if (_followShuttle) {
                _mapController.move(_currentLocation, _mapController.camera.zoom);
              }
            },
            tooltip: _followShuttle ? 'Following shuttle' : 'Manual navigation',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor(_currentStatus).withValues(alpha: 0.1),
              border: Border(
                bottom: BorderSide(
                  color: _getStatusColor(_currentStatus).withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getStatusIcon(_currentStatus),
                  color: _getStatusColor(_currentStatus),
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shuttle Status',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getStatusDisplayName(_currentStatus),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(_currentStatus),
                        ),
                      ),
                      if (_isRunning) ...[
                        const SizedBox(height: 4),
                        Text(
                          _demoService.currentLocationName,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_isRunning)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Live',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Map
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation,
                initialZoom: 12.0,
                minZoom: 10.0,
                maxZoom: 18.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.shuttle_tracker',
                ),

                // Route line (if demo is running)
                if (_isRunning)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _demoService.getAllRoutePoints(),
                        strokeWidth: 4.0,
                        color: Colors.blue.withValues(alpha: 0.5),
                      ),
                    ],
                  ),

                // Shuttle marker
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation,
                      width: 50,
                      height: 50,
                      child: _buildShuttleIcon(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Control Panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isRunning) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _stopDemo,
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop Demo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Point ${_demoService.currentPointIndex + 1} of ${_demoService.totalPoints} • Updates every 3 seconds',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _startDemo,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start Demo Shuttle'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 20, color: Colors.grey[700]),
                            const SizedBox(width: 8),
                            Text(
                              'Demo Route Information',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Route: CPUT Bellville → Cape Town City Centre → Back to Campus',
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                        Text(
                          '• ${_demoService.totalPoints} waypoints along the route',
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                        Text(
                          '• Updates every 3 seconds (simulated real-time)',
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                        Text(
                          '• Watch status change as shuttle progresses',
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}


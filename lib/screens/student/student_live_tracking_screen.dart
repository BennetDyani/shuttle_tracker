import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../services/demo_shuttle_service.dart';
import '../../services/location_ws_service.dart';
import '../../services/APIService.dart';
import '../../providers/auth_provider.dart';
import '../../models/User.dart';
import 'dart:math' as math;

/// Unified live tracking screen for all students (both disabled and normal).
/// Uses the demo shuttle service for real-time tracking simulation.
/// Filters shuttles based on student type (disabled students see only minibuses).
class StudentLiveTrackingScreen extends StatefulWidget {
  const StudentLiveTrackingScreen({super.key});

  @override
  State<StudentLiveTrackingScreen> createState() => _StudentLiveTrackingScreenState();
}

class _StudentLiveTrackingScreenState extends State<StudentLiveTrackingScreen> {
  final DemoShuttleService _demoService = DemoShuttleService();
  final LocationWebSocketService _wsService = LocationWebSocketService();
  final MapController _mapController = MapController();
  final APIService _apiService = APIService();

  LatLng _currentLocation = const LatLng(-33.8825, 18.6394); // CPUT Bellville
  String _currentStatus = 'AT_CAMPUS';
  bool _isRunning = false;
  bool _followShuttle = true;
  bool _isLoadingUser = true;
  bool _isDisabledStudent = false;
  List<dynamic> _availableShuttles = [];
  String? _selectedShuttleId;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadShuttles();
  }

  @override
  void dispose() {
    _demoService.stopDemo();
    try {
      _wsService.disconnect();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    setState(() => _isLoadingUser = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uidStr = auth.userId;
      if (uidStr == null || uidStr.isEmpty) throw Exception('Not logged in');
      final uid = int.tryParse(uidStr);
      if (uid == null) throw Exception('Invalid user id');

      final userMap = await _apiService.fetchUserById(uid);
      final user = User.fromJson(userMap);

      setState(() {
        _isDisabledStudent = user.disability;
      });
    } catch (e) {
      debugPrint('Error loading user info: $e');
      // Default to normal student if error
      setState(() => _isDisabledStudent = false);
    } finally {
      setState(() => _isLoadingUser = false);
    }
  }

  Future<void> _loadShuttles() async {
    try {
      final shuttles = await _apiService.fetchShuttles();
      setState(() {
        _availableShuttles = shuttles.where((shuttle) {
          final type = shuttle['shuttleType']?.toString().toUpperCase() ??
                       shuttle['shuttle_type']?.toString().toUpperCase() ??
                       shuttle['type']?.toString().toUpperCase() ?? '';

          // Filter based on student type
          if (_isDisabledStudent) {
            // Disabled students see only MINIBUS
            return type == 'MINIBUS';
          } else {
            // Normal students see only BUS
            return type == 'BUS';
          }
        }).toList();

        // Auto-select first available shuttle
        if (_availableShuttles.isNotEmpty && _selectedShuttleId == null) {
          _selectedShuttleId = _availableShuttles.first['shuttleId']?.toString() ??
                              _availableShuttles.first['shuttle_id']?.toString() ??
                              _availableShuttles.first['id']?.toString();
        }
      });
    } catch (e) {
      debugPrint('Error loading shuttles: $e');
      setState(() => _availableShuttles = []);
    }
  }

  void _startDemo() {
    setState(() => _isRunning = true);

    _demoService.startDemo(
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
      }, userId: '',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tracking ${_isDisabledStudent ? 'minibus' : 'bus'} started!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _stopDemo() {
    _demoService.stopDemo();
    setState(() => _isRunning = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tracking stopped.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'AT_CAMPUS':
        return 'At Campus';
      case 'LEAVING':
        return 'Leaving Campus';
      case 'EN_ROUTE':
        return 'En Route';
      case 'ALMOST_THERE':
        return 'Almost There';
      case 'ARRIVED':
        return 'Arrived';
      case 'HEADING_BACK':
        return 'Heading Back';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
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
      angle: _isRunning ? math.pi / 4 : 0,
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
          _isDisabledStudent ? Icons.accessible : Icons.directions_bus,
          color: _getStatusColor(_currentStatus),
          size: 30,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live Tracking')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Live ${_isDisabledStudent ? 'Minibus' : 'Bus'} Tracking'),
        actions: [
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
                        '${_isDisabledStudent ? 'Minibus' : 'Bus'} Status',
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

                // Route line
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
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isRunning) ...[
                  Text(
                    'Track your ${_isDisabledStudent ? 'accessible minibus' : 'campus bus'} in real-time',
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _startDemo,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Tracking'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    onPressed: _stopDemo,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Tracking'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
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


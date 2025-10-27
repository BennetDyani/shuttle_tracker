import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import 'package:shuttle_tracker/services/location_ws_service.dart';
import 'package:shuttle_tracker/models/driver_model/location_status.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shuttle_tracker/services/location_polling_service.dart';
import 'package:shuttle_tracker/models/driver_model/LocationMessage.dart' as ModelMsg;
import '../../../widgets/dashboard_action.dart';

// For a real map, use a package like google_maps_flutter or flutter_map.
// This screen subscribes to location WS broadcasts and shows status alerts.
class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final LocationWebSocketService _ws = LocationWebSocketService();

  // Latest shuttle state from WS / polling
  double? _shuttleLat;
  double? _shuttleLng;
  String? _latestStatus; // raw status string (enum name)
  String? _latestDriverId;
  String? _latestShuttleId;

  // Map
  final MapController _mapController = MapController();

  // Polling fallback cancel function
  void Function()? _pollCancel;

  @override
  void initState() {
    super.initState();
    // TODO: Implement proper WebSocket connection when backend is ready
    // For now, using placeholder to avoid compilation errors
    try {
      // Connect with example shuttle ID
      _ws.connect(1, 1);

      // Subscribe to shuttle location
      _ws.subscribeToShuttleLocation(1, (data) {
        if (!mounted) return;
        setState(() {
          _shuttleLat = data['latitude'] as double?;
          _shuttleLng = data['longitude'] as double?;
          _latestShuttleId = data['shuttleId']?.toString();
          _latestStatus = data['status'] as String?;
        });
      });

      // Subscribe to status updates
      _ws.subscribeToShuttleStatus(1, (data) {
        if (!mounted) return;
        setState(() {
          _latestStatus = data['status'] as String?;
        });
        // Show status notification
        if (_latestStatus != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Shuttle status: $_latestStatus')),
          );
        }
      });
    } catch (e) {
      debugPrint('WebSocket connection error: $e');
      // Fallback to polling if needed
      if (_pollCancel == null) {
        _pollCancel = LocationPollingService().subscribe(onMessage: (ModelMsg.LocationMessage m) {
          if (!mounted) return;
          setState(() {
            _latestDriverId = m.driverId?.toString();
            _latestShuttleId = m.shuttleId?.toString();
            _shuttleLat = null;
            _shuttleLng = null;
            _latestStatus = m.locationStatus.toString().split('.').last;
          });
        });
      }
    }
  }

  @override
  void dispose() {
    try {
      _pollCancel?.call();
    } catch (_) {}
    try {
      _ws.disconnect();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Track Shuttle'),
        centerTitle: true,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: Column(
        children: [
          // Status banner
          if (_latestStatus != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: _getStatusColor(_latestStatus),
              width: double.infinity,
              child: Text(
                'Shuttle ${_latestShuttleId ?? 'Unknown'}: ${_getStatusLabel(_latestStatus)}',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),

          // Map
          Expanded(
            child: (_shuttleLat != null && _shuttleLng != null)
                ? FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: LatLng(_shuttleLat!, _shuttleLng!),
                      initialZoom: 14.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.shuttle_tracker',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(_shuttleLat!, _shuttleLng!),
                            width: 80,
                            height: 80,
                            child: const Icon(
                              Icons.directions_bus,
                              color: Colors.blue,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Waiting for shuttle location...'),
                      ],
                    ),
                  ),
          ),

          // Info panel
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[900],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_latestShuttleId != null)
                  Text(
                    'Shuttle ID: $_latestShuttleId',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                if (_shuttleLat != null && _shuttleLng != null)
                  Text(
                    'Location: ${_shuttleLat!.toStringAsFixed(6)}, ${_shuttleLng!.toStringAsFixed(6)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                if (_latestStatus != null)
                  Text(
                    'Status: ${_getStatusLabel(_latestStatus)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    switch (status.toUpperCase()) {
      case 'LEAVING':
      case 'DEPARTING_CAMPUS':
        return Colors.orange;
      case 'EN_ROUTE':
      case 'ON_ROUTE_TO_RESIDENCE':
        return Colors.blue;
      case 'ALMOST_THERE':
        return Colors.lightBlue;
      case 'ARRIVED':
      case 'AT_RESIDENCE':
        return Colors.green;
      case 'HEADING_BACK':
      case 'RETURNING_TO_CAMPUS':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String? status) {
    if (status == null) return 'Unknown';
    switch (status.toUpperCase()) {
      case 'AT_CAMPUS':
        return 'At Campus';
      case 'LEAVING':
      case 'DEPARTING_CAMPUS':
        return 'Leaving Campus';
      case 'EN_ROUTE':
      case 'ON_ROUTE_TO_RESIDENCE':
        return 'En Route';
      case 'ALMOST_THERE':
        return 'Almost There';
      case 'ARRIVED':
      case 'AT_RESIDENCE':
        return 'Arrived';
      case 'HEADING_BACK':
      case 'RETURNING_TO_CAMPUS':
        return 'Heading Back';
      default:
        return status;
    }
  }
}


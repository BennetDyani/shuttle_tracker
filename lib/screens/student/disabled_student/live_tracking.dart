import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shuttle_tracker/services/location_ws_service.dart';
import 'package:shuttle_tracker/services/location_polling_service.dart';
import 'package:shuttle_tracker/models/driver_model/LocationMessage.dart' as ModelMsg;
import 'package:shuttle_tracker/models/driver_model/location_status.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/dashboard_action.dart';

class DisabledLiveTrackingScreen extends StatefulWidget {
  const DisabledLiveTrackingScreen({super.key});

  @override
  State<DisabledLiveTrackingScreen> createState() => _DisabledLiveTrackingScreenState();
}

class _DisabledLiveTrackingScreenState extends State<DisabledLiveTrackingScreen> {
  final LocationWebSocketService _ws = LocationWebSocketService();
  final MapController _mapController = MapController();

  double? _shuttleLat;
  double? _shuttleLng;
  String? _latestStatus;
  String? _latestShuttleId;
  String? _latestDriverId;

  void Function()? _pollCancel;

  // --- New: route data and selection state ---
  late final Map<String, List<LatLng>> _routes = {
    // Sample routes (replace with real route data as available)
    'Campus Loop A': [
      LatLng(14.5775, 121.0294),
      LatLng(14.5780, 121.0300),
      LatLng(14.5790, 121.0310),
      LatLng(14.5800, 121.0320),
    ],
    'Campus Loop B': [
      LatLng(14.5760, 121.0280),
      LatLng(14.5750, 121.0270),
      LatLng(14.5740, 121.0265),
    ],
    'Express Shuttle': [
      LatLng(14.5810, 121.0330),
      LatLng(14.5820, 121.0340),
      LatLng(14.5830, 121.0350),
    ],
  };

  String _selectedRouteName = 'Campus Loop A';

  // Recommend route using a simple heuristic: choose the route whose first point is closest to the shuttle (if known)
  String _recommendRoute() {
    if (_shuttleLat == null || _shuttleLng == null) return _selectedRouteName;
    final shuttlePoint = LatLng(_shuttleLat!, _shuttleLng!);
    final Distance dist = Distance();
    String best = _selectedRouteName;
    double? bestD;
    _routes.forEach((name, points) {
      if (points.isEmpty) return;
      final d = dist(shuttlePoint, points.first);
      if (bestD == null || d < bestD!) {
        bestD = d;
        best = name;
      }
    });
    return best;
  }

  void _applySelectedRoute() {
    final points = _routes[_selectedRouteName];
    if (points == null || points.isEmpty) return;
    // compute simple center and move map
    double lat = 0, lng = 0;
    for (final p in points) {
      lat += p.latitude;
      lng += p.longitude;
    }
    lat /= points.length;
    lng /= points.length;
    try {
      _mapController.move(LatLng(lat, lng), 15);
    } catch (_) {}
    setState(() {});
  }

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
    } catch (e) {
      debugPrint('WebSocket connection error: $e');
      // Fallback to polling if available
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
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        actions: const [
          DashboardAction(),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 300,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                // keep minimal options to stay compatible with the project's flutter_map version
                onPositionChanged: (pos, _) {},
              ),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                // show selected route as a polyline
                if (_routes[_selectedRouteName] != null && _routes[_selectedRouteName]!.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(points: _routes[_selectedRouteName]!, color: Colors.yellow, strokeWidth: 4),
                    ],
                  ),
                MarkerLayer(markers: [
                  if (_shuttleLat != null && _shuttleLng != null)
                    Marker(
                      width: 64,
                      height: 64,
                      point: LatLng(_shuttleLat!, _shuttleLng!),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.directions_bus, color: Colors.yellow, size: 56),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.yellow, borderRadius: BorderRadius.circular(8)),
                            child: Text(_latestStatus ?? '-', style: const TextStyle(fontSize: 12, color: Colors.black)),
                          ),
                        ],
                      ),
                    ),
                ]),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                // High-contrast placeholder content
                Container(
                  color: Colors.black,
                  width: double.infinity,
                  height: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Route selector
                            Expanded(
                              child: Row(
                                children: [
                                  const Text('Route:', style: TextStyle(color: Colors.yellow, fontSize: 20, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  DropdownButton<String>(
                                    value: _selectedRouteName,
                                    dropdownColor: Colors.black,
                                    onChanged: (v) {
                                      if (v == null) return;
                                      setState(() {
                                        _selectedRouteName = v;
                                      });
                                      _applySelectedRoute();
                                    },
                                    items: _routes.keys.map((name) => DropdownMenuItem(value: name, child: Text(name, style: const TextStyle(color: Colors.white)))).toList(),
                                  ),
                                ],
                              ),
                            ),
                            // Recommend action
                            ElevatedButton(
                              onPressed: () {
                                final rec = _recommendRoute();
                                setState(() {
                                  _selectedRouteName = rec;
                                });
                                _applySelectedRoute();
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Recommended route: $rec')));
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow, foregroundColor: Colors.black),
                              child: const Text('Take recommended route'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, color: Colors.yellow),
                            const SizedBox(width: 8),
                            const Text('ETA: 5 mins', style: TextStyle(color: Colors.white, fontSize: 18)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_latestShuttleId != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text('Shuttle: ${_latestShuttleId!}', style: const TextStyle(color: Colors.white, fontSize: 18)),
                        ),
                      if (_latestDriverId != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
                          child: Text('Driver: ${_latestDriverId!}', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                        ),
                      if (_latestStatus != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                          child: Text('Status: ${LocationStatusExtension.fromString(_latestStatus!).label}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 20,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.volume_up, color: Colors.black),
                    label: const Text('Read ETA Aloud', style: TextStyle(color: Colors.black)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.yellow,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.support_agent, color: Colors.black),
                        label: const Text('Call for Assistance', style: TextStyle(color: Colors.black)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.yellow,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

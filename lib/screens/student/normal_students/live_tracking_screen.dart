import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import 'package:shuttle_tracker/services/location_ws_service.dart';
import 'package:shuttle_tracker/services/location_stomp_client.dart';
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
  final LocationWsService _ws = LocationWsService();

  // Latest shuttle state from WS / polling
  double? _shuttleLat;
  double? _shuttleLng;
  String? _latestStatus; // raw status string (enum name)
  String? _latestDriverId;
  String? _latestShuttleId;

  // Small history (optional)
  final List<LocationMessageDto> _messages = [];

  // Map
  final MapController _mapController = MapController();

  // Polling fallback cancel function
  void Function()? _pollCancel;

  @override
  void initState() {
    super.initState();
    // Connect and subscribe
    try {
      _ws.connect(onConnected: (_) {
        // If polling was active, stop it
        try {
          _pollCancel?.call();
        } catch (_) {}
        _pollCancel = null;

        // Subscribe only after the client is connected/activated
        _ws.subscribeToLocations((msg) {
          if (!mounted) return;
          setState(() {
            _latestDriverId = msg.driverId;
            _latestShuttleId = msg.shuttleId;
            _shuttleLat = msg.latitude;
            _shuttleLng = msg.longitude;
            _latestStatus = msg.status;
            _messages.insert(0, msg);
            if (_messages.length > 50) _messages.removeRange(50, _messages.length);
          });

          // Show transient alert for status updates
          if (msg.status != null && mounted) {
            try {
              final s = LocationStatusExtension.fromString(msg.status!);
              final label = s.label;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('${msg.shuttleId} — $label'),
                duration: const Duration(seconds: 4),
              ));
            } catch (_) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${msg.shuttleId} — ${msg.status}')));
            }
          }
        });
      }, onError: (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('WS error: $err')));
        }
        // Start polling fallback if WS fails
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
            // show status alert
            try {
              final s = m.locationStatus;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_latestShuttleId ?? 'Shuttle'} — ${s.label}')));
            } catch (_) {}
          });
        }
      });

      // If already connected (rare), subscribe immediately
      if (_ws.isConnected) {
        _ws.subscribeToLocations((msg) {
          if (!mounted) return;
          setState(() {
            _latestDriverId = msg.driverId;
            _latestShuttleId = msg.shuttleId;
            _shuttleLat = msg.latitude;
            _shuttleLng = msg.longitude;
            _latestStatus = msg.status;
            _messages.insert(0, msg);
            if (_messages.length > 50) _messages.removeRange(50, _messages.length);
          });
        });
      }
    } catch (_) {}
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
        actions: [
          const DashboardAction(),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 300,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                // keep minimal options to stay compatible with the project's flutter_map version
                onPositionChanged: (pos, _) {
                  // no-op, could sync zoom if desired
                },
              ),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                MarkerLayer(markers: [
                  if (_shuttleLat != null && _shuttleLng != null)
                    Marker(
                      width: 48,
                      height: 48,
                      point: LatLng(_shuttleLat!, _shuttleLng!),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.directions_bus, color: Colors.yellow, size: 32),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.yellow, borderRadius: BorderRadius.circular(6)),
                            child: Text(_latestStatus ?? '-', style: const TextStyle(fontSize: 10, color: Colors.black)),
                          ),
                        ],
                      ),
                    ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Stack(
              children: [
                // Existing placeholder area for map legend and shuttle info
                Container(
                  color: Colors.black,
                  width: double.infinity,
                  height: double.infinity,
                  child: const Center(
                    child: Text('[MapView Placeholder]', style: TextStyle(color: Colors.blueGrey, fontSize: 18)),
                  ),
                ),
                // Dynamic shuttle info
                Positioned(
                  top: 24,
                  left: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.directions_bus, color: _latestStatus != null ? Colors.yellow : Colors.white, size: 40),
                      const SizedBox(height: 6),
                      Text(_latestShuttleId != null ? 'Shuttle: ${_latestShuttleId!}' : 'Shuttle', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      if (_shuttleLat != null && _shuttleLng != null) Text('Lat: ${_shuttleLat!.toStringAsFixed(5)}, Lng: ${_shuttleLng!.toStringAsFixed(5)}', style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
                // Persistent status banner when available
                if (_latestStatus != null)
                  Positioned(
                    top: 80,
                    left: 20,
                    right: 20,
                    child: Card(
                      color: Colors.grey[900],
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.white70),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_latestShuttleId ?? 'Shuttle'} — ${LocationStatusExtension.fromString(_latestStatus!).label}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() => _latestStatus = null);
                              },
                              child: const Text('Dismiss'),
                            )
                          ],
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

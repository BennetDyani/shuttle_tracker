import 'dart:async';
import 'dart:math';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shuttle_tracker/services/location_ws_service.dart';
import 'package:shuttle_tracker/services/location_stomp_client.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../../services/APIService.dart';
import '../../services/endpoints.dart';
import '../../services/stop_event_bus.dart';
import '../../models/driver_model/location_status.dart';

class LiveRouteTrackingScreen extends StatefulWidget {
  final String driverId;
  final String shuttleId;
  final int? routeId; // optional route id to fetch stops

  const LiveRouteTrackingScreen({super.key, this.driverId = 'driver-1', this.shuttleId = 'shuttle-1', this.routeId});

  @override
  State<LiveRouteTrackingScreen> createState() => _LiveRouteTrackingScreenState();
}

class _LiveRouteTrackingScreenState extends State<LiveRouteTrackingScreen> {
  final _ws = LocationWsService();

  Timer? _timer;
  bool _connected = false;

  // Simulated coordinates for sending updates periodically
  double _lat = -33.9249;
  double _lng = 18.4241;

  // Collected location updates (both sent and received)
  final List<LocationMessageDto> _messages = [];
  static const int _maxRows = 200;
  static const _sendInterval = Duration(seconds: 5);

  // Map state
  MapController? _mapController;
  List<Marker> _stopMarkers = [];
  Marker? _liveMarker;
  LatLngBounds? _bounds;
  bool _loadingStops = false;
  bool _followLive = true;
  List<LatLng> _routePoints = []; // ordered by sequence
  List<LatLng> _livePath = []; // realtime path of vehicle
  final int _maxLivePathPoints = 500;
  double _currentZoom = 13.0;

  // Search and create-on-map state
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  bool _createOnMap = false; // when true, tapping map places a temp marker to create a stop
  Marker? _tempMarker;

  // Driver status state (one of LocationStatus values as string)
  LocationStatus? _selectedStatus;

  // StopEventBus subscription holders
  StreamSubscription<Map<String, dynamic>>? _createdSub;
  StreamSubscription<Map<String, dynamic>>? _updatedSub;
  StreamSubscription<dynamic>? _deletedSub;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _connectAndStartSending();
    // If a routeId was provided, fetch stops for that route
    if (widget.routeId != null) {
      _fetchStopsForRoute(widget.routeId!);
    }
    // Listen to stop events to update markers live
    _createdSub = StopEventBus().onCreated.listen((payload) {
      _handleStopCreated(payload);
    });
    _updatedSub = StopEventBus().onUpdated.listen((payload) {
      _handleStopUpdated(payload);
    });
    _deletedSub = StopEventBus().onDeleted.listen((id) {
      _handleStopDeleted(id);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ws.disconnect();
    _searchController.dispose();
    _createdSub?.cancel();
    _updatedSub?.cancel();
    _deletedSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchStopsForRoute(int routeId) async {
    setState(() => _loadingStops = true);
    try {
      final raw = await APIService().get(Endpoints.routeStopsReadByRouteId(routeId));
      List<dynamic> list;
      if (raw is List) list = raw;
      else if (raw is Map && raw['data'] is List) list = raw['data'] as List<dynamic>;
      else list = [raw];

      // Try to order stops by sequence/seq/order if present, otherwise keep original order
      final List<Map<String, dynamic>> asMaps = [];
      for (final s in list) {
        if (s is Map<String, dynamic>) asMaps.add(s);
        else if (s is Map) asMaps.add(Map<String, dynamic>.from(s));
      }
      // Determine if sequence key exists
      bool hasSeq = asMaps.any((m) => m.containsKey('sequence') || m.containsKey('seq') || m.containsKey('order'));
      if (hasSeq) {
        asMaps.sort((a, b) {
          final aSeq = (a['sequence'] ?? a['seq'] ?? a['order'])?.toString() ?? '';
          final bSeq = (b['sequence'] ?? b['seq'] ?? b['order'])?.toString() ?? '';
          final ai = int.tryParse(aSeq) ?? 0;
          final bi = int.tryParse(bSeq) ?? 0;
          return ai.compareTo(bi);
        });
      }

      final markers = <Marker>[];
      final points = <LatLng>[];
      final routePts = <LatLng>[];

      for (final s in asMaps) {
        try {
          final lat = (s['latitude'] ?? s['lat'] ?? s['latitud'] ?? s['location']?['latitude']);
          final lng = (s['longitude'] ?? s['lng'] ?? s['long'] ?? s['location']?['longitude']);
          final latD = lat is num ? lat.toDouble() : double.tryParse(lat?.toString() ?? '');
          final lngD = lng is num ? lng.toDouble() : double.tryParse(lng?.toString() ?? '');
          if (latD == null || lngD == null) {
            // keep stop data even if no coords, but don't create marker
            continue;
          }
          final name = (s['name'] ?? s['stopName'] ?? s['title'] ?? '').toString();
          final marker = Marker(
            width: 40,
            height: 40,
            point: LatLng(latD, lngD),
            child: Tooltip(
              message: name,
              child: GestureDetector(
                onTap: () => _showStopDetails(s),
                child: const Icon(Icons.place, color: Colors.red, size: 28),
              ),
            ),
          );
          markers.add(marker);
          points.add(LatLng(latD, lngD));
          routePts.add(LatLng(latD, lngD));
        } catch (_) {
          continue;
        }
      }
      if (mounted) setState(() {
        _stopMarkers = markers;
        _routePoints = routePts;
        if (points.isNotEmpty) _bounds = LatLngBounds.fromPoints(points);
      });
    } catch (e) {
      // ignore: show a snackbar if needed
    } finally {
      if (mounted) setState(() => _loadingStops = false);
    }
  }

  void _handleStopCreated(Map<String, dynamic> payload) {
    // Add a marker if lat/lng present and optional route matches
    try {
      final lat = payload['latitude'] ?? payload['lat'] ?? payload['location']?['latitude'];
      final lng = payload['longitude'] ?? payload['lng'] ?? payload['location']?['longitude'];
      final latD = lat is num ? lat.toDouble() : double.tryParse(lat?.toString() ?? '');
      final lngD = lng is num ? lng.toDouble() : double.tryParse(lng?.toString() ?? '');
      if (latD == null || lngD == null) return;
      final name = (payload['name'] ?? payload['stopName'] ?? payload['title'])?.toString() ?? '';
      final marker = Marker(
        width: 40,
        height: 40,
        point: LatLng(latD, lngD),
        child: Tooltip(
          message: name,
          child: GestureDetector(
            onTap: () => _showStopDetails(payload),
            child: const Icon(Icons.place, color: Colors.red, size: 28),
          ),
        ),
      );
      setState(() {
        _stopMarkers.add(marker);
        _updateBoundsWithPoint(LatLng(latD, lngD));
      });
      // If map currently visible, fit to bounds (with a slight delay to allow marker to render)
      try {
        Future.delayed(const Duration(milliseconds: 250), () {
          if (_bounds != null) {
            final cLat = (_bounds!.north + _bounds!.south) / 2.0;
            final cLng = (_bounds!.east + _bounds!.west) / 2.0;
            final latSpan = (_bounds!.north - _bounds!.south).abs();
            final lngSpan = (_bounds!.east - _bounds!.west).abs();
            final maxSpan = max(latSpan, lngSpan);
            double zoom;
            if (maxSpan < 0.005) zoom = 15.0;
            else if (maxSpan < 0.05) zoom = 13.0;
            else if (maxSpan < 0.5) zoom = 10.0;
            else zoom = 6.0;
            _mapController?.move(LatLng(cLat, cLng), zoom);
          }
        });
      } catch (_) {}
    } catch (_) {}
  }

  void _handleStopUpdated(Map<String, dynamic> payload) {
    try {
      // Remove any marker near the updated coords and re-add
      final lat = payload['latitude'] ?? payload['lat'] ?? payload['location']?['latitude'];
      final lng = payload['longitude'] ?? payload['lng'] ?? payload['location']?['longitude'];
      final latD = lat is num ? lat.toDouble() : double.tryParse(lat?.toString() ?? '');
      final lngD = lng is num ? lng.toDouble() : double.tryParse(lng?.toString() ?? '');
      // Simple approach: rebuild markers by fetching stops again if routeId known
      if (widget.routeId != null) {
        _fetchStopsForRoute(widget.routeId!);
        return;
      }
      if (latD == null || lngD == null) return;
      final name = (payload['name'] ?? payload['stopName'] ?? payload['title'])?.toString() ?? '';
      // Replace any marker at same lat/lng
      setState(() {
        _stopMarkers.removeWhere((m) => (m.point.latitude - latD).abs() < 0.000001 && (m.point.longitude - lngD).abs() < 0.000001);
        _stopMarkers.add(Marker(
          width: 40,
          height: 40,
          point: LatLng(latD, lngD),
          child: Tooltip(
            message: name,
            child: GestureDetector(
              onTap: () => _showStopDetails(payload),
              child: const Icon(Icons.place, color: Colors.red, size: 28),
            ),
          ),
        ));
        _updateBoundsWithPoint(LatLng(latD, lngD));
      });
    } catch (_) {}
  }

  void _handleStopDeleted(dynamic id) {
    try {
      // If we can identify marker by matching id in marker's key (not available), fallback to refetch if routeId known
      if (widget.routeId != null) {
        _fetchStopsForRoute(widget.routeId!);
        return;
      }
      // Otherwise do nothing (best-effort)
    } catch (_) {}
  }

  void _updateBoundsWithPoint(LatLng pt) {
    try {
      if (_bounds == null) {
        _bounds = LatLngBounds(pt, pt);
      } else {
        final north = max(_bounds!.north, pt.latitude);
        final south = min(_bounds!.south, pt.latitude);
        final east = max(_bounds!.east, pt.longitude);
        final west = min(_bounds!.west, pt.longitude);
        _bounds = LatLngBounds(LatLng(south, west), LatLng(north, east));
      }
    } catch (_) {}
  }

  // Show stop details and provide Edit/Delete actions for drivers/admins
  void _showStopDetails(Map<String, dynamic> stop) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final seq = (stop['sequence'] ?? stop['seq'] ?? stop['order'])?.toString() ?? '-';
        final name = (stop['name'] ?? stop['stopName'] ?? stop['title'])?.toString() ?? 'Stop $seq';
        final address = (stop['address'] ?? stop['location']?['address'] ?? stop['addr'])?.toString() ?? '';
        final eta = (stop['eta'] ?? stop['etaTime'] ?? stop['time'])?.toString() ?? '-';
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Sequence: $seq'),
              if (address.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Address: $address'),
              ],
              const SizedBox(height: 8),
              Text('ETA: $eta'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _showEditStopDialog(stop);
                    },
                    child: const Text('Edit'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _confirmDeleteStop(stop);
                    },
                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditStopDialog(Map<String, dynamic> stop) async {
    final id = stop['id'] ?? stop['stop_id'] ?? stop['stopId'];
    final _nameCtl = TextEditingController(text: stop['name'] ?? stop['stopName'] ?? '');
    final _latCtl = TextEditingController(text: (stop['latitude'] ?? stop['lat'])?.toString() ?? '');
    final _lngCtl = TextEditingController(text: (stop['longitude'] ?? stop['lng'])?.toString() ?? '');
    final _seqCtl = TextEditingController(text: (stop['sequence'] ?? stop['seq'])?.toString() ?? '');
    final _addrCtl = TextEditingController(text: stop['address'] ?? '');
    final _etaCtl = TextEditingController(text: stop['eta'] ?? '');
    final _formKey = GlobalKey<FormState>();

    final shouldSave = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Edit Stop'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: _nameCtl, decoration: const InputDecoration(labelText: 'Stop name'), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
            const SizedBox(height: 8),
            TextFormField(controller: _latCtl, decoration: const InputDecoration(labelText: 'Latitude'), keyboardType: TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 8),
            TextFormField(controller: _lngCtl, decoration: const InputDecoration(labelText: 'Longitude'), keyboardType: TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 8),
            TextFormField(controller: _seqCtl, decoration: const InputDecoration(labelText: 'Sequence (optional)'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextFormField(controller: _addrCtl, decoration: const InputDecoration(labelText: 'Address (optional)')),
            const SizedBox(height: 8),
            TextFormField(controller: _etaCtl, decoration: const InputDecoration(labelText: 'ETA (optional)')),
          ]),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')), ElevatedButton(onPressed: () {
        if (!_formKey.currentState!.validate()) return; Navigator.of(ctx).pop(true);
      }, child: const Text('Save'))],
    ));

    if (shouldSave != true) return;

    final payload = <String, dynamic>{
      if (id != null) 'id': id,
      'name': _nameCtl.text.trim(),
      if (_latCtl.text.trim().isNotEmpty) 'latitude': double.tryParse(_latCtl.text.trim()),
      if (_lngCtl.text.trim().isNotEmpty) 'longitude': double.tryParse(_lngCtl.text.trim()),
      if (_seqCtl.text.trim().isNotEmpty) 'sequence': int.tryParse(_seqCtl.text.trim()),
      if (_addrCtl.text.trim().isNotEmpty) 'address': _addrCtl.text.trim(),
      if (_etaCtl.text.trim().isNotEmpty) 'eta': _etaCtl.text.trim(),
    };
    // Include route context when available to satisfy backends that expect it in the body
    if (widget.routeId != null) {
      payload['routeId'] = widget.routeId;
      payload['route_id'] = widget.routeId;
    }

    final candidates = <String>[];
    if (widget.routeId != null && id != null) {
      candidates.add('routes/${widget.routeId}/stops/update');
      candidates.add('routes/${widget.routeId}/stops/update/$id');
    }
    if (id != null) candidates.add('stops/update/$id');
    candidates.add('stops/update');

    try {
      dynamic res;
      Exception? lastErr;
      for (final ep in candidates) {
        try {
          res = await APIService().put(ep, payload);
          break;
        } catch (e) {
          lastErr = e is Exception ? e : Exception(e.toString());
          // Inspect ApiException body (if any) and surface clear guidance for route errors
          String msg = e.toString();
          try {
            if (e is ApiException) {
              final b = e.body;
              if (b is String) msg = b;
              else if (b is Map || b is List) msg = b.toString();
            }
          } catch (_) {}
          if (msg.contains('Route not found') || msg.toLowerCase().contains('route not found')) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Server reported "Route not found" — select the correct route before updating the stop')));
            break;
          }
          continue;
        }
      }
      if (res == null) throw lastErr ?? Exception('Failed to update stop');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stop updated')));
      final updated = (res is Map<String, dynamic>) ? Map<String, dynamic>.from(res) : payload;
      StopEventBus().emitUpdated(updated);
      _handleStopUpdated(updated);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update stop: ${e.toString()}')));
    }
  }

  Future<void> _confirmDeleteStop(Map<String, dynamic> stop) async {
    final id = stop['id'] ?? stop['stop_id'] ?? stop['stopId'];
    final proceed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Stop'),
      content: const Text('Are you sure you want to delete this stop?'),
      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete'))],
    ));
    if (proceed != true) return;
    try {
      bool success = false;
      if (id != null) {
        final candidates = <String>[];
        if (widget.routeId != null) candidates.add('routes/${widget.routeId}/stops/delete/$id');
        candidates.add('stops/delete/$id');
        candidates.add('stops/$id');
        Exception? lastErr;
        for (final ep in candidates) {
          try {
            await APIService().delete(ep);
            success = true;
            break;
          } catch (e) {
            lastErr = e is Exception ? e : Exception(e.toString());
            continue;
          }
        }
        if (!success) throw lastErr ?? Exception('Delete failed');
      } else {
        throw Exception('Stop id not available');
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stop deleted')));
      StopEventBus().emitDeleted(id);
      if (widget.routeId != null) _fetchStopsForRoute(widget.routeId!);
      else {
        // attempt to remove marker by coords if present
        final lat = stop['latitude'] ?? stop['lat'];
        final lng = stop['longitude'] ?? stop['lng'];
        final latD = lat is num ? lat.toDouble() : double.tryParse(lat?.toString() ?? '');
        final lngD = lng is num ? lng.toDouble() : double.tryParse(lng?.toString() ?? '');
        if (latD != null && lngD != null) {
          setState(() {
            _stopMarkers.removeWhere((m) => (m.point.latitude - latD).abs() < 0.000001 && (m.point.longitude - lngD).abs() < 0.000001);
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete stop: ${e.toString()}')));
    }
  }

  void _connectAndStartSending() {
    _ws.connect(onConnected: (_) {
      setState(() => _connected = true);
      // Subscribe to broadcasts and collect messages (optionally filter by current driver/shuttle)
      _ws.subscribeToLocations((msg) {
        if (msg.driverId == widget.driverId && msg.shuttleId == widget.shuttleId) {
          _appendMessage(msg);
          // Update live marker on the map
          _updateLiveMarker(msg.latitude, msg.longitude, msg.timestamp);
          // If the incoming message includes a status, reflect it locally
          if (msg.status != null) {
            try {
              final s = LocationStatusExtension.fromString(msg.status!);
              setState(() {
                _selectedStatus = s;
              });
            } catch (_) {}
          }
        }
      });

      // Start periodic updates every 5 seconds
      _timer?.cancel();
      _timer = Timer.periodic(_sendInterval, (_) => _sendUpdate());
      // Send immediately as well
      _sendUpdate();
    }, onError: (err) {
      setState(() => _connected = false);
      // Optionally show a snackbar/toast
    });
  }

  void _updateLiveMarker(double lat, double lng, String? ts) {
    final m = Marker(
      width: 48,
      height: 48,
      point: LatLng(lat, lng),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.directions_bus, color: Colors.blue, size: 28),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
            child: Text(_fmtTs(ts), style: const TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
    setState(() {
      _liveMarker = m;
      // Append to live path
      _livePath.add(LatLng(lat, lng));
      if (_livePath.length > _maxLivePathPoints) _livePath.removeRange(0, _livePath.length - _maxLivePathPoints);
    });
    // Optionally move map to live marker if follow enabled
    try {
      if (_mapController != null && _followLive) _mapController!.move(LatLng(lat, lng), _currentZoom);
    } catch (_) {}
  }

  void _appendMessage(LocationMessageDto msg) {
    setState(() {
      _messages.insert(0, msg);
      if (_messages.length > _maxRows) {
        _messages.removeRange(_maxRows, _messages.length);
      }
    });
  }

  void _sendUpdate() {
    // Simple drift to simulate movement
    final newLat = _lat + 0.0003;
    final newLng = _lng + 0.0002;

    // Send to server (timestamp optional)
    final nowIso = DateTime.now().toIso8601String();
    _ws.sendLocationUpdate(
      driverId: widget.driverId,
      shuttleId: widget.shuttleId,
      latitude: newLat,
      longitude: newLng,
      timestampIso8601: nowIso,
      status: _selectedStatus?.toString().split('.').last,
    );

    // Also POST to the REST endpoint as a fallback/persistence so polling clients can read it
    try {
      final payload = {
        'driverId': widget.driverId,
        'shuttleId': widget.shuttleId,
        'latitude': newLat,
        'longitude': newLng,
        'timestamp': nowIso,
        if (_selectedStatus != null) 'status': _selectedStatus!.toString().split('.').last,
      };
      // Fire-and-forget
      APIService().post(Endpoints.locationUpdate, payload).catchError((_) {});
    } catch (_) {}

    // Optimistically append the sent message to the table
    _appendMessage(LocationMessageDto(
      driverId: widget.driverId,
      shuttleId: widget.shuttleId,
      latitude: newLat,
      longitude: newLng,
      timestamp: nowIso,
      status: _selectedStatus?.toString().split('.').last,
    ));

    // Update the source (target) position for next tick
    _lat = newLat;
    _lng = newLng;
  }

  Future<void> _performSearch(String q) async {
    if (q.trim().isEmpty) return;
    setState(() {
      _searching = true;
      _searchResults = [];
    });
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/search').replace(queryParameters: {
        'q': q,
        'format': 'json',
        'limit': '6',
      });
      final resp = await http.get(uri, headers: {'User-Agent': 'shuttle_tracker_app'});
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as List<dynamic>;
        final results = <Map<String, dynamic>>[];
        for (final it in data) {
          if (it is Map<String, dynamic>) {
            results.add({'display_name': it['display_name'], 'lat': it['lat'], 'lon': it['lon']});
          }
        }
        if (mounted) setState(() => _searchResults = results);
      }
    } catch (_) {}
    if (mounted) setState(() => _searching = false);
  }

  Future<void> _onSearchSelected(Map<String, dynamic> item) async {
    final lat = double.tryParse(item['lat']?.toString() ?? '');
    final lng = double.tryParse(item['lon']?.toString() ?? '');
    if (lat == null || lng == null) return;
    // Move map to selected result
    try {
      _mapController?.move(LatLng(lat, lng), 15.0);
    } catch (_) {}
    // Optionally prompt to create stop here
    final shouldCreate = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(item['display_name'] ?? 'Selected location', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Close')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Create stop here')),
          ])
        ]),
      ),
    );
    if (shouldCreate == true) {
      await _createStopAt(lat, lng, suggestedName: item['display_name']);
    }
  }

  Future<void> _createStopAt(double lat, double lng, {String? suggestedName}) async {
    // Small dialog to collect name/sequence/address/eta, prefilled coordinates
    final _nameCtl = TextEditingController(text: suggestedName ?? '');
    final _seqCtl = TextEditingController();
    final _addrCtl = TextEditingController();
    final _etaCtl = TextEditingController();
    final _formKey = GlobalKey<FormState>();

    final shouldCreate = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Create Stop'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: _nameCtl, decoration: const InputDecoration(labelText: 'Stop name'), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
            const SizedBox(height: 8),
            Row(children: [Expanded(child: Text('Lat: ${lat.toStringAsFixed(6)}')), const SizedBox(width: 8), Expanded(child: Text('Lng: ${lng.toStringAsFixed(6)}'))]),
            const SizedBox(height: 8),
            TextFormField(controller: _seqCtl, decoration: const InputDecoration(labelText: 'Sequence (optional)'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextFormField(controller: _addrCtl, decoration: const InputDecoration(labelText: 'Address (optional)')),
            const SizedBox(height: 8),
            TextFormField(controller: _etaCtl, decoration: const InputDecoration(labelText: 'ETA (optional)')),
          ]),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')), ElevatedButton(onPressed: () {
        if (!_formKey.currentState!.validate()) return; Navigator.of(ctx).pop(true);
      }, child: const Text('Create'))],
    ));

    if (shouldCreate != true) return;

    final name = _nameCtl.text.trim();
    final seq = int.tryParse(_seqCtl.text.trim());
    final addr = _addrCtl.text.trim();
    final eta = _etaCtl.text.trim();

    final payload = <String, dynamic>{
      'name': name,
      'latitude': lat,
      'longitude': lng,
      if (seq != null) 'order': seq,
      if (seq != null) 'sequence': seq,
      if (addr.isNotEmpty) 'address': addr,
      if (eta.isNotEmpty) 'eta': eta,
    };
    // Include route context in payload if available
    if (widget.routeId != null) {
      payload['routeId'] = widget.routeId;
      payload['route_id'] = widget.routeId;
    }

    final candidates = <String>[];
    if (widget.routeId != null) {
      candidates.add('routes/${widget.routeId}/stops');
    }
    candidates.add('stops');

    try {
      dynamic res;
      Exception? lastErr;
      for (final ep in candidates) {
        try {
          res = await APIService().post(ep, payload);
          break;
        } catch (e) {
          lastErr = e is Exception ? e : Exception(e.toString());
          final msg = e.toString();
          if (msg.contains('Route not found') || msg.toLowerCase().contains('route not found')) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Server reported "Route not found" — select the correct route before creating a stop')));
            break; // stop trying further endpoints when route is missing
          }
          continue;
        }
      }
      if (res == null) throw lastErr ?? Exception('Failed to create stop');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stop created')));
      final created = (res is Map<String, dynamic>) ? Map<String, dynamic>.from(res) : {...payload};
      final eventPayload = {...created, if (widget.routeId != null) 'routeId': widget.routeId};
      StopEventBus().emitCreated(eventPayload);
      // Add marker immediately
      _handleStopCreated(eventPayload);
      // clear temporary UI state (temp marker and create-on-map mode)
      setState(() {
        _tempMarker = null;
        _createOnMap = false;
        _searchResults = [];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create stop: ${e.toString()}')));
    }
  }

  String _fmtCoord(double v) => v.toStringAsFixed(6);
  String _fmtTs(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    // Show only time for brevity HH:MM:SS
    try {
      final dt = DateTime.tryParse(iso);
      if (dt == null) return iso;
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      final ss = dt.second.toString().padLeft(2, '0');
      return '$hh:$mm:$ss';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Driver Locations'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Icon(_connected ? Icons.cloud_done : Icons.cloud_off, color: _connected ? Colors.lightGreen : Colors.redAccent),
          ),
          // Follow live toggle
          IconButton(
            tooltip: _followLive ? 'Following live bus' : 'Do not follow',
            icon: Icon(_followLive ? Icons.my_location : Icons.location_disabled),
            onPressed: () => setState(() => _followLive = !_followLive),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Map view (if stops are available or live updates are present)
          SizedBox(
            height: 300,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    onPositionChanged: (pos, _) {
                      // keep local zoom in sync (avoid frequent setState)
                      _currentZoom = pos.zoom;
                    },
                    onTap: (tapPos, latlng) {
                      if (_createOnMap) {
                        // place temporary marker and prompt creation
                        setState(() {
                          _tempMarker = Marker(
                            width: 40,
                            height: 40,
                            point: latlng,
                            child: const Icon(Icons.add_location_alt, color: Colors.green, size: 36),
                          );
                        });
                        // prompt creation
                        Future.microtask(() => _createStopAt(latlng.latitude, latlng.longitude));
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      // Use the single-host OSM tile server to avoid reliance on subdomains
                      // and follow the maintainers' guidance: https://github.com/openstreetmap/operations/issues/737
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    ),
                    // Polylines: route path and live path
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(polylines: [
                        Polyline(points: _routePoints, color: Colors.blue.withAlpha((0.8 * 255).round()), strokeWidth: 4.0),
                      ]),
                    if (_livePath.isNotEmpty)
                      PolylineLayer(polylines: [
                        Polyline(points: _livePath, color: Colors.orange.withAlpha((0.9 * 255).round()), strokeWidth: 3.0),
                      ]),
                    MarkerLayer(markers: [if (_liveMarker != null) _liveMarker!, ..._stopMarkers, if (_tempMarker != null) _tempMarker!]),
                  ],
                ),
                if (_loadingStops)
                  const Positioned(top: 8, left: 8, right: 8, child: LinearProgressIndicator()),
                if (_bounds != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: FloatingActionButton.small(
                      onPressed: () {
                        // Fit bounds: compute center and zoom heuristic
                        try {
                          if (_bounds != null) {
                            final cLat = (_bounds!.north + _bounds!.south) / 2.0;
                            final cLng = (_bounds!.east + _bounds!.west) / 2.0;
                            final latSpan = (_bounds!.north - _bounds!.south).abs();
                            final lngSpan = (_bounds!.east - _bounds!.west).abs();
                            final maxSpan = max(latSpan, lngSpan);
                            double zoom;
                            if (maxSpan < 0.005) zoom = 15.0;
                            else if (maxSpan < 0.05) zoom = 13.0;
                            else if (maxSpan < 0.5) zoom = 10.0;
                            else zoom = 6.0;
                            _mapController?.move(LatLng(cLat, cLng), zoom);
                          }
                        } catch (_) {}
                      },
                      child: const Icon(Icons.fit_screen),
                    ),
                  ),
                // Map legend + OSM attribution
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withAlpha((0.9 * 255).round()), borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.directions_bus, size: 16, color: Colors.blue),
                          const SizedBox(width: 6),
                          const Text('Live bus'),
                          const SizedBox(width: 12),
                          const Icon(Icons.place, size: 16, color: Colors.red),
                          const SizedBox(width: 6),
                          const Text('Stops'),
                        ]),
                        const SizedBox(height: 6),
                        const Text('© OpenStreetMap contributors', style: TextStyle(fontSize: 10, color: Colors.black54)),
                      ],
                    ),
                  ),
                ),
                // Search box and create-on-map toggle
                Positioned(
                  top: 8,
                  left: 8,
                  right: 56,
                  child: Column(
                    children: [
                      Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search place',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searching ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          onSubmitted: (v) => _performSearch(v),
                        ),
                      ),
                      if (_searchResults.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)]),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _searchResults.length,
                            itemBuilder: (ctx, idx) {
                              final it = _searchResults[idx];
                              return ListTile(
                                dense: true,
                                title: Text(it['display_name'] ?? ''),
                                onTap: () => _onSearchSelected(it),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                // Status selector for driver (if this screen is used by driver)
                Positioned(
                  top: 64,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)]),
                    child: Row(children: [
                      const Icon(Icons.info_outline, size: 16),
                      const SizedBox(width: 8),
                      DropdownButton<LocationStatus>(
                        value: _selectedStatus,
                        hint: const Text('Status'),
                        items: LocationStatus.values.map((s) => DropdownMenuItem<LocationStatus>(value: s, child: Text(s.label))).toList(),
                        onChanged: (val) {
                          setState(() => _selectedStatus = val);
                          // Send an immediate status update with current coordinates
                          try {
                            _ws.sendLocationUpdate(
                              driverId: widget.driverId,
                              shuttleId: widget.shuttleId,
                              latitude: _lat,
                              longitude: _lng,
                              timestampIso8601: DateTime.now().toIso8601String(),
                              status: val?.toString().split('.').last,
                            );
                          } catch (_) {}
                        },
                      ),
                    ]),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Column(children: [
                    FloatingActionButton.small(
                      heroTag: 'createModeBtn',
                      backgroundColor: _createOnMap ? Colors.green : null,
                      onPressed: () => setState(() {
                        _createOnMap = !_createOnMap;
                        if (!_createOnMap) _tempMarker = null;
                      }),
                      child: const Icon(Icons.add_location_alt),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'fitBtn',
                      onPressed: () {
                        try {
                          if (_bounds != null) {
                            final cLat = (_bounds!.north + _bounds!.south) / 2.0;
                            final cLng = (_bounds!.east + _bounds!.west) / 2.0;
                            final latSpan = (_bounds!.north - _bounds!.south).abs();
                            final lngSpan = (_bounds!.east - _bounds!.west).abs();
                            final maxSpan = max(latSpan, lngSpan);
                            double zoom;
                            if (maxSpan < 0.005) zoom = 15.0;
                            else if (maxSpan < 0.05) zoom = 13.0;
                            else if (maxSpan < 0.5) zoom = 10.0;
                            else zoom = 6.0;
                            _mapController?.move(LatLng(cLat, cLng), zoom);
                          }
                        } catch (_) {}
                      },
                      child: const Icon(Icons.my_location),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Chip(label: Text('Driver: ${widget.driverId}')),
                const SizedBox(width: 8),
                Chip(label: Text('Shuttle: ${widget.shuttleId}')),
                const Spacer(),
                TextButton.icon(
                  onPressed: _messages.isEmpty
                      ? null
                      : () => setState(() => _messages.clear()),
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _buildTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    if (_messages.isEmpty) {
      return const Center(child: Text('No location updates yet'));
    }

    final columns = const [
      DataColumn(label: Text('Time')),
      DataColumn(label: Text('Driver ID')),
      DataColumn(label: Text('Shuttle ID')),
      DataColumn(label: Text('Latitude')),
      DataColumn(label: Text('Longitude')),
    ];

    final rows = _messages.map((m) {
      return DataRow(cells: [
        DataCell(Text(_fmtTs(m.timestamp))),
        DataCell(Text(m.driverId)),
        DataCell(Text(m.shuttleId)),
        DataCell(Text(_fmtCoord(m.latitude))),
        DataCell(Text(_fmtCoord(m.longitude))),
      ]);
    }).toList();

    // Wrap in horizontal scroll for small screens
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 600),
          child: SingleChildScrollView(
            child: DataTable(columns: columns, rows: rows),
          ),
        ),
      ),
    );
  }
}

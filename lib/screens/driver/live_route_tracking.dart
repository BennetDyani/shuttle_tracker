import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shuttle_tracker/services/location_ws_service.dart';
import 'package:shuttle_tracker/services/location_stomp_client.dart';

class LiveRouteTrackingScreen extends StatefulWidget {
  final String driverId;
  final String shuttleId;

  const LiveRouteTrackingScreen({super.key, this.driverId = 'driver-1', this.shuttleId = 'shuttle-1'});

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

  @override
  void initState() {
    super.initState();
    _connectAndStartSending();
  }

  void _connectAndStartSending() {
    _ws.connect(onConnected: (_) {
      setState(() => _connected = true);
      // Subscribe to broadcasts and collect messages (optionally filter by current driver/shuttle)
      _ws.subscribeToLocations((msg) {
        if (msg.driverId == widget.driverId && msg.shuttleId == widget.shuttleId) {
          _appendMessage(msg);
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
    );

    // Optimistically append the sent message to the table
    _appendMessage(LocationMessageDto(
      driverId: widget.driverId,
      shuttleId: widget.shuttleId,
      latitude: newLat,
      longitude: newLng,
      timestamp: nowIso,
    ));

    // Update the source (target) position for next tick
    _lat = newLat;
    _lng = newLng;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ws.disconnect();
    super.dispose();
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
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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

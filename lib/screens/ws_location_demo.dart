import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shuttle_tracker/services/location_ws_service.dart';
import 'package:shuttle_tracker/services/location_stomp_client.dart';
import 'package:shuttle_tracker/services/globals.dart' as globals;

class WsLocationDemoScreen extends StatefulWidget {
  const WsLocationDemoScreen({super.key});

  @override
  State<WsLocationDemoScreen> createState() => _WsLocationDemoScreenState();
}

class _WsLocationDemoScreenState extends State<WsLocationDemoScreen> {
  final _driverIdCtrl = TextEditingController(text: 'driver-123');
  final _shuttleIdCtrl = TextEditingController(text: 'shuttle-1');
  final _latCtrl = TextEditingController(text: '-33.9249');
  final _lngCtrl = TextEditingController(text: '18.4241');
  final _timestampCtrl = TextEditingController();

  final _logs = <String>[];
  StreamSubscription? _timerSub;

  final _ws = LocationWsService();
  bool _autoSend = false;

  void _append(String msg) {
    setState(() => _logs.insert(0, msg));
  }

  void _connect() {
    _ws.connect(onConnected: (frame) {
      final sessionHeader = frame.headers == null ? null : frame.headers!['session'];
      _append('Connected: session ${sessionHeader ?? ''}');
      _ws.subscribeToLocations((LocationMessageDto msg) {
        _append('Received: driver=${msg.driverId}, shuttle=${msg.shuttleId}, lat=${msg.latitude}, lng=${msg.longitude}, ts=${msg.timestamp ?? 'null'}');
      });
    }, onError: (err) {
      _append('Error: $err');
    });
  }

  void _disconnect() {
    _ws.disconnect();
    _append('Disconnected');
  }

  void _sendOnce() {
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    if (lat == null || lng == null) {
      _append('Invalid coordinates');
      return;
    }

    final tsRaw = _timestampCtrl.text.trim();
    final ts = tsRaw.isEmpty ? null : tsRaw; // must be ISO-8601 if provided

    _ws.sendLocationUpdate(
      driverId: _driverIdCtrl.text.trim(),
      shuttleId: _shuttleIdCtrl.text.trim(),
      latitude: lat,
      longitude: lng,
      timestampIso8601: ts,
    );
    _append('Sent update to ${globals.appDestinationPrefix}/update-location');
  }

  void _toggleAutoSend() {
    setState(() => _autoSend = !_autoSend);
    _timerSub?.cancel();
    if (_autoSend) {
      _timerSub = Stream.periodic(const Duration(seconds: 3)).listen((_) {
        _sendOnce();
      });
    }
  }

  @override
  void dispose() {
    _timerSub?.cancel();
    _driverIdCtrl.dispose();
    _shuttleIdCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _timestampCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wsUrl = LocationStompClient.buildWebSocketUrl(
      globals.apiBaseUrl,
      globals.wsEndpointPath,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('WS Location Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WebSocket URL: $wsUrl'),
            Text('Subscribe: ${globals.topicDestinationPrefix}/locations'),
            Text('Send: ${globals.appDestinationPrefix}/update-location'),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _ws.isConnected ? null : _connect,
                  child: const Text('Connect'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _ws.isConnected ? _disconnect : null,
                  child: const Text('Disconnect'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _sendOnce,
                  child: const Text('Send Once'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _toggleAutoSend,
                  child: Text(_autoSend ? 'Stop Auto' : 'Auto Every 3s'),
                ),
              ],
            ),
            const Divider(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _driverIdCtrl,
                    decoration: const InputDecoration(labelText: 'Driver ID'),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _shuttleIdCtrl,
                    decoration: const InputDecoration(labelText: 'Shuttle ID'),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _latCtrl,
                    decoration: const InputDecoration(labelText: 'Latitude'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _lngCtrl,
                    decoration: const InputDecoration(labelText: 'Longitude'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _timestampCtrl,
                    decoration: const InputDecoration(labelText: 'Timestamp (ISO-8601, optional)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Logs:'),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, idx) => Text(_logs[idx]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

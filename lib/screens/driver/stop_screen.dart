import 'package:flutter/material.dart';
import 'dart:async';

import 'live_route_tracking.dart';
import '../../services/APIService.dart';
import '../../services/endpoints.dart';
import '../../services/shuttle_service.dart';
import '../../services/stop_event_bus.dart';

class DriverStopsScreen extends StatefulWidget {
  const DriverStopsScreen({super.key});

  @override
  State<DriverStopsScreen> createState() => _DriverStopsScreenState();
}

class _DriverStopsScreenState extends State<DriverStopsScreen> {
  List<dynamic> stops = [];
  bool isLoading = true;
  String? errorMessage;
  // Routes state
  final ShuttleService _shuttleService = ShuttleService();
  List<dynamic> _routes = [];
  bool _loadingRoutes = true;
  int? _selectedRouteId;
  // Event bus subscriptions to update list immediately
  StreamSubscription<Map<String, dynamic>>? _createdSub;
  StreamSubscription<Map<String, dynamic>>? _updatedSub;
  StreamSubscription<dynamic>? _deletedSub;

  // Helper to fetch routes then select one and load stops
  Future<void> _loadRoutesAndStops() async {
    setState(() {
      _loadingRoutes = true;
      errorMessage = null;
    });
    try {
      final fetched = await _shuttleService.getRoutes();
      // fetched may be List<Map<String,dynamic>> or List<dynamic>
      _routes = fetched.cast<dynamic>();
      // Choose first route by default if none selected
      if ((_selectedRouteId == null) && _routes.isNotEmpty) {
        final first = _routes.first;
        // Accept different key names
        final rid = (first['routeId'] ?? first['route_id'] ?? first['id']) ?? first['id'];
        if (rid is int) _selectedRouteId = rid;
        else if (rid is String) _selectedRouteId = int.tryParse(rid);
      }
      if (_selectedRouteId != null) await _fetchStops();
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load routes: ${e.toString()}';
      });
    } finally {
      if (mounted) setState(() => _loadingRoutes = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadRoutesAndStops();
    // subscribe to stop events so the list refreshes when stops are modified elsewhere
    _createdSub = StopEventBus().onCreated.listen((payload) {
      // if route context provided, only refresh when it matches
      final rid = payload['routeId'] ?? payload['route_id'] ?? payload['routeId'];
      if (rid == null || _selectedRouteId == null || rid == _selectedRouteId) {
        _fetchStops();
      }
    });
    _updatedSub = StopEventBus().onUpdated.listen((payload) {
      final rid = payload['routeId'] ?? payload['route_id'] ?? payload['routeId'];
      if (rid == null || _selectedRouteId == null || rid == _selectedRouteId) {
        _fetchStops();
      }
    });
    _deletedSub = StopEventBus().onDeleted.listen((id) {
      // conservative: refresh list
      _fetchStops();
    });
  }

  @override
  void dispose() {
    _createdSub?.cancel();
    _updatedSub?.cancel();
    _deletedSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchStops() async {
    if (_selectedRouteId == null) {
      setState(() {
        stops = [];
        isLoading = false;
        errorMessage = 'No route selected';
      });
      return;
    }
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final stopsData = await APIService().get(Endpoints.routeStopsReadByRouteId(_selectedRouteId!));
      // Normalize to list
      final List<dynamic> list = (stopsData is List) ? stopsData : (stopsData is Map && stopsData['data'] is List ? stopsData['data'] as List<dynamic> : [stopsData]);
      setState(() {
        stops = list;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stops'),
        actions: [
          IconButton(
            tooltip: 'Add stop',
            icon: const Icon(Icons.add_location_alt),
            onPressed: () async {
              if (_selectedRouteId == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a route before adding a stop')));
                return;
              }
              await _showAddStopDialog(context);
            },
          ),
        ],
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Error: ' + errorMessage!),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () async => await _loadRoutesAndStops(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await _fetchStops();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        // Route selector
                        if (_loadingRoutes)
                          const LinearProgressIndicator()
                        else if (_routes.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                            child: DropdownButtonFormField<int>(
                              initialValue: _selectedRouteId,
                              decoration: const InputDecoration(labelText: 'Select Route', border: OutlineInputBorder()),
                              items: _routes.map<DropdownMenuItem<int>>((r) {
                                final rid = (r['routeId'] ?? r['route_id'] ?? r['id']);
                                final id = (rid is int) ? rid : int.tryParse(rid?.toString() ?? '');
                                final name = (r['name'] ?? r['routeName'] ?? r['title'] ?? 'Route ${id ?? ''}').toString();
                                return DropdownMenuItem<int>(value: id, child: Text(name));
                              }).toList(),
                              onChanged: (val) async {
                                setState(() {
                                  _selectedRouteId = val;
                                });
                                await _fetchStops();
                              },
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        const SizedBox(height: 12),
                        Expanded(
                          child: stops.isEmpty
                              ? const Center(child: Text('No stops found for the selected route.'))
                              : ListView.separated(
                                  itemCount: stops.length,
                                  separatorBuilder: (context, index) => const Divider(height: 24),
                                  itemBuilder: (context, index) {
                                    final stop = stops[index] ?? {};
                                    final seq = (stop is Map && (stop['sequence'] ?? stop['seq'] ?? stop['order']) != null)
                                        ? (stop['sequence'] ?? stop['seq'] ?? stop['order']).toString()
                                        : (index + 1).toString();
                                    final name = (stop is Map && (stop['name'] ?? stop['stopName'] ?? stop['title']) != null)
                                        ? (stop['name'] ?? stop['stopName'] ?? stop['title']).toString()
                                        : 'Stop ${seq}';
                                    final etaRaw = (stop is Map) ? (stop['eta'] ?? stop['etaTime'] ?? stop['time']) : null;
                                    final eta = etaRaw?.toString() ?? '-';
                                    final isLast = index == stops.length - 1;
                                    return Card(
                                      color: isLast ? Colors.blue[50] : null,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: isLast ? Colors.blue : Colors.grey[300],
                                          child: Text(seq, style: TextStyle(color: isLast ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                                        ),
                                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(eta, style: const TextStyle(color: Colors.blueGrey)),
                                            const SizedBox(width: 8),
                                            PopupMenuButton<String>(
                                              onSelected: (v) async {
                                                if (v == 'edit') {
                                                  await _showEditStopDialog(context, stop, index);
                                                } else if (v == 'delete') {
                                                  await _confirmDeleteStop(context, stop, index);
                                                }
                                              },
                                              itemBuilder: (ctx) => [
                                                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                                const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => LiveRouteTrackingScreen(routeId: _selectedRouteId)),
          );
        },
        icon: const Icon(Icons.map),
        label: const Text('View on Map'),
      ),
    );
  }

  Future<void> _showAddStopDialog(BuildContext context) async {
    final _nameCtl = TextEditingController();
    final _latCtl = TextEditingController();
    final _lngCtl = TextEditingController();
    final _seqCtl = TextEditingController();
    final _addrCtl = TextEditingController();
    final _etaCtl = TextEditingController();
    final _formKey = GlobalKey<FormState>();
    bool _submitting = false;

    Future<void> _submit() async {
      if (!_formKey.currentState!.validate() || _submitting) return;
      final name = _nameCtl.text.trim();
      final lat = double.tryParse(_latCtl.text.trim());
      final lng = double.tryParse(_lngCtl.text.trim());
      final seq = int.tryParse(_seqCtl.text.trim());
      final addr = _addrCtl.text.trim();
      final eta = _etaCtl.text.trim();

      final payload = <String, dynamic>{
        'name': name,
        if (lat != null) 'latitude': lat,
        if (lng != null) 'longitude': lng,
        if (seq != null) 'order': seq,
        if (seq != null) 'sequence': seq,
        if (addr.isNotEmpty) 'address': addr,
        if (eta.isNotEmpty) 'eta': eta,
      };
      // Include route context in payload if available (some backends expect route id in body)
      if (_selectedRouteId != null) {
        payload['routeId'] = _selectedRouteId;
        payload['route_id'] = _selectedRouteId; // try both common keys
      }

      // Try several plausible endpoints until one succeeds
      final candidates = <String>[];
      if (_selectedRouteId != null) {
        candidates.add('routes/${_selectedRouteId}/stops');
      }
      candidates.add('stops');

      _submitting = true;
      try {
        dynamic res;
        Exception? lastErr;
        for (final ep in candidates) {
          try {
            res = await APIService().post(ep, payload);
            break; // success
          } catch (e) {
            lastErr = e is Exception ? e : Exception(e.toString());
            // Inspect ApiException body (if any) to detect server message like 'Route not found'
            String msg = e.toString();
            try {
              if (e is ApiException) {
                final b = e.body;
                if (b is String) msg = b;
                else if (b is Map || b is List) msg = b.toString();
              }
            } catch (_) {}
            if (msg.contains('Route not found') || msg.toLowerCase().contains('route not found')) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Server reported "Route not found" — select the correct route before creating a stop')));
              break; // stop trying further endpoints because route context is missing
            }
            continue;
          }
        }
        if (res == null) throw lastErr ?? Exception('Failed to create stop');
        // success
        if (mounted) Navigator.of(context).pop();
        ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Stop created')));
        // Emit created event with returned server object if available, include routeId for context
        final created = (res is Map<String, dynamic>) ? Map<String, dynamic>.from(res) : <String, dynamic>{'name': name, 'latitude': lat, 'longitude': lng, 'sequence': seq};
        final eventPayload = {...created, if (_selectedRouteId != null) 'routeId': _selectedRouteId};
        StopEventBus().emitCreated(eventPayload);
        await _fetchStops();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create stop: ${e.toString()}')));
      } finally {
        _submitting = false;
      }
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Stop'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: _nameCtl, decoration: const InputDecoration(labelText: 'Stop name'), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
                const SizedBox(height: 8),
                TextFormField(controller: _latCtl, decoration: const InputDecoration(labelText: 'Latitude'), keyboardType: TextInputType.numberWithOptions(decimal: true), validator: (v) => v != null && v.trim().isNotEmpty && double.tryParse(v.trim()) == null ? 'Invalid' : null),
                const SizedBox(height: 8),
                TextFormField(controller: _lngCtl, decoration: const InputDecoration(labelText: 'Longitude'), keyboardType: TextInputType.numberWithOptions(decimal: true), validator: (v) => v != null && v.trim().isNotEmpty && double.tryParse(v.trim()) == null ? 'Invalid' : null),
                const SizedBox(height: 8),
                TextFormField(controller: _seqCtl, decoration: const InputDecoration(labelText: 'Sequence (optional)'), keyboardType: TextInputType.number, validator: (v) => v != null && v.trim().isNotEmpty && int.tryParse(v.trim()) == null ? 'Invalid' : null),
                const SizedBox(height: 8),
                TextFormField(controller: _addrCtl, decoration: const InputDecoration(labelText: 'Address (optional)')),
                const SizedBox(height: 8),
                TextFormField(controller: _etaCtl, decoration: const InputDecoration(labelText: 'ETA (optional)')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(onPressed: _submit, child: const Text('Create')),
        ],
      ),
    );
  }

  Future<void> _showEditStopDialog(BuildContext context, dynamic stop, int index) async {
    final id = stop is Map ? (stop['id'] ?? stop['stop_id'] ?? stop['stopId']) : null;
    final _nameCtl = TextEditingController(text: stop is Map ? (stop['name'] ?? stop['stopName'] ?? '') : '');
    final _latCtl = TextEditingController(text: stop is Map ? (stop['latitude']?.toString() ?? stop['lat']?.toString() ?? '') : '');
    final _lngCtl = TextEditingController(text: stop is Map ? (stop['longitude']?.toString() ?? stop['lng']?.toString() ?? '') : '');
    final _seqCtl = TextEditingController(text: stop is Map ? (stop['sequence']?.toString() ?? stop['seq']?.toString() ?? '') : '');
    final _addrCtl = TextEditingController(text: stop is Map ? (stop['address'] ?? '') : '');
    final _etaCtl = TextEditingController(text: stop is Map ? (stop['eta'] ?? '') : '');
    final _formKey = GlobalKey<FormState>();

    Future<void> _submit() async {
      if (!_formKey.currentState!.validate()) return;
      final payload = <String, dynamic>{
        if (id != null) 'id': id,
        'name': _nameCtl.text.trim(),
        if (_latCtl.text.trim().isNotEmpty) 'latitude': double.tryParse(_latCtl.text.trim()),
        if (_lngCtl.text.trim().isNotEmpty) 'longitude': double.tryParse(_lngCtl.text.trim()),
        if (_seqCtl.text.trim().isNotEmpty) 'order': int.tryParse(_seqCtl.text.trim()),
        if (_seqCtl.text.trim().isNotEmpty) 'sequence': int.tryParse(_seqCtl.text.trim()),
        if (_addrCtl.text.trim().isNotEmpty) 'address': _addrCtl.text.trim(),
        if (_etaCtl.text.trim().isNotEmpty) 'eta': _etaCtl.text.trim(),
      };
      // Include route context when available to satisfy backends that expect it in the body
      if (_selectedRouteId != null) {
        payload['routeId'] = _selectedRouteId;
        payload['route_id'] = _selectedRouteId;
      }

      final candidates = <String>[];
      if (_selectedRouteId != null && id != null) {
        candidates.add('routes/${_selectedRouteId}/stops/update');
        candidates.add('routes/${_selectedRouteId}/stops/update/$id');
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
            final msg = e.toString();
            if (msg.contains('Route not found') || msg.toLowerCase().contains('route not found')) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Server reported "Route not found" — select the correct route before updating the stop')));
              break;
            }
            continue;
          }
        }
        if (res == null) throw lastErr ?? Exception('Failed to update stop');
        Navigator.of(context).pop();
        ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Stop updated')));
        // Emit event and refresh
        final created = res is Map<String, dynamic> ? Map<String, dynamic>.from(res) : payload;
        StopEventBus().emitUpdated(created);
        await _fetchStops();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update stop: ${e.toString()}')));
      }
    }

    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Edit Stop'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: _nameCtl, decoration: const InputDecoration(labelText: 'Stop name'), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
            TextFormField(controller: _latCtl, decoration: const InputDecoration(labelText: 'Latitude'), keyboardType: TextInputType.numberWithOptions(decimal: true)),
            TextFormField(controller: _lngCtl, decoration: const InputDecoration(labelText: 'Longitude'), keyboardType: TextInputType.numberWithOptions(decimal: true)),
            TextFormField(controller: _seqCtl, decoration: const InputDecoration(labelText: 'Sequence (optional)'), keyboardType: TextInputType.number),
            TextFormField(controller: _addrCtl, decoration: const InputDecoration(labelText: 'Address (optional)')),
            TextFormField(controller: _etaCtl, decoration: const InputDecoration(labelText: 'ETA (optional)')),
          ]),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')), ElevatedButton(onPressed: _submit, child: const Text('Save'))],
    ));
  }

  Future<void> _confirmDeleteStop(BuildContext context, dynamic stop, int index) async {
    final id = stop is Map ? (stop['id'] ?? stop['stop_id'] ?? stop['stopId']) : null;
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
        if (_selectedRouteId != null) candidates.add('routes/${_selectedRouteId}/stops/delete/$id');
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
        // No id: try delete by payload route/sequence if available
        throw Exception('Stop id not available');
      }
      ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Stop deleted')));
      StopEventBus().emitDeleted(id);
      await _fetchStops();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete stop: ${e.toString()}')));
    }
  }
}

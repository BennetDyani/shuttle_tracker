import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../widgets/dashboard_action.dart';
import 'live_tracking_screen.dart';
import '../../../services/APIService.dart';

class StopsScreen extends StatefulWidget {
  const StopsScreen({super.key});

  @override
  State<StopsScreen> createState() => _StopsScreenState();
}

class _StopsScreenState extends State<StopsScreen> {
  bool _loadingRoutes = true;
  bool _loadingStops = false;
  String? _error;

  List<Map<String, dynamic>> _routes = [];
  int? _selectedRouteId;

  List<Map<String, String>> _stops = [];

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    setState(() {
      _loadingRoutes = true;
      _error = null;
    });
    try {
      final raw = await APIService().fetchRoutes();
      final parsed = <Map<String, dynamic>>[];
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          int? id;
          if (item['id'] is int) id = item['id'] as int;
          else if (item['route_id'] is int) id = item['route_id'] as int;
          else if (item['routeId'] is int) id = item['routeId'] as int;
          else if (item['id'] is String) id = int.tryParse(item['id']);

          String name = (item['name'] ?? item['route_name'] ?? item['title'] ?? '').toString();
          if (id != null && name.isNotEmpty) parsed.add({'id': id, 'name': name});
        }
      }
      if (parsed.isEmpty) throw Exception('No routes available');
      setState(() {
        _routes = parsed;
        _selectedRouteId = parsed.first['id'] as int?;
      });
      if (_selectedRouteId != null) await _loadStops(_selectedRouteId!);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loadingRoutes = false;
      });
    }
  }

  Future<void> _loadStops(int routeId) async {
    setState(() {
      _loadingStops = true;
      _error = null;
      _stops = [];
    });
    try {
      final raw = await APIService().fetchRouteStops(routeId);
      final parsed = <Map<String, String>>[];
      for (final s in raw) {
        if (s is Map<String, dynamic>) {
          final name = (s['name'] ?? s['stop_name'] ?? s['title'] ?? s['label'] ?? '').toString();
          final eta = (s['eta'] ?? s['next_eta'] ?? s['eta_text'] ?? '').toString();
          if (name.isNotEmpty) parsed.add({'name': name, 'eta': eta.isNotEmpty ? eta : '—'});
        }
      }
      setState(() {
        _stops = parsed;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loadingStops = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stops'),
        centerTitle: true,
        actions: const [DashboardAction()],
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loadingRoutes) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            DropdownButtonFormField<int>(
              initialValue: _selectedRouteId,
              items: _routes
                  .map((route) => DropdownMenuItem<int>(value: route['id'] as int?, child: Text(route['name'] ?? 'Route')))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedRouteId = val;
                  });
                  _loadStops(val);
                }
              },
              decoration: const InputDecoration(
                labelText: 'Select Route',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _loadingStops
                  ? const Center(child: CircularProgressIndicator())
                  : _stops.isEmpty
                      ? Center(child: Text(_error != null ? 'Error: $_error' : 'No stops available'))
                      : ListView.builder(
                          itemCount: _stops.length,
                          itemBuilder: (context, index) {
                            final stop = _stops[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(stop['name']!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(Icons.access_time, size: 16, color: Colors.blueGrey),
                                            const SizedBox(width: 4),
                                            Text('Next shuttle: ${stop['eta']}'),
                                          ],
                                        ),
                                      ],
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => const LiveTrackingScreen()),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: const Text('View on Map'),
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
    );
  }
}

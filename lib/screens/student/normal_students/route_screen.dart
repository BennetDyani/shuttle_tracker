import 'package:flutter/material.dart';
import '../../../services/APIService.dart';
import '../../../widgets/dashboard_action.dart';
import 'live_tracking_screen.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  List<dynamic> routes = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchRoutes();
  }

  Future<void> _fetchRoutes() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final result = await APIService().get('routes/getAll');
      // Normalize to a list in case backend wraps the response
      List<dynamic>? rawList;
      if (result is List) rawList = result;
      else if (result is Map<String, dynamic>) {
        if (result['data'] is List) rawList = result['data'] as List<dynamic>;
        else if (result['routes'] is List) rawList = result['routes'] as List<dynamic>;
      }
      if (rawList == null) throw Exception('Invalid routes response: $result');
      setState(() {
        routes = rawList!;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  String _getField(Map r, List<String> keys, [String fallback = '-']) {
    for (final k in keys) {
      if (r.containsKey(k) && r[k] != null) return r[k].toString();
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shuttle Routes'),
        centerTitle: true,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        actions: const [DashboardAction()],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text('Error: $errorMessage'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: routes.length,
                  itemBuilder: (context, index) {
                    final raw = routes[index];
                    // ensure we have a Map-like object
                    final Map route = (raw is Map<String, dynamic>) ? raw : Map<String, dynamic>.from(raw as Map);
                    final name = _getField(route, ['name', 'routeName', 'title'], 'Route ${index + 1}');
                    final start = _getField(route, ['start', 'origin', 'from'], 'Unknown');
                    final end = _getField(route, ['end', 'destination', 'to'], 'Unknown');
                    final hours = _getField(route, ['hours', 'operatingHours', 'schedule'], '-');

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.play_arrow, size: 18, color: Colors.green),
                                const SizedBox(width: 4),
                                Text(start),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward, size: 16),
                                const SizedBox(width: 8),
                                const Icon(Icons.flag, size: 18, color: Colors.red),
                                const SizedBox(width: 4),
                                Text(end),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 16, color: Colors.blueGrey),
                                const SizedBox(width: 4),
                                Text('Operating hours: $hours'),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton(
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
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

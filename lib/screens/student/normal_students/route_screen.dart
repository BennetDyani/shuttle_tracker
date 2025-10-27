import 'package:flutter/material.dart';
import '../../../services/APIService.dart';
import '../../../widgets/dashboard_action.dart';
import '../student_live_tracking_screen.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  List<dynamic> routes = [];
  Map<String, dynamic> shuttleMap = {};
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
      // Load shuttles first to filter bus routes
      final shuttles = await APIService().fetchShuttles();
      final busIds = <String>{};

      for (var shuttle in shuttles) {
        final type = shuttle['shuttleType']?.toString().toUpperCase() ??
                     shuttle['shuttle_type']?.toString().toUpperCase() ?? '';
        if (type == 'BUS') {
          final id = shuttle['shuttleId']?.toString() ?? shuttle['shuttle_id']?.toString();
          if (id != null) {
            busIds.add(id);
            shuttleMap[id] = shuttle;
          }
        }
      }

      // Load routes
      final result = await APIService().get('routes/getAll');
      // Normalize to a list in case backend wraps the response
      List<dynamic>? rawList;
      if (result is List) rawList = result;
      else if (result is Map<String, dynamic>) {
        if (result['data'] is List) rawList = result['data'] as List<dynamic>;
        else if (result['routes'] is List) rawList = result['routes'] as List<dynamic>;
      }
      if (rawList == null) throw Exception('Invalid routes response: $result');

      // Filter routes that use bus shuttles
      final busRoutes = rawList.where((route) {
        final shuttleId = route['shuttleId']?.toString() ?? route['shuttle_id']?.toString();
        return shuttleId != null && busIds.contains(shuttleId);
      }).toList();

      setState(() {
        routes = busRoutes;
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

  String _getShuttleInfo(Map route) {
    final shuttleId = route['shuttleId']?.toString() ?? route['shuttle_id']?.toString();
    if (shuttleId != null && shuttleMap.containsKey(shuttleId)) {
      final shuttle = shuttleMap[shuttleId];
      return shuttle['licensePlate']?.toString() ??
             shuttle['plate']?.toString() ??
             'Bus';
    }
    return 'Bus';
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
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: $errorMessage', textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _fetchRoutes,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : routes.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.directions_bus_outlined, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'No bus routes available',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _fetchRoutes,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refresh'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchRoutes,
                      child: ListView.builder(
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
                    final shuttleInfo = _getShuttleInfo(route);

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
                            const SizedBox(height: 12),
                            // Shuttle info
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.directions_bus, color: Colors.green, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    shuttleInfo,
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
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
                                    MaterialPageRoute(builder: (_) => const StudentLiveTrackingScreen()),
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
              ),
    );
  }
}

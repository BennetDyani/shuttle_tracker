import 'package:flutter/material.dart';
import '../../../services/APIService.dart';
import '../student_live_tracking_screen.dart';

class AccessibleRoutesScreen extends StatefulWidget {
  const AccessibleRoutesScreen({super.key});

  @override
  State<AccessibleRoutesScreen> createState() => _AccessibleRoutesScreenState();
}

class _AccessibleRoutesScreenState extends State<AccessibleRoutesScreen> {
  final APIService _apiService = APIService();

  List<dynamic> _routes = [];
  Map<String, dynamic> _shuttleMap = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAccessibleRoutes();
  }

  Future<void> _loadAccessibleRoutes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load shuttles first to filter minibus routes
      final shuttles = await _apiService.fetchShuttles();
      final minibusIds = <String>{};

      for (var shuttle in shuttles) {
        final type = shuttle['shuttleType']?.toString().toUpperCase() ??
                     shuttle['shuttle_type']?.toString().toUpperCase() ?? '';
        if (type == 'MINIBUS') {
          final id = shuttle['shuttleId']?.toString() ?? shuttle['shuttle_id']?.toString();
          if (id != null) {
            minibusIds.add(id);
            _shuttleMap[id] = shuttle;
          }
        }
      }

      // Load routes
      final result = await _apiService.get('routes/getAll');
      List<dynamic>? rawList;
      if (result is List) {
        rawList = result;
      } else if (result is Map<String, dynamic>) {
        rawList = (result['data'] ?? result['routes'] ?? []) as List<dynamic>?;
      }

      if (rawList == null) throw Exception('Invalid routes response');

      // Filter routes that use minibus shuttles
      final accessibleRoutes = rawList.where((route) {
        // Check if route has any minibus assigned
        final shuttleId = route['shuttleId']?.toString() ?? route['shuttle_id']?.toString();
        return shuttleId != null && minibusIds.contains(shuttleId);
      }).toList();

      setState(() {
        _routes = accessibleRoutes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _getField(Map route, List<String> keys, [String fallback = '-']) {
    for (final k in keys) {
      if (route.containsKey(k) && route[k] != null) return route[k].toString();
    }
    return fallback;
  }

  String _getShuttleInfo(dynamic route) {
    final shuttleId = route['shuttleId']?.toString() ?? route['shuttle_id']?.toString();
    if (shuttleId != null && _shuttleMap.containsKey(shuttleId)) {
      final shuttle = _shuttleMap[shuttleId];
      return shuttle['licensePlate']?.toString() ??
             shuttle['plate']?.toString() ??
             'Minibus';
    }
    return 'Accessible Minibus';
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: const Text('Accessible Routes'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAccessibleRoutes,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _routes.isEmpty
                  ? _buildEmptyView()
                  : _buildRoutesList(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAccessibleRoutes,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.accessible, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No accessible minibus routes available',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Check back later for updated routes',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAccessibleRoutes,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutesList() {
    return RefreshIndicator(
      onRefresh: _loadAccessibleRoutes,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _routes.length,
        itemBuilder: (context, index) {
          final route = _routes[index] as Map;
          return _buildRouteCard(route);
        },
      ),
    );
  }

  Widget _buildRouteCard(Map route) {
    final name = _getField(route, ['name', 'routeName', 'route_name', 'title'], 'Accessible Route');
    final start = _getField(route, ['start', 'origin', 'from'], 'Campus');
    final end = _getField(route, ['end', 'destination', 'to'], 'Destination');
    final hours = _getField(route, ['hours', 'operatingHours', 'operating_hours', 'schedule'], 'Check schedule');
    final shuttleInfo = _getShuttleInfo(route);
    final distance = _getField(route, ['distance', 'length'], '');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.accessible, color: Colors.blue, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Accessible',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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

            // Route details
            Row(
              children: [
                const Icon(Icons.place, size: 18, color: Colors.green),
                const SizedBox(width: 4),
                Expanded(child: Text(start, style: const TextStyle(fontSize: 14))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.arrow_downward, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                if (distance.isNotEmpty)
                  Text(distance, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 18, color: Colors.red),
                const SizedBox(width: 4),
                Expanded(child: Text(end, style: const TextStyle(fontSize: 14))),
              ],
            ),
            const SizedBox(height: 12),

            // Operating hours
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hours,
                      style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Action button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const StudentLiveTrackingScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.map),
                label: const Text('Track on Map'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

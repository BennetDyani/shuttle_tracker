import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/APIService.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/dashboard_action.dart';

class StudentScheduleScreen extends StatefulWidget {
  const StudentScheduleScreen({super.key});

  @override
  State<StudentScheduleScreen> createState() => _StudentScheduleScreenState();
}

class _StudentScheduleScreenState extends State<StudentScheduleScreen> {
  final List<dynamic> schedules = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  String? errorMessage;
  int _page = 1;
  final int _pageSize = 12;
  bool _hasMore = true;
  String _filter = '';

  // expanded route stops cache per routeId
  final Map<int, List<dynamic>> _routeStops = {};
  final Set<int> _loadingStops = {};

  @override
  void initState() {
    super.initState();
    _loadPage(reset: true);
  }

  Future<void> _loadPage({bool reset = false, bool forceRefresh = false}) async {
    if (reset) {
      _page = 1;
      _hasMore = true;
      schedules.clear();
    }

    if (!_hasMore && !reset) return;

    setState(() {
      if (_page == 1) isLoading = true;
      else isLoadingMore = true;
      errorMessage = null;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uidStr = auth.userId;
      final int? uid = uidStr != null && uidStr.isNotEmpty ? int.tryParse(uidStr) : null;

      final results = await APIService().fetchSchedules(userId: uid, forceRefresh: forceRefresh, page: _page, pageSize: _pageSize, filter: (_filter.isEmpty ? null : _filter));

      setState(() {
        schedules.addAll(results);
        // if fewer than pageSize, assume no more pages
        if (results.length < _pageSize) _hasMore = false;
        else _hasMore = true;
        _page++;
      });
    } catch (e) {
      final msg = e.toString();
      setState(() {
        errorMessage = _friendlyErrorMessage(msg);
      });
    } finally {
      setState(() {
        isLoading = false;
        isLoadingMore = false;
      });
    }
  }

  String _friendlyErrorMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('socket') || lower.contains('network') || lower.contains('failed host lookup') || lower.contains('network/api error')) {
      return 'Network error: please check your connection and try again.';
    }
    // ApiException or server errors often include status
    if (lower.contains('apiexception') || lower.contains('400') || lower.contains('500') || lower.contains('401') || lower.contains('403')) {
      return 'Server error: ${raw}';
    }
    return raw;
  }

  Future<void> _onRefresh() async {
    APIService().clearCache();
    await _loadPage(reset: true, forceRefresh: true);
  }

  Future<void> _retry() async {
    APIService().clearCache();
    await _loadPage(reset: true, forceRefresh: true);
  }

  Future<void> _toggleExpandRoute(int? routeId) async {
    if (routeId == null) return;
    if (_routeStops.containsKey(routeId)) {
      // already loaded; collapse by removing from map (UI will rebuild)
      setState(() {
        _routeStops.remove(routeId);
      });
      return;
    }
    setState(() => _loadingStops.add(routeId));
    try {
      final stops = await APIService().fetchRouteStops(routeId);
      setState(() {
        _routeStops[routeId] = stops;
      });
    } catch (e) {
      // store an empty list so repeated expand attempts don't re-fetch endlessly; show snackbar
      setState(() {
        _routeStops[routeId] = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load stops: ${e.toString()}')));
    } finally {
      setState(() => _loadingStops.remove(routeId));
    }
  }

  int? _extractRouteId(Map item) {
    // Try common fields: routeId, route_id, route.id, route
    if (item.containsKey('routeId') && item['routeId'] != null) {
      final v = item['routeId'];
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
    }
    if (item.containsKey('route_id') && item['route_id'] != null) {
      final v = item['route_id'];
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
    }
    if (item['route'] is Map<String, dynamic>) {
      final r = item['route'] as Map<String, dynamic>;
      if (r['id'] != null) {
        final v = r['id'];
        if (v is int) return v;
        if (v is String) return int.tryParse(v);
      }
    }
    // fallback: if route is numeric
    if (item['route'] is int) return item['route'] as int;
    if (item['route'] is String) return int.tryParse(item['route']);
    return null;
  }

  String _getField(Map item, List<String> keys, [String fallback = '-']) {
    for (final k in keys) {
      if (item.containsKey(k) && item[k] != null) return item[k].toString();
    }
    // nested route map
    if (item['route'] is Map<String, dynamic>) {
      final r = item['route'] as Map<String, dynamic>;
      for (final k in keys) {
        if (r.containsKey(k) && r[k] != null) return r[k].toString();
      }
    }
    return fallback;
  }

  Widget _buildRetry() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(errorMessage ?? 'Something went wrong'),
          const SizedBox(height: 8),
          ElevatedButton.icon(onPressed: _retry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedule'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final result = await showSearch(context: context, delegate: _ScheduleSearchDelegate(initial: _filter));
              if (result != null) {
                setState(() {
                  _filter = result;
                });
                await _loadPage(reset: true, forceRefresh: true);
              }
            },
          ),
          const DashboardAction(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : (errorMessage != null)
                ? _buildRetry()
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: schedules.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= schedules.length) {
                        // Load more tile
                        if (isLoadingMore) return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
                        return Center(
                          child: ElevatedButton(
                            onPressed: () => _loadPage(),
                            child: const Text('Load more'),
                          ),
                        );
                      }

                      final raw = schedules[index];
                      final Map item = (raw is Map<String, dynamic>) ? raw : Map<String, dynamic>.from(raw as Map);

                      final route = _getField(item, ['route', 'routeName', 'route_title'], 'Route');
                      final start = _getField(item, ['start', 'startTime', 'from'], '-');
                      final end = _getField(item, ['end', 'endTime', 'to'], '-');
                      final status = _getField(item, ['status'], 'Upcoming');
                      final shuttle = _getField(item, ['shuttle', 'shuttleName', 'vehicle'], '-');

                      final routeId = _extractRouteId(item);
                      final expandedStops = routeId != null ? _routeStops[routeId] : null;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(18.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    status.toLowerCase() == 'active' ? Icons.circle : Icons.pause_circle_filled,
                                    color: status.toLowerCase() == 'active' ? Colors.green : Colors.orange,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(route, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                                  const SizedBox(width: 8),
                                  Text(status, style: TextStyle(color: status.toLowerCase() == 'active' ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.access_time, size: 18, color: Colors.blueGrey),
                                  const SizedBox(width: 6),
                                  Text('Start: $start'),
                                  const SizedBox(width: 16),
                                  const Icon(Icons.access_time, size: 18, color: Colors.blueGrey),
                                  const SizedBox(width: 6),
                                  Text('End: $end'),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text('Shuttle: $shuttle'),
                              const SizedBox(height: 12),
                              if (routeId != null)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        TextButton.icon(
                                          onPressed: () => _toggleExpandRoute(routeId),
                                          icon: _loadingStops.contains(routeId) ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.place),
                                          label: Text(expandedStops == null ? 'Show stops' : (expandedStops.isEmpty ? 'No stops' : 'Hide stops')),
                                        ),
                                        const SizedBox(width: 8),
                                        const Spacer(),
                                        TextButton(
                                          onPressed: () {
                                            // navigate to map view for this route if desired
                                          },
                                          child: const Text('View on Map'),
                                        ),
                                      ],
                                    ),
                                    if (expandedStops != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: expandedStops.map<Widget>((s) {
                                            final stopName = (s is Map && s.containsKey('stopName')) ? s['stopName'].toString() : (s is Map && s.containsKey('name') ? s['name'].toString() : s.toString());
                                            return Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.location_on, size: 16, color: Colors.blueGrey),
                                                  const SizedBox(width: 8),
                                                  Expanded(child: Text(stopName)),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                  ],
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

class _ScheduleSearchDelegate extends SearchDelegate<String> {
  final String initial;
  _ScheduleSearchDelegate({this.initial = ''}) : super(searchFieldLabel: 'Filter schedules');

  @override
  String? get searchFieldLabel => 'Filter schedules';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, initial));
  }

  @override
  Widget buildResults(BuildContext context) {
    close(context, query.trim());
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return const SizedBox.shrink();
  }
}

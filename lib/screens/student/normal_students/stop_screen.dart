import 'package:flutter/material.dart';
import '../../../widgets/dashboard_action.dart';
import 'live_tracking_screen.dart';
import '../../../services/APIService.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';

class StopsScreen extends StatefulWidget {
  const StopsScreen({super.key});

  @override
  State<StopsScreen> createState() => _StopsScreenState();
}

class _StopsScreenState extends State<StopsScreen> {
  bool _isLoading = true;
  String? _error;

  List<Map<String, dynamic>> _allStops = [];
  Set<String> _subscribedStops = {};
  Timer? _refreshTimer;
  String _searchQuery = '';
  String _filterType = 'all'; // all, subscribed, unsubscribed

  @override
  void initState() {
    super.initState();
    _initialize();
    // Auto-refresh stops every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadAllStops(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _loadSubscriptions();
    await _loadAllStops();
  }

  Future<void> _loadSubscriptions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userId = auth.userId ?? 'unknown';

      final key = 'subscribed_stops_$userId';
      final List<String>? saved = prefs.getStringList(key);

      setState(() {
        _subscribedStops = saved?.toSet() ?? {};
      });
    } catch (e) {
      debugPrint('Error loading subscriptions: $e');
    }
  }

  Future<void> _saveSubscriptions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userId = auth.userId ?? 'unknown';

      final key = 'subscribed_stops_$userId';
      await prefs.setStringList(key, _subscribedStops.toList());
    } catch (e) {
      debugPrint('Error saving subscriptions: $e');
    }
  }

  Future<void> _loadAllStops({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final routes = await APIService().fetchRoutes();
      final Set<String> uniqueStops = {};
      final List<Map<String, dynamic>> allStopsData = [];

      // Collect all stops from all routes
      for (final route in routes) {
        if (route is Map<String, dynamic>) {
          final routeId = route['id'] ?? route['route_id'] ?? route['routeId'];
          final routeName = (route['name'] ?? route['route_name'] ?? 'Route').toString();

          if (routeId != null) {
            try {
              final stops = await APIService().fetchRouteStops(
                routeId is int ? routeId : int.tryParse(routeId.toString()) ?? 0
              );

              for (final stop in stops) {
                if (stop is Map<String, dynamic>) {
                  final stopName = (stop['name'] ?? stop['stop_name'] ?? stop['title'] ?? '').toString();
                  final eta = (stop['eta'] ?? stop['next_eta'] ?? '—').toString();
                  final stopId = (stop['id'] ?? stop['stop_id'] ?? '').toString();

                  // Only add unique stops
                  if (stopName.isNotEmpty && !uniqueStops.contains(stopName)) {
                    uniqueStops.add(stopName);
                    allStopsData.add({
                      'name': stopName,
                      'route': routeName,
                      'eta': eta,
                      'id': stopId,
                    });
                  }
                }
              }
            } catch (e) {
              debugPrint('Error loading stops for route $routeId: $e');
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _allStops = allStopsData..sort((a, b) => a['name'].compareTo(b['name']));
        });
      }
    } catch (e) {
      if (!silent && mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (!silent && mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleSubscription(String stopName) async {
    setState(() {
      if (_subscribedStops.contains(stopName)) {
        _subscribedStops.remove(stopName);
      } else {
        _subscribedStops.add(stopName);
      }
    });

    await _saveSubscriptions();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _subscribedStops.contains(stopName)
                ? 'Subscribed to $stopName'
                : 'Unsubscribed from $stopName',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Apply search and filter
    final filtered = _allStops.where((stop) {
      // Search filter
      if (_searchQuery.isNotEmpty &&
          !stop['name'].toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }

      // Type filter
      final isSubscribed = _subscribedStops.contains(stop['name']);
      if (_filterType == 'subscribed' && !isSubscribed) return false;
      if (_filterType == 'unsubscribed' && !isSubscribed) return false;

      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Stops'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadAllStops(),
            tooltip: 'Refresh stops',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onSelected: (value) {
              setState(() {
                _filterType = value;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(_filterType == 'all' ? Icons.check : Icons.circle_outlined, size: 20),
                    const SizedBox(width: 8),
                    const Text('All Stops'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'subscribed',
                child: Row(
                  children: [
                    Icon(_filterType == 'subscribed' ? Icons.check : Icons.circle_outlined, size: 20),
                    const SizedBox(width: 8),
                    const Text('Subscribed Only'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'unsubscribed',
                child: Row(
                  children: [
                    Icon(_filterType == 'unsubscribed' ? Icons.check : Icons.circle_outlined, size: 20),
                    const SizedBox(width: 8),
                    const Text('Available'),
                  ],
                ),
              ),
            ],
          ),
          const DashboardAction(),
        ],
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.blue.shade700, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Subscribe to stops you frequent',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Showing ${_allStops.length} stop${_allStops.length != 1 ? 's' : ''} • ${_subscribedStops.length} subscribed',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search stops...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),
          // Stops list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _searchQuery.isNotEmpty ? Icons.search_off : Icons.location_off,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No stops match "$_searchQuery"'
                                  : 'No stops available',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => _loadAllStops(),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => await _loadAllStops(),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final stop = filtered[index];
                            final stopName = stop['name'] as String;
                            final routeName = stop['route'] as String;
                            final eta = stop['eta'] as String;
                            final isSubscribed = _subscribedStops.contains(stopName);
                            final isLast = index == filtered.length - 1;

                            return Card(
                              margin: EdgeInsets.only(bottom: isLast ? 16 : 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: isSubscribed
                                                ? Colors.green.shade100
                                                : Colors.blue.shade100,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            isSubscribed
                                                ? Icons.notifications_active
                                                : Icons.location_on,
                                            color: isSubscribed
                                                ? Colors.green.shade700
                                                : Colors.blue.shade700,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                stopName,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.directions_bus,
                                                    size: 14,
                                                    color: Colors.grey,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      routeName,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.access_time,
                                                    size: 14,
                                                    color: Colors.grey,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'ETA: $eta',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Switch(
                                          value: isSubscribed,
                                          onChanged: (value) => _toggleSubscription(stopName),
                                          activeThumbColor: Colors.green,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => const LiveTrackingScreen(),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.map, size: 18),
                                          label: const Text('View on Map'),
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
          ),
        ],
      ),
      floatingActionButton: _subscribedStops.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showMySubscriptions,
              icon: const Icon(Icons.notifications_active),
              label: Text('My Stops (${_subscribedStops.length})'),
            )
          : null,
    );
  }

  void _showMySubscriptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Colors.blue),
            SizedBox(width: 8),
            Text('My Subscribed Stops'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _subscribedStops.isEmpty
              ? const Center(child: Text('No subscribed stops'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _subscribedStops.length,
                  itemBuilder: (context, index) {
                    final stopName = _subscribedStops.elementAt(index);
                    return ListTile(
                      leading: const Icon(Icons.location_on, color: Colors.green),
                      title: Text(stopName),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () {
                          _toggleSubscription(stopName);
                          if (_subscribedStops.isEmpty) {
                            Navigator.pop(context);
                          } else {
                            // Rebuild dialog
                            Navigator.pop(context);
                            _showMySubscriptions();
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (_subscribedStops.isNotEmpty)
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Unsubscribe from All?'),
                    content: const Text(
                      'Are you sure you want to unsubscribe from all stops?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _subscribedStops.clear();
                          });
                          _saveSubscriptions();
                          Navigator.pop(context); // Close confirmation
                          Navigator.pop(context); // Close manage dialog
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Unsubscribed from all stops'),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Unsubscribe All'),
                      ),
                    ],
                  ),
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Unsubscribe All'),
            ),
        ],
      ),
    );
  }
}


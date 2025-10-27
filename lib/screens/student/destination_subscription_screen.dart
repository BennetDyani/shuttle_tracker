import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/APIService.dart';
import '../../providers/auth_provider.dart';
import '../../models/User.dart';

/// Screen for students to subscribe to specific destinations.
/// They'll get notifications when shuttles are heading to their subscribed destinations.
class DestinationSubscriptionScreen extends StatefulWidget {
  const DestinationSubscriptionScreen({super.key});

  @override
  State<DestinationSubscriptionScreen> createState() => _DestinationSubscriptionScreenState();
}

class _DestinationSubscriptionScreenState extends State<DestinationSubscriptionScreen> {
  final APIService _apiService = APIService();

  bool _isLoadingUser = true;
  bool _isDisabledStudent = false;
  bool _isLoadingDestinations = true;

  List<String> _availableDestinations = [];
  Set<String> _subscribedDestinations = {};
  String _searchQuery = '';
  String _filterType = 'all'; // all, subscribed, unsubscribed

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadUserInfo();
    await _loadDestinations();
    await _loadSubscriptions();
  }

  Future<void> _loadUserInfo() async {
    setState(() => _isLoadingUser = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uidStr = auth.userId;
      if (uidStr == null || uidStr.isEmpty) throw Exception('Not logged in');
      final uid = int.tryParse(uidStr);
      if (uid == null) throw Exception('Invalid user id');

      final userMap = await _apiService.fetchUserById(uid);
      final user = User.fromJson(userMap);

      setState(() {
        _isDisabledStudent = user.disability;
      });
    } catch (e) {
      debugPrint('Error loading user info: $e');
      setState(() => _isDisabledStudent = false);
    } finally {
      setState(() => _isLoadingUser = false);
    }
  }

  Future<void> _loadDestinations() async {
    setState(() => _isLoadingDestinations = true);
    try {
      final routes = await _apiService.fetchRoutes();

      // Extract unique destinations from routes
      final Set<String> destinations = {};
      for (var route in routes) {
        final destination = route['destination']?.toString() ??
                          route['end']?.toString() ??
                          route['to']?.toString();
        if (destination != null && destination.isNotEmpty) {
          destinations.add(destination);
        }

        final origin = route['origin']?.toString() ??
                      route['start']?.toString() ??
                      route['from']?.toString();
        if (origin != null && origin.isNotEmpty) {
          destinations.add(origin);
        }
      }

      setState(() {
        _availableDestinations = destinations.toList()..sort();
      });
    } catch (e) {
      debugPrint('Error loading destinations: $e');
      setState(() => _availableDestinations = []);
    } finally {
      setState(() => _isLoadingDestinations = false);
    }
  }

  Future<void> _loadSubscriptions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userId = auth.userId ?? 'unknown';

      final key = 'subscribed_destinations_$userId';
      final List<String>? saved = prefs.getStringList(key);

      setState(() {
        _subscribedDestinations = saved?.toSet() ?? {};
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

      final key = 'subscribed_destinations_$userId';
      await prefs.setStringList(key, _subscribedDestinations.toList());
    } catch (e) {
      debugPrint('Error saving subscriptions: $e');
    }
  }

  Future<void> _toggleSubscription(String destination) async {
    setState(() {
      if (_subscribedDestinations.contains(destination)) {
        _subscribedDestinations.remove(destination);
      } else {
        _subscribedDestinations.add(destination);
      }
    });

    await _saveSubscriptions();

    // Show feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _subscribedDestinations.contains(destination)
                ? 'Subscribed to $destination'
                : 'Unsubscribed from $destination',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser || _isLoadingDestinations) {
      return Scaffold(
        appBar: AppBar(title: const Text('Destination Subscriptions')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriptions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initialize,
            tooltip: 'Refresh',
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
                    const Text('All Destinations'),
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
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.notifications_active,
                      color: Colors.blue.shade700,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Get notified when ${_isDisabledStudent ? 'minibuses' : 'buses'} head to your destinations',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Subscribed to ${_subscribedDestinations.length} of ${_availableDestinations.length} destination${_availableDestinations.length != 1 ? 's' : ''}',
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
                hintText: 'Search destinations...',
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
          Expanded(
            child: _availableDestinations.isEmpty
                ? _buildEmptyView()
                : _buildDestinationsList(),
          ),
        ],
      ),
      floatingActionButton: _subscribedDestinations.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showManageSubscriptionsDialog,
              icon: const Icon(Icons.manage_accounts),
              label: Text('Manage (${_subscribedDestinations.length})'),
            )
          : null,
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No destinations available',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initialize,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationsList() {
    // Apply search and filter
    final filtered = _availableDestinations.where((destination) {
      // Search filter
      if (_searchQuery.isNotEmpty &&
          !destination.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }

      // Type filter
      final isSubscribed = _subscribedDestinations.contains(destination);
      if (_filterType == 'subscribed' && !isSubscribed) return false;
      if (_filterType == 'unsubscribed' && isSubscribed) return false;

      return true;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No destinations match "$_searchQuery"'
                  : 'No destinations in this filter',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final destination = filtered[index];
        final isSubscribed = _subscribedDestinations.contains(destination);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSubscribed ? Colors.green.shade100 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isSubscribed ? Icons.notifications_active : Icons.location_on,
                color: isSubscribed ? Colors.green.shade700 : Colors.grey.shade600,
                size: 24,
              ),
            ),
            title: Text(
              destination,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(
                    isSubscribed ? Icons.check_circle : Icons.circle_outlined,
                    size: 14,
                    color: isSubscribed ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      isSubscribed
                          ? 'Receiving notifications'
                          : 'Tap to subscribe',
                      style: TextStyle(
                        fontSize: 12,
                        color: isSubscribed ? Colors.green : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            trailing: Switch(
              value: isSubscribed,
              onChanged: (value) => _toggleSubscription(destination),
              activeThumbColor: Colors.green,
            ),
            onTap: () => _toggleSubscription(destination),
          ),
        );
      },
    );
  }

  void _showManageSubscriptionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.blue),
            SizedBox(width: 8),
            Text('My Subscriptions'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _subscribedDestinations.isEmpty
              ? const Center(
                  child: Text('No active subscriptions'),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _subscribedDestinations.length,
                  itemBuilder: (context, index) {
                    final destination = _subscribedDestinations.elementAt(index);
                    return ListTile(
                      leading: const Icon(Icons.location_on, color: Colors.green),
                      title: Text(destination),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () {
                          _toggleSubscription(destination);
                          if (_subscribedDestinations.isEmpty) {
                            Navigator.pop(context);
                          } else {
                            // Rebuild dialog
                            Navigator.pop(context);
                            _showManageSubscriptionsDialog();
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
          if (_subscribedDestinations.isNotEmpty)
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Unsubscribe from All?'),
                    content: const Text(
                      'Are you sure you want to unsubscribe from all destinations?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _subscribedDestinations.clear();
                          });
                          _saveSubscriptions();
                          Navigator.pop(context); // Close confirmation
                          Navigator.pop(context); // Close manage dialog
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Unsubscribed from all destinations'),
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


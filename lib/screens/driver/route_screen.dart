import 'package:flutter/material.dart';
import '../../services/shuttle_service.dart';
import '../../models/driver_model/Route.dart' as driver_model;
import '../../models/driver_model/Stop.dart';
import 'live_route_tracking.dart';

class DriverRouteScreen extends StatefulWidget {
  const DriverRouteScreen({super.key});

  @override
  State<DriverRouteScreen> createState() => _DriverRouteScreenState();
}

class _DriverRouteScreenState extends State<DriverRouteScreen> {
  final ShuttleService _service = ShuttleService();
  List<driver_model.Route> routes = [];
  driver_model.Route? selectedRoute;
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
      final fetchedRoutes = await _service.getRoutes();
      if (fetchedRoutes.isEmpty) {
        setState(() {
          errorMessage = 'No routes available. Please contact admin.';
          isLoading = false;
        });
        return;
      }

      // Parse routes from the response
      final parsedRoutes = <driver_model.Route>[];
      for (final routeMap in fetchedRoutes) {
        try {
          // Create a route with safe parsing
          final routeId = routeMap['route_id'] ?? routeMap['routeId'] ?? routeMap['id'] ?? 0;
          final origin = routeMap['origin'] ?? routeMap['start'] ?? 'Unknown Origin';
          final destination = routeMap['destination'] ?? routeMap['end'] ?? 'Unknown Destination';

          // Parse stops if available
          final stopsList = <Stop>[];
          if (routeMap['stops'] != null && routeMap['stops'] is List) {
            for (final stopData in routeMap['stops']) {
              try {
                stopsList.add(Stop.fromJson(stopData));
              } catch (e) {
                // Skip invalid stops
                debugPrint('Error parsing stop: $e');
              }
            }
          }

          parsedRoutes.add(driver_model.Route(
            routeId: routeId is int ? routeId : int.tryParse(routeId.toString()) ?? 0,
            origin: origin.toString(),
            destination: destination.toString(),
            stops: stopsList,
          ));
        } catch (e) {
          debugPrint('Error parsing route: $e');
        }
      }

      setState(() {
        routes = parsedRoutes;
        selectedRoute = parsedRoutes.isNotEmpty ? parsedRoutes.first : null;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load routes: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Routes'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRoutes,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchRoutes,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : routes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.route_outlined, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'No routes assigned',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Contact your administrator to assign routes',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Route Selector Dropdown
                          if (routes.length > 1)
                            Card(
                              elevation: 1,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                child: DropdownButton<driver_model.Route>(
                                  isExpanded: true,
                                  value: selectedRoute,
                                  hint: const Text('Select a route'),
                                  items: routes.map((route) {
                                    return DropdownMenuItem(
                                      value: route,
                                      child: Text('${route.origin} → ${route.destination}'),
                                    );
                                  }).toList(),
                                  onChanged: (route) {
                                    setState(() {
                                      selectedRoute = route;
                                    });
                                  },
                                ),
                              ),
                            ),
                          if (routes.length > 1) const SizedBox(height: 16),

                          // Active Route Card
                          if (selectedRoute != null) ...[
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${selectedRoute!.origin} – ${selectedRoute!.destination}',
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on, size: 18, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${selectedRoute!.stops.length} Stops',
                                          style: const TextStyle(color: Colors.grey, fontSize: 16),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => const LiveRouteTrackingScreen(),
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        icon: const Icon(Icons.map),
                                        label: const Text('View on Map'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Route Details Section
                            Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(18.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        Icon(Icons.route, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Route Stops',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    if (selectedRoute!.stops.isNotEmpty)
                                      ...selectedRoute!.stops.asMap().entries.map((entry) {
                                        final index = entry.key;
                                        final stop = entry.value;
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 28,
                                                height: 28,
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade100,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    '${index + 1}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.blue.shade700,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  stop.stopName,
                                                  style: const TextStyle(fontSize: 15),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      })
                                    else
                                      const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Text(
                                          'No stops configured for this route.',
                                          style: TextStyle(color: Colors.grey, fontSize: 14),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
    );
  }
}
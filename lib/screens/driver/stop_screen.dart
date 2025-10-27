import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/auth_provider.dart';
import '../../services/APIService.dart';
import '../../services/shuttle_service.dart';
import '../../models/driver_model/Stop.dart';

class StopScreen extends StatefulWidget {
  const StopScreen({super.key});

  @override
  State<StopScreen> createState() => _StopScreenState();
}

class _StopScreenState extends State<StopScreen> {
  final ShuttleService _shuttleService = ShuttleService();

  bool isLoading = true;
  String? errorMessage;

  Map<String, dynamic>? driverAssignment;
  Map<String, dynamic>? routeDetails;
  List<Stop> stops = [];
  List<Stop> selectedStops = [];
  int? driverId;
  int? routeId;

  @override
  void initState() {
    super.initState();
    _loadDriverRoute();
  }

  Future<void> _loadDriverRoute() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // 1. Get current user's driver ID
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uidStr = auth.userId;
      if (uidStr == null || uidStr.isEmpty) {
        throw Exception('Not logged in');
      }
      final uid = int.tryParse(uidStr);
      if (uid == null) throw Exception('Invalid user id');

      final user = await APIService().fetchUserById(uid);
      final email = (user['email'] ?? '') as String;
      if (email.isEmpty) {
        throw Exception('No email available for the current user.');
      }

      // 2. Get driver record
      final fetchedDriver = await APIService().fetchDriverByEmail(email);
      driverId = fetchedDriver['driver_id'] ?? fetchedDriver['driverId'] ?? fetchedDriver['id'];

      if (driverId == null) {
        throw Exception('Driver ID not found');
      }

      // 3. Get driver's assignment to find the route
      final assignments = await _shuttleService.getDriverAssignments();
      Map<String, dynamic>? matched;
      for (final Map<String, dynamic> a in assignments) {
        final aid = (a['driverId'] ?? a['driver_id'] ?? a['driver'])?.toString() ?? '';
        if (aid.isEmpty) continue;
        if (int.tryParse(aid) == driverId || aid == driverId.toString()) {
          matched = a;
          break;
        }
      }

      if (matched == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'No route assigned to you yet. Please contact the administrator.';
        });
        return;
      }

      driverAssignment = matched;

      // 4. Get schedule to find route
      final scheduleId = (matched['scheduleId'] ?? matched['schedule_id'] ?? matched['schedule'])?.toString();
      if (scheduleId != null && scheduleId.isNotEmpty) {
        final schedules = await _shuttleService.getSchedules();
        for (final s in schedules) {
          final sid = (s['schedule_id'] ?? s['scheduleId'] ?? s['id'])?.toString();
          if (sid == scheduleId) {
            final routeIdRaw = (s['route_id'] ?? s['routeId'] ?? s['route'])?.toString();
            if (routeIdRaw != null && routeIdRaw.isNotEmpty) {
              routeId = int.tryParse(routeIdRaw);

              // 5. Get route details
              final routes = await _shuttleService.getRoutes();
              for (final r in routes) {
                final rid = (r['route_id'] ?? r['routeId'] ?? r['id'])?.toString();
                if (rid == routeIdRaw) {
                  routeDetails = r;
                  break;
                }
              }

              // 6. Get existing stops for this route
              if (routeId != null) {
                final stopsData = await _shuttleService.getStopsByRoute(routeId!);
                stops = stopsData.map((s) => Stop.fromJson(s)).toList();
              }
              break;
            }
          }
        }
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  String _getRouteName() {
    if (routeDetails != null) {
      return (routeDetails!['name'] ??
              routeDetails!['routeName'] ??
              routeDetails!['route_name'] ??
              'Unknown Route').toString();
    }
    return 'Unknown Route';
  }

  String _getRouteDescription() {
    if (routeDetails != null) {
      return (routeDetails!['description'] ??
              routeDetails!['route_description'] ??
              'No description available').toString();
    }
    return 'No description available';
  }

  Future<void> _addStopDialog() async {
    final nameController = TextEditingController();
    bool useCurrentLocation = false;
    bool useMapSelection = true;
    double? latitude;
    double? longitude;
    bool fetchingLocation = false;

    // Default to Cape Town, South Africa coordinates
    LatLng selectedLocation = const LatLng(-33.9249, 18.4241); // Cape Town city center
    final MapController mapController = MapController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Update coordinates when location is selected
          if (useMapSelection) {
            latitude = selectedLocation.latitude;
            longitude = selectedLocation.longitude;
          }

          return AlertDialog(
            title: const Text('Add Stop'),
            content: SizedBox(
              width: double.maxFinite,
              height: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Stop Name',
                        hintText: 'e.g., Main Campus Gate',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Location method selection
                    const Text(
                      'Select Location Method:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),

                    RadioListTile<String>(
                      title: const Text('Tap on Map'),
                      subtitle: const Text('Select location by tapping the map'),
                      value: 'map',
                      groupValue: useMapSelection ? 'map' : (useCurrentLocation ? 'gps' : 'manual'),
                      onChanged: (value) {
                        setDialogState(() {
                          useMapSelection = true;
                          useCurrentLocation = false;
                        });
                      },
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),

                    RadioListTile<String>(
                      title: const Text('Use Current GPS Location'),
                      subtitle: const Text('Use your current position'),
                      value: 'gps',
                      groupValue: useMapSelection ? 'map' : (useCurrentLocation ? 'gps' : 'manual'),
                      onChanged: (value) {
                        setDialogState(() {
                          useMapSelection = false;
                          useCurrentLocation = true;
                        });
                      },
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),

                    RadioListTile<String>(
                      title: const Text('Enter Coordinates Manually'),
                      subtitle: const Text('Type latitude and longitude'),
                      value: 'manual',
                      groupValue: useMapSelection ? 'map' : (useCurrentLocation ? 'gps' : 'manual'),
                      onChanged: (value) {
                        setDialogState(() {
                          useMapSelection = false;
                          useCurrentLocation = false;
                        });
                      },
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),

                    const SizedBox(height: 16),

                    // Show map if map selection is active
                    if (useMapSelection) ...[
                      const Text(
                        'Tap on the map to select stop location:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 300,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: FlutterMap(
                            mapController: mapController,
                            options: MapOptions(
                              initialCenter: selectedLocation,
                              initialZoom: 13.0,
                              onTap: (tapPosition, point) {
                                setDialogState(() {
                                  selectedLocation = point;
                                  latitude = point.latitude;
                                  longitude = point.longitude;
                                });
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.shuttle_tracker',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: selectedLocation,
                                    width: 40,
                                    height: 40,
                                    child: const Icon(
                                      Icons.location_pin,
                                      size: 40,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info, size: 16, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Selected: ${selectedLocation.latitude.toStringAsFixed(6)}, ${selectedLocation.longitude.toStringAsFixed(6)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Show GPS loading if GPS is selected
                    if (useCurrentLocation && fetchingLocation) ...[
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Getting location...'),
                        ],
                      ),
                    ],

                    if (useCurrentLocation && latitude != null && longitude != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Location: ${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],

                    // Show manual input fields if manual is selected
                    if (!useMapSelection && !useCurrentLocation) ...[
                      const SizedBox(height: 16),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          hintText: 'e.g., -33.9249',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        onChanged: (value) {
                          latitude = double.tryParse(value);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          hintText: 'e.g., 18.4241',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        onChanged: (value) {
                          longitude = double.tryParse(value);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a stop name')),
                    );
                    return;
                  }

                  if (useCurrentLocation && !fetchingLocation) {
                    setDialogState(() => fetchingLocation = true);
                    try {
                      // Check location permission
                      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                      if (!serviceEnabled) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Location services are disabled')),
                          );
                        }
                        setDialogState(() => fetchingLocation = false);
                        return;
                      }

                      LocationPermission permission = await Geolocator.checkPermission();
                      if (permission == LocationPermission.denied) {
                        permission = await Geolocator.requestPermission();
                        if (permission == LocationPermission.denied) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Location permission denied')),
                            );
                          }
                          setDialogState(() => fetchingLocation = false);
                          return;
                        }
                      }

                      if (permission == LocationPermission.deniedForever) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Location permission permanently denied')),
                          );
                        }
                        setDialogState(() => fetchingLocation = false);
                        return;
                      }

                      // Get current position
                      Position position = await Geolocator.getCurrentPosition(
                        desiredAccuracy: LocationAccuracy.high,
                      );

                      latitude = position.latitude;
                      longitude = position.longitude;
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to get location: $e')),
                        );
                      }
                      setDialogState(() => fetchingLocation = false);
                      return;
                    }
                    setDialogState(() => fetchingLocation = false);
                  }

                  if (latitude == null || longitude == null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please provide valid coordinates')),
                      );
                    }
                    return;
                  }

                  // Add the stop
                  if (context.mounted) {
                    Navigator.pop(context);
                    await _addStop(
                      nameController.text.trim(),
                      latitude!,
                      longitude!,
                    );
                  }
                },
                child: const Text('Add Stop'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addStop(String name, double latitude, double longitude) async {
    if (routeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No route assigned')),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      await _shuttleService.addStopToRoute(
        routeId: routeId!,
        name: name,
        latitude: latitude,
        longitude: longitude,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stop "$name" added successfully')),
        );
        await _loadDriverRoute(); // Refresh the stops
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add stop: $e')),
        );
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Stops'),
        elevation: 0,
        actions: [
          if (!isLoading && routeId != null)
            IconButton(
              icon: const Icon(Icons.add_location),
              onPressed: _addStopDialog,
              tooltip: 'Add Stop',
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadDriverRoute,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDriverRoute,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Route Info Card
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.route,
                                      color: Theme.of(context).primaryColor,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _getRouteName(),
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                Text(
                                  'Description:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _getRouteDescription(),
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Stops Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Stops on This Route',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${stops.length} stop${stops.length != 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (stops.isEmpty)
                          Card(
                            elevation: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.location_searching,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No stops added yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Based on the route description, you can add stops by tapping the + button above',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...stops.asMap().entries.map((entry) {
                            final index = entry.key;
                            final stop = entry.value;
                            return Card(
                              elevation: 1,
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  stop.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Text(
                                  'Lat: ${stop.latitude.toStringAsFixed(6)}, '
                                  'Long: ${stop.longitude.toStringAsFixed(6)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.location_on,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            );
                          }),

                        const SizedBox(height: 16),

                        // Info Card
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue[700]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Add stops based on your route description. You can add main stops or shared stops as needed.',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}


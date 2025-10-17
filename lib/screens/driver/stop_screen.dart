import 'package:flutter/material.dart';

import 'live_route_tracking.dart';
import '../../services/APIService.dart';
import '../../services/endpoints.dart';

class DriverStopsScreen extends StatefulWidget {
  const DriverStopsScreen({super.key});

  @override
  State<DriverStopsScreen> createState() => _DriverStopsScreenState();
}

class _DriverStopsScreenState extends State<DriverStopsScreen> {
  List<dynamic> stops = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchStops();
  }

  Future<void> _fetchStops() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      // Replace with actual route ID
      final stopsData = await APIService().get(Endpoints.routeStopsReadByRouteId(1));
      setState(() {
        stops = stopsData;
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
        title: const Text('Stops for Route A'),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text('Error: ' + errorMessage!))
              : ListView.separated(
                  padding: const EdgeInsets.all(20.0),
                  itemCount: stops.length,
                  separatorBuilder: (context, index) => const Divider(height: 32, thickness: 1),
                  itemBuilder: (context, index) {
                    final stop = stops[index];
                    final isLast = index == stops.length - 1;
                    return Card(
                      color: isLast ? Colors.blue[50] : null,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isLast ? Colors.blue : Colors.grey[300],
                                  child: Text(
                                    stop['sequence'].toString(),
                                    style: TextStyle(
                                      color: isLast ? Colors.white : Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  stop['name'],
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const Spacer(),
                                Text(stop['eta'], style: const TextStyle(color: Colors.blueGrey)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LiveRouteTrackingScreen()),
          );
        },
        icon: const Icon(Icons.map),
        label: const Text('View on Map'),
      ),
    );
  }
}

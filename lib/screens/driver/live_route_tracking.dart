import 'package:flutter/material.dart';

class LiveRouteTrackingScreen extends StatefulWidget {
  const LiveRouteTrackingScreen({super.key});

  @override
  State<LiveRouteTrackingScreen> createState() => _LiveRouteTrackingScreenState();
}

class _LiveRouteTrackingScreenState extends State<LiveRouteTrackingScreen> {
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Route Tracking'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 600;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Text(
                              _error!,
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                            ),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Live Route Tracking - Coming Soon'),
                              // TODO: Implement live route tracking functionality
                            ],
                          ),
              ),
            ),
          );
        },
      ),
    );
  }
}

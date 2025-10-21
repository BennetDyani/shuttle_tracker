import 'package:flutter/material.dart';
import '../widgets/hardcoded_destinations.dart';

/// Simple screen that receives a [Destination] via Navigator arguments.
/// This is a small helper so the `HardcodedDestinations` widget can navigate
/// to a real route during testing/demo.
class AdminSelectRouteScreen extends StatelessWidget {
  static const routeName = '/admin/select_route';
  const AdminSelectRouteScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    Destination? dest;
    if (args is Destination) dest = args;

    return Scaffold(
      appBar: AppBar(title: Text('Select route')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Destination', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dest?.name ?? 'No destination selected', style: Theme.of(context).textTheme.titleLarge),
                    if (dest?.description != null) ...[
                      const SizedBox(height: 8),
                      Text(dest!.description!),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: dest == null ? null : () {
                // Placeholder action: navigate back with selection summary
                Navigator.of(context).pop({'destinationId': dest!.id});
              },
              child: const Text('Create schedule for this destination'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

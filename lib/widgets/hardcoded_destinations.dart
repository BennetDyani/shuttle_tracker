import 'package:flutter/material.dart';

/// A small immutable model for a destination preset.
class Destination {
  final String id;
  final String name;
  final String? description;

  const Destination({
    required this.id,
    required this.name,
    this.description,
  });

  @override
  String toString() => 'Destination(id: $id, name: $name)';
}

/// A grid of hardcoded destination buttons admins can tap to start creating a schedule.
///
/// Usage:
/// - Place inside any screen and provide an optional [onDestinationSelected]
///   callback to handle selection. If that callback is omitted, the widget will
///   navigate to `/admin/select_route` and pass the selected [Destination]
///   via `Navigator.pushNamed(..., arguments: destination)`.
class HardcodedDestinations extends StatelessWidget {
  final List<Destination>? destinations;
  final void Function(Destination)? onDestinationSelected;
  final int crossAxisCount;
  final double spacing;

  const HardcodedDestinations({
    Key? key,
    this.destinations,
    this.onDestinationSelected,
    this.crossAxisCount = 2,
    this.spacing = 8.0,
  }) : super(key: key);

  static const List<Destination> _defaultDestinations = [
    Destination(id: 'd1', name: 'Central Station'),
    Destination(id: 'd2', name: 'North Campus'),
    Destination(id: 'd3', name: 'South Campus'),
    Destination(id: 'd4', name: 'Airport'),
    Destination(id: 'd5', name: 'Main Library'),
    Destination(id: 'd6', name: 'Sports Complex'),
    Destination(id: 'd7', name: 'Student Center'),
    Destination(id: 'd8', name: 'East Gate'),
    Destination(id: 'd9', name: 'West Gate'),
    Destination(id: 'd10', name: 'Medical Center'),
  ];

  void _handleSelection(BuildContext context, Destination dest) {
    if (onDestinationSelected != null) {
      onDestinationSelected!(dest);
      return;
    }
    Navigator.pushNamed(context, '/admin/select_route', arguments: dest);
  }

  @override
  Widget build(BuildContext context) {
    final list = destinations ?? _defaultDestinations;
    return Padding(
      padding: EdgeInsets.all(spacing),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: 3,
        children: list.map((d) {
          return ElevatedButton(
            onPressed: () => _handleSelection(context, d),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Icon(Icons.place),
                const SizedBox(width: 8),
                Expanded(child: Text(d.name, overflow: TextOverflow.ellipsis)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}


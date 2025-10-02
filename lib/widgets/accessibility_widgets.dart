import 'package:flutter/material.dart';

// 1. Accessibility Status Display
class AccessibilityStatusCard extends StatelessWidget {
  final bool hasRamp;
  final bool hasPrioritySeating;
  final bool hasWheelchairSpace;
  final bool isLowFloor;

  const AccessibilityStatusCard({
    Key? key,
    required this.hasRamp,
    required this.hasPrioritySeating,
    required this.hasWheelchairSpace,
    required this.isLowFloor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🦽 Current Accessibility Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildStatusRow('Ramp Available', hasRamp),
            _buildStatusRow('Priority Seating', hasPrioritySeating),
            _buildStatusRow('Wheelchair Space', hasWheelchairSpace),
            _buildStatusRow('Low Floor', isLowFloor),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String text, bool available) {
    return Row(
      children: [
        Icon(
          available ? Icons.check_circle : Icons.error,
          color: available ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 8),
        Text(text),
        const Spacer(),
        Text(
          available ? 'Available' : 'Not Available',
          style: TextStyle(
            color: available ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// 2. Special Assistance Requests
class EmergencyAssistancePanel extends StatelessWidget {
  final bool canRequestRamp;
  final bool canRequestPriorityBoarding;
  final bool canRequestExtraTime;
  final bool canRequestStaffAssistance;
  final Function(String)? onRequestAssistance;

  const EmergencyAssistancePanel({
    Key? key,
    required this.canRequestRamp,
    required this.canRequestPriorityBoarding,
    required this.canRequestExtraTime,
    required this.canRequestStaffAssistance,
    this.onRequestAssistance,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🆘 Quick Assistance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canRequestRamp)
                  _buildAssistanceButton('Ramp Assistance', Icons.ramp_right),
                if (canRequestPriorityBoarding)
                  _buildAssistanceButton('Priority Boarding', Icons.accessible_forward),
                if (canRequestExtraTime)
                  _buildAssistanceButton('Extra Time', Icons.timer),
                if (canRequestStaffAssistance)
                  _buildAssistanceButton('Staff Help', Icons.support_agent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssistanceButton(String text, IconData icon) {
    return ElevatedButton.icon(
      icon: Icon(icon),
      label: Text(text),
      onPressed: () => onRequestAssistance?.call(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue[800],
      ),
    );
  }
}

// 3. Personalized Shuttle Preferences
class PreferredShuttleSettings extends StatefulWidget {
  final bool requiresRamp;
  final bool requiresPrioritySeating;
  final bool requiresLowFloor;
  final bool requiresExtraSpace;
  final Function(bool, bool, bool, bool)? onPreferencesChanged;

  const PreferredShuttleSettings({
    Key? key,
    required this.requiresRamp,
    required this.requiresPrioritySeating,
    required this.requiresLowFloor,
    required this.requiresExtraSpace,
    this.onPreferencesChanged,
  }) : super(key: key);

  @override
  _PreferredShuttleSettingsState createState() => _PreferredShuttleSettingsState();
}

class _PreferredShuttleSettingsState extends State<PreferredShuttleSettings> {
  late bool _requiresRamp;
  late bool _requiresPriority;
  late bool _requiresLowFloor;
  late bool _requiresExtraSpace;

  @override
  void initState() {
    super.initState();
    _requiresRamp = widget.requiresRamp;
    _requiresPriority = widget.requiresPrioritySeating;
    _requiresLowFloor = widget.requiresLowFloor;
    _requiresExtraSpace = widget.requiresExtraSpace;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⭐ My Preferences',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Require Ramp Access'),
              value: _requiresRamp,
              onChanged: (value) => setState(() {
                _requiresRamp = value;
                widget.onPreferencesChanged?.call(_requiresRamp, _requiresPriority, _requiresLowFloor, _requiresExtraSpace);
              }),
            ),
            SwitchListTile(
              title: const Text('Priority Seating'),
              value: _requiresPriority,
              onChanged: (value) => setState(() {
                _requiresPriority = value;
                widget.onPreferencesChanged?.call(_requiresRamp, _requiresPriority, _requiresLowFloor, _requiresExtraSpace);
              }),
            ),
            SwitchListTile(
              title: const Text('Low Floor Shuttle'),
              value: _requiresLowFloor,
              onChanged: (value) => setState(() {
                _requiresLowFloor = value;
                widget.onPreferencesChanged?.call(_requiresRamp, _requiresPriority, _requiresLowFloor, _requiresExtraSpace);
              }),
            ),
            SwitchListTile(
              title: const Text('Extra Space Required'),
              value: _requiresExtraSpace,
              onChanged: (value) => setState(() {
                _requiresExtraSpace = value;
                widget.onPreferencesChanged?.call(_requiresRamp, _requiresPriority, _requiresLowFloor, _requiresExtraSpace);
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// 4. Accessible Route Information
class AccessibleRouteMap extends StatelessWidget {
  final bool showsElevators;
  final bool showsRamps;
  final bool showsAccessiblePaths;
  final bool showsBarrierFreeRoutes;

  const AccessibleRouteMap({
    Key? key,
    required this.showsElevators,
    required this.showsRamps,
    required this.showsAccessiblePaths,
    required this.showsBarrierFreeRoutes,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🗺️ Accessible Routes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.map, size: 50, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text('Elevators: ${showsElevators ? 'ON' : 'OFF'}'),
                  backgroundColor: showsElevators ? Colors.green[100] : Colors.grey[300],
                ),
                Chip(
                  label: Text('Ramps: ${showsRamps ? 'ON' : 'OFF'}'),
                  backgroundColor: showsRamps ? Colors.green[100] : Colors.grey[300],
                ),
                Chip(
                  label: Text('Accessible Paths: ${showsAccessiblePaths ? 'ON' : 'OFF'}'),
                  backgroundColor: showsAccessiblePaths ? Colors.green[100] : Colors.grey[300],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
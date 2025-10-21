import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// A small AppBar action that navigates to the appropriate student dashboard.
///
/// Usage:
/// - Place inside `actions` of an AppBar:
///   actions: [ DashboardAction(), ]
///
/// Optional: provide [hasUnsavedChanges] to show a confirmation dialog before
/// navigating away. The callback may be synchronous or return a Future<bool>.
class DashboardAction extends StatelessWidget {
  final Future<bool> Function()? hasUnsavedChanges;
  final String tooltip;

  const DashboardAction({Key? key, this.hasUnsavedChanges, this.tooltip = 'Dashboard'}) : super(key: key);

  Future<bool> _confirmDiscard(BuildContext context) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave page?'),
        content: const Text('You have unsaved changes. Do you want to discard them and go to the dashboard?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Discard')),
        ],
      ),
    );
    return res == true;
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: const Icon(Icons.home),
      onPressed: () async {
        // If caller provided a check for unsaved changes, call it
        if (hasUnsavedChanges != null) {
          try {
            final result = await hasUnsavedChanges!();
            if (result == true) {
              // there are unsaved changes; confirm
              final ok = await _confirmDiscard(context);
              if (!ok) return;
            }
          } catch (e) {
            // If the check threw, be conservative and ask the user
            final ok = await _confirmDiscard(context);
            if (!ok) return;
          }
        }

        final role = Provider.of<AuthProvider>(context, listen: false).role?.toUpperCase();
        final route = (role == 'DISABLED_STUDENT') ? '/student/disabled/dashboard' : '/student/dashboard';
        Navigator.pushReplacementNamed(context, route);
      },
    );
  }
}


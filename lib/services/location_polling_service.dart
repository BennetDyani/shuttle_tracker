// filepath: c:\Kotlin\shuttle_tracker1\lib\services\location_polling_service.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shuttle_tracker/services/APIService.dart';
import 'package:shuttle_tracker/models/driver_model/LocationMessage.dart';

/// Simple polling service that periodically fetches recent location messages
/// and notifies subscribers. This is intended as a WS fallback for student
/// clients when the websocket/STOMP connection is unavailable.
class LocationPollingService {
  static final LocationPollingService _instance = LocationPollingService._internal();
  factory LocationPollingService() => _instance;
  LocationPollingService._internal();

  /// Subscribe to periodic fetches. Returns a cancel function to stop polling.
  /// Optional [shuttleId] / [driverId] narrow the server query.
  /// The callback is invoked for each new LocationMessage not seen before.
  void Function() subscribe({
    required void Function(LocationMessage msg) onMessage,
    Duration interval = const Duration(seconds: 5),
    int? shuttleId,
    int? driverId,
  }) {
    final seen = <String>{};
    Timer? timer;
    final fetchNow = () async {
      try {
        final list = await APIService().fetchRecentLocationMessages(limit: 20, shuttleId: shuttleId, driverId: driverId);
        // Sort ascending by timestamp so we deliver older first
        list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        for (final m in list) {
          final key = '${m.driverId ?? ''}-${m.shuttleId ?? ''}-${m.timestamp.toIso8601String()}';
          if (!seen.contains(key)) {
            seen.add(key);
            try {
              onMessage(m);
            } catch (_) {}
          }
        }
      } catch (_) {
        // ignore network errors silently; caller UI can show status if desired
      }
    };

    // Fire immediately, then start periodic timer
    fetchNow();
    timer = Timer.periodic(interval, (_) => fetchNow());

    return () {
      try {
        timer?.cancel();
      } catch (_) {}
      seen.clear();
    };
  }
}

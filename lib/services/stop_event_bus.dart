import 'dart:async';

// Simple event bus for stop create/update/delete events so different screens can react.
class StopEventBus {
  static final StopEventBus _instance = StopEventBus._internal();
  factory StopEventBus() => _instance;
  StopEventBus._internal();

  final StreamController<Map<String, dynamic>> _createdController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _updatedController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<dynamic> _deletedController = StreamController<dynamic>.broadcast();

  Stream<Map<String, dynamic>> get onCreated => _createdController.stream;
  Stream<Map<String, dynamic>> get onUpdated => _updatedController.stream;
  Stream<dynamic> get onDeleted => _deletedController.stream;

  void emitCreated(Map<String, dynamic> payload) => _createdController.add(payload);
  void emitUpdated(Map<String, dynamic> payload) => _updatedController.add(payload);
  void emitDeleted(dynamic id) => _deletedController.add(id);

  void dispose() {
    _createdController.close();
    _updatedController.close();
    _deletedController.close();
  }
}


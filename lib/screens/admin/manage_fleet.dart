import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shuttle_tracker/services/APIService.dart';
import 'package:shuttle_tracker/services/endpoints.dart';
import 'package:shuttle_tracker/services/logger.dart';
import 'package:shuttle_tracker/models/Shuttle.dart' as ShuttleModel;
import 'package:shuttle_tracker/models/driver_model/Driver.dart';

// Use typed ShuttleModel.ShuttleModel for canonical mapping
class ManageFleetScreen extends StatefulWidget {
  const ManageFleetScreen({Key? key}) : super(key: key);

  @override
  State<ManageFleetScreen> createState() => _ManageFleetScreenState();
}

class _ManageFleetScreenState extends State<ManageFleetScreen> {
  bool _loading = true;
  String? _error;
  String? _lastRawJson;
  final List<ShuttleModel.ShuttleModel> shuttles = [];
  final List<Driver> drivers = [];
  String statusFilter = 'ALL';
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchShuttles();
  }

  List<ShuttleModel.ShuttleModel> get filteredShuttles {
    return shuttles.where((s) {
      final matchesStatus = statusFilter == 'ALL' || s.status == statusFilter;
      final matchesSearch = searchQuery.isEmpty ||
          s.plate.toLowerCase().contains(searchQuery.toLowerCase()) ||
          (s.driver ?? '').toLowerCase().contains(searchQuery.toLowerCase()) ||
          (s.notes ?? '').toLowerCase().contains(searchQuery.toLowerCase());
      return matchesStatus && matchesSearch;
    }).toList();
  }

  Future<void> _fetchShuttles() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = APIService();
      // Fetch shuttles and drivers in parallel
      final futures = await Future.wait([api.fetchShuttles(), api.fetchDrivers().catchError((_) => <dynamic>[]) ]);
      final res = futures[0] as List<dynamic>;
      final driversRes = futures[1] as List<dynamic>;
      // fetchShuttles guarantees a List or throws
      try {
        _lastRawJson = const JsonEncoder.withIndent('  ').convert(res);
      } catch (_) {
        _lastRawJson = res.toString();
      }
      final fetched = res.map((m) => ShuttleModel.ShuttleModel.fromJson(m as Map<String, dynamic>)).toList();
      final fetchedDrivers = driversRes.map((d) {
        try {
          if (d is Map<String, dynamic>) return Driver.fromJson(d);
        } catch (_) {}
        return null;
      }).where((x) => x != null).cast<Driver>().toList();

      setState(() {
        shuttles.clear();
        shuttles.addAll(fetched);
        drivers.clear();
        drivers.addAll(fetchedDrivers);
        _loading = false;
      });
      return;
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load shuttles: $e')));
    }
  }

  void _showAddEditDialog({ShuttleModel.ShuttleModel? shuttle}) {
    showDialog(context: context, builder: (_) => AddEditShuttleDialog(shuttle: shuttle, drivers: drivers, onSubmit: (s) {
      // After server-confirmed create/update, reload canonical list
      _fetchShuttles();
    }));
  }

  Future<void> _deleteShuttle(ShuttleModel.ShuttleModel s) async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Shuttle'),
      content: Text('Delete shuttle ${s.plate}? This action cannot be undone.'),
      actions: [TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(ctx, false)), TextButton(child: const Text('Delete'), onPressed: () => Navigator.pop(ctx, true))],
    ));
    if (confirmed != true) return;
    try {
      final api = APIService();
      int? resolvedId = int.tryParse(s.id.replaceAll(RegExp(r'[^0-9]'), ''));
      if (resolvedId != null && resolvedId > 0) {
        await api.deleteShuttle(resolvedId);
      } else {
        // fallback: try delete by plate
        final enc = Uri.encodeComponent(s.plate);
        await api.delete('shuttles/deleteByPlate/$enc');
      }
      // Refresh list from server to ensure canonical state
      await _fetchShuttles();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shuttle deleted')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete shuttle: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fleet Management'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _fetchShuttles),
          IconButton(icon: const Icon(Icons.info_outline), tooltip: 'Raw JSON', onPressed: () {
            if (_lastRawJson == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No raw JSON available')));
              return;
            }
            showDialog(context: context, builder: (_) => AlertDialog(
              title: const Text('Raw shuttles JSON'),
              content: SizedBox(width: 600, child: SingleChildScrollView(child: Text(_lastRawJson!))),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
            ));
          })
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Shuttle'),
        onPressed: () => _showAddEditDialog(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          Row(children: [
            DropdownButton<String>(
              value: statusFilter,
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Status')),
                DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                DropdownMenuItem(value: 'IN_SERVICE', child: Text('In Service')),
                DropdownMenuItem(value: 'MAINTENANCE', child: Text('Maintenance')),
                DropdownMenuItem(value: 'RETIRED', child: Text('Retired')),
              ],
              onChanged: (v) => setState(() => statusFilter = v ?? 'ALL'),
            ),
            const SizedBox(width: 12),
            Expanded(child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by plate, driver, notes'), onChanged: (v) => setState(() => searchQuery = v))),
            const SizedBox(width: 12),
            ElevatedButton.icon(icon: const Icon(Icons.refresh), label: const Text('Reload'), onPressed: _fetchShuttles),
          ],),
          const SizedBox(height: 12),
          Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : (_error != null ? Center(child: Text('Failed to load: $_error')) : _buildTable())),
        ]),
      ),
    );
  }

  Widget _buildTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('ID')),
          DataColumn(label: Text('Plate')),
          DataColumn(label: Text('Capacity')),
          DataColumn(label: Text('Driver')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Last Serviced')),
          DataColumn(label: Text('Actions')),
        ],
        rows: filteredShuttles.map((s) {
          return DataRow(cells: [
            DataCell(Text(s.id)),
            DataCell(Text(s.plate)),
            DataCell(Text(s.capacity?.toString() ?? '-')),
            DataCell(Text(s.driver ?? '-')),
            DataCell(Text(s.status)),
            DataCell(Text(s.lastServiced != null ? s.lastServiced!.toLocal().toString().split(' ')[0] : '-')),
            DataCell(Row(children: [
              IconButton(icon: const Icon(Icons.edit), tooltip: 'Edit', onPressed: () => _showAddEditDialog(shuttle: s)),
              IconButton(icon: const Icon(Icons.delete), tooltip: 'Delete', onPressed: () => _deleteShuttle(s)),
              IconButton(icon: const Icon(Icons.info), tooltip: 'View Raw', onPressed: () async {
                // Attempt to fetch canonical record from server
                try {
                  final api = APIService();
                  int? resolvedId = int.tryParse(s.id.replaceAll(RegExp(r'[^0-9]'), ''));
                  dynamic single;
                  if (resolvedId != null && resolvedId > 0) single = await api.get('shuttles/read/$resolvedId');
                  else single = await api.get('shuttles/readByPlate/${Uri.encodeComponent(s.plate)}');
                  final pretty = const JsonEncoder.withIndent('  ').convert(single);
                  if (mounted) showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Server Shuttle Record'), content: SizedBox(width:600, child: SingleChildScrollView(child: Text(pretty))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to fetch shuttle: $e')));
                }
              }),
            ])),
          ]);
        }).toList(),
      ),
    );
  }
}

class AddEditShuttleDialog extends StatefulWidget {
  final ShuttleModel.ShuttleModel? shuttle;
  final void Function(ShuttleModel.ShuttleModel s) onSubmit;
  final List<Driver> drivers;
  const AddEditShuttleDialog({Key? key, this.shuttle, required this.onSubmit, this.drivers = const []}) : super(key: key);

  @override
  State<AddEditShuttleDialog> createState() => _AddEditShuttleDialogState();
}

class _AddEditShuttleDialogState extends State<AddEditShuttleDialog> {
  final _formKey = GlobalKey<FormState>();
  late String plate;
  int? selectedDriverId;
  int? capacity;
  String status = 'ACTIVE';
  DateTime? lastServiced;
  String? notes;
  Map<String, String?> fieldErrors = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final s = widget.shuttle;
    plate = s?.plate ?? '';
    // attempt to map driver name to driverId if available
    selectedDriverId = null;
    selectedDriverId = null;
    if (s?.driver != null && s!.driver!.isNotEmpty) {
      final matches = widget.drivers.where((d) => (d.user.name + ' ' + d.user.surname).trim() == s.driver).toList();
      if (matches.isNotEmpty) selectedDriverId = matches.first.driverId;
    }
    capacity = s?.capacity;
    status = s?.status ?? 'ACTIVE';
    lastServiced = s?.lastServiced;
    notes = s?.notes;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _submitting = true);
    fieldErrors.clear();
    try {
      final api = APIService();
      if (widget.shuttle == null) {
        final payload = <String, dynamic>{
          'plate': plate,
          if (capacity != null) 'capacity': capacity,
          if (selectedDriverId != null) 'driverId': selectedDriverId,
          if (selectedDriverId == null && plate.isNotEmpty) 'driver': null,
          'status': status,
          if (lastServiced != null) 'last_serviced': lastServiced!.toIso8601String(),
          if (notes != null && notes!.isNotEmpty) 'notes': notes,
        };
        final result = await api.createShuttle(payload);
        AppLogger.debug('Created shuttle', data: result);
        // Parse authoritative shuttle returned by server
        Map<String, dynamic>? obj;
        if (result is Map<String, dynamic>) {
          obj = (result['shuttle'] is Map<String, dynamic>) ? (result['shuttle'] as Map<String, dynamic>) : result as Map<String, dynamic>;
        }
        if (obj != null) {
          final created = ShuttleModel.ShuttleModel.fromJson(obj);
          if (mounted) widget.onSubmit(created);
          if (mounted) Navigator.pop(context);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shuttle created')));
        } else {
          // fallback: just close and let parent refresh
          if (mounted) Navigator.pop(context);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shuttle created')));
          if (mounted) widget.onSubmit(ShuttleModel.ShuttleModel(id: 'S${DateTime.now().millisecondsSinceEpoch}', plate: plate));
        }
      } else {
        // update
        final sOld = widget.shuttle!;
        int? resolvedId = int.tryParse(sOld.id.replaceAll(RegExp(r'[^0-9]'), ''));
        if (resolvedId == null || resolvedId == 0) {
          try {
            final got = await api.get('shuttles/readByPlate/${Uri.encodeComponent(sOld.plate)}');
            if (got is Map<String, dynamic>) {
              final idVal = got['shuttle_id'] ?? got['id'] ?? got['shuttleId'];
              if (idVal != null) resolvedId = int.tryParse(idVal.toString());
            }
          } catch (_) {}
        } else {
          try {
            final got = await api.get('shuttles/read/$resolvedId');
            if (got is Map<String, dynamic>) {}
          } catch (_) {}
        }
        final payload = <String, dynamic>{
          'plate': plate,
          if (capacity != null) 'capacity': capacity,
          if (selectedDriverId != null) 'driverId': selectedDriverId,
          'status': status,
          if (lastServiced != null) 'last_serviced': lastServiced!.toIso8601String(),
          if (notes != null && notes!.isNotEmpty) 'notes': notes,
        };
        dynamic updateResult;
        if (resolvedId != null && resolvedId > 0) {
          updateResult = await api.updateShuttle(resolvedId, payload);
        } else {
          // last resort: attempt to PUT to /shuttles/update if backend expects that
          try {
            updateResult = await api.put(Endpoints.shuttleUpdate, payload);
          } catch (_) {}
        }
        // Try to parse authoritative updated shuttle
        Map<String, dynamic>? updatedObj;
        if (updateResult is Map<String, dynamic>) {
          updatedObj = (updateResult['shuttle'] is Map<String, dynamic>) ? (updateResult['shuttle'] as Map<String, dynamic>) : updateResult as Map<String, dynamic>;
        }
        if (updatedObj == null && resolvedId != null && resolvedId > 0) {
          try {
            final got = await api.get('shuttles/read/$resolvedId');
            if (got is Map<String, dynamic>) updatedObj = got;
          } catch (_) {}
        }
        if (updatedObj != null) {
          final updated = ShuttleModel.ShuttleModel.fromJson(updatedObj);
          if (mounted) widget.onSubmit(updated);
          if (mounted) Navigator.pop(context);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shuttle updated')));
        } else {
          // fallback: notify and close
          if (mounted) Navigator.pop(context);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shuttle updated')));
          if (mounted) widget.onSubmit(ShuttleModel.ShuttleModel(id: sOld.id, plate: plate));
        }
      }
    } catch (e) {
      // Surface server side validation errors if returned in ApiException
      if (e is ApiException && e.body is Map<String, dynamic>) {
        final body = e.body as Map<String, dynamic>;
        setState(() {
          body.forEach((k, v) {
            fieldErrors[k] = v is String ? v : v?.toString();
          });
        });
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save shuttle: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.shuttle != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Shuttle' : 'Add Shuttle'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              initialValue: plate,
              decoration: const InputDecoration(labelText: 'Plate / Registration'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Enter plate' : null,
              onSaved: (v) => plate = v!.trim(),
            ),
            TextFormField(
              initialValue: capacity != null ? capacity.toString() : null,
              decoration: const InputDecoration(labelText: 'Capacity (seats)'),
              keyboardType: TextInputType.number,
              onSaved: (v) => capacity = v == null || v.isEmpty ? null : int.tryParse(v),
            ),
            // Assigned Driver dropdown (populated from drivers endpoint when available)
            DropdownButtonFormField<int?>(
              value: selectedDriverId,
              decoration: InputDecoration(labelText: 'Assigned Driver (optional)', errorText: fieldErrors['driverId']),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('--- No driver ---')),
                ...widget.drivers.map((d) => DropdownMenuItem<int?>(value: d.driverId, child: Text((d.user.name + ' ' + d.user.surname).trim()))),
              ],
              onChanged: (v) => setState(() => selectedDriverId = v),
              onSaved: (v) => selectedDriverId = v,
            ),
            DropdownButtonFormField<String>(
              initialValue: status,
              items: const [
                DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                DropdownMenuItem(value: 'IN_SERVICE', child: Text('In Service')),
                DropdownMenuItem(value: 'MAINTENANCE', child: Text('Maintenance')),
                DropdownMenuItem(value: 'RETIRED', child: Text('Retired')),
              ],
              onChanged: (v) => setState(() => status = v ?? 'ACTIVE'),
              decoration: const InputDecoration(labelText: 'Status'),
            ),
            TextFormField(
              initialValue: lastServiced != null ? lastServiced!.toLocal().toString().split(' ')[0] : null,
              decoration: const InputDecoration(labelText: 'Last Serviced (YYYY-MM-DD)'),
              onSaved: (v) {
                if (v == null || v.isEmpty) { lastServiced = null; return; }
                try { lastServiced = DateTime.tryParse(v); } catch (_) { lastServiced = null; }
              },
            ),
            TextFormField(
              initialValue: notes,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 3,
              onSaved: (v) => notes = v?.trim(),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
        ElevatedButton(child: _submitting ? SizedBox(height:16,width:16, child: CircularProgressIndicator(color: Colors.white, strokeWidth:2)) : const Text('Save'), onPressed: _submitting ? null : _handleSubmit),
      ],
    );
  }
}

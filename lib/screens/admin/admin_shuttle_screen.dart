import 'package:flutter/material.dart';
import 'package:shuttle_tracker/screens/admin/admin_home_screen.dart';
import 'package:shuttle_tracker/screens/admin/admin_stats_screen.dart';
import 'package:shuttle_tracker/screens/admin/admin_settings_screen.dart';
import 'package:shuttle_tracker/screens/admin/admin_users_screen.dart';

// Updated Shuttle Model
class Shuttle {
  final String id;
  String name;
  String plateNumber;
  int capacity;
  String shuttleType; // "Bus", "Minibus"
  String startingPoint;
  String destination;
  String? driverName; // Nullable if no driver assigned
  String status; // "Active", "Inactive", "Maintenance"

  Shuttle({
    required this.id,
    required this.name,
    required this.plateNumber,
    required this.capacity,
    required this.shuttleType,
    required this.startingPoint,
    required this.destination,
    this.driverName,
    required this.status,
  });
}

class AdminShuttleScreen extends StatefulWidget {
  const AdminShuttleScreen({super.key});

  @override
  State<AdminShuttleScreen> createState() => _AdminShuttleScreenState();
}

class _AdminShuttleScreenState extends State<AdminShuttleScreen>
    with SingleTickerProviderStateMixin {
  final int _selectedIndex = 2; // "Shuttles" is highlighted
  late TabController _tabController;
  String _currentFilter = "All";

  // Placeholder Shuttle Data - Updated with new fields
  final List<Shuttle> _allShuttles = [
    Shuttle(id: 'S101',
        name: 'Campus Express',
        plateNumber: 'CA 123-456',
        capacity: 25,
        shuttleType: 'Bus',
        startingPoint: 'Main Campus',
        destination: 'North Residence',
        driverName: 'Jane Doe',
        status: 'Active'),
    Shuttle(id: 'S102',
        name: 'City Link',
        plateNumber: 'CB 789-012',
        capacity: 15,
        shuttleType: 'Minibus',
        startingPoint: 'Bellville Station',
        destination: 'District 6 Hub',
        driverName: 'John Smith',
        status: 'Inactive'),
    Shuttle(id: 'S103',
        name: 'Tech Runner',
        plateNumber: 'CC 345-678',
        capacity: 20,
        shuttleType: 'Bus',
        startingPoint: 'Tech Park Gate 1',
        destination: 'Central Library',
        status: 'Maintenance'),
    Shuttle(id: 'S104',
        name: 'Alpha Mover',
        plateNumber: 'CD 901-234',
        capacity: 15,
        shuttleType: 'Minibus',
        startingPoint: 'Waterfront Mall',
        destination: 'City Center',
        driverName: 'Alex Green',
        status: 'Active'),
  ];

  List<Shuttle> _filteredShuttles = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _filterShuttles();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging ||
        _tabController.index != _tabController.previousIndex) {
      setState(() {
        _currentFilter =
        ["All", "Active", "Inactive", "Maintenance"][_tabController.index];
        _filterShuttles();
      });
    }
  }

  void _filterShuttles() {
    if (_currentFilter == "All") {
      _filteredShuttles = List.from(_allShuttles);
    } else {
      _filteredShuttles =
          _allShuttles
              .where((shuttle) => shuttle.status == _currentFilter)
              .toList();
    }
    setState(() {}); // Ensure UI updates
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  void _onBottomNavItemTapped(int index) {
    if (_selectedIndex == index) return;
    Widget pageBuilder(BuildContext context) {
      switch (index) {
        case 0:
          return const AdminHomeScreen();
        case 1:
          return const AdminUsersScreen();
        case 2:
          return const AdminShuttleScreen();
        case 3:
          return const AdminStatsScreen();
        case 4:
          return const AdminSettingsScreen();
        default:
          return const AdminShuttleScreen();
      }
    }
    Navigator.pushReplacement(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => pageBuilder(context),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero));
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Active':
        return Colors.green.shade600;
      case 'Inactive':
        return Colors.grey.shade600;
      case 'Maintenance':
        return Colors.orange.shade700;
      default:
        return Colors.black;
    }
  }

  void _addShuttleDialog() {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    String name = '';
    String plateNumber = '';
    int? capacity;
    String? shuttleType; // Nullable for dropdown
    String startingPoint = '';
    String destination = '';
    String status = 'Active'; // Default status

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Add New Shuttle'),
          content: StatefulBuilder(
              builder: (context, setDialogState) { // For dropdown updates
                return SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        TextFormField(decoration: const InputDecoration(
                            labelText: 'Shuttle Name (e.g., Campus Express)'),
                            validator: (val) =>
                            val == null || val.isEmpty
                                ? 'Enter shuttle name'
                                : null,
                            onChanged: (val) => name = val),
                        TextFormField(decoration: const InputDecoration(
                            labelText: 'Plate Number'),
                            validator: (val) =>
                            val == null || val.isEmpty
                                ? 'Enter plate number'
                                : null,
                            onChanged: (val) => plateNumber = val),
                        TextFormField(decoration: const InputDecoration(
                            labelText: 'Capacity'),
                            keyboardType: TextInputType.number,
                            validator: (val) {
                              if (val == null || val.isEmpty ||
                                  int.tryParse(val) == null ||
                                  int.parse(val) <= 0) {
                                return 'Enter valid capacity';
                              }
                              return null;
                            },
                            onChanged: (val) => capacity = int.tryParse(val)),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                              labelText: 'Shuttle Type'),
                          value: shuttleType,
                          items: ['Bus', 'Minibus'].map((String type) =>
                              DropdownMenuItem<String>(
                                  value: type, child: Text(type))).toList(),
                          onChanged: (String? newValue) =>
                              setDialogState(() => shuttleType = newValue),
                          validator: (val) =>
                          val == null
                              ? 'Select shuttle type'
                              : null,
                        ),
                        TextFormField(decoration: const InputDecoration(
                            labelText: 'Starting Point'),
                            validator: (val) =>
                            val == null || val.isEmpty
                                ? 'Enter starting point'
                                : null,
                            onChanged: (val) => startingPoint = val),
                        TextFormField(decoration: const InputDecoration(
                            labelText: 'Destination'),
                            validator: (val) =>
                            val == null || val.isEmpty
                                ? 'Enter destination'
                                : null,
                            onChanged: (val) => destination = val),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                              labelText: 'Initial Status'),
                          value: status,
                          items: ['Active', 'Inactive', 'Maintenance'].map((
                              String stat) =>
                              DropdownMenuItem<String>(
                                  value: stat, child: Text(stat))).toList(),
                          onChanged: (String? newValue) =>
                              setDialogState(() => status = newValue!),
                          validator: (val) =>
                          val == null
                              ? 'Select status'
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              }),
          actions: <Widget>[
            TextButton(child: const Text('Cancel'),
                onPressed: () => Navigator.of(dialogContext).pop()),
            TextButton(
              child: const Text('Add Shuttle'),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  setState(() {
                    _allShuttles.add(Shuttle(
                      id: 'S${_allShuttles.length + 101 + DateTime
                          .now()
                          .millisecond}',
                      // Simplistic unique ID
                      name: name,
                      plateNumber: plateNumber,
                      capacity: capacity!,
                      shuttleType: shuttleType!,
                      startingPoint: startingPoint,
                      destination: destination,
                      status: status,
                    ));
                    _filterShuttles();
                  });
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Shuttle added successfully!')));
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _changeShuttleStatusDialog(Shuttle shuttle) {
    String newStatus = shuttle.status; // Initialize with current status
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Change Status for ${shuttle.name}'),
          content: DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'New Status'),
            value: newStatus,
            items: ['Active', 'Inactive', 'Maintenance']
                .map((String value) =>
                DropdownMenuItem<String>(value: value, child: Text(value)))
                .toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                newStatus = newValue;
              }
            },
          ),
          actions: <Widget>[
            TextButton(child: const Text('Cancel'),
                onPressed: () => Navigator.of(dialogContext).pop()),
            TextButton(
              child: const Text('Update Status'),
              onPressed: () {
                setState(() {
                  shuttle.status = newStatus;
                  _filterShuttles(); // Re-apply filters to update list if necessary
                });
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        '${shuttle.name} status updated to $newStatus')));
              },
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shuttle Management'),
        backgroundColor: theme.colorScheme.primary,
        titleTextStyle: TextStyle(color: theme.colorScheme.onPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold),
        iconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
        actions: [
          IconButton(icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Add Shuttle',
              onPressed: _addShuttleDialog),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.onPrimary,
          unselectedLabelColor: theme.colorScheme.onPrimary.withOpacity(0.7),
          indicatorColor: theme.colorScheme.onPrimary,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Active'),
            Tab(text: 'Inactive'),
            Tab(text: 'Maintenance')
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(4, (index) {
          if (_filteredShuttles.isEmpty) {
            return Center(child: Text(
                'No shuttles found for "${_currentFilter}".',
                style: theme.textTheme.titleMedium));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: _filteredShuttles.length,
            itemBuilder: (context, itemIndex) {
              final shuttle = _filteredShuttles[itemIndex];
              return Card(
                margin: const EdgeInsets.symmetric(
                    vertical: 6.0, horizontal: 8.0),
                elevation: 2.0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(shuttle.name,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                        fontWeight: FontWeight.bold)),
                                Text('Plate: ${shuttle.plateNumber}',
                                    style: theme.textTheme.bodySmall),
                                Text('${shuttle
                                    .shuttleType} - Capacity: ${shuttle
                                    .capacity}',
                                    style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                          Chip(
                            label: Text(shuttle.status, style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
                            backgroundColor: _getStatusColor(shuttle.status),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8.0, vertical: 2.0),
                            materialTapTargetSize: MaterialTapTargetSize
                                .shrinkWrap,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Route: ${shuttle.startingPoint} → ${shuttle
                          .destination}', style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 4),
                      Text(
                        shuttle.driverName != null &&
                            shuttle.driverName!.isNotEmpty ? 'Driver: ${shuttle
                            .driverName}' : 'Driver: Not Assigned',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade700,
                            fontStyle: shuttle.driverName == null ? FontStyle
                                .italic : FontStyle.normal),
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Placeholder for Edit button
                          TextButton(child: const Text('Edit'), onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Edit ${shuttle
                                    .name} (not implemented).')));
                          }),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            onSelected: (String value) {
                              if (value == 'change_status') {
                                _changeShuttleStatusDialog(shuttle);
                              } else if (value == 'assign_driver') {
                                // TODO: Implement Assign Driver functionality
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(
                                        'Assign Driver for ${shuttle
                                            .name} (not implemented).')));
                              }
                            },
                            itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(
                                  value: 'change_status',
                                  child: Text('Change Status')),
                              const PopupMenuItem<String>(
                                  value: 'assign_driver',
                                  child: Text('Assign Driver')),
                              // Add other actions like 'Remove' if needed
                            ],
                            child: const Icon(Icons.more_vert),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
          BottomNavigationBarItem(
              icon: Icon(Icons.directions_bus), label: 'Shuttles'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'Settings'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
        showUnselectedLabels: true,
        onTap: _onBottomNavItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
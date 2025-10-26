import 'package:flutter/material.dart';
import '../../services/APIService.dart';
import '../../services/logger.dart';

class ManageDriversScreen extends StatefulWidget {
  const ManageDriversScreen({super.key});

  @override
  State<ManageDriversScreen> createState() => _ManageDriversScreenState();
}

class _ManageDriversScreenState extends State<ManageDriversScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _availableShuttles = [];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _licenseController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _licenseController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = APIService();

      // Load drivers and shuttles in parallel
      final results = await Future.wait([
        api.fetchDrivers(),
        api.fetchShuttles(),
      ]);

      if (!mounted) return;

      final List<dynamic> driversData = results[0];
      final List<dynamic> shuttlesData = results[1];

      setState(() {
        _drivers = driversData.map((d) => d as Map<String, dynamic>).toList();
        _availableShuttles = shuttlesData.map((s) => s as Map<String, dynamic>).toList();
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Failed to load drivers data', error: e);
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _showAddDriverDialog() {
    // Reset form controllers
    _nameController.clear();
    _licenseController.clear();
    _phoneController.clear();
    _emailController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Driver'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter driver\'s name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _licenseController,
                  decoration: const InputDecoration(
                    labelText: 'License Number',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter license number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;

              try {
                final payload = {
                  'name': _nameController.text,
                  'licenseNumber': _licenseController.text,
                  'phoneNumber': _phoneController.text,
                  'email': _emailController.text,
                  'status': 'Active',
                };

                await APIService().post('drivers/create', payload);
                if (!mounted) return;

                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Driver added successfully')),
                );
                _loadData(); // Refresh the list
              } catch (e) {
                AppLogger.error('Failed to add driver', error: e);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to add driver: ${e.toString()}')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditDriverDialog(Map<String, dynamic> driver) {
    final selectedShuttleId = driver['shuttleId'];

    _nameController.text = driver['name'] ?? '';
    _licenseController.text = driver['licenseNumber'] ?? '';
    _phoneController.text = driver['phoneNumber'] ?? '';
    _emailController.text = driver['email'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Driver: ${driver['name']}'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter driver\'s name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _licenseController,
                  decoration: const InputDecoration(
                    labelText: 'License Number',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter license number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedShuttleId?.toString(),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('No Shuttle Assigned'),
                    ),
                    ..._availableShuttles.map((shuttle) => DropdownMenuItem(
                      value: shuttle['id'].toString(),
                      child: Text(shuttle['licensePlate'] ?? 'Unknown Shuttle'),
                    )).toList(),
                  ],
                  onChanged: (val) {
                    // Update selected shuttle
                  },
                  decoration: const InputDecoration(
                    labelText: 'Assigned Shuttle',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;

              try {
                final payload = {
                  'name': _nameController.text,
                  'licenseNumber': _licenseController.text,
                  'phoneNumber': _phoneController.text,
                  'email': _emailController.text,
                };

                await APIService().put('drivers/${driver['id']}', payload);
                if (!mounted) return;

                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Driver updated successfully')),
                );
                _loadData(); // Refresh the list
              } catch (e) {
                AppLogger.error('Failed to update driver', error: e);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to update driver: ${e.toString()}')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showRemoveDriverDialog(Map<String, dynamic> driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Driver'),
        content: Text('Are you sure you want to remove ${driver['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await APIService().delete('drivers/${driver['id']}');
                if (!mounted) return;

                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Driver removed successfully')),
                );
                _loadData(); // Refresh the list
              } catch (e) {
                AppLogger.error('Failed to remove driver', error: e);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to remove driver: ${e.toString()}')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Drivers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: SearchBar(
                                  hintText: 'Search drivers...',
                                  leading: const Icon(Icons.search),
                                  onChanged: (value) {
                                    // TODO: Implement search
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: _showAddDriverDialog,
                                icon: const Icon(Icons.add),
                                label: Text(constraints.maxWidth > 600 ? 'Add Driver' : ''),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _drivers.isEmpty
                              ? const Center(child: Text('No drivers found'))
                              : constraints.maxWidth > 600
                                  ? _buildDriversTable()
                                  : _buildDriversList(),
                        ),
                      ],
                    );
                  },
                ),
    );
  }

  Widget _buildDriversTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('License')),
            DataColumn(label: Text('Phone')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: _drivers.map((driver) {
            return DataRow(
              cells: [
                DataCell(Text(driver['name'] ?? '')),
                DataCell(Text(driver['licenseNumber'] ?? '')),
                DataCell(Text(driver['phoneNumber'] ?? '')),
                DataCell(Text(driver['email'] ?? '')),
                DataCell(Text(driver['status'] ?? 'Active')),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditDriverDialog(driver),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _showRemoveDriverDialog(driver),
                      tooltip: 'Remove',
                    ),
                  ],
                )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDriversList() {
    return ListView.builder(
      itemCount: _drivers.length,
      itemBuilder: (context, index) {
        final driver = _drivers[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(driver['name'] ?? ''),
            subtitle: Text('License: ${driver['licenseNumber'] ?? ''}\nPhone: ${driver['phoneNumber'] ?? ''}'),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _showEditDriverDialog(driver);
                    break;
                  case 'remove':
                    _showRemoveDriverDialog(driver);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'remove', child: Text('Remove')),
              ],
            ),
          ),
        );
      },
    );
  }
}

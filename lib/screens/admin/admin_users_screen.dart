import 'package:flutter/material.dart';
import 'package:shuttle_tracker/screens/admin/admin_home_screen.dart';
import 'package:shuttle_tracker/screens/admin/admin_shuttle_screen.dart';
import 'package:shuttle_tracker/screens/admin/admin_stats_screen.dart';
import 'package:shuttle_tracker/screens/admin/admin_settings_screen.dart';

// Updated User Model
class User {
  final String id;
  String name; // Made mutable for potential editing
  String role; // "Student", "Driver", "Admin"
  String avatarInitials;
  String status; // "Active", "Inactive"

  User({
    required this.id,
    required this.name,
    required this.role,
    required this.avatarInitials,
    this.status = "Active", // Default to Active for new users
  });
}

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen>
    with SingleTickerProviderStateMixin {
  final int _selectedIndex = 1; // "Users" is highlighted
  late TabController _tabController;
  String _currentFilter = "All";
  String _searchQuery = "";
  final int _maxAdmins = 3;

  // Placeholder User Data - Updated with status
  final List<User> _allUsers = [
    User(id: 'u001',
        name: 'Alice Wonderland',
        role: 'Student',
        avatarInitials: 'AW',
        status: 'Active'),
    User(id: 'u002',
        name: 'Bob The Builder',
        role: 'Driver',
        avatarInitials: 'BB',
        status: 'Active'),
    User(id: 'u003',
        name: 'Charlie Admin',
        role: 'Admin',
        avatarInitials: 'CA',
        status: 'Active'),
    User(id: 'u004',
        name: 'Diana Prince',
        role: 'Student',
        avatarInitials: 'DP',
        status: 'Active'),
    User(id: 'u005',
        name: 'Edward Scissorhands',
        role: 'Driver',
        avatarInitials: 'ES',
        status: 'Inactive'),
    User(id: 'u006',
        name: 'Fiona Gallagher',
        role: 'Student',
        avatarInitials: 'FG',
        status: 'Active'),
    User(id: 'u007',
        name: 'George Jetson',
        role: 'Admin',
        avatarInitials: 'GJ',
        status: 'Active'),
    User(id: 'u008',
        name: 'Hank Hill',
        role: 'Admin',
        avatarInitials: 'HH',
        status: 'Inactive'),
    // Add one more admin to test the limit if needed:
    // User(id: 'u009', name: 'Ivy Inspector', role: 'Admin', avatarInitials: 'II', status: 'Active'),
  ];

  List<User> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _applyFilters(); // Initial filter
  }

  void _handleTabSelection() {
    // Ensure setState is called to rebuild with the new filter
    if (_tabController.indexIsChanging ||
        _tabController.index != _tabController.previousIndex) {
      setState(() {
        _currentFilter =
        ["All", "Students", "Drivers", "Admins"][_tabController.index];
        _applyFilters();
      });
    }
  }

  void _applyFilters() {
    List<User> usersToShow = List.from(_allUsers);

    // Apply role filter
    if (_currentFilter != "All") {
      // Convert tab name to role name (e.g., "Students" -> "Student")
      String roleToFilter = _currentFilter.endsWith('s') ? _currentFilter
          .substring(0, _currentFilter.length - 1) : _currentFilter;
      usersToShow =
          usersToShow.where((user) => user.role == roleToFilter).toList();
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      usersToShow = usersToShow
          .where((user) =>
          user.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    setState(() {
      _filteredUsers = usersToShow;
    });
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
          return const AdminUsersScreen();
      }
    }
    Navigator.pushReplacement(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => pageBuilder(context),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero));
  }

  void _showSearchDialog(BuildContext context) {
    TextEditingController searchController = TextEditingController(
        text: _searchQuery);
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Search Users'),
            content: TextField(controller: searchController,
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'Enter user name...')),
            actions: [
              TextButton(child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop()),
              TextButton(child: const Text('Search'), onPressed: () {
                setState(() {
                  _searchQuery = searchController.text;
                  _applyFilters();
                });
                Navigator.of(context).pop();
              }),
            ],
          ),
    );
  }

// ... (rest of the AdminUsersScreen class)

  void _addUserDialog(BuildContext context) {
    // Only count ACTIVE admins towards the limit
    int currentActiveAdminCount = _allUsers
        .where((user) => user.role == 'Admin' && user.status == 'Active')
        .length;
    bool canAddAdmin = currentActiveAdminCount < _maxAdmins;

    String? selectedRole;
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Add New User'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setStateDialog) {
              List<String> availableRoles = ['Driver'];
              // The decision to show "Admin" in the dropdown is based on whether *any* new admin slot is available
              if (canAddAdmin) {
                availableRoles.add('Admin');
              } else {
                // If we can't add an admin, but there are inactive admins, we might still allow "Admin"
                // role selection, and the final check before adding will prevent exceeding active limit.
                // For simplicity, if canAddAdmin is false, we can choose to not show "Admin" role or handle it at submission.
                // Current logic: if canAddAdmin is true, 'Admin' is an option.
              }


              return Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                          labelText: 'Full Name', border: OutlineInputBorder()),
                      validator: (value) {
                        if (value == null || value
                            .trim()
                            .isEmpty) {
                          return 'Please enter a name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                          labelText: 'Select Role',
                          border: OutlineInputBorder()),
                      value: selectedRole,
                      hint: const Text('Select Role'),
                      // Only show 'Admin' as an option if a slot is truly available considering active admins
                      items: (canAddAdmin ? ['Driver', 'Admin'] : ['Driver'])
                          .map((String value) {
                        return DropdownMenuItem<String>(
                            value: value, child: Text(value));
                      }).toList(),
                      onChanged: (String? newValue) {
                        setStateDialog(() {
                          selectedRole = newValue;
                        });
                      },
                      validator: (value) =>
                      value == null
                          ? 'Please select a role'
                          : null,
                    ),
                    // Show this message if 'Admin' role is not even an option because active admin limit is met
                    if (!canAddAdmin)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Max number of active Admins ($_maxAdmins) reached. Deactivate an existing admin to add a new one.',
                          style: TextStyle(color: Theme
                              .of(context)
                              .colorScheme
                              .error, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(child: const Text('Cancel'),
                onPressed: () => Navigator.of(dialogContext).pop()),
            TextButton(
              child: const Text('Add User'),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  if (selectedRole == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a role.')));
                    return;
                  }

                  // Recalculate here as well, just before adding, to be absolutely sure
                  int latestActiveAdminCount = _allUsers
                      .where((user) =>
                  user.role == 'Admin' && user.status == 'Active')
                      .length;
                  if (selectedRole == 'Admin' &&
                      latestActiveAdminCount >= _maxAdmins) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            'Cannot add more active Admins. Limit is $_maxAdmins.')));
                    return;
                  }

                  setState(() {
                    String newId = 'u${_allUsers.length + DateTime
                        .now()
                        .millisecondsSinceEpoch}';
                    String name = nameController.text.trim();
                    String initials = name.isNotEmpty ? (name
                        .split(' ')
                        .length > 1 ? name.split(' ')[0][0] + name.split(
                        ' ')[1][0] : name[0]) : "N/A";
                    _allUsers.add(User(id: newId,
                        name: name,
                        role: selectedRole!,
                        avatarInitials: initials.toUpperCase(),
                        status: "Active")); // New users are active
                    _applyFilters();
                  });
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          '${selectedRole!} user added successfully.')));
                }
              },
            ),
          ],
        );
      },
    );
  }

// ... (rest of the AdminUsersScreen class including build method etc.)
// Make sure the full class structure is preserved from the previous version.
// The following is the closing part of the class from the previous complete version.
// Ensure this integrates correctly.

  // ... (ListView.builder and other UI elements from the previous complete version)
  // ... (The rest of the build method, Scaffold, BottomNavigationBar, etc.)

  void _toggleUserStatusDialog(User user) {
    if (user.role == 'Student') return;

    String actionText = user.status == 'Active' ? 'Deactivate' : 'Activate';
    Color actionColor = user.status == 'Active' ? Theme
        .of(context)
        .colorScheme
        .error : Colors.green;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) =>
          AlertDialog(
            title: Text('$actionText User?'),
            content: Text(
                'Are you sure you want to $actionText ${user.name} (${user
                    .role})?'),
            actions: [
              TextButton(child: const Text('Cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop()),
              TextButton(
                child: Text(actionText, style: TextStyle(color: actionColor)),
                onPressed: () {
                  setState(() {
                    user.status =
                    user.status == 'Active' ? 'Inactive' : 'Active';
                    _applyFilters();
                  });
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${user.name} has been ${actionText
                          .toLowerCase()}d.')));
                },
              ),
            ],
          ),
    );
  }

  void _deleteStudentDialog(User student) {
    if (student.role != 'Student') return;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) =>
          AlertDialog(
            title: const Text('Delete Student?'),
            content: Text('Are you sure you want to delete ${student
                .name}? This action cannot be undone.'),
            actions: [
              TextButton(child: const Text('Cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop()),
              TextButton(
                child: Text('Delete', style: TextStyle(color: Theme
                    .of(context)
                    .colorScheme
                    .error)),
                onPressed: () {
                  setState(() {
                    _allUsers.removeWhere((user) => user.id == student.id);
                    _applyFilters();
                  });
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${student.name} has been deleted.')));
                },
              ),
            ],
          ),
    );
  }

  void _editUserDialog(User user) {
    // For now, just a placeholder. In a real app, this would open a form.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(
          'Edit functionality for ${user.name} (not implemented).')),
    );
    // TODO: Implement a dialog or screen to edit user details (name, role if applicable, etc.)
    // Example: Similar to _addUserDialog but pre-filled and updates the user.
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: theme.colorScheme.primary,
        titleTextStyle: TextStyle(color: theme.colorScheme.onPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold),
        iconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
        actions: [
          IconButton(icon: const Icon(Icons.search),
              tooltip: 'Search Users',
              onPressed: () => _showSearchDialog(context)),
          IconButton(icon: const Icon(Icons.person_add_alt_1_outlined),
              tooltip: 'Add User',
              onPressed: () => _addUserDialog(context)),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.onPrimary,
          unselectedLabelColor: theme.colorScheme.onPrimary.withOpacity(0.7),
          indicatorColor: theme.colorScheme.onPrimary,
          isScrollable: false,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Students'),
            Tab(text: 'Drivers'),
            Tab(text: 'Admins')
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(4, (tabIndex) {
          if (_filteredUsers.isEmpty && _searchQuery.isNotEmpty) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                  'No users found for "$_searchQuery"${_currentFilter != "All"
                      ? " in $_currentFilter"
                      : ""}.', textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium),
            ));
          } else if (_filteredUsers.isEmpty) {
            return Center(child: Text('No users in "${_currentFilter}".',
                style: theme.textTheme.titleMedium));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: _filteredUsers.length,
            itemBuilder: (context, itemIndex) {
              final user = _filteredUsers[itemIndex];
              return Card(
                margin: const EdgeInsets.symmetric(
                    vertical: 6.0, horizontal: 8.0),
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: user.status == 'Active' ? theme
                                .colorScheme.secondaryContainer : Colors.grey
                                .shade400,
                            child: Text(
                              user.avatarInitials,
                              style: TextStyle(
                                  color: user.status == 'Active' ? theme
                                      .colorScheme.onSecondaryContainer : Colors
                                      .white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      user.role,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(color: theme.colorScheme
                                          .onSurfaceVariant),
                                    ),
                                    const SizedBox(width: 8),
                                    if (user.role !=
                                        'Student') // Display status for Drivers and Admins
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: user.status == 'Active'
                                              ? Colors.green.withOpacity(0.2)
                                              : Colors.red.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                              4),
                                        ),
                                        child: Text(
                                          user.status,
                                          style: TextStyle(
                                            color: user.status == 'Active'
                                                ? Colors.green.shade800
                                                : Colors.red.shade800,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (user.role !=
                              'Student') // 3-dot menu for Drivers/Admins (can be expanded)
                            IconButton(
                              icon: const Icon(Icons.more_vert),
                              tooltip: 'More Actions',
                              onPressed: () {
                                // For now, could show user details or specific actions in a bottom sheet/menu
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(
                                      'More actions for ${user
                                          .name} (not implemented).')),
                                );
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (user.role == 'Student') ...[
                            TextButton.icon(
                              icon: Icon(Icons.delete_outline, size: 18,
                                  color: theme.colorScheme.error),
                              label: Text('Delete', style: TextStyle(
                                  color: theme.colorScheme.error)),
                              onPressed: () => _deleteStudentDialog(user),
                            ),
                          ],
                          if (user.role == 'Driver' ||
                              user.role == 'Admin') ...[
                            TextButton.icon(
                              icon: Icon(Icons.edit_outlined, size: 18,
                                  color: theme.colorScheme.primary),
                              label: Text('Edit', style: TextStyle(
                                  color: theme.colorScheme.primary)),
                              onPressed: () => _editUserDialog(user),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              icon: Icon(user.status == 'Active' ? Icons
                                  .pause_circle_outline : Icons
                                  .play_circle_outline, size: 18,
                                  color: user.status == 'Active' ? theme
                                      .colorScheme.error : Colors.green),
                              label: Text(user.status == 'Active'
                                  ? 'Deactivate'
                                  : 'Activate', style: TextStyle(
                                  color: user.status == 'Active' ? theme
                                      .colorScheme.error : Colors.green)),
                              onPressed: () => _toggleUserStatusDialog(user),
                            ),
                          ]
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
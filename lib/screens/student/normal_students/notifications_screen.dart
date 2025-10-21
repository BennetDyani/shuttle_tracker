import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/APIService.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/notifications_provider.dart';
import '../../../widgets/dashboard_action.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool isLoading = true;
  String? error;
  List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications({bool force = false}) async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uidStr = auth.userId;
      final int? uid = uidStr != null && uidStr.isNotEmpty ? int.tryParse(uidStr) : null;
      final result = await APIService().fetchNotifications(userId: uid);
      setState(() {
        notifications = result;
      });
      // Update provider unread count
      Provider.of<NotificationsProvider>(context, listen: false).refresh(userId: uid);
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        actions: const [DashboardAction()],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Error: $error'),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(onPressed: _loadNotifications, icon: const Icon(Icons.refresh), label: const Text('Retry'))
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadNotifications(force: true),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final n = notifications[index];
                      final title = (n['title'] ?? n['subject'] ?? n['message'] ?? '') as String;
                      final body = (n['body'] ?? n['message'] ?? n['description'] ?? '') as String;
                      final time = (n['createdAt'] ?? n['created_at'] ?? n['time'] ?? '')?.toString();
                      final unread = (n['read'] == false) || (n['is_read'] == false) || (n['unread'] == true);
                      return ListTile(
                        leading: Icon(Icons.notifications, color: unread ? Colors.blue : Colors.grey),
                        title: Text(title.isNotEmpty ? title : 'Notification', maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: Text(time ?? ''),
                        onTap: () async {
                          // Mark as read if unread
                          final idRaw = n['id'] ?? n['notification_id'] ?? n['notificationId'] ?? n['id'];
                          final int? nid = idRaw is int ? idRaw : (idRaw is String ? int.tryParse(idRaw) : null);
                          if (unread && nid != null) {
                            final ok = await Provider.of<NotificationsProvider>(context, listen: false).markAsRead(nid);
                            if (ok) {
                              setState(() {
                                notifications[index] = Map<String, dynamic>.from(n)..['read'] = true;
                              });
                            }
                          }

                          showDialog(context: context, builder: (_) => AlertDialog(
                            title: Text(title.isNotEmpty ? title : 'Notification'),
                            content: SingleChildScrollView(child: Text(body)),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
                            ],
                          ));
                        },
                      );
                    },
                  ),
                ),
    );
  }
}

import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/user_role.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationModel {
  final int notificationId;
  final String title;
  final String message;
  final String type;
  final int? referenceId;
  final bool isRead;
  final DateTime createdDate;

  NotificationModel({
    required this.notificationId,
    required this.title,
    required this.message,
    required this.type,
    this.referenceId,
    required this.isRead,
    required this.createdDate,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      notificationId: json['notificationId'] ?? 0,
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? '',
      referenceId: json['referenceId'],
      isRead: json['isRead'] ?? false,
      createdDate:
          DateTime.tryParse(json['createdDate'] ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  bool _isLoading = true;
  List<NotificationModel> _notifications = [];
  String _error = '';

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('th', timeago.ThMessages());
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final response = await ApiProvider().get('/notifications');
      if (mounted && response['status'] == 200 && response['data'] is List) {
        final data = response['data'] as List;
        setState(() {
          _notifications = data
              .map((json) => NotificationModel.fromJson(json))
              .toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load notifications');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'ไม่สามารถโหลดการแจ้งเตือนได้';
        });
      }
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.isRead) return;

    try {
      // Optimistically update UI
      setState(() {
        final index = _notifications.indexWhere(
          (n) => n.notificationId == notification.notificationId,
        );
        if (index != -1) {
          _notifications[index] = NotificationModel(
            notificationId: notification.notificationId,
            title: notification.title,
            message: notification.message,
            type: notification.type,
            referenceId: notification.referenceId,
            isRead: true, // Update isRead status
            createdDate: notification.createdDate,
          );
        }
      });
      await ApiProvider().put(
        '/notifications/${notification.notificationId}/read',
        data: {},
      );
    } catch (e) {
      debugPrint('Failed to mark notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await ApiProvider().put('/notifications/read-all', data: {});
      _fetchNotifications(); // Refresh the list
    } catch (e) {
      debugPrint('Failed to mark all as read: $e');
    }
  }

  void _onNotificationTap(NotificationModel notification) {
    _markAsRead(notification);

    if (notification.referenceId == null) return;

    final role = Provider.of<UserRoleProvider>(
      context,
      listen: false,
    ).currentRole;

    if (role == Role.organizer) {
      switch (notification.type) {
        case 'JOIN_SESSION':
        case 'CANCEL_BOOKING':
        case 'PLAYER_CHECKIN':
        case 'PAYMENT_RECEIVED':
          context.push('/manage-game/${notification.referenceId}');
          break;
      }
    } else {
      switch (notification.type) {
        case 'MATCH_STARTING':
        case 'SESSION_UPDATED':
        case 'SESSION_CANCELLED':
        case 'PROMOTED_TO_ACTIVE':
        case 'REMOVED_FROM_SESSION':
        case 'PAYMENT_CONFIRMED_BY_ORGANIZER':
          context.push('/game-player/${notification.referenceId}');
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('การแจ้งเตือน'),
        actions: [
          if (_notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('อ่านทั้งหมด'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchNotifications,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return Center(child: Text(_error));
    }
    if (_notifications.isEmpty) {
      return const Center(child: Text('ไม่มีการแจ้งเตือน'));
    }

    return ListView.separated(
      itemCount: _notifications.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return ListTile(
          leading: !notification.isRead
              ? Icon(
                  Icons.circle,
                  color: Theme.of(context).primaryColor,
                  size: 12,
                )
              : const SizedBox(width: 12),
          title: Text(
            notification.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(notification.message),
              const SizedBox(height: 4),
              Text(
                timeago.format(notification.createdDate, locale: 'th'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          onTap: () => _onNotificationTap(notification),
        );
      },
    );
  }
}

import 'package:badminton/component/notification_provider.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/user_role.dart';
import 'package:flutter/material.dart';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dialog.dart';
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
      notificationId: json['notificationId'] is int ? json['notificationId'] : int.tryParse(json['notificationId']?.toString() ?? '0') ?? 0,
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      referenceId: json['referenceId'] is int ? json['referenceId'] : int.tryParse(json['referenceId']?.toString() ?? ''),
      isRead: json['isRead'] is bool ? json['isRead'] : (json['isRead']?.toString().toLowerCase() == 'true'),
      createdDate:
          DateTime.tryParse(json['createdDate']?.toString() ?? '')?.toLocal() ??
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
      final response = await ApiProvider().get('/Notifications');
      if (mounted && response['status'] == 200) {
        final data = response['data'] as List? ?? [];
        setState(() {
          _notifications = data
              .map((json) => NotificationModel.fromJson(json as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
        // ซิงค์จำนวนแจ้งเตือนที่ยังไม่อ่านกับ Provider
        if (mounted) Provider.of<NotificationProvider>(context, listen: false).fetchUnreadCount();
      } else {
        throw Exception(response['message'] ?? 'Failed to load notifications');
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'ไม่สามารถโหลดการแจ้งเตือนได้\n(${e.toString().replaceFirst('Exception: ', '')})';
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
        '/Notifications/${notification.notificationId}/read',
        data: {},
      );
      if (mounted) Provider.of<NotificationProvider>(context, listen: false).decrement();
    } catch (e) {
      debugPrint('Failed to mark notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await ApiProvider().put('/Notifications/read-all', data: {});
      _fetchNotifications(); // Refresh the list
      if (mounted) Provider.of<NotificationProvider>(context, listen: false).clear();
    } catch (e) {
      debugPrint('Failed to mark all as read: $e');
    }
  }

  Future<void> _deleteAll() async {
    showDialogMsg(
      context,
      title: 'ลบการแจ้งเตือนทั้งหมด',
      subtitle: 'คุณต้องการลบการแจ้งเตือนทั้งหมดใช่หรือไม่?',
      isWarning: true,
      btnLeft: 'ลบทั้งหมด',
      btnLeftBackColor: Colors.red,
      btnLeftForeColor: Colors.white,
      btnRight: 'ยกเลิก',
      onConfirm: () async {
        try {
          await ApiProvider().delete('/Notifications/delete-all');
          _fetchNotifications();
          if (mounted) Provider.of<NotificationProvider>(context, listen: false).clear();
        } catch (e) {
          debugPrint('Failed to delete all notifications: $e');
        }
      },
    );
  }

  Future<void> _onNotificationTap(NotificationModel notification) async {
    _markAsRead(notification);

    if (notification.referenceId == null) return;

    final role = Provider.of<UserRoleProvider>(
      context,
      listen: false,
    ).currentRole;

    // แสดงหน้าจอโหลดระหว่างเช็คสถานะก๊วน
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (role == Role.organizer) {
        final response = await ApiProvider().get('/GameSessions/${notification.referenceId}');
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop(); // ปิดหน้าโหลด
        
        if (response['status'] == 200 && response['data'] != null) {
          final int status = response['data']['status'] ?? 1;
          if (status == 1) {
            context.go('/manage'); // ยังไม่เปิดก๊วน -> ใช้ go() เพื่อกลับไปหน้าหลัก
          } else if (status == 2) {
            context.push('/manage-game/${notification.referenceId}'); // ก๊วนเปิดแล้ว -> ไปหน้ากระดานควบคุม
          } else {
            context.push('/history-organizer-payment', extra: notification.referenceId); // จบหรือยกเลิกแล้ว -> ไปหน้าประวัติ
          }
        }
      } else {
        // ฝั่งของผู้เล่น
        final response = await ApiProvider().get('/player/gamesessions/${notification.referenceId}');
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop();

        if (response['status'] == 200 && response['data'] != null) {
          final int status = response['data']['status'] ?? 1;
          final String userStatus = response['data']['currentUserStatus'] ?? 'NotJoined';

          if (status == 2 && userStatus == 'CheckedIn') {
            context.push('/game-player/${notification.referenceId}'); // ก๊วนเปิดและเช็คอินแล้ว -> หน้ากระดานคนเล่น
          } else if (status == 3 || status == 4 || userStatus == 'CheckedOut') {
            context.push('/history-detail/${notification.referenceId}'); // จบหรือจ่ายเงินแล้ว -> ไปหน้าประวัติ
          } else {
            context.go('/my-game-user'); // ยังไม่เปิด หรือยังไม่เช็คอิน -> ใช้ go() เพื่อกลับไปหน้าหลัก
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูลก๊วน')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppBarSubMain(
        title: 'การแจ้งเตือน',
        showNotification: false, // ซ่อนไอคอนกระดิ่งซ้ำซ้อนในหน้านี้
      ),
      body: Column(
        children: [
          if (_notifications.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_notifications.any((n) => !n.isRead))
                    TextButton(
                      onPressed: _markAllAsRead,
                      child: const Text('อ่านทั้งหมด'),
                    ),
                  TextButton(
                    onPressed: _deleteAll,
                    child: const Text('ลบทั้งหมด', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchNotifications,
              child: _buildBody(),
            ),
          ),
        ],
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

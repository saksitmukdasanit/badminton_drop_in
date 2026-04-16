import 'package:badminton/component/notification_page.dart';
import 'package:flutter/material.dart';

class OrganizerNotificationPage extends StatelessWidget {
  const OrganizerNotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    // This page is a simple wrapper around the shared NotificationPage.
    // The AppBar is handled inside NotificationPage itself.
    return const NotificationPage();
  }
}
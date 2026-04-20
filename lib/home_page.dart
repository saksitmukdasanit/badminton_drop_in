import 'package:badminton/page/organizer/home_organizer.dart';
import 'package:badminton/page/user/home_user.dart';
import 'package:badminton/shared/user_role.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentRole = context.watch<UserRoleProvider>().currentRole;

    // เลือกหน้า Home ที่จะแสดงผลตาม Role ของผู้ใช้
    if (currentRole == Role.organizer) {
      return const HomeOrganizerPage();
    }
    // Role.player หรือกรณีอื่นๆ จะไปที่หน้า Home ของผู้เล่น
    return const HomeUserPage();
  }
}
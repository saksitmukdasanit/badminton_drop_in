import 'package:badminton/component/loading_image_network.dart';
import 'package:badminton/shared/user_role.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';

import 'package:provider/provider.dart'; // สำหรับ ImageFilter

class BottomNavItem {
  final String iconPath;
  final String label;
  final String initialPath; // Path หลักเมื่อกดปุ่ม
  final List<String> activePaths; // Path ทั้งหมดที่เกี่ยวข้องกับเมนูนี้

  BottomNavItem({
    required this.iconPath,
    required this.label,
    required this.initialPath,
    required this.activePaths,
  });
}

class MenuBarPage extends StatelessWidget {
  final Widget child; // ตัวแปรสำหรับรับหน้าที่ต้องการแสดง

  MenuBarPage({super.key, required this.child});

  //--- ผู้ใช้ ----
  // --- เมนูสำหรับ Player ---
  final List<BottomNavItem> _playerMenuItems = [
    BottomNavItem(
      iconPath: 'assets/icon/home.png',
      label: 'Home',
      initialPath: '/',
      activePaths: const ['/'],
    ),
    BottomNavItem(
      iconPath: 'assets/icon/search.png',
      label: 'Find Team',
      initialPath: '/search-user',
      activePaths: const [
        '/search-user',
        '/player-list',
        '/booking-confirm',
        '/payment',
      ],
    ),
    BottomNavItem(
      iconPath: 'assets/icon/racket.png',
      label: 'My Game',
      initialPath: '/my-game-user',
      activePaths: const [
        '/my-game-user',
        '/booking-confirm-game',
        '/payment-cancel',
        '/payment-now',
      ],
    ),
    BottomNavItem(
      iconPath: 'assets/icon/history.png',
      label: 'History',
      initialPath: '/history-user',
      activePaths: const [
        '/history-user',
        '/booking-confirm-history',
        '/payment-history',
        '/history-detail',
      ],
    ),
    BottomNavItem(
      iconPath: 'assets/icon/profile.png',
      label: 'Profile',
      initialPath: '/profile-user',
      activePaths: const [
        '/profile-user',
        '/edit-profile-user',
        '/change-password',
        '/saved-payment',
        '/favourite',
        '/apply-organizer',
        '/login',
      ],
    ),
  ];

  //---- ผู้จัด ----
  final List<BottomNavItem> _organizerMenuItems = [
    BottomNavItem(
      iconPath: 'assets/icon/home.png',
      label: 'Home',
      initialPath: '/',
      activePaths: ['/'],
    ),
    BottomNavItem(
      iconPath: 'assets/icon/add_game.png',
      label: 'New Game',
      initialPath: '/new-game',
      activePaths: ['/new-game', '/add-game'],
    ),
    BottomNavItem(
      iconPath: 'assets/icon/manage.png',
      label: 'Manage',
      initialPath: '/manage',
      activePaths: ['/manage', '/manage-game'],
    ),
    BottomNavItem(
      iconPath: 'assets/icon/history.png',
      label: 'History',
      initialPath: '/history-organizer',
      activePaths: ['/history-organizer', '/history-organizer-payment'],
    ),
    BottomNavItem(
      iconPath: 'assets/icon/profile.png',
      label: 'Profile',
      initialPath: '/profile-organizer',
      activePaths: [
        '/profile-organizer',
        '/edit-profile-organizer',
        '/edit-transfer',
        '/edit-skill-level',
        '/finance',
      ],
    ), // ตัวอย่าง
  ];

  @override
  Widget build(BuildContext context) {
    final currentRole = context.watch<UserRoleProvider>().currentRole;
    final location = GoRouterState.of(context).uri.path;

    final List<BottomNavItem> activeMenuItems = currentRole == Role.player
        ? _playerMenuItems
        : _organizerMenuItems;

    int getCurrentIndex() {
      final index = activeMenuItems.indexWhere(
        (item) => item.activePaths.any(
          (path) => path == '/' ? location == path : location.startsWith(path),
        ),
      );

      return index == -1 ? 0 : index;
    }

    final selectedIndex = getCurrentIndex();

    // 1. กำหนดสี Gradient พื้นหลังให้เปลี่ยนตาม Role อัตโนมัติ
    final List<Color> gradientColors = currentRole == Role.player
        ? const [Color(0xFFFFFFFF), Color(0xFFCBF5EA)] // สีธีมสำหรับผู้เล่น
        : const [Color(0xFFFFFFFF), Color(0xFFE2E8F0)];

    return Scaffold(
      extendBody: true,
      // 2. ใส่พื้นหลังไว้ที่ MenuBar เป็นแกนหลักของแอป
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        // 3. ปิด bottom safe area เพื่อให้สีลากยาวไปสุดขอบจอด้านล่าง (ทะลุใต้เมนูลอย)
        child: SafeArea(top: false, bottom: false, child: child),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          left: 15,
          right: 15,
          bottom: 15 + MediaQuery.of(context).padding.bottom, // ระยะลอยจากขอบล่าง
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // เพิ่มระดับความเบลอ
            child: Container(
              height: 75, // เพิ่มความสูงเล็กน้อยเพื่อแก้ปัญหา RenderFlex overflow
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.85), // สีหลักแบบโปร่งแสง
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2), // เส้นขอบสีขาวบางๆ
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: activeMenuItems.asMap().entries.map((entry) {
                  int index = entry.key;
                  BottomNavItem item = entry.value;
                  return _buttonBottomBar(
                    context,
                    item.iconPath,
                    item.label,
                    index,
                    selectedIndex,
                    item.initialPath,
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buttonBottomBar(
    BuildContext context,
    String image,
    String title,
    int index,
    int selectedIndex,
    String path, {
    bool network = false,
  }) {
    final bool isSelected = index == selectedIndex;

    return Expanded(
      flex: isSelected ? 2 : 1, // ขยายพื้นที่เพิ่มเมื่อถูกเลือก
      child: InkWell(
        onTap: () {
          context.go(path);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 30,
              // padding: EdgeInsets.symmetric(horizontal: 0, vertical: 5),
              // margin: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: network
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(40),
                        child: LoadingImageNetwork(
                          image,
                          height: 20,
                          width: 20,
                        ),
                      )
                    : Image.asset(
                        image,
                        height: 20,
                        width: 20,
                        color: Color(0xFFFFFFFF),
                        // color: hasSelected ? Color(0xFFFFFFFF) : Colors.black,
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFFFFFFFF),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1, // ป้องกันการขึ้นบรรทัดใหม่ที่ทำให้ Layout พัง
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

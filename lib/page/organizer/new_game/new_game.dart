import 'dart:async';
import 'package:badminton/component/app_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NewGamePage extends StatefulWidget {
  const NewGamePage({super.key});

  @override
  NewGamePageState createState() => NewGamePageState();
}

class NewGamePageState extends State<NewGamePage> {
  late Future<dynamic> futureModel;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      appBar: AppBarSubMain(title: 'New Game', isBack: false),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFD5DCF4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // กำหนด breakpoint สำหรับการเปลี่ยน Layout (ปรับค่าได้ตามความเหมาะสม)
            const double tabletBreakpoint = 600.0;

            bool isTablet = constraints.maxWidth >= tabletBreakpoint;

            return Container(
              // พื้นหลังไล่ระดับสี
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE8EAF6), // สีฟ้าอ่อน
                    Color(0xFFF3E5F5), // สีม่วงอ่อน
                  ],
                ),
              ),
              child: isTablet
                  ? _buildTabletLayout() // Layout สำหรับจอใหญ่ (iPad)
                  : _buildMobileLayout(), // Layout สำหรับจอเล็ก (Mobile)
            );
          },
        ),
      ),
    );
  }

  // --- Layout สำหรับจอใหญ่ ---
  Widget _buildTabletLayout() {
    return const Row(
      children: [
        // 1. เมนูเลือกวัน (ด้านข้าง)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: _DaySelector(isVertical: true),
        ),
        // 2. เนื้อหาหลัก (ตรงกลาง)
        Expanded(child: Center(child: _MainContent())),
      ],
    );
  }

  // --- Layout สำหรับจอเล็ก ---
  Widget _buildMobileLayout() {
    return const Column(
      children: [
        // 1. เมนูเลือกวัน (ด้านบน, เลื่อนได้)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: _DaySelector(isVertical: false),
        ),
        // 2. เนื้อหาหลัก
        Expanded(child: Center(child: _MainContent())),
      ],
    );
  }
}

// --- Widget ย่อย: เนื้อหาหลัก (ปุ่ม 2 ปุ่ม) ---
class _MainContent extends StatelessWidget {
  const _MainContent();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 24.0, // ระยะห่างแนวนอน
      runSpacing: 24.0, // ระยะห่างแนวตั้ง (กรณีขึ้นบรรทัดใหม่)
      alignment: WrapAlignment.center,
      children: [
        _MainActionButton(
          icon: Icons.add_circle_outline,
          title: 'All New',
          subtitle: 'สร้างใหม่ทั้งหมด',
          onTap: () {
            context.push('/add-game/new');
          },
        ),
        _MainActionButton(
          icon: Icons.history,
          title: 'From History',
          subtitle: 'สร้างซ้ำจากที่เคย\nสร้างไว้แล้ว',
          onTap: () {},
        ),
      ],
    );
  }
}

// --- Widget ย่อย: เมนูเลือกวัน ---
class _DaySelector extends StatelessWidget {
  final bool isVertical;
  const _DaySelector({required this.isVertical});

  @override
  Widget build(BuildContext context) {
    // ข้อมูลวันจำลอง
    final List<Map<String, dynamic>> days = [
      {'code': 'Mon', 'day': 'M', 'isNew': false},
      {'code': 'Tue', 'day': 'T', 'isNew': false},
      {'code': 'Wed', 'day': 'W', 'isNew': false},
      {'code': 'Thu', 'day': 'T', 'isNew': false},
      {'code': 'Fri', 'day': 'F', 'isNew': false},
      {'code': 'Sat', 'day': 'S', 'isNew': true}, // วันที่มี badge +NEW
      {'code': 'Sun', 'day': 'S', 'isNew': false},
    ];

    // สร้าง list ของ widget ปุ่มวัน
    final dayWidgets = days
        .map(
          (day) => Padding(
            padding: isVertical
                ? const EdgeInsets.symmetric(vertical: 8.0)
                : const EdgeInsets.symmetric(horizontal: 8.0),
            child: _DayIcon(
              label: day['day'],
              isNew: day['isNew'],
              onTap: () {},
            ),
          ),
        )
        .toList();

    const titleWidget = Text(
      'สร้างก๊วนด่วน',
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );

    if (isVertical) {
      // Layout แนวตั้งสำหรับจอใหญ่
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [titleWidget, ...dayWidgets],
      );
    } else {
      // Layout แนวนอนสำหรับจอเล็ก (เลื่อนได้)
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [titleWidget, ...dayWidgets],
        ),
      );
    }
  }
}

// --- Widget ย่อย: ปุ่มวงกลมแสดงวัน ---
class _DayIcon extends StatelessWidget {
  final String label;
  final bool isNew;
  final VoidCallback? onTap;

  const _DayIcon({required this.label, this.isNew = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isNew
        ? Colors.green.shade600
        : Colors.indigo.shade800;
    final Color fgColor = Colors.white;

    // ใช้ Stack เพื่อวาง Badge "+NEW" ทับบนวงกลม
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: fgColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        if (isNew)
          Positioned(
            top: -4,
            right: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '+NEW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// --- Widget ย่อย: ปุ่ม Action หลัก (All New, From History) ---
class _MainActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _MainActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 180,
        height: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade700),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

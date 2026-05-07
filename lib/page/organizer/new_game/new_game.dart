import 'dart:async';
import 'dart:ui';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/page/organizer/new_game/from_history.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NewGamePage extends StatefulWidget {
  const NewGamePage({super.key});

  @override
  NewGamePageState createState() => NewGamePageState();
}

class NewGamePageState extends State<NewGamePage> {
  late Future<dynamic> futureModel;
  Map<int, dynamic> _latestGames = {}; // เก็บข้อมูลก๊วนล่าสุดของแต่ละวัน (1=Mon, 7=Sun)
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final response = await ApiProvider().get('/GameSessions/my-history');
      List<dynamic> listData = [];
      if (response is List) {
        listData = response;
      } else if (response is Map && response['data'] is List) {
        listData = response['data'];
      }

      Map<int, dynamic> tempLatest = {};

      for (var data in listData) {
        if (data['date'] != null) {
          DateTime date = DateTime.parse(data['date']);
          int weekday = date.weekday;
          
          // เก็บข้อมูลล่าสุดของวันนั้นๆ
          if (!tempLatest.containsKey(weekday)) {
            tempLatest[weekday] = data;
          } else {
            DateTime existingDate = DateTime.parse(tempLatest[weekday]['date']);
            if (date.isAfter(existingDate)) {
              tempLatest[weekday] = data;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _latestGames = tempLatest;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching history: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onDaySelected(int weekday) async {
    final game = _latestGames[weekday];
    // ถ้ามีประวัติ (เคยสร้างแล้ว) ให้ไปหน้า AddGame พร้อมข้อมูล
    if (game != null) {
      // แสดง Loading ด้วย State แทน showDialog เพื่อป้องกันจอดำ/ค้าง
      setState(() => _isLoading = true);

      try {
        // ดึงข้อมูลรายละเอียด
        final response = await ApiProvider().get('/GameSessions/${game['gameSessionId']}');

        Map<String, dynamic>? sessionData;
        if (response is Map) {
          sessionData = response['data'] ?? response;
        }

        if (sessionData != null && mounted) {
           DateTime now = DateTime.now();
           // คำนวณวันถัดไปของสัปดาห์
           int daysUntil = (weekday - now.weekday + 7) % 7;
           if (daysUntil == 0) daysUntil = 7;
           DateTime nextDate = now.add(Duration(days: daysUntil));

           context.push('/add-game/new', extra: {
             'sourceSessionId': game['gameSessionId'],
             'initialDate': nextDate,
             'sessionData': sessionData,
           });
        }
      } catch (e) {
        debugPrint('Error: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } 
    // ถ้ายังไม่เคยสร้าง (+NEW) ไม่ต้องทำอะไร (แสดงหน้า MainContent ปกติ)
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false, // ปิดการทะลุ Menu bar เพื่อป้องกันปุ่มโดนบัง
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

            // Menu bar ลอย: ~15 + 75 + 15 + safe area — ใช้ค่าจาก MediaQuery แทน magic number คงที่
            final double bottomClearance =
                MediaQuery.of(context).padding.bottom;
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
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomClearance),
                  child: isTablet
                      ? _buildTabletLayout() // Layout สำหรับจอใหญ่ (iPad)
                      : _buildMobileLayout(), // Layout สำหรับจอเล็ก (Mobile)
                ),
            );
          },
        ),
      ),
    );
  }

  // --- Layout สำหรับจอใหญ่ ---
  Widget _buildTabletLayout() {
    return Row(
      children: [
        // 1. เมนูเลือกวัน (ด้านข้าง)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: _DaySelector(
            isVertical: true,
            latestGames: _latestGames,
            onDaySelected: _onDaySelected,
          ),
        ),
        // 2. เนื้อหาหลัก (ตรงกลาง)
        Expanded(child: Center(child: _MainContent())),
      ],
    );
  }

  // --- Layout สำหรับจอเล็ก ---
  Widget _buildMobileLayout() {
    return Column(
      children: [
        // 1. เมนูเลือกวัน (ด้านบน, เลื่อนได้)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: _DaySelector(
            isVertical: false,
            latestGames: _latestGames,
            onDaySelected: _onDaySelected,
          ),
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
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const FromHistoryPage()),
            );
          },
        ),
        _MainActionButton(
          icon: Icons.repeat,
          title: 'Recurring',
          subtitle: 'ก๊วนประจำสัปดาห์',
          onTap: () => context.push('/recurring-templates'),
        ),
      ],
    );
  }
}

// --- Widget ย่อย: เมนูเลือกวัน ---
class _DaySelector extends StatelessWidget {
  final bool isVertical;
  final Map<int, dynamic> latestGames;
  final Function(int) onDaySelected;

  const _DaySelector({
    required this.isVertical,
    required this.latestGames,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    
    // กำหนดสีประจำวัน
    final List<Color> dayColors = [
      Colors.yellow.shade600, // 1=Mon
      Colors.pink.shade400,   // 2=Tue
      Colors.green.shade500,  // 3=Wed
      Colors.orange.shade500, // 4=Thu
      Colors.blue.shade500,   // 5=Fri
      Colors.purple.shade500, // 6=Sat
      Colors.red.shade500,    // 7=Sun
    ];

    // สร้าง list ของ widget ปุ่มวัน
    final dayWidgets = List.generate(7, (index) {
      int weekday = index + 1; // 1=Mon, 7=Sun
      bool hasHistory = latestGames.containsKey(weekday);
      bool isNew = !hasHistory;

      return Padding(
        padding: isVertical
            ? const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0)
            : const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
        child: _DayIcon(
          label: dayLabels[index],
          isNew: isNew,
          dayColor: dayColors[index],
          onTap: () => onDaySelected(weekday),
        ),
      );
    });

    const titleWidget = Text(
      'สร้างก๊วนด่วน',
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );

    if (isVertical) {
      // Layout แนวตั้งสำหรับจอใหญ่
      return SingleChildScrollView(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [titleWidget, const SizedBox(height: 16), ...dayWidgets],
        ),
      );
    } else {
      // Layout แนวนอนสำหรับจอเล็ก (เลื่อนได้)
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [titleWidget, const SizedBox(width: 16), ...dayWidgets],
        ),
      );
    }
  }
}

// --- Widget ย่อย: ปุ่มวงกลมแสดงวัน ---
class _DayIcon extends StatelessWidget {
  final String label;
  final bool isNew;
  final Color dayColor;
  final VoidCallback? onTap;

  const _DayIcon({required this.label, this.isNew = false, required this.dayColor, this.onTap});

  @override
  Widget build(BuildContext context) {
    // ตรวจสอบถ้าเป็นวันจันทร์ (สีเหลือง) ให้ใช้ตัวหนังสือสีดำเพื่อให้อ่านง่าย
    final bool isYellow = dayColor == Colors.yellow.shade600;
    final Color fgColor = (!isNew && isYellow) ? Colors.black87 : Colors.white;

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
            decoration: BoxDecoration(
              color: isNew ? Colors.white.withValues(alpha: 0.6) : dayColor,
              shape: BoxShape.circle,
              border: isNew ? Border.all(color: Colors.grey.shade400, width: 1.5) : null,
              boxShadow: !isNew
                  ? [
                      BoxShadow(
                        color: dayColor.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ]
                  : [],
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: isNew ? Colors.grey.shade700 : fgColor,
                  fontSize: 22,
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              ),
              child: const Text(
                '+NEW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
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
      borderRadius: BorderRadius.circular(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0), // เอฟเฟกต์ Glassmorphism
          child: Container(
            width: 160,
            height: 160,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  spreadRadius: 0,
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

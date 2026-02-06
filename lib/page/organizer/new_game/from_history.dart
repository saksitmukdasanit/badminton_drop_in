import 'dart:async';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HistoryGameModel {
  final int id; // เพิ่ม ID เพื่อใช้ดึงข้อมูลตอนจะสร้างใหม่
  final DateTime date;
  final String groupName;
  final String startTime;
  final String endTime;
  final String courtName;
  final int price;
  final int currentPlayers;
  final int maxPlayers;
  final int totalCourts;

  HistoryGameModel({
    required this.id,
    required this.date,
    required this.groupName,
    required this.startTime,
    required this.endTime,
    required this.courtName,
    required this.price,
    required this.currentPlayers,
    required this.maxPlayers,
    required this.totalCourts,
  });
}

class FromHistoryPage extends StatefulWidget {
  const FromHistoryPage({super.key});

  @override
  State<FromHistoryPage> createState() => _FromHistoryPageState();
}

class _FromHistoryPageState extends State<FromHistoryPage> {
  DateTime _focusedDate = DateTime.now();
  bool _isLoading = false;
  
  // Mock Data
  List<HistoryGameModel> _historyGames = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiProvider().get('/GameSessions/my-history');
      
      List<dynamic> listData = [];
      if (response is List) {
        listData = response;
      } else if (response is Map && response['data'] is List) {
        listData = response['data'];
      }

      if (listData.isNotEmpty) {
        setState(() {
          _historyGames = listData.map((data) {
            DateTime date = DateTime.now();
            // C# ส่งมาเป็น 'date' (DateTime)
            if (data['date'] != null) {
              try {
                date = DateTime.parse(data['date']);
              } catch (_) {}
            }
            return HistoryGameModel(
              id: data['gameSessionId'] ?? 0, // Map กับ GameSessionId
              date: date,
              groupName: data['groupName'] ?? '',
              startTime: data['startTime'] ?? '',
              endTime: data['endTime'] ?? '',
              courtName: data['venueName'] ?? '', // Map กับ VenueName
              price: num.tryParse(data['price']?.toString() ?? '0')?.toInt() ?? 0, // Map กับ Price
              currentPlayers: num.tryParse(data['totalParticipants']?.toString() ?? '0')?.toInt() ?? 0, // Map กับ TotalParticipants
              maxPlayers: 0, // Backend ไม่ได้ส่ง MaxParticipants มาใน DTO นี้ (อาจต้องดึงเพิ่มทีหลัง)
              totalCourts: num.tryParse(data['totalCourts']?.toString() ?? '0')?.toInt() ?? 0, // Map กับ TotalCourts
            );
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching history: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onGameSelected(HistoryGameModel game) async {
    // ใช้ตัวแปร State ควบคุม Loading แทน showDialog เพื่อป้องกันปัญหา Dialog ค้าง
    setState(() => _isLoading = true);

    try {
      // ดึงข้อมูลรายละเอียดทั้งหมดของก๊วนก่อน
      // เพิ่ม Timeout 10 วินาที ป้องกันการค้าง
      final response = await ApiProvider().get('/GameSessions/${game.id}')
          .timeout(const Duration(seconds: 10));

      Map<String, dynamic>? sessionData;
      if (response is Map) {
        sessionData = response['data'] ?? response;
      }

      if (mounted && sessionData != null) {
        DateTime now = DateTime.now();
        int daysUntil = (game.date.weekday - now.weekday + 7) % 7;
        if (daysUntil == 0) {
          daysUntil = 7;
        }
        DateTime nextDate = now.add(Duration(days: daysUntil));

        context.push(
          '/add-game/new',
          extra: {
            'sourceSessionId': game.id,
            'initialDate': nextDate,
            'sessionData': sessionData, // ส่งข้อมูลทั้งหมดไปด้วย
          },
        );
      }
    } catch (e) {
      debugPrint('Error fetching session details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถดึงข้อมูลรายละเอียดได้ กรุณาลองใหม่')),
        );
      }
    } finally {
      // มั่นใจได้ว่า Loading จะถูกปิดเสมอ
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBarSubMain(title: 'ประวัติการสร้าง', isBack: true),
      body: Column(
        children: [
          _buildMonthHeader(),
          _buildDaysOfWeek(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildCalendarGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthHeader() {
    // แสดงชื่อเดือนแบบง่ายๆ
    const List<String> months = [
      'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
      'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'
    ];
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _focusedDate =
                    DateTime(_focusedDate.year, _focusedDate.month - 1);
              });
            },
          ),
          Text(
            '${months[_focusedDate.month - 1]} ${_focusedDate.year + 543}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _focusedDate =
                    DateTime(_focusedDate.year, _focusedDate.month + 1);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDaysOfWeek() {
    const days = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];
    return Row(
      children: days
          .map((day) => Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = DateUtils.getDaysInMonth(_focusedDate.year, _focusedDate.month);
    final firstDayOfMonth = DateTime(_focusedDate.year, _focusedDate.month, 1);
    final int weekdayOffset = firstDayOfMonth.weekday - 1; // Mon=1 -> index 0
    final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: isLandscape ? 1.1 : 0.6, // แนวนอนให้เตี้ยลง (1.1), แนวตั้งให้สูง (0.6)
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: daysInMonth + weekdayOffset,
      itemBuilder: (context, index) {
        if (index < weekdayOffset) {
          return const SizedBox();
        }
        final day = index - weekdayOffset + 1;
        final currentDate = DateTime(_focusedDate.year, _focusedDate.month, day);
        
        // หาข้อมูลก๊วนในวันนี้
        final game = _historyGames.firstWhere(
          (g) => isSameDay(g.date, currentDate),
          orElse: () => HistoryGameModel(
            date: currentDate,
            groupName: '',
            id: 0,
            startTime: '',
            endTime: '',
            courtName: '',
            price: 0,
            currentPlayers: 0,
            maxPlayers: 0,
            totalCourts: 0,
          ),
        );

        final bool hasGame = game.groupName.isNotEmpty;

        return _CalendarCell(
          day: day,
          date: currentDate,
          game: hasGame ? game : null,
          onTap: hasGame ? () => _onGameSelected(game) : null,
        );
      },
    );
  }

  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _CalendarCell extends StatelessWidget {
  final int day;
  final DateTime date;
  final HistoryGameModel? game;
  final VoidCallback? onTap;

  const _CalendarCell({
    required this.day,
    required this.date,
    this.game,
    this.onTap,
  });

  // ฟังก์ชันคืนค่าสีพื้นหลังตามวันในสัปดาห์
  Color _getDayBackgroundColor(int weekday) {
    switch (weekday) {
      case 1: return const Color(0xFFFFF9C4); // Mon - Yellow
      case 2: return const Color(0xFFF8BBD0); // Tue - Pink
      case 3: return const Color(0xFFC8E6C9); // Wed - Green
      case 4: return const Color(0xFFFFE0B2); // Thu - Orange
      case 5: return const Color(0xFFBBDEFB); // Fri - Blue
      case 6: return const Color(0xFFE1BEE7); // Sat - Purple
      case 7: return const Color(0xFFFFCDD2); // Sun - Red
      default: return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasGame = game != null;
    final Color bgColor = hasGame ? _getDayBackgroundColor(date.weekday) : Colors.white;
    final Color borderColor = hasGame ? Colors.grey.shade300 : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      onLongPress: hasGame
          ? () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(game!.groupName),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('เวลา: ${game!.startTime} - ${game!.endTime}'),
                      Text('สนาม: ${game!.courtName}'),
                      const SizedBox(height: 8),
                      Row(children: [
                        Icon(Icons.monetization_on,
                            size: 16, color: Colors.green[700]),
                        const SizedBox(width: 4),
                        Text('${game!.price} บาท'),
                      ]),
                      Row(children: [
                        Icon(Icons.people, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 4),
                        Text('${game!.currentPlayers} คน'),
                      ]),
                      Row(children: [
                        Icon(Icons.stadium, size: 16, color: Colors.orange[700]),
                        const SizedBox(width: 4),
                        Text('${game!.totalCourts} สนาม'),
                      ]),
                    ],
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('ปิด')),
                    ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          if (onTap != null) onTap!();
                        },
                        child: const Text('สร้างรายการนี้')),
                  ],
                ),
              );
            }
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: hasGame ? Colors.black87 : Colors.grey,
                fontSize: 12,
              ),
            ),
            if (hasGame) ...[
              const SizedBox(height: 2),
              Text(
                game!.groupName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Text(
                '${game!.startTime}-${game!.endTime}',
                style: const TextStyle(fontSize: 10),
              ),
              Text(
                game!.courtName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Price
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.monetization_on, size: 12, color: Colors.green[700]),
                        const SizedBox(width: 1),
                        Expanded(child: Text('${game!.price}', style: const TextStyle(fontSize: 9), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                  // Players
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.people, size: 12, color: Colors.blue[700]),
                        const SizedBox(width: 1),
                        Expanded(child: Text('${game!.currentPlayers}', style: const TextStyle(fontSize: 9), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                  // Courts
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.stadium, size: 12, color: Colors.orange[700]),
                        const SizedBox(width: 1),
                        Expanded(child: Text('${game!.totalCourts}', style: const TextStyle(fontSize: 9), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }
}
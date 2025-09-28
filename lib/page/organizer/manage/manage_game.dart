import 'dart:async';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/button.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/player_avatar.dart';
import 'package:badminton/model/player.dart';
import 'package:badminton/widget/expense_panel.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// file: models.dart (สมมติว่าไฟล์นี้ถูก import เข้ามา)
enum CourtStatus { waiting, playing, paused }

class PlayingCourt {
  final int courtNumber;
  List<Player?> players = List.filled(4, null);
  CourtStatus status = CourtStatus.waiting;
  Duration elapsedTime = Duration.zero;
  bool isLocked = false;

  PlayingCourt({required this.courtNumber});
}

class ReadyTeam {
  final int id;
  List<Player?> players = List.filled(4, null);
  bool isLocked = false;

  ReadyTeam({required this.id});
}
// จบส่วนของไฟล์ models.dart

class ManageGamePage extends StatefulWidget {
  final String id;
  const ManageGamePage({super.key, required this.id});

  @override
  State<ManageGamePage> createState() => _ManageGamePage();
}

class _ManageGamePage extends State<ManageGamePage> {
  // --- 1. STATE MANAGEMENT: ข้อมูลทั้งหมดของหน้าจอ ---
  List<PlayingCourt> playingCourts = List.generate(
    3,
    (index) => PlayingCourt(courtNumber: index + 1),
  );
  List<ReadyTeam> readyTeams = List.generate(
    3,
    (index) => ReadyTeam(id: index + 1),
  );
  List<Player> waitingPlayers = List.generate(
    20,
    (index) => Player(
      id: 'p$index',
      name: 'Bua',
      imageUrl: 'https://i.pravatar.cc/150?u=p$index',
      level: (index % 8) + 1,
      // เพิ่มข้อมูลตัวอย่าง
      gamesPlayed: 15 + index,
      totalPlayTime: Duration(hours: 8 + index, minutes: 30 + (index * 5)),
      fullName: 'บัว (อรัสยา แสนดี)',
      emergencyContactName: 'สมสวย แสนดี',
      emergencyContactPhone: '0879955123',
      shuttlesUsed: 4 + index,
      waitingTime: Duration(minutes: 10, seconds: 15),
      gameHistory: [
        GameHistory(
          gameNumber: 1,
          courtInfo: '1, 4',
          partner: 'เจน',
          opponents: ['นุ่น', 'โบว์'],
        ),
        GameHistory(
          gameNumber: 2,
          courtInfo: '1, 4',
          partner: 'เจน',
          opponents: ['นุ่น', 'โบว์'],
        ),
        GameHistory(
          gameNumber: 3,
          courtInfo: '1, 4',
          partner: 'เจน',
          opponents: ['นุ่น', 'โบว์'],
        ),
      ],
    ),
  );
  List<Player> selectedPlayers = [];
  final Map<int, Timer> _timers = {};
  final GlobalKey _fabKey = GlobalKey(); // Key สำหรับหาตำแหน่งของ FAB
  OverlayEntry? _fabMenuOverlay; // ตัวแปรสำหรับเก็บเมนู Overlay ของเรา
  bool _isRosterPanelVisible = false;
  Player? _viewingPlayer;
  Player? _playerForExpenses;
  bool _isStartGame = false;

  @override
  void dispose() {
    _timers.forEach((key, timer) => timer.cancel());
    super.dispose();
  }

  // --- 2. TIMER LOGIC: ฟังก์ชันสำหรับจัดการเวลา ---
  void _startTimer(PlayingCourt court) {
    _timers[court.courtNumber]?.cancel();
    setState(() {
      court.status = CourtStatus.playing;
      court.isLocked = true; // <<< NEW: ล็อกสนามเมื่อเกมเริ่ม
    });
    _timers[court.courtNumber] = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      if (mounted) {
        setState(() {
          court.elapsedTime += const Duration(seconds: 1);
        });
      }
    });
  }

  void _pauseTimer(PlayingCourt court) {
    _timers[court.courtNumber]?.cancel();
    if (mounted) {
      setState(() {
        court.status = CourtStatus.paused;
        court.isLocked = false; // ปลดล็อกสนามเพื่อให้เปลี่ยนผู้เล่นได้
      });
    }
  }

  void _endGame(PlayingCourt court) {
    _timers[court.courtNumber]?.cancel();
    if (mounted) {
      setState(() {
        // --- ส่วนที่เพิ่มเข้ามา ---
        // 1. วนลูปเพื่อย้ายผู้เล่นทุกคนในสนามกลับไปที่ waitingPlayers list
        for (var player in court.players) {
          if (player != null) {
            // คืนผู้เล่นกลับไปที่ List ผู้เล่นที่รอ
            if (!waitingPlayers.contains(player)) {
              waitingPlayers.add(player);
            }
            // ถ้าผู้เล่นคนนี้เคยถูกเลือกไว้ ให้เอาออกจาก selected list ด้วย
            selectedPlayers.remove(player);
          }
        }

        // --- ส่วนโค้ดเดิมที่ปรับปรุง ---
        // 2. รีเซ็ตสถานะทั้งหมดของสนาม
        court.status = CourtStatus.waiting;
        court.isLocked = false;
        court.elapsedTime = Duration.zero;

        // 3. เคลียร์ผู้เล่นทั้งหมดออกจากสนาม
        court.players = List.filled(4, null);
      });
    }
  }

  Future<void> _showPauseOrEndGameDialog(PlayingCourt court) async {
    return showDialogMsg(
      context,
      title: 'หยุดเกม',
      subtitle: 'คุณต้องการหยุดชั่วคราว หรือ จบเกมนี้?',
      isWarning: true,
      btnLeft: 'จบเกม',
      btnLeftBackColor: Color(0xFFFFFFFF),
      btnLeftForeColor: Color(0xFF0E9D7A),
      btnRight: 'หยุดชั่วคราว',
      onConfirm: () {
        _endGame(court);
      },
      onConfirmRight: () {
        _pauseTimer(court);
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  void _placeSelectedPlayers(dynamic courtOrTeam) {
    if (selectedPlayers.isEmpty) {
      return; // ถ้าไม่มีผู้เล่นที่เลือกไว้ ก็ไม่ต้องทำอะไร
    }

    // ตรวจสอบก่อนว่าทีมถูกล็อกหรือไม่
    if (courtOrTeam is ReadyTeam && courtOrTeam.isLocked) return;

    setState(() {
      // สร้าง List ของผู้เล่นที่จะย้าย เพื่อไม่ให้เกิดปัญหาตอนวนลูปแล้วลบ item
      final playersToMove = List<Player>.from(selectedPlayers);

      for (var player in playersToMove) {
        // หาช่องว่างช่องแรกในสนาม
        int emptySlotIndex = courtOrTeam.players.indexOf(null);
        if (emptySlotIndex != -1) {
          // ถ้าเจอช่องว่าง ให้ย้ายผู้เล่น
          courtOrTeam.players[emptySlotIndex] = player;
          waitingPlayers.remove(player);
          selectedPlayers.remove(player);
        } else {
          // ถ้าสนามเต็มแล้ว ให้หยุดวนลูป
          break;
        }
      }
    });
  }

  void _onPlayerTap(Player player) {
    setState(() {
      final isSelected = selectedPlayers.contains(player);
      if (isSelected) {
        selectedPlayers.remove(player);
      } else {
        if (selectedPlayers.length < 4) {
          selectedPlayers.add(player);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('เลือกผู้เล่นได้สูงสุด 4 คน'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    });
  }

  void _removePlayerFromCourt(dynamic courtOrTeam, int slotIndex) {
    setState(() {
      Player? playerToRemove = courtOrTeam.players[slotIndex];
      if (playerToRemove != null) {
        // นำผู้เล่นออกจากสนาม
        courtOrTeam.players[slotIndex] = null;
        // คืนผู้เล่นกลับไปที่ List ผู้เล่นที่รอ
        if (!waitingPlayers.contains(playerToRemove)) {
          waitingPlayers.add(playerToRemove);
        }
        // ถ้าผู้เล่นคนนี้ถูกเลือกอยู่ ให้เอาออกจาก List ที่เลือกด้วย
        selectedPlayers.remove(playerToRemove);
      }
    });
  }

  // --- 3. MAIN BUILD METHOD: โครงสร้างหลักของหน้าจอ ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarSubMain(title: 'จัดการก๊วนแมวเหมียว'),
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildSectionTitle('สนาม'), // เปลี่ยนชื่อ Section ให้สั้นลง
                const SizedBox(height: 8),
                _buildSyncedCourtsList(), // Widget หลักที่แสดงสนามทั้งหมด
                const SizedBox(height: 24),
                _buildSectionTitle(
                  'ผู้เล่นที่รอ',
                ), // เปลี่ยนชื่อ Section ให้สั้นลง
                const SizedBox(height: 8),
                _buildWaitingPlayersGrid(),
              ],
            ),
          ),

          // Roster Panel
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: 0,
            bottom: 0,
            right: _isRosterPanelVisible ? 0 : -365, // -460 คือซ่อนไปทางขวา
            child: RosterManagementPanel(
              // ส่ง callback ไปให้ Panel เพื่อให้มันสั่งปิดตัวเองได้
              onClose: () {
                setState(() {
                  _isRosterPanelVisible = false;
                });
              },
            ),
          ),

          // Player Profile Panel
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top:
                MediaQuery.of(context).size.height *
                (MediaQuery.of(context).size.width > 820 ? 0.2 : 0.5),
            bottom: 0,
            // จะแสดง Panel ก็ต่อเมื่อ _viewingPlayer ไม่ใช่ null
            right: _viewingPlayer != null ? 0 : -365,
            child: PlayerProfilePanel(
              // ส่งข้อมูลผู้เล่นที่กำลังดูเข้าไป
              player: _viewingPlayer,
              onClose: () {
                setState(() {
                  _viewingPlayer = null; // สั่งปิดโดยการเคลียร์ข้อมูล
                });
              },
              onShowExpenses: (player) {
                setState(() {
                  _viewingPlayer = null; // สั่งปิด Profile Panel
                  _playerForExpenses = player; // สั่งเปิด Expense Panel
                });
              },
            ),
          ),

          // Expense Panel
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: 0,
            bottom: 0,
            right: _playerForExpenses != null
                ? 0
                : -460, // ควบคุมด้วย State ใหม่
            child: ExpensePanel(
              player: _playerForExpenses,
              onClose: () {
                setState(() {
                  _playerForExpenses = null; // สั่งปิด Expense Panel
                });
              },
            ),
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            bottom: 20,
            right: _isRosterPanelVisible
                ? 375
                : _viewingPlayer != null
                ? 430
                : _playerForExpenses != null
                ? 460
                : 20,
            child: Builder(
              key: _fabKey, // ผูก Key เข้ากับปุ่ม
              builder: (context) {
                return FloatingActionButton(
                  onPressed: _toggleFabMenu, // เรียกใช้ฟังก์ชันเปิด/ปิดเมนู
                  backgroundColor: Colors.indigo, // เปลี่ยนสีให้ตรงตามดีไซน์
                  child: const Icon(Icons.menu, color: Colors.white),
                );
              },
            ),
          ),
        ],
      ),

      // floatingActionButton: Builder(
      //   // ใช้ Builder เพื่อให้มี context ของตัวเอง
      //   key: _fabKey, // ผูก Key เข้ากับปุ่ม
      //   builder: (context) {
      //     return FloatingActionButton(
      //       onPressed: _toggleFabMenu, // เรียกใช้ฟังก์ชันเปิด/ปิดเมนู
      //       backgroundColor: Colors.indigo, // เปลี่ยนสีให้ตรงตามดีไซน์
      //       child: const Icon(Icons.menu, color: Colors.white),
      //     );
      //   },
      // ),
    );
  }

  // --- 4. UI BUILDERS: ฟังก์ชันสำหรับสร้างส่วนต่างๆ ของ UI ---

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildSyncedCourtsList() {
    const double cardHeight = 230; // เพิ่มความสูง
    const double spacing = 12;
    const double totalHeight = cardHeight + spacing + cardHeight;
    const double cardWidth = 210; // เพิ่มความกว้าง

    return SizedBox(
      height: totalHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: playingCourts.length + 1,
        itemBuilder: (context, index) {
          if (index == playingCourts.length) {
            return _buildAddCourtButton(height: totalHeight, width: cardWidth);
          }
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: Column(
                children: [
                  _buildCourtCard(playingCourts[index]),
                  const SizedBox(height: spacing),
                  _buildReadyTeamCard(readyTeams[index]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddCourtButton({required double height, required double width}) {
    return InkWell(
      onTap: () {
        setState(() {
          playingCourts.add(
            PlayingCourt(courtNumber: playingCourts.length + 1),
          );
          readyTeams.add(ReadyTeam(id: readyTeams.length + 1));
        });
      },
      child: Container(
        width: width,
        height: height,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: Colors.grey[350],
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 40),
      ),
    );
  }

  Widget _buildCourtCard(PlayingCourt court) {
    // กำหนดสีเพื่อการจัดการที่ง่าย
    const Color topColor = Color(0xFF2E9A8A);
    const Color bottomColor = Color(0xFF2A3A8A);

    final bool isFull = court.players.every((p) => p != null);
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero, // ใช้ margin จาก parent แทน
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias, // ทำให้ child ถูกตัดตามขอบมนของ Card
        elevation: 4,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // --- Layer 1: พื้นหลังสีเขียวและน้ำเงิน ---
            Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(child: _buildTopHalf(court, topColor)),
                Expanded(child: _buildBottomHalf(court, bottomColor)),
              ],
            ),
            // --- Layer 2: ปุ่ม Pause ตรงกลาง ---
            _buildCenterPauseButton(court, isFull: isFull),

            // Layer 3: Overlay สีขาวจางๆ
            if (court.status == CourtStatus.playing)
              Positioned.fill(
                child: InkWell(
                  onTap: () {
                    if (court.status == CourtStatus.playing) {
                      // ถ้ากำลังเล่นอยู่ กดหยุดได้เสมอ
                      _showPauseOrEndGameDialog(court);
                    } else if (isFull) {
                      // ถ้ายังไม่เริ่ม จะเริ่มได้ก็ต่อเมื่อผู้เล่นเต็ม
                      _startTimer(court);
                    } else {
                      // ถ้าผู้เล่นไม่เต็ม ให้แสดงข้อความ
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'ต้องมีผู้เล่นครบ 4 คนจึงจะเริ่มเกมได้',
                          ),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2), // สีขาวโปร่งแสง
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  // --- NEW: สร้าง Helper Widget เพื่อให้โค้ดสะอาดขึ้น ---

  // Widget สำหรับสร้างครึ่งบน (สีเขียว)
  Widget _buildTopHalf(PlayingCourt court, Color backgroundColor) {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          // --- แถวควบคุมด้านบนสุด ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.remove_circle_outline, color: Colors.white),
                  SizedBox(width: 3),
                  Icon(
                    Icons.sports_tennis_sharp,
                    color: Colors.white,
                  ), // ใช้ไอคอนเทนนิสแทนลูกแบด
                  SizedBox(width: 3),
                  Icon(Icons.add_circle_outline, color: Colors.white),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withOpacity(0.8)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '0',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // --- ช่องผู้เล่น ---
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPlayerSlot(court, 0),
                _buildPlayerSlot(court, 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget สำหรับสร้างครึ่งล่าง (สีน้ำเงิน)
  Widget _buildBottomHalf(PlayingCourt court, Color backgroundColor) {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // --- ช่องผู้เล่น ---
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPlayerSlot(court, 2),
                _buildPlayerSlot(court, 3),
              ],
            ),
          ),
          // --- แถวข้อมูลด้านล่างสุด ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(court.elapsedTime),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'สนาม ${court.courtNumber}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget สำหรับสร้างปุ่ม Pause ตรงกลาง
  Widget _buildCenterPauseButton(PlayingCourt court, {required bool isFull}) {
    // ตรวจสอบว่ากำลังเล่นอยู่หรือไม่
    bool isPlaying = court.status == CourtStatus.playing;

    return InkWell(
      onTap: () {
        if (isPlaying) {
          // ถ้ากำลังเล่นอยู่ กดหยุดได้เสมอ
          _showPauseOrEndGameDialog(court);
        } else if (isFull) {
          // ถ้ายังไม่เริ่ม จะเริ่มได้ก็ต่อเมื่อผู้เล่นเต็ม
          _startTimer(court);
        } else {
          // ถ้าผู้เล่นไม่เต็ม ให้แสดงข้อความ
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ต้องมีผู้เล่นครบ 4 คนจึงจะเริ่มเกมได้'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        // ใช้ Icon แทน Text เพื่อความสวยงาม
        child: Icon(
          isPlaying ? Icons.pause : Icons.play_arrow,
          color: isPlaying
              ? Colors.blueAccent
              : (isFull ? Colors.green : Colors.grey),
          size: 24,
        ),
      ),
    );
  }

  Widget _buildReadyTeamCard(ReadyTeam team) {
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero, // ใช้ margin จาก parent แทน
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias, // ทำให้ child ถูกตัดตามขอบมนของ Card
        elevation: 4,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              color: Color(0xFF64646D),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --- แถวผู้เล่นด้านบน ---
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildPlayerSlot(team, 0), // ตำแหน่ง A
                        _buildPlayerSlot(team, 1), // ตำแหน่ง B
                      ],
                    ),
                  ),

                  // --- เส้นคั่นกลางพร้อมหมายเลขและไอคอนล็อก ---
                  // _buildDividerWithNumber(team),

                  // --- แถวผู้เล่นด้านล่าง ---
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildPlayerSlot(team, 2), // ตำแหน่ง C
                        _buildPlayerSlot(team, 3), // ตำแหน่ง D
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildDividerWithNumber(team),
            if (team.isLocked)
              Positioned.fill(
                child: InkWell(
                  onTap: () {
                    showDialogMsg(
                      context,
                      title: 'ปลดล็อค',
                      subtitle: 'คุณต้องการปลดล็อคหรือไม่?',
                      isWarning: true,
                      btnLeft: 'ปลดล็อค',
                      btnLeftForeColor: Color(0xFFFFFFFF),
                      btnLeftBackColor: Color(0xFF0E9D7A),
                      // btnRight: 'หยุดชั่วคราว',
                      onConfirm: () {
                        setState(() => team.isLocked = !team.isLocked);
                      },
                      // onConfirmRight: () {
                      //   _pauseTimer(court);
                      // },
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(
                        0.4,
                      ), // Overlay สีดำโปร่งแสง
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- NEW: ฟังก์ชันใหม่สำหรับสร้างเส้นคั่นกลาง ---
  Widget _buildDividerWithNumber(ReadyTeam team) {
    bool isFull = team.players.every((p) => p != null);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Colors.white, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isFull)
                  InkWell(
                    onTap: () => setState(() => team.isLocked = !team.isLocked),
                    child: Icon(
                      team.isLocked ? Icons.lock : Icons.lock_open,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
          const Expanded(child: Divider(color: Colors.white, thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildWaitingPlayersGrid() {
    return Wrap(
      spacing: 8.0,
      runSpacing: 12.0,
      children: waitingPlayers.map((player) {
        final isSelected = selectedPlayers.contains(player);
        final selectionOrder = isSelected
            ? selectedPlayers.indexOf(player) + 1
            : 0;
        final dynamic dragData = isSelected ? selectedPlayers : player;

        return Draggable<Object>(
          data: dragData,
          feedback: isSelected
              ? _buildGroupDragFeedback(selectedPlayers)
              : _buildPlayerAvatar(player, isDragging: true),
          childWhenDragging: Opacity(
            opacity: 0.5,
            child: _buildPlayerAvatar(player),
          ),
          onDragEnd: (details) {},
          child: GestureDetector(
            onTap: () => _onPlayerTap(player),
            onLongPress: () {
              setState(() {
                _viewingPlayer = player;
              });
            },
            child: _buildPlayerAvatar(
              player,
              isSelected: isSelected,
              selectionOrder: selectionOrder,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGroupDragFeedback(List<Player> players) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(
          players.length > 3 ? 3 : players.length, // แสดงสูงสุด 3 คน
          (index) => Positioned(
            top: (index * 15).toDouble(),
            left: (index * 15).toDouble(),
            child: _buildPlayerAvatar(players[index], isDragging: true),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerAvatar(
    Player player, {
    bool isDragging = false,
    bool isSelected = false,
    int selectionOrder = 0,
  }) {
    return SizedBox(
      width: 90,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PlayerAvatar(player: player),

          // --- Layer 3: Overlay เมื่อถูกเลือก ---
          if (isSelected && !isDragging)
            Container(
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.75),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Center(
                child: Text(
                  '$selectionOrder',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayerSlot(dynamic courtOrTeam, int slotIndex) {
    bool isLocked =
        (courtOrTeam is ReadyTeam && courtOrTeam.isLocked) ||
        (courtOrTeam is PlayingCourt && courtOrTeam.isLocked);
    Player? player = courtOrTeam.players[slotIndex];

    return DragTarget<Object>(
      builder: (context, candidateData, rejectedData) {
        if (player != null) {
          final isSelected = selectedPlayers.contains(player);
          // --- REQUIREMENT 1: คำนวณลำดับ ---
          final selectionOrder = isSelected
              ? selectedPlayers.indexOf(player) + 1
              : 0;

          if (isLocked) return _buildPlayerAvatar(player);
          return GestureDetector(
            onTap: () {
              if (isLocked) return; // ถ้าล็อกอยู่จะกดเลือกไม่ได้
              _onPlayerTap(player);
            },
            onLongPress: () {
              if (isLocked) return;
              setState(() {
                _viewingPlayer =
                    player; // เมื่อกดค้าง ให้แสดง Profile ของผู้เล่นคนนี้
              });
            },
            child: Draggable<Player>(
              data: player,
              maxSimultaneousDrags: isLocked ? 0 : 1,
              onDragEnd: (details) {
                // wasAccepted เป็น false หมายถึงลากไปวางในที่ที่ไม่ใช่ DragTarget
                if (!details.wasAccepted) {
                  // ถ้าลากไปทิ้งข้างนอก ให้เอาผู้เล่นออกจากสนาม
                  _removePlayerFromCourt(courtOrTeam, slotIndex);
                }
              },
              onDragCompleted: () {
                setState(() {
                  courtOrTeam.players[slotIndex] = null;
                });
              },
              feedback: _buildPlayerAvatar(player, isDragging: true),
              childWhenDragging: _buildEmptySlot(),

              child: _buildPlayerAvatar(
                player,
                isSelected: isSelected,
                selectionOrder: selectionOrder,
              ),
            ),
          );
        }
        return GestureDetector(
          onTap: () {
            if (isLocked) return; // ถ้าล็อกอยู่ จะกดวางไม่ได้
            _placeSelectedPlayers(courtOrTeam);
          },
          child: _buildEmptySlot(
            isHighlighted: !isLocked && candidateData.isNotEmpty,
          ),
        );
      },
      onAcceptWithDetails: (details) {
        if (isLocked) return;
        // --- ตรวจสอบ Type ของข้อมูลที่ลากมา ---
        if (details.data is List<Player>) {
          // ถ้าเป็น List (ลากมาเป็นกลุ่ม)
          _placeSelectedPlayers(courtOrTeam);
        } else if (details.data is Player) {
          // ถ้าเป็น Player (ลากมาคนเดียว)
          setState(() {
            final playerToDrop = details.data as Player;
            if (courtOrTeam.players[slotIndex] == null) {
              courtOrTeam.players[slotIndex] = playerToDrop;
              waitingPlayers.remove(playerToDrop);
              selectedPlayers.remove(playerToDrop);
            }
          });
        }
      },
    );
  }

  Widget _buildEmptySlot({bool isHighlighted = false}) {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        color: isHighlighted
            ? Colors.green.withOpacity(0.5)
            : Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          'A', // อาจจะเปลี่ยนเป็น B, C, D ตามตำแหน่ง
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ฟังก์ชันสำหรับสลับการเปิด/ปิดเมนู
  void _toggleFabMenu() {
    if (_fabMenuOverlay == null) {
      _openFabMenu();
    } else {
      _closeFabMenu();
    }
  }

  // ฟังก์ชันสำหรับปิดเมนู
  void _closeFabMenu() {
    _fabMenuOverlay?.remove();
    setState(() {
      _fabMenuOverlay = null;
    });
  }

  // ฟังก์ชันสำหรับเปิดเมนู
  void _openFabMenu() {
    // หาตำแหน่งและขนาดของปุ่ม FAB
    final fabRenderBox =
        _fabKey.currentContext!.findRenderObject() as RenderBox;
    final fabPosition = fabRenderBox.localToGlobal(Offset.zero);
    final fabSize = fabRenderBox.size;

    _fabMenuOverlay = OverlayEntry(
      builder: (context) {
        // สร้าง Layer โปร่งแสงเต็มจอ เมื่อกดที่ Layer นี้จะปิดเมนู
        return Positioned.fill(
          child: GestureDetector(
            onTap: _closeFabMenu,
            child: Container(
              color: Colors.transparent,
              child: Stack(
                children: [
                  // วางตำแหน่งของเมนู
                  Positioned(
                    // จัดตำแหน่งให้อยู่เหนือปุ่ม FAB
                    bottom:
                        MediaQuery.of(context).size.height -
                        fabPosition.dy -
                        fabSize.height,
                    right:
                        MediaQuery.of(context).size.width -
                        fabPosition.dx -
                        fabSize.width,
                    child: _buildFabMenu(), // เรียกใช้ Widget เมนู
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    // แสดง Overlay และอัปเดต State
    Overlay.of(context).insert(_fabMenuOverlay!);
    setState(() {});
  }

  // --- NEW: ฟังก์ชันสำหรับสร้าง UI ของเมนู ---
  Widget _buildFabMenu() {
    // สร้าง Widget ที่เป็นรายการเมนู
    Widget menuItem(String text, {VoidCallback? onTap, bool isEnabled = true}) {
      return InkWell(
        onTap: isEnabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 18,
              color: isEnabled ? Color(0xFF243F94) : Colors.grey[400],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(text: 'เข้าร่วมแล้ว '),
                  TextSpan(
                    text: '62/70',
                    style: TextStyle(color: Colors.green),
                  ),
                  TextSpan(text: ' คน'),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              'เวลา 00:00:00 น.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
          const Divider(height: 1),
          menuItem(
            'สแกนเข้าร่วมเกม',
            onTap: () {
              _closeFabMenu(); // ปิดเมนู FAB ก่อน
              _showQrScannerDialog(context); // แล้วค่อยเปิดหน้าต่างสแกน
            },
          ),
          const Divider(height: 1),
          menuItem(
            'จัดการรายชื่อ',
            onTap: () {
              _closeFabMenu();
              setState(() {
                _isRosterPanelVisible = !_isRosterPanelVisible;
              });
            },
          ),
          const Divider(height: 1),
          menuItem('ดูผลรายงาน', isEnabled: true), // ตัวอย่างปุ่มที่กดไม่ได้
          const Divider(height: 1),
          menuItem('จัดคิวแบบ fix สนาม', onTap: () {}),
          const Divider(height: 1),
          !_isStartGame
              ? menuItem(
                  'เริ่มการแข่งขัน',
                  onTap: () {
                    showDialogMsg(
                      context,
                      title: 'ยืนยันการเริ่มเกม',
                      subtitle: 'เริ่มเกม ก๊วนแมวเหมียว',
                      btnLeftBackColor: Color(0xFF0E9D7A),
                      btnLeftForeColor: Color(0xFFFFFFFF),
                      btnRight: 'ยกเลิก',
                      btnRightBackColor: Color(0xFFFFFFFF),
                      btnRightForeColor: Color(0xFF0E9D7A),
                      onConfirm: () {
                        _closeFabMenu();
                        setState(() {
                          _isStartGame = true;
                        });
                      },
                    );
                  },
                )
              : menuItem(
                  'จบการแข่งขัน',
                  onTap: () {
                    showDialogMsg(
                      context,
                      title: 'ยืนยันการจบเกม',
                      subtitle: 'คุณต้องการจบเกม ก๊วนแมวเหมียว',
                      isWarning: true,
                      isSlideAction: true,
                      onConfirm: () {
                        showDialogMsg(
                          context,
                          title: 'ยืนยันการจบเกม',
                          subtitle: 'คุณได้จบเกม ก๊วนแมวเหมียว',
                          btnLeftBackColor: Color(0xFF0E9D7A),
                          btnLeftForeColor: Color(0xFFFFFFFF),
                          onConfirm: () {
                            _closeFabMenu();
                            context.go('/history-organizer');
                          },
                        );
                      },
                    );
                  },
                ),
        ],
      ),
    );
  }

  void _showQrScannerDialog(BuildContext context) {
    // Controller สำหรับจัดการกล้อง
    final MobileScannerController controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal, // ความเร็วในการตรวจจับ
      facing: CameraFacing.back, // ใช้กล้องหลัง
    );

    bool isScanCompleted = false; // ตัวแปรป้องกันการสแกนซ้ำซ้อน

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 300,
            height: 350,
            child: Column(
              children: [
                // --- Header ของ Dialog ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Scan QR Code',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // --- พื้นที่แสดงกล้อง ---
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: MobileScanner(
                        controller: controller,
                        // onDetect จะถูกเรียกเมื่อสแกนเจอ QR Code
                        onDetect: (capture) {
                          // ป้องกันการทำงานซ้ำซ้อนถ้าสแกนติดกันเร็วๆ
                          if (isScanCompleted) return;

                          final List<Barcode> barcodes = capture.barcodes;
                          if (barcodes.isNotEmpty &&
                              barcodes.first.rawValue != null) {
                            isScanCompleted = true;
                            final String qrCodeData = barcodes.first.rawValue!;

                            // ปิด Dialog
                            Navigator.of(context).pop();

                            // แสดงผลลัพธ์ (คุณสามารถนำไปใช้งานต่อได้เลย)
                            print('Scanned QR Code: $qrCodeData');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('สแกนสำเร็จ: $qrCodeData'),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      // หยุดการทำงานของกล้องเมื่อ Dialog ถูกปิด
      controller.dispose();
    });
  }
}

class RosterManagementPanel extends StatefulWidget {
  final VoidCallback onClose; // เพิ่ม Callback สำหรับปุ่มปิด
  const RosterManagementPanel({super.key, required this.onClose});

  @override
  State<RosterManagementPanel> createState() => _RosterManagementPanelState();
}

class _RosterManagementPanelState extends State<RosterManagementPanel> {
  // --- ข้อมูลตัวอย่าง ---
  final List<RosterPlayer> _players = List.generate(
    25,
    (index) => RosterPlayer(
      no: index + 1,
      nickname: 'แก้ว',
      fullName: 'สมชาย คำใจดี',
      gender: 'หญิง',
      skillLevel: (index % 5) + 1, // สุ่ม level 1-5
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          Colors.transparent, // ทำให้พื้นหลังโปร่งใสเพื่อใช้ฉากหลังของ Dialog
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: 365, // กำหนดความกว้างของ Side Sheet
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              bottomLeft: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // --- Header ---
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'จัดการรายชื่อ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),

              // --- ตารางข้อมูล ---
              Expanded(
                child: SingleChildScrollView(
                  // ทำให้ตาราง scroll ได้ถ้าข้อมูลยาว
                  child: DataTable(
                    columnSpacing: 16,
                    columns: const [
                      DataColumn(label: Text('no')),
                      DataColumn(label: Text('ชื่อเล่น')),
                      DataColumn(label: Text('เพศ')),
                      DataColumn(label: Text('ระดับมือ')),
                      DataColumn(label: Text('check')),
                    ],
                    rows: _players.map((player) {
                      return DataRow(
                        cells: [
                          DataCell(Text('${player.no}')),
                          DataCell(Text(player.nickname)),
                          DataCell(Text(player.gender)),
                          DataCell(
                            // --- Dropdown สำหรับเลือกระดับมือ ---
                            DropdownButton<int>(
                              value: player.skillLevel,
                              underline:
                                  const SizedBox(), // เอาเส้นใต้ของ Dropdown ออก
                              items: [1, 2, 3, 4, 5].map((level) {
                                return DropdownMenuItem(
                                  value: level,
                                  child: Text('P $level'),
                                );
                              }).toList(),
                              onChanged: (newValue) {
                                setState(() {
                                  player.skillLevel = newValue!;
                                });
                              },
                            ),
                          ),
                          DataCell(
                            // --- Checkbox ---
                            Checkbox(
                              value: player.isChecked,
                              onChanged: (newValue) {
                                setState(() {
                                  player.isChecked = newValue!;
                                });
                              },
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),

              // --- Bottom Buttons ---
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {},
                        child: const Text('บันทึกระดับมือ'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                        ),
                        child: const Text('เพิ่มผู้เล่น Walk In'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlayerProfilePanel extends StatefulWidget {
  final Player? player; // รับ Player ที่อาจเป็น null ได้
  final VoidCallback onClose;
  final Function(Player) onShowExpenses;

  const PlayerProfilePanel({
    super.key,
    this.player,
    required this.onClose,
    required this.onShowExpenses,
  });

  @override
  State<PlayerProfilePanel> createState() => _PlayerProfilePanelState();
}

class _PlayerProfilePanelState extends State<PlayerProfilePanel> {
  // State ภายในของ Panel เอง
  bool _isEmergencyContactVisible = false;
  late int _selectedSkillLevel;

  @override
  void initState() {
    super.initState();
    _selectedSkillLevel = widget.player?.level ?? 1;
  }

  // อัปเดตค่าเมื่อ Widget ถูกสร้างใหม่ (เมื่อเลือกผู้เล่นคนใหม่)
  @override
  void didUpdateWidget(covariant PlayerProfilePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.player != oldWidget.player) {
      _selectedSkillLevel = widget.player?.level ?? 1;
      _isEmergencyContactVisible = false; // รีเซ็ตการแสดงข้อมูลติดต่อ
    }
  }

  @override
  Widget build(BuildContext context) {
    // ถ้าไม่มีข้อมูลผู้เล่น ให้แสดงเป็น Container ว่างๆ
    if (widget.player == null) {
      return const SizedBox.shrink();
    }

    final player = widget.player!;

    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: 420,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              bottomLeft: Radius.circular(20),
            ),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          child: Column(
            children: [
              // --- Header ---
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: NetworkImage(player.imageUrl),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            player.fullName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Row(
                            children: [
                              const Text('ระดับมือ: '),
                              DropdownButton<int>(
                                value: _selectedSkillLevel,
                                items: [1, 2, 3, 4, 5, 6, 7, 8]
                                    .map(
                                      (l) => DropdownMenuItem(
                                        value: l,
                                        child: Text('LV.$l'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedSkillLevel = val!),
                              ),
                              const Spacer(),
                              // --- ปุ่มรถพยาบาล ---
                              IconButton(
                                icon: const Icon(
                                  Icons.medical_services_outlined,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isEmergencyContactVisible =
                                        !_isEmergencyContactVisible;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),

              // --- Emergency Contact ---
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isEmergencyContactVisible
                    ? Container(
                        key: const ValueKey('contact_visible'),
                        width: double.infinity,
                        color: Colors.red[100],
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'ผู้ติดต่อฉุกเฉิน: ${player.emergencyContactName} ${player.emergencyContactPhone}',
                          style: TextStyle(color: Colors.red[800]),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('contact_hidden')),
              ),

              // --- ตารางประวัติ ---
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  children: [
                    const TextSpan(text: 'เล่นไป '),
                    TextSpan(
                      text: '${player.gamesPlayed} เกม  ',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    TextSpan(
                      text: '${player.shuttlesUsed} ลูก  ',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const TextSpan(text: 'เวลาที่รอ '),
                    TextSpan(
                      text:
                          '${player.waitingTime.inMinutes}.${player.waitingTime.inSeconds.remainder(60).toString().padLeft(2, '0')} นาที',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              // ตาราง
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Table(
                      border: TableBorder.all(
                        color: Colors.grey.shade700,
                        width: 1,
                      ),
                      columnWidths: const {
                        0: FlexColumnWidth(1),
                        1: FlexColumnWidth(1.5),
                        2: FlexColumnWidth(1),
                        3: FlexColumnWidth(1),
                        4: FlexColumnWidth(2),
                      },
                      children: [
                        // แถวหัวข้อ
                        buildRow([
                          'เกมที่',
                          '#',
                          'ทีม',
                          'VS',
                          'คู่แข่ง',
                        ], isHeader: true),
                        // แถวข้อมูล
                        buildRow(['1', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['2', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['3', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['1', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['2', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['3', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                      ],
                    ),
                  ),
                ),
              ),

              // --- Bottom Buttons ---
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: CustomElevatedButton(
                        padding: EdgeInsetsGeometry.symmetric(
                          horizontal: 8,
                          vertical: 16,
                        ),
                        text: 'หยุดเกมส์ผู้เล่น',
                        backgroundColor: Color(0xFFFFFFFF),
                        foregroundColor: Color(0xFF0E9D7A),
                        side: BorderSide(color: Color(0xFFB3B3C1)),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomElevatedButton(
                        padding: EdgeInsetsGeometry.symmetric(
                          horizontal: 8,
                          vertical: 16,
                        ),
                        text: 'จบเกมส์ผู้เล่น',
                        backgroundColor: Color(0xFFFFFFFF),
                        foregroundColor: Color(0xFF0E9D7A),
                        side: BorderSide(color: Color(0xFFB3B3C1)),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomElevatedButton(
                        padding: EdgeInsetsGeometry.symmetric(
                          horizontal: 8,
                          vertical: 16,
                        ),
                        text: 'ค่าใช้จ่าย',
                        backgroundColor: Color(0xFF243F94),
                        side: BorderSide(color: Color(0xFFB3B3C1)),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        icon: Icons.keyboard_arrow_down,
                        onPressed: () {
                          widget.onShowExpenses(widget.player!);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TableRow buildRow(List<String> cells, {bool isHeader = false}) {
    return TableRow(
      children: cells.map((cell) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            cell,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              fontSize: 16,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class ExpensePanel extends StatefulWidget {
  final Player? player;
  final VoidCallback onClose;

  const ExpensePanel({super.key, this.player, required this.onClose});

  @override
  State<ExpensePanel> createState() => _ExpensePanelState();
}

class _ExpensePanelState extends State<ExpensePanel> {
  // State ภายในของ Panel เอง
  bool _isEmergencyContactVisible = false;
  late int _selectedSkillLevel;

  @override
  void initState() {
    super.initState();
    _selectedSkillLevel = widget.player?.level ?? 1;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.player == null) {
      return const SizedBox.shrink();
    }
    final player = widget.player!;
    final sizedBoxheight = 20.0;

    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: 450,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              bottomLeft: Radius.circular(20),
            ),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                // --- Header ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: NetworkImage(player.imageUrl),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            player.fullName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Row(
                            children: [
                              const Text('ระดับมือ: '),
                              DropdownButton<int>(
                                value: _selectedSkillLevel,
                                items: [1, 2, 3, 4, 5, 6, 7, 8]
                                    .map(
                                      (l) => DropdownMenuItem(
                                        value: l,
                                        child: Text('LV.$l'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedSkillLevel = val!),
                              ),
                              const Spacer(),
                              // --- ปุ่มรถพยาบาล ---
                              IconButton(
                                icon: const Icon(
                                  Icons.medical_services_outlined,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isEmergencyContactVisible =
                                        !_isEmergencyContactVisible;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
                // --- Emergency Contact ---
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isEmergencyContactVisible
                      ? Container(
                          key: const ValueKey('contact_visible'),
                          width: double.infinity,
                          color: Colors.red[100],
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'ผู้ติดต่อฉุกเฉิน: ${player.emergencyContactName} ${player.emergencyContactPhone}',
                            style: TextStyle(color: Colors.red[800]),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('contact_hidden')),
                ),
                SizedBox(height: sizedBoxheight),
                // --- ตารางประวัติ ---
                Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                    children: [
                      const TextSpan(text: 'เล่นไป '),
                      TextSpan(
                        text: '${player.gamesPlayed} เกม  ',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      TextSpan(
                        text: '${player.shuttlesUsed} ลูก  ',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const TextSpan(text: 'เวลาที่รอ '),
                      TextSpan(
                        text:
                            '${player.waitingTime.inMinutes}.${player.waitingTime.inSeconds.remainder(60).toString().padLeft(2, '0')} นาที',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: sizedBoxheight),
                // ตาราง
                SizedBox(
                  height: 300,
                  child: SingleChildScrollView(
                    child: Table(
                      border: TableBorder.all(
                        color: Colors.grey.shade700,
                        width: 1,
                      ),
                      columnWidths: const {
                        0: FlexColumnWidth(1),
                        1: FlexColumnWidth(1.5),
                        2: FlexColumnWidth(1),
                        3: FlexColumnWidth(1),
                        4: FlexColumnWidth(2),
                      },
                      children: [
                        // แถวหัวข้อ
                        buildRow([
                          'เกมที่',
                          '#',
                          'ทีม',
                          'VS',
                          'คู่แข่ง',
                        ], isHeader: true),
                        // แถวข้อมูล
                        buildRow(['1', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['2', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['3', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['1', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['2', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['3', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['1', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['2', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['3', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['1', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['2', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['3', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['1', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['2', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['3', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['1', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['2', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['3', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: sizedBoxheight),
                // --- Bottom Buttons ---
                Row(
                  children: [
                    Expanded(
                      child: CustomElevatedButton(
                        padding: EdgeInsetsGeometry.symmetric(
                          horizontal: 8,
                          vertical: 16,
                        ),
                        text: 'หยุดเกมส์ผู้เล่น',
                        backgroundColor: Color(0xFFFFFFFF),
                        foregroundColor: Color(0xFF0E9D7A),
                        side: BorderSide(color: Color(0xFFB3B3C1)),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomElevatedButton(
                        padding: EdgeInsetsGeometry.symmetric(
                          horizontal: 8,
                          vertical: 16,
                        ),
                        text: 'จบเกมส์ผู้เล่น',
                        backgroundColor: Color(0xFFFFFFFF),
                        foregroundColor: Color(0xFF0E9D7A),
                        side: BorderSide(color: Color(0xFFB3B3C1)),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomElevatedButton(
                        padding: EdgeInsetsGeometry.symmetric(
                          horizontal: 8,
                          vertical: 16,
                        ),
                        text: 'ค่าใช้จ่าย',
                        backgroundColor: Color(0xFF243F94),
                        side: BorderSide(color: Color(0xFFB3B3C1)),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        icon: Icons.keyboard_arrow_up,
                        enabled: true,
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
                SizedBox(height: sizedBoxheight),

                ExpensePanelWidget(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TableRow buildRow(List<String> cells, {bool isHeader = false}) {
    return TableRow(
      children: cells.map((cell) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            cell,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              fontSize: 16,
            ),
          ),
        );
      }).toList(),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';

// file: models.dart (สมมติว่าไฟล์นี้ถูก import เข้ามา)
enum CourtStatus { waiting, playing, paused }

class Player {
  final String id;
  final String name;
  final String imageUrl;
  final int level;

  Player({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.level,
  });
}

class PlayingCourt {
  final int courtNumber;
  List<Player?> players = List.filled(4, null);
  CourtStatus status = CourtStatus.waiting;
  Duration elapsedTime = Duration.zero;

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
    6,
    (index) => PlayingCourt(courtNumber: index + 1),
  );
  List<ReadyTeam> readyTeams = List.generate(
    6,
    (index) => ReadyTeam(id: index + 1),
  );
  List<Player> waitingPlayers = List.generate(
    20,
    (index) => Player(
      id: 'p$index',
      name: 'Bua',
      imageUrl: 'https://i.pravatar.cc/150?u=p$index',
      level: (index % 8) + 1,
    ),
  );
  List<Player> selectedPlayers = [];
  final Map<int, Timer> _timers = {};

  @override
  void dispose() {
    _timers.forEach((key, timer) => timer.cancel());
    super.dispose();
  }

  // --- 2. TIMER LOGIC: ฟังก์ชันสำหรับจัดการเวลา ---
  void _startTimer(PlayingCourt court) {
    // ยกเลิก timer เก่า (ถ้ามี) เพื่อป้องกันการซ้อนทับ

    _timers[court.courtNumber]?.cancel();
    setState(() {
      court.status = CourtStatus.playing;
    });
    _timers[court.courtNumber] = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      if (mounted) {
        // เช็คว่า widget ยังอยู่ใน tree ก่อนเรียก setState
        setState(() {
          court.elapsedTime += const Duration(seconds: 1);
        });
      }
    });
  }

  void _pauseTimer(PlayingCourt court) {
    _timers[court.courtNumber]?.cancel();
    if (mounted)
      setState(() {
        court.status = CourtStatus.paused;
      });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
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

  // --- 3. MAIN BUILD METHOD: โครงสร้างหลักของหน้าจอ ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      // appBar: AppBar(title: const Text('จัดการเกมส์ก๊วนแมวเหมียว')), // ใช้ AppBar ของคุณได้เลย
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSectionTitle('สนาม'), // เปลี่ยนชื่อ Section ให้สั้นลง
            const SizedBox(height: 8),
            _buildSyncedCourtsList(), // Widget หลักที่แสดงสนามทั้งหมด
            const SizedBox(height: 24),
            _buildSectionTitle('ผู้เล่นที่รอ'), // เปลี่ยนชื่อ Section ให้สั้นลง
            const SizedBox(height: 8),
            _buildWaitingPlayersGrid(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: Colors.black,
        child: const Icon(Icons.menu, color: Colors.white),
      ),
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
    const double cardHeight = 140; // เพิ่มความสูงให้การ์ด
    const double spacing = 12;
    const double totalHeight = cardHeight + spacing + cardHeight;
    const double cardWidth = 130; // เพิ่มความกว้างให้การ์ด

    return SizedBox(
      height: totalHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: playingCourts.length + 1,
        itemBuilder: (context, index) {
          if (index == playingCourts.length) {
            return _buildAddCourtButton(height: totalHeight, width: 110);
          }
          return SizedBox(
            width: cardWidth,
            child: Column(
              children: [
                _buildCourtCard(playingCourts[index]),
                const SizedBox(height: spacing),
                _buildReadyTeamCard(readyTeams[index]),
              ],
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
    return Container(
      height: 140,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF2E9A8A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [_buildPlayerSlot(court, 0), _buildPlayerSlot(court, 1)],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [_buildPlayerSlot(court, 2), _buildPlayerSlot(court, 3)],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text(
                _formatDuration(court.elapsedTime),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (court.status == CourtStatus.waiting ||
                  court.status == CourtStatus.paused)
                InkWell(
                  onTap: () => _startTimer(court),
                  child: const Icon(Icons.play_arrow, color: Colors.white),
                ),
              if (court.status == CourtStatus.playing)
                InkWell(
                  onTap: () => _pauseTimer(court),
                  child: const Icon(Icons.pause, color: Colors.white),
                ),
            ],
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
    );
  }

  Widget _buildReadyTeamCard(ReadyTeam team) {
    bool isFull = team.players.every((p) => p != null);
    return Container(
      height: 140,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: team.isLocked ? Colors.blueGrey[600] : const Color(0xFF6F6F6F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 20,
            child: isFull
                ? Align(
                    alignment: Alignment.topRight,
                    child: InkWell(
                      onTap: () =>
                          setState(() => team.isLocked = !team.isLocked),
                      child: Icon(
                        team.isLocked ? Icons.lock : Icons.lock_open,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  )
                : null,
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPlayerSlot(team, 0),
                    _buildPlayerSlot(team, 1),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPlayerSlot(team, 2),
                    _buildPlayerSlot(team, 3),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingPlayersGrid() {
    return Wrap(
      spacing: 8.0,
      runSpacing: 12.0,
      children: waitingPlayers.map((player) {
        bool isSelected = selectedPlayers.contains(player);
        final selectionOrder = isSelected
            ? selectedPlayers.indexOf(player) + 1
            : 0;

        return Draggable<Player>(
          data: player,
          feedback: _buildPlayerAvatar(player, isDragging: true),
          childWhenDragging: Opacity(
            opacity: 0.5,
            child: _buildPlayerAvatar(player),
          ),
          child: GestureDetector(
            onTap: () => _onPlayerTap(player),
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

  Widget _buildPlayerAvatar(
    Player player, {
    bool isDragging = false,
    bool isSelected = false,
    int selectionOrder = 0, // รับลำดับที่เลือก
    double radius = 35, // รับขนาดของ avatar
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: isSelected
                ? Border.all(color: Colors.blueAccent, width: 3)
                : null,
            boxShadow: isDragging
                ? [const BoxShadow(color: Colors.black38, blurRadius: 10)]
                : null,
          ),
          child: CircleAvatar(
            radius: radius,
            backgroundImage: NetworkImage(player.imageUrl),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(radius),
                    bottomRight: Radius.circular(radius),
                  ),
                ),
                child: Text(
                  player.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: radius * 0.34,
                  ),
                ),
              ),
            ),
          ),
        ),
        // --- REQUIREMENT 1: แสดงตัวเลขลำดับ ---
        if (isSelected && !isDragging)
          Positioned(
            top: -4,
            left: -4,
            child: CircleAvatar(
              radius: 12,
              backgroundColor: Colors.blueAccent,
              child: Text(
                '$selectionOrder',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlayerSlot(dynamic courtOrTeam, int slotIndex) {
    bool isLocked = (courtOrTeam is ReadyTeam && courtOrTeam.isLocked);
    Player? player = courtOrTeam.players[slotIndex];

    return DragTarget<Player>(
      builder: (context, candidateData, rejectedData) {
        if (player != null) {
          final isSelected = selectedPlayers.contains(player);
          // --- REQUIREMENT 1: คำนวณลำดับ ---
          final selectionOrder = isSelected
              ? selectedPlayers.indexOf(player) + 1
              : 0;

          if (isLocked) return _buildPlayerAvatar(player);
          return Draggable<Player>(
            data: player,
            onDragEnd: (details) {
              // ถ้าลากไปวางไม่สำเร็จ (isDropped = false) ให้คืนผู้เล่นกลับสนามเดิม
              if (!details.wasAccepted) {
                setState(() {
                  courtOrTeam.players[slotIndex] = player;
                });
              }
            },
            onDragCompleted: () {
              setState(() {
                courtOrTeam.players[slotIndex] = null;
              });
            },
            feedback: _buildPlayerAvatar(player, isDragging: true, radius: 22),
            childWhenDragging: _buildEmptySlot(),
            child: _buildPlayerAvatar(
              player,
              isSelected: isSelected,
              selectionOrder: selectionOrder,
              radius: 22,
            ),
          );
        }
        return GestureDetector(
          onTap: () {
            if (isLocked) return;
            if (selectedPlayers.isNotEmpty) {
              setState(() {
                if (courtOrTeam is ReadyTeam) {
                  for (var p in selectedPlayers) {
                    int emptySlot = courtOrTeam.players.indexOf(null);
                    if (emptySlot != -1) {
                      courtOrTeam.players[emptySlot] = p;
                      waitingPlayers.remove(p);
                    }
                  }
                } else if (courtOrTeam is PlayingCourt &&
                    selectedPlayers.length == 1) {
                  courtOrTeam.players[slotIndex] = selectedPlayers.first;
                  waitingPlayers.remove(selectedPlayers.first);
                }
                selectedPlayers.clear();
              });
            }
          },
          child: _buildEmptySlot(
            isHighlighted: !isLocked && candidateData.isNotEmpty,
          ),
        );
      },
      onAcceptWithDetails: (details) {
        final playerToDrop = details.data;
        if (isLocked) return;
        setState(() {
          if (courtOrTeam.players[slotIndex] == null) {
            // ย้ายผู้เล่นที่ลากมาวาง
            courtOrTeam.players[slotIndex] = playerToDrop;
            waitingPlayers.remove(playerToDrop);
            selectedPlayers.remove(playerToDrop);
          }
        });
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
}

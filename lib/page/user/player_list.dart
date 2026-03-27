import 'package:badminton/component/app_bar.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';

// --- 1. สร้าง Model สำหรับเก็บข้อมูลผู้เล่น ---
class Player {
  final int id;
  final String nickname;
  final String gender;
  String skillLevel; // ทำให้สามารถเปลี่ยนแปลงได้
  final String imageUrl;
  final int status; // 1 = ตัวจริง, 2 = สำรอง

  Player({
    required this.id,
    required this.nickname,
    required this.gender,
    required this.skillLevel,
    required this.imageUrl,
    required this.status,
  });

  factory Player.fromJson(Map<String, dynamic> json, int index) {
    return Player(
      id: index + 1,
      nickname: json['nickname'] ?? '-',
      gender: json['genderName'] ?? json['gender'] ?? '-', // เปลี่ยนเป็น genderName ตาม API
      skillLevel: json['skillLevelName'] ?? '-',
      imageUrl: json['profilePhotoUrl'] ?? '',
      status: json['status'] ?? 1, // ดึงสถานะมาเก็บไว้
    );
  }
}

// --- 2. หน้าจอหลักสำหรับแสดงรายชื่อ ---
class PlayerListPage extends StatefulWidget {
  const PlayerListPage({super.key, required this.id});
  final String id;

  @override
  State<PlayerListPage> createState() => _PlayerListPageState();
}

class _PlayerListPageState extends State<PlayerListPage> {
  // --- 3. สร้างข้อมูลจำลอง ---
  List<Player> players = [];
  bool isUse = true;
  bool _isLoading = true;
  String teamName = ''; // เพิ่มตัวแปรสำหรับเก็บชื่อก๊วน

  @override
  void initState() {
    super.initState();
    _fetchPlayers();
  }

  Future<void> _fetchPlayers() async {
    try {
      // แก้ไข: เปลี่ยนไปใช้ API ของฝั่งผู้เล่นเพื่อดึงข้อมูล session ซึ่งมีรายชื่อผู้เล่นอยู่ข้างใน
      final response = await ApiProvider().get('/player/gamesessions/${widget.id}');
      if (mounted && response['status'] == 200) {
        // แก้ไข: ดึงข้อมูลจาก key 'participants' ที่อยู่ใน object data
        final List<dynamic> data = response['data']['participants'] ?? [];
        setState(() {
          teamName = response['data']['groupName'] ?? 'รายชื่อผู้เล่น'; // ดึงชื่อก๊วนมาเก็บ
          players = data.asMap().entries.map((e) => Player.fromJson(e.value, e.key)).toList();
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // กรองผู้เล่น: isUse = true คือผู้เล่น (1), isUse = false คือสำรอง (2)
    final filteredPlayers = players.where((p) => p.status == (isUse ? 1 : 2)).toList();

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      appBar: AppBarSubMain(title: teamName.isNotEmpty ? teamName : 'กำลังโหลด...'), // ใช้ชื่อก๊วนมาเป็น Title
      body: Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
        color: Colors.white,
        child: Column(
          children: [
            _buildHeader(context),
            const Divider(color: Colors.grey),
            _isLoading
                ? const Expanded(child: Center(child: CircularProgressIndicator()))
                : filteredPlayers.isEmpty
                    ? Expanded(
                        child: Center(
                          child: Text(isUse ? 'ไม่มีผู้เล่นตัวจริงในขณะนี้' : 'ไม่มีรายชื่อคิวสำรอง'),
                        ),
                      )
                    : Expanded(
                        child: ListView.builder(
                          itemCount: filteredPlayers.length,
                          itemBuilder: (context, index) {
                            return _buildPlayerRow(filteredPlayers[index]);
                          },
                        ),
                      ),
            _buildPagination(),
          ],
        ),
      ),
    );
  }

  // Widget สำหรับ Header ของตาราง
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              'ลำดับ',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'ชื่อเล่น',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'เพศ',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'ระดับมือ',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget สำหรับแสดงข้อมูลผู้เล่นแต่ละแถว
  Widget _buildPlayerRow(Player player) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              '${player.id}',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                if (player.imageUrl.isNotEmpty)
                  CircleAvatar(
                    radius: 12,
                    backgroundImage: NetworkImage(player.imageUrl),
                  )
                else
                  const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 16)),
                const SizedBox(width: 8),
                Text(
                  player.nickname,
                  style: TextStyle(
                    fontSize: getResponsiveFontSize(context, fontSize: 14),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              player.gender,
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              player.skillLevel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Expanded(flex: 2, child: _buildSkillLevelDropdown(player)),
        ],
      ),
    );
  }

  // Widget สำหรับ Pagination ด้านล่าง
  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPageNumber('ผู้เล่น', isActive: isUse),
          _buildPageNumber('สำรอง', isActive: !isUse),
        ],
      ),
    );
  }

  Widget _buildPageNumber(String text, {bool isActive = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: GestureDetector(
        onTap: () {
          setState(() {
            isUse = !isUse;
          });
        },
        child: Text(
          text,
          style: TextStyle(
            color: isActive ? Colors.green : Colors.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  // // Widget สำหรับ Dropdown เลือกระดับมือ
  // Widget _buildSkillLevelDropdown(Player player) {
  //   return Container(
  //     padding: const EdgeInsets.symmetric(horizontal: 8.0),
  //     decoration: BoxDecoration(
  //       color: skillLevels[player.skillLevel], // สีพื้นหลังตามระดับมือ
  //       borderRadius: BorderRadius.circular(4.0),
  //       // border: Border.all(
  //       //   color: Colors.grey, // สีของเส้นขอบ
  //       //   width: 1.0, // ความหนาของเส้นขอบ
  //       // ),
  //     ),
  //     child: DropdownButton<String>(
  //       value: player.skillLevel,
  //       isExpanded: true,
  //       underline: const SizedBox(), // เอาเส้นใต้ออก
  //       icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
  //       style: const TextStyle(color: Colors.black),
  //       dropdownColor: Colors.grey[800],
  //       items: skillLevels.keys.map((String level) {
  //         return DropdownMenuItem<String>(value: level, child: Text(level));
  //       }).toList(),
  //       onChanged: (String? newValue) {
  //         setState(() {
  //           player.skillLevel = newValue!;
  //         });
  //       },
  //     ),
  //   );
  // }
}

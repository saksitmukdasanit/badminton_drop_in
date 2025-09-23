import 'dart:math';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';

// --- 1. สร้าง Model สำหรับเก็บข้อมูลผู้เล่น ---
class Player {
  final int id;
  final String nickname;
  final String gender;
  String skillLevel; // ทำให้สามารถเปลี่ยนแปลงได้
  final String imageUrl;

  Player({
    required this.id,
    required this.nickname,
    required this.gender,
    required this.skillLevel,
    required this.imageUrl,
  });
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
  late List<Player> players;
  bool isUse = true;

  

  @override
  void initState() {
    super.initState();
    players = _generateMockPlayers(56);
  }

  List<Player> _generateMockPlayers(int count) {
    return List.generate(count, (i) {
      return Player(
        id: i + 1,
        nickname: 'แก้ว',
        gender: 'หญิง',
        skillLevel: skillLevels.keys.elementAt(
          Random().nextInt(skillLevels.length),
        ),
        imageUrl:
            'https://images.unsplash.com/photo-1494790108377-be9c29b29330?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=687&q=80',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      appBar: AppBarSubMain(title: widget.id),
      body: Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
        color: Colors.white,
        child: Column(
          children: [
            _buildHeader(context),
            const Divider(color: Colors.grey),
            Expanded(
              child: ListView.builder(
                itemCount: players.length,
                itemBuilder: (context, index) {
                  return _buildPlayerRow(players[index]);
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
                CircleAvatar(
                  radius: 12,
                  backgroundImage: NetworkImage(player.imageUrl),
                ),
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

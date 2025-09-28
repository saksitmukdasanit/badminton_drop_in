import 'package:badminton/model/player.dart';
import 'package:flutter/material.dart';

// ฟังก์ชันสำหรับกำหนดสีตาม Level
// คุณสามารถเพิ่มหรือแก้ไขสีของแต่ละ Level ได้ที่นี่
Color _getColorForLevel(int level) {
  switch (level) {
    case 1:
      return Colors.grey.shade400;
    case 2:
      return Colors.blue.shade200;
    case 3:
      return Colors.orange.shade300;
    case 4:
      return Colors.green.shade300;
    case 5:
      return Colors.purple.shade200;
    case 6:
      return Colors.red.shade300;
    case 7:
      return Colors.teal.shade200;
    case 8:
      return Colors.amber.shade400;
    default:
      return Colors.grey.shade300;
  }
}

// (แนะนำ) ฟังก์ชันจัดรูปแบบเวลา
String _formatTotalPlayTime(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  return '${hours}h ${minutes}m';
}

class PlayerAvatar extends StatelessWidget {
  final Player player;

  const PlayerAvatar({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    final color = _getColorForLevel(player.level); // ดึงสีตาม Level

    return Card(
      // shape: CircleBorder(
      //   // ทำให้ Card เป็นวงกลม
      //   side: BorderSide(
      //     color: Colors.white,
      //     width: 3,
      //   ),
      // ),
      clipBehavior: Clip.antiAlias, // ตัด child ให้เป็นวงกลมตาม Card
      elevation: 4,
      child: Column(
        children: [
          // --- Column 1: LV และสีพื้นหลัง ---
          Container(
            color: color,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Text(
              'LV. ${player.level}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),

          // --- Column 2: รูปภาพ ---
          Expanded(
            child: Image.network(
              player.imageUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              // เพิ่ม Loading Builder เพื่อให้ UX ดีขึ้น
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.person, color: Colors.grey);
              },
            ),
          ),

          // --- Column 3: ข้อมูลและสีพื้นหลัง ---
          Container(
            color: color,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Column(
              children: [
                Text(
                  player.name,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${player.gamesPlayed}: | ${_formatTotalPlayTime(player.totalPlayTime)}',
                  style: const TextStyle(color: Colors.black54, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

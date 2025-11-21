import 'package:badminton/model/player.dart';
import 'package:flutter/material.dart';

// FIX: สร้างฟังก์ชันแปลง Hex Color (เช่น "#eb4747") เป็น Color object
Color _colorFromHex(String? hexColor) {
  if (hexColor == null || hexColor.isEmpty) {
    return Colors.grey.shade300; // สีเริ่มต้นถ้าไม่มีข้อมูล
  }
  final hexCode = hexColor.replaceAll('#', '');
  return Color(int.parse('FF$hexCode', radix: 16));
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
    // FIX: ใช้สีจาก player.skillLevelColor โดยตรง
    final color = _colorFromHex(player.skillLevelColor);
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
              // FIX: ใช้ชื่อระดับจาก player.skillLevelName
              player.skillLevelName ?? 'N/A',
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
            child: (player.imageUrl != null && player.imageUrl!.isNotEmpty)
                ? Image.network(
                    player.imageUrl!,
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
                  )
                : const Icon(Icons.person, color: Colors.grey),
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
                  '${player.gamesPlayed ?? 0}: | ${_formatTotalPlayTime(player.totalPlayTime ?? Duration.zero)}',
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

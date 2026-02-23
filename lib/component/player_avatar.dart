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

// ฟังก์ชันจัดรูปแบบเวลา (MM:SS)
String _formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
  String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
  return "$twoDigitMinutes:$twoDigitSeconds";
}

class PlayerAvatar extends StatelessWidget {
  final Player player;

  const PlayerAvatar({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    // FIX: ใช้สีจาก player.skillLevelColor โดยตรง
    final color = _colorFromHex(player.skillLevelColor);
    // คำนวณสีตัวอักษร (ขาว/ดำ) ตามความสว่างของพื้นหลัง
    final textColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black87;

    return Card(
      clipBehavior: Clip.antiAlias, // ตัด child ให้เป็นวงกลมตาม Card
      elevation: 4,
      margin: EdgeInsets.zero, // ลบ margin เพื่อให้จัด layout ภายนอกได้ง่าย
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
              style: TextStyle(
                color: textColor,
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
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
            child: Column(
              children: [
                Text(
                  player.name,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                // --- NEW: แสดง Stats แบบ Badge ภายใน Card ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Badge จำนวนเกม
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'G: ${player.gamesPlayed ?? 0}',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Badge เวลาที่รอ (สีน้ำเงินเข้ม ตัวหนังสือเหลือง)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade900,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'W: ${_formatDuration(player.totalPlayTime ?? Duration.zero)}',
                        style: const TextStyle(
                          color: Colors.yellowAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

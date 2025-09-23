import 'package:flutter/material.dart';

class GameCard extends StatefulWidget {
  // 1. กำหนด parameter เพื่อรับข้อมูลจากภายนอก
  final String teamName;
  final String imageUrl;
  final String date;
  final String time;
  final String courtName;
  final String location;
  final String price;
  final String shuttlecockInfo;
  final String gameInfo;
  final int currentPlayers;
  final int maxPlayers;
  final String organizerName;
  final String organizerImageUrl;
  final bool isInitiallyBookmarked;

  const GameCard({
    super.key,
    required this.teamName,
    required this.imageUrl,
    required this.date,
    required this.time,
    required this.courtName,
    required this.location,
    required this.price,
    required this.shuttlecockInfo,
    required this.gameInfo,
    required this.currentPlayers,
    required this.maxPlayers,
    required this.organizerName,
    required this.organizerImageUrl,
    this.isInitiallyBookmarked = false,
  });

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> {
  // 2. สร้าง State สำหรับจัดการสถานะของ Bookmark
  late bool isBookmarked;

  @override
  void initState() {
    super.initState();
    isBookmarked = widget.isInitiallyBookmarked;
  }

  @override
  Widget build(BuildContext context) {
    // 3. ย้ายโค้ด UI ทั้งหมดมาไว้ใน build method
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- ส่วนหัวข้อ ---
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFFF5CC), // พื้นหลังเหลืองอ่อน
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.teamName, // 4. ใช้ข้อมูลจาก widget
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    size: 26,
                  ),
                  onPressed: () {
                    // 5. setState ทำงานได้อย่างถูกต้องใน StatefulWidget
                    setState(() {
                      isBookmarked = !isBookmarked;
                    });
                  },
                ),
              ],
            ),
          ),
          // --- รูปภาพ ---
          Image.network(
            widget.imageUrl, // 4. ใช้ข้อมูลจาก widget
            width: double.infinity,
            height: 180,
            fit: BoxFit.cover,
          ),
          // --- รายละเอียด ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.date}  ${widget.time}', // 4. ใช้ข้อมูลจาก widget
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.courtName, // 4. ใช้ข้อมูลจาก widget
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.teal[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.location, // 4. ใช้ข้อมูลจาก widget
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoColumn('ค่าสนาม', widget.price),
                    _buildInfoColumn('Yonex (model)', widget.shuttlecockInfo),
                    _buildInfoColumn('เล่น 21 แต้ม', widget.gameInfo),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    const Text('ผู้เล่น '),
                    Text(
                      '${widget.currentPlayers}/${widget.maxPlayers} คน', // 4. ใช้ข้อมูลจาก widget
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ดูผู้เล่น',
                      style: TextStyle(
                        color: Colors.teal[600],
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundImage: NetworkImage(widget.organizerImageUrl), // 4. ใช้ข้อมูลจาก widget
                    ),
                    const SizedBox(width: 8),
                    Text(widget.organizerName), // 4. ใช้ข้อมูลจาก widget
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 6. ย้ายฟังก์ชัน helper มาไว้ในคลาส
  Widget _buildInfoColumn(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';

class GameCard2 extends StatefulWidget {
  // กำหนด parameter เพื่อรับข้อมูลจากภายนอก
  final String teamName;
  final String imageUrl;
  final String day;
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
  final VoidCallback? onCardTap;
  final VoidCallback? onTapOrganizer;
  final VoidCallback? onTapPlayers;

  const GameCard2({
    super.key,
    required this.teamName,
    required this.imageUrl,
    required this.day,
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
    this.onCardTap,
    this.onTapOrganizer,
    this.onTapPlayers,
    this.isInitiallyBookmarked = false,
  });

  @override
  State<GameCard2> createState() => _GameCard2State();
}

class _GameCard2State extends State<GameCard2> {
  late bool isBookmarked;

  @override
  void initState() {
    super.initState();
    isBookmarked = widget.isInitiallyBookmarked;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onCardTap,
      child: Card(
        // ทำให้ Card มีขอบมนและเงา
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 4,
        margin: EdgeInsets.zero,
        // ClipRRect เพื่อให้ Container ที่เป็น Header มีขอบมนตาม Card
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- ส่วน Header ---
              Container(
                color: dayColors.firstWhere(
                  (d) => d['code'] == widget.day,
                )['display'],
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.teamName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                        size: 28,
                        color: Colors.black87,
                      ),
                      onPressed: () {
                        setState(() {
                          isBookmarked = !isBookmarked;
                        });
                      },
                    ),
                  ],
                ),
              ),
              // --- ส่วนรูปภาพและรายละเอียด ---
              Container(
                color: Colors.white, // พื้นหลังส่วนล่างเป็นสีขาว
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- รูปภาพด้านซ้าย ---
                    ClipRRect(
                      // borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        widget.imageUrl,
                        width: 120,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    ),
                    // --- รายละเอียดด้านขวา ---
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: _buildGameDetails(context),
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

  // Widget สำหรับรายละเอียดเกมด้านขวา
  Widget _buildGameDetails(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.date}  ${widget.time}',
          style: TextStyle(
            fontSize: getResponsiveFontSize(context, fontSize: 12),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.courtName,
          style: TextStyle(
            fontSize: getResponsiveFontSize(context, fontSize: 12),
            color: Colors.teal[600],
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(widget.location, style: TextStyle(color: Colors.grey[700])),
        // const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildInfoColumn('ค่าสนาม', widget.price),
            _buildInfoColumn('เล่น 21 แต้ม', widget.gameInfo),
          ],
        ),
        _buildInfoColumn('Yonex (model)', widget.shuttlecockInfo),
        Row(
          children: [
            const Text('ผู้เล่น '),
            Text(
              '${widget.currentPlayers}/${widget.maxPlayers}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.teal[600],
                fontSize: getResponsiveFontSize(context, fontSize: 14),
              ),
            ),
            const Text(' คน '),
            GestureDetector(
              onTap: widget.onTapPlayers,
              child: Text(
                'ดูผู้เล่น',
                style: TextStyle(
                  color: Colors.teal[600],
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundImage: NetworkImage(widget.organizerImageUrl),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onTapOrganizer,
              child: Text(
                widget.organizerName,
                style: TextStyle(
                  fontSize: getResponsiveFontSize(context, fontSize: 14),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // Widget ย่อยสำหรับแสดงข้อมูล
  Widget _buildInfoColumn(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: getResponsiveFontSize(context, fontSize: 10),
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: getResponsiveFontSize(context, fontSize: 10),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

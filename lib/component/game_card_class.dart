import 'package:badminton/model/game_card_model.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';

class GameCardClass extends StatefulWidget {
  // --- CHANGED: รับข้อมูลเป็น Model ก้อนเดียว ---
  final GameCardModel game;

  // Callbacks ยังคงรับเหมือนเดิม
  final VoidCallback? onCardTap;
  final VoidCallback? onTapOrganizer;
  final VoidCallback? onTapPlayers;

  const GameCardClass({
    super.key,
    required this.game, // เปลี่ยนเป็นรับ game model
    this.onCardTap,
    this.onTapOrganizer,
    this.onTapPlayers,
  });

  @override
  State<GameCardClass> createState() => _GameCardClassState();
}

class _GameCardClassState extends State<GameCardClass> {
  late bool isBookmarked;

  @override
  void initState() {
    super.initState();
    // CHANGED: เข้าถึงข้อมูลเริ่มต้นผ่าน widget.game
    isBookmarked = widget.game.isInitiallyBookmarked;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onCardTap,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 4,
        margin: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- ส่วน Header ---
              Container(
                // ACCESSING DATA: เข้าถึงข้อมูลผ่าน widget.game
                color: dayColors.firstWhere(
                  (d) => d['code'] == widget.game.day,
                )['display'],
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.game.teamName, // ACCESSING DATA
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
                color: Colors.white,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- รูปภาพด้านซ้าย ---
                    ClipRRect(
                      child: Image.network(
                        widget.game.imageUrl, // ACCESSING DATA
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

  Widget _buildGameDetails(BuildContext context) {
    // ในนี้ก็เข้าถึงข้อมูลผ่าน widget.game ทั้งหมด
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.game.date}  ${widget.game.time}',
          style: TextStyle(
            fontSize: getResponsiveFontSize(context, fontSize: 12),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.game.courtName,
          style: TextStyle(
            fontSize: getResponsiveFontSize(context, fontSize: 12),
            color: Colors.teal[600],
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(widget.game.location, style: TextStyle(color: Colors.grey[700])),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildInfoColumn('ค่าสนาม', widget.game.price),
            _buildInfoColumn('เล่น 21 แต้ม', widget.game.gameInfo),
          ],
        ),
        _buildInfoColumn('Yonex (model)', widget.game.shuttlecockInfo),
        Row(
          children: [
            const Text('ผู้เล่น '),
            Text(
              '${widget.game.currentPlayers}/${widget.game.maxPlayers}',
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
              backgroundImage: NetworkImage(widget.game.organizerImageUrl),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onTapOrganizer,
              child: Text(
                widget.game.organizerName,
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

  Widget _buildInfoColumn(String title, String value) {
    // ฟังก์ชันนี้ไม่จำเป็นต้องแก้ เพราะรับค่ามาตรงๆ
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
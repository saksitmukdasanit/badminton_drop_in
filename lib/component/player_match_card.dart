import 'package:badminton/component/button.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/dropdown.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';

class PlayerMatchCard extends StatefulWidget {
  final dynamic match;
  final int index;

  const PlayerMatchCard({super.key, required this.match, required this.index});

  @override
  State<PlayerMatchCard> createState() => _PlayerMatchCardState();
}

class _PlayerMatchCardState extends State<PlayerMatchCard> {
  String? _selectedResult;
  late TextEditingController _noteController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedResult = widget.match['result']?.toString();
    _noteController = TextEditingController(text: widget.match['notes'] ?? '');
  }

  @override
  void didUpdateWidget(covariant PlayerMatchCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.match['matchId'] != oldWidget.match['matchId']) {
      _selectedResult = widget.match['result']?.toString();
      _noteController.text = widget.match['notes'] ?? '';
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitResult() async {
    if (_selectedResult == null) {
      showDialogMsg(context, title: 'แจ้งเตือน', subtitle: 'กรุณาเลือกผลการแข่งขัน', btnLeft: 'ตกลง', onConfirm: () {});
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ApiProvider().post(
        '/player/gamesessions/matches/${widget.match['matchId']}/submit-result',
        data: {
          "result": int.parse(_selectedResult!),
          "notes": _noteController.text,
        }
      );
      if (mounted) {
        showDialogMsg(context, title: 'สำเร็จ', subtitle: 'บันทึกผลการแข่งขันเรียบร้อย', btnLeft: 'ตกลง', onConfirm: () {});
      }
    } catch (e) {
      if (mounted){
        showDialogMsg(context, title: 'เกิดข้อผิดพลาด', subtitle: e.toString().replaceFirst('Exception: ', ''), btnLeft: 'ตกลง', onConfirm: () {});
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _formatResult(dynamic result) {
    switch (result?.toString()) {
      case '1': return 'ชนะ';
      case '2': return 'แพ้';
      case '3': return 'เสมอ';
      default: return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    // ใช้ myTeam ที่ประกอบร่างมาจากหน้าหลัก ถ้าไม่มีให้สร้าง default
    List<dynamic> myTeam = widget.match['myTeam'] ?? [
      {'nickname': 'ฉัน', 'profilePhotoUrl': null},
      if (widget.match['teammate'] != null && widget.match['teammate']['nickname'] != 'N/A') widget.match['teammate']
    ];

    List<dynamic> opponents = widget.match['opponents'] ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // --- ส่วนผู้เล่นด้านซ้าย ---
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('เกมที่ ${widget.index}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(width: 8),
                      Text('สนาม ${widget.match['courtNumber']}', style: const TextStyle(color: Colors.black54, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildPlayerTeamBlock(
                    const Color(0xFF1ABC9C),
                    const Radius.circular(12),
                    const Radius.circular(0),
                    false,
                    myTeam,
                  ),
                  _buildPlayerTeamBlock(
                    const Color(0xFF2C3E50),
                    const Radius.circular(0),
                    const Radius.circular(12),
                    true,
                    opponents,
                  ),
                ],
              ),
            ),
            // --- ส่วนรายละเอียดด้านขวา ---
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('เวลาเล่น: ${widget.match['durationMinutes'] ?? 0} นาที', style: const TextStyle(color: Colors.black54, fontSize: 14), textAlign: TextAlign.right),
                    const SizedBox(height: 10),
                    // Dropdown สำหรับผลการแข่งขัน
                    CustomDropdown(
                      labelText: '',
                      initialValue: _selectedResult,
                      items: [
                        {"code": '1', "value": 'ชนะ'},
                        {"code": '2', "value": 'แพ้'},
                        {"code": '3', "value": 'เสมอ'},
                      ],
                      onChanged: (val) => setState(() => _selectedResult = val),
                    ),
                    const SizedBox(height: 8),
                    // ช่องใส่ Note
                    TextField(
                      controller: _noteController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Note',
                        filled: true,
                        fillColor: Colors.grey[200],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.all(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    CustomElevatedButton(
                      text: 'บันทึกผล',
                      isLoading: _isSubmitting,
                      onPressed: _submitResult,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      fontSize: 14,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerTeamBlock(Color bgColor, Radius top, Radius bottom, bool isBottom, List<dynamic> players) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.only(topLeft: top, topRight: top, bottomLeft: bottom, bottomRight: bottom),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: players.map((p) {
              return Column(
                children: [
                  if (p != null && p['profilePhotoUrl'] != null && p['profilePhotoUrl'].toString().isNotEmpty)
                    CircleAvatar(radius: 15, backgroundImage: NetworkImage(p['profilePhotoUrl']))
                  else
                    const CircleAvatar(radius: 15, child: Icon(Icons.person, size: 16)),
                  const SizedBox(height: 5),
                  Text(
                    p != null ? (p['nickname'] ?? 'N/A') : 'N/A',
                    style: TextStyle(fontSize: getResponsiveFontSize(context, fontSize: 12), color: Colors.white),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
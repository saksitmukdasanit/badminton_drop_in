import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:badminton/shared/api_provider.dart';

class BillSummaryService {
  static Future<void> generateAndShare(
      BuildContext context, int sessionId, String sessionName) async {
    // 1. Fetch data
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final res =
          await ApiProvider().get('/GameSessions/$sessionId/financials');
      if (context.mounted) Navigator.pop(context); // close loading

      if (res['status'] == 200 && res['data'] != null) {
        final data = res['data'];

        // 2. Render Widget off-screen using RepaintBoundary
        if (context.mounted) {
          await _captureAndShare(context, data, sessionName);
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ไม่สามารถโหลดข้อมูลบิลได้')));
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context); // close loading
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    }
  }

  static Future<void> _captureAndShare(
      BuildContext context, Map<String, dynamic> data, String sessionName) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          _BillPreviewDialog(data: data, sessionName: sessionName),
    );
  }
}

class _BillPreviewDialog extends StatefulWidget {
  final Map<String, dynamic> data;
  final String sessionName;

  const _BillPreviewDialog({
    required this.data,
    required this.sessionName,
  });

  @override
  State<_BillPreviewDialog> createState() => _BillPreviewDialogState();
}

class _BillPreviewDialogState extends State<_BillPreviewDialog> {
  final GlobalKey _globalKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareImage() async {
    setState(() => _isSharing = true);
    try {
      RenderRepaintBoundary boundary =
          _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final buffer = byteData.buffer;
        final tempDir = Directory.systemTemp;
        final file = await File('${tempDir.path}/bill_summary.png').create();
        await file.writeAsBytes(buffer.asUint8List(
            byteData.offsetInBytes, byteData.lengthInBytes));

        await Share.shareXFiles([XFile(file.path)],
            text: 'สรุปยอด ${widget.sessionName}');
      }
    } catch (e) {
      debugPrint('Share error: $e');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final participants = (widget.data['participants'] as List?) ?? [];

    // หาผู้เล่นทั้งหมดที่ต้องจ่ายเงิน (โชว์ความโปร่งใส)
    final validParticipants = participants.where((p) {
      return p['participantType'] != 'Guest' || (p['totalCost'] != null && p['totalCost'] > 0);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ส่วนที่จะถูกแคปเจอร์
          RepaintBoundary(
            key: _globalKey,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sports_tennis,
                      size: 48, color: Color(0xFF0E9D7A)),
                  const SizedBox(height: 8),
                  const Text(
                    'สรุปบิลค่าใช้จ่าย',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  Text(
                    widget.sessionName,
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                  const Divider(height: 32, thickness: 1),
                  // รายชื่อผู้เล่น
                  ...validParticipants.map((p) {
                    final name = p['nickname'] ?? p['name'] ?? 'ผู้เล่น';
                    final amount =
                        (num.tryParse('${p['totalCost'] ?? 0}') ?? 0)
                            .toDouble();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(name,
                                style: const TextStyle(fontSize: 16),
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text('${amount.toStringAsFixed(0)} ฿',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }).toList(),

                  const Divider(height: 32, thickness: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ยอดรวมทั้งหมด',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(
                          '${(num.tryParse('${widget.data['totalIncome'] ?? 0}') ?? 0).toStringAsFixed(0)} ฿',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0E9D7A))),
                    ],
                  ),

                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: const [
                        Text('จัดการก๊วนง่ายๆ ไม่ต้องปวดหัว',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text('โหลดเลยแอป DropInBad',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0E9D7A))),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),

          // ปุ่ม Action (ไม่ถูกแคปเจอร์)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ข้าม',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0E9D7A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isSharing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.share, size: 20),
                  label: const Text('แชร์ลง LINE',
                      style: TextStyle(fontSize: 16)),
                  onPressed: _isSharing ? null : _shareImage,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

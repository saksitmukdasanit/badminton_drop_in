import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:badminton/component/button.dart';
import 'package:gal/gal.dart';

Future<bool?> showQrPaymentDialog(BuildContext context, double amount, {required String qrData, required int sessionId, required int billId}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => QrPaymentDialog(
      amount: amount,
      qrData: qrData,
      sessionId: sessionId,
      billId: billId,
    ),
  );
}

class QrPaymentDialog extends StatefulWidget {
  final double amount;
  final String qrData;
  final int sessionId;
  final int billId;

  const QrPaymentDialog({
    super.key,
    required this.amount,
    required this.qrData,
    required this.sessionId,
    required this.billId,
  });

  @override
  State<QrPaymentDialog> createState() => _QrPaymentDialogState();
}

class _QrPaymentDialogState extends State<QrPaymentDialog> {
  HubConnection? _hubConnection;
  int? _myUserId;
  final GlobalKey _qrKey = GlobalKey();
  bool _isSaving = false;
  Timer? _timer;
  int _remainingSeconds = 15 * 60; // 15 นาที

  @override
  void initState() {
    super.initState();
    _fetchMyUserIdAndInitSignalR();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer?.cancel();
          // ปิดหน้าต่างอัตโนมัติเมื่อเวลาหมดและคืนค่า false
          if (mounted) Navigator.of(context).pop(false);
        }
      });
    });
  }

  Future<void> _fetchMyUserIdAndInitSignalR() async {
    try {
      // ดึงข้อมูลตัวเองก่อนเพื่อเอา userId ไปเปรียบเทียบตอน SignalR ส่งมา
      final res = await ApiProvider().get('/Profiles/me');
      if (mounted) {
        _myUserId = res['data']['userId'] ?? res['data']['id'];
        _initSignalR();
      }
    } catch (e) {
      debugPrint('Error fetching user profile for QR Dialog: $e');
    }
  }

  Future<void> _initSignalR() async {
    _hubConnection = ApiProvider().createHubConnection('/managementGameHub');

    // ดักฟัง Event QrPaymentSuccess จาก Backend
    _hubConnection!.on("QrPaymentSuccess", (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        int paidBillId = int.tryParse(arguments[0].toString()) ?? 0;
        
        // ตรวจสอบว่า Bill ID ที่จ่ายสำเร็จ ตรงกับบิลที่กำลังเปิดอยู่หรือไม่
        if (paidBillId == widget.billId) {
          if (mounted) {
            Navigator.of(context).pop(true); // คืนค่า true บอกว่าจ่ายสำเร็จแล้ว
          }
        }
      }
    });

    try {
      await _hubConnection!.start();
      // เข้ากลุ่ม SignalR ของก๊วนนี้เพื่อรอรับ Event
      await _hubConnection!.invoke("JoinSessionGroup", args: [widget.sessionId.toString()]);
    } catch (e) {
      debugPrint("SignalR error in QR Dialog: $e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hubConnection?.stop(); // ปิดการเชื่อมต่อเมื่อปิด Dialog
    super.dispose();
  }

  Future<void> _saveQrCode() async {
    setState(() => _isSaving = true);
    try {
      RenderRepaintBoundary boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0); // ตั้งค่าความละเอียดภาพ
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();
        
        await Gal.putImageBytes(pngBytes, name: "QR_Payment_${widget.billId}");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('บันทึกรูป QR Code ลงเครื่องสำเร็จ'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ไม่สามารถบันทึกรูปได้: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'สแกนเพื่อชำระเงิน',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // --- เพิ่มการแสดงเวลานับถอยหลัง ---
            Text(
              'หมดเวลาใน: ${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')} นาที',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ยอดชำระ: ${widget.amount.toStringAsFixed(2)} บาท',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0E9D7A),
              ),
            ),
            const SizedBox(height: 24),
            // ห่อด้วย RepaintBoundary เพื่อให้สามารถแคปเจอร์ภาพนำไปบันทึกได้
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: QrImageView(
                  data: widget.qrData,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white, // สำคัญสำหรับแคปเจอร์ภาพ
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _isSaving ? null : _saveQrCode,
              icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download),
              label: const Text('ดาวน์โหลด QR Code'),
            ),
            const SizedBox(height: 24),
            const Text(
              'เมื่อชำระเงินสำเร็จ หน้าต่างนี้จะปิดอัตโนมัติ',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: CustomElevatedButton(
                text: 'ยกเลิก / ปิด',
                backgroundColor: Colors.white,
                foregroundColor: Colors.grey.shade700,
                side: BorderSide(color: Colors.grey.shade300),
                onPressed: () {
                  Navigator.of(context).pop(false); // คืนค่า false ถ้ายกเลิกเอง
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

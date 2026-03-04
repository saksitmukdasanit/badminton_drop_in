import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

// ฟังก์ชันกลางสำหรับเรียก QR Code Dialog
Future<bool?> showQrPaymentDialog(BuildContext context, double amount) {
  final qrData = "PromptPay:08x-xxx-xxxx:$amount"; 

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('สแกน QR Code เพื่อจ่ายเงิน'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 200.0,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'ยอดชำระ: ${amount.toStringAsFixed(0)} บาท', 
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false), 
          child: const Text('ยกเลิก')
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, true); // ส่งค่า true กลับไปเพื่อยืนยัน
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0E9D7A), 
            foregroundColor: Colors.white
          ),
          child: const Text('ยืนยันการชำระเงิน'),
        ),
      ],
    ),
  );
}

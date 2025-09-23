import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrCodeDisplayDialog extends StatelessWidget {
  final String qrData; // ข้อมูลที่จะใส่ใน QR Code
  final String? bottomText; // ข้อความเสริมด้านล่าง (ถ้ามี)

  const QrCodeDisplayDialog({super.key, required this.qrData, this.bottomText});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // แสดง QR Code
                QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 220.0, // ปรับขนาดให้ใหญ่ขึ้นเล็กน้อย
                ),
                // แสดงข้อความด้านล่างถ้ามี
                if (bottomText != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    bottomText!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          // ปุ่มปิด (X)
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showQrDialog(
  BuildContext context, {
  required String data,
  String? bottomText,
}) {
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      // เรียกใช้ Component ที่เราสร้าง
      return QrCodeDisplayDialog(qrData: data, bottomText: bottomText);
    },
  );
}

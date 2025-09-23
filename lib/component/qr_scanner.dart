import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isScanCompleted = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _handleBarcodeDetection(BarcodeCapture capture) {
    if (_isScanCompleted) return; 

    final String? scannedData = capture.barcodes.first.rawValue;
    if (scannedData != null) {
      setState(() {
        _isScanCompleted = true; 
      });
      _scannerController.stop();

      // แสดง Dialog แล้วค่อยกลับไปหน้าก่อนหน้า
      showSuccessDialog(context, scannedData).then((_) {
        // เมื่อ Dialog ปิด ให้กลับไปหน้า Home
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  Future<void> showSuccessDialog(BuildContext context, String result) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Text('สแกนสำเร็จ'),
            ],
          ),
          content: Text('ข้อมูลที่สแกนได้:\n$result'),
          actions: <Widget>[
            TextButton(
              child: const Text('ตกลง'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สแกน QR Code')),
      body: MobileScanner(
        controller: _scannerController,
        onDetect: _handleBarcodeDetection,
      ),
    );
  }
}

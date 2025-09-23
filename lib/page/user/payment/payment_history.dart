import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/payment_history_card.dart';
import 'package:flutter/material.dart';

class PaymentHistoryPage extends StatefulWidget {
  final String code;

  const PaymentHistoryPage({super.key, required this.code});

  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  @override
  void initState() {
    super.initState();
    // คุณสามารถใช้ widget.code ที่ได้รับมาเพื่อดึงข้อมูลจาก API ได้ที่นี่
    // ตัวอย่าง: print('Showing history for code: ${widget.code}');
    // fetchHistoryData(widget.code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      appBar: AppBarSubMain(title: 'ประวัติการชำระเงิน', isBack: false),
      body: Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFCBF5EA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          children: const [
            // --- การ์ดที่ 1: สถานะรอคืนเงิน ---
            PaymentHistoryCard(
              bookingType: 'จองเป็นผู้เล่นตัวจริง',
              status: PaymentStatus.pendingRefund,
              courtPrice: 120,
              fee: 10,
              totalPrice: 130,
              paymentDate: 'dd/mm/yy',
              paymentTime: 'hh:mm น.',
              paymentMethod: 'บัตรเครดิต **** **** **** 9000',
            ),
            SizedBox(height: 16),
            // --- การ์ดที่ 2: สถานะชำระเรียบร้อย ---
            PaymentHistoryCard(
              bookingType: 'จองเป็นผู้เล่นตัวจริง',
              status: PaymentStatus.completed,
              courtPrice: 120,
              fee: 10,
              totalPrice: 130,
              paymentDate: 'dd/mm/yy',
              paymentTime: 'hh:mm น.',
              paymentMethod: 'บัตรเครดิต **** **** **** 9000',
            ),
          ],
        ),
      ),
    );
  }
}

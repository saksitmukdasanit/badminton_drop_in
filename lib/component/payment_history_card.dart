// --- Component สำหรับสร้างการ์ดประวัติการจอง ---
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';

enum PaymentStatus { pendingRefund, completed }

class PaymentHistoryCard extends StatelessWidget {
  final String bookingType;
  final PaymentStatus status;
  final int courtPrice;
  final int fee;
  final int totalPrice;
  final String paymentDate;
  final String paymentTime;
  final String paymentMethod;

  const PaymentHistoryCard({
    super.key,
    required this.bookingType,
    required this.status,
    required this.courtPrice,
    required this.fee,
    required this.totalPrice,
    required this.paymentDate,
    required this.paymentTime,
    required this.paymentMethod,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPending = status == PaymentStatus.pendingRefund;
    final statusText = isPending ? 'ยกเลิกแล้วรอคืนเงิน' : 'ชำระเรียบร้อย';
    final statusColor = isPending ? Colors.red : Colors.green;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- ส่วนหัวข้อ ---
            Text(
              bookingType,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: getResponsiveFontSize(context, fontSize: 16),
                height: 0.1,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ระบบจะโอนเงินคืนภายใน 7 วันทำการ',
                  style: TextStyle(
                    fontWeight: FontWeight.w300,
                    fontSize: getResponsiveFontSize(context, fontSize: 14),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'T&C',
                    style: TextStyle(
                      // --- (แก้ไข) ปรับสีให้เข้ากับ Theme ใหม่ ---
                      color: Theme.of(context).primaryColor,
                      decoration: TextDecoration.underline,
                      decorationColor: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ],
            ),

            // const SizedBox(height: 12),
            // --- รายละเอียดราคา ---
            _buildPriceRow(context, 'ค่าสนาน', '$courtPrice บาท'),
            _buildPriceRow(context, 'ค่าธรรมเนียม', '$fee บาท'),
            _buildPriceRow(context, 'ราคารวม', '$totalPrice บาท', isBold: true),
            const Divider(height: 24),
            // --- สถานะการชำระเงิน ---
            Row(
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '$paymentDate $paymentTime',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  paymentMethod,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(width: 8),
                // --- ไอคอนบัตรเครดิต ---
                Image.asset('assets/icon/master_card.png',width: 24,),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Widget ย่อยสำหรับสร้างแถวของราคา
  Widget _buildPriceRow(
    BuildContext context,
    String title,
    String amount, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: getResponsiveFontSize(context, fontSize: 20),
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: getResponsiveFontSize(context, fontSize: 20),
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

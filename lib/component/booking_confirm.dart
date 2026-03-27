// --- 1. สร้าง Component สำหรับหน้าตา Dialog ---
import 'package:badminton/page/user/booking_confirm.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BookingConfirmDialog extends StatelessWidget {
  // --- กำหนด Parameter เพื่อให้ Dialog นำข้อมูลไปใช้ได้ ---
  final BookingDetails details;
  final VoidCallback onConfirm;

  const BookingConfirmDialog({
    super.key,
    required this.details,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min, // ทำให้ Dialog สูงเท่าที่จำเป็น
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- ชื่อสนาม ---
                Text(
                  details.courtName,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                // --- วันที่และเวลา ---
                Chip(
                  label: Text(
                    '${details.date}  ${details.time}',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  backgroundColor: dayColors.firstWhere(
                    (d) => d['code'] == details.day,
                  )['display'],
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(width: 0, color: Colors.transparent),
                  ),
                ),
                // --- รายละเอียดค่าใช้จ่ายและผู้เล่น (ปรับใหม่ให้อ่านง่ายขึ้น) ---
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildIconDetail(context, Icons.payments_outlined, 'ค่าสนาม', '${details.courtFee ?? details.price} บาท')),
                          Expanded(child: _buildIconDetail(context, Icons.sports_tennis, 'ค่าลูกแบด', details.isBuffet ? 'เหมาจ่าย ${details.shuttleFee ?? 0}บ.' : '${details.shuttleFee ?? 0}บ./เกม')),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildIconDetail(context, Icons.score, 'รูปแบบ', '21 แต้ม ${details.gameInfo}')),
                          Expanded(child: _buildIconDetail(context, Icons.group_outlined, 'ผู้เล่น', '${details.currentPlayers}/${details.maxPlayers} คน\n(สำรอง 10)')),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                // --- ข้อความยืนยัน ---
                if (details.currentPlayers >= details.maxPlayers) ...[
                  Center(
                    child: Text(
                      'คิวผู้เล่นเต็มแล้ว (จองเป็นตัวสำรอง)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ),
                  SizedBox(height: 16),
                ],
                // --- ปุ่ม Confirm ---
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onConfirm,
                    child: Text(
                      'Confirm',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // --- ปุ่มปิด (X) ---
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.grey),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  // Widget ย่อยสำหรับสร้างกล่องรายละเอียดพร้อมไอคอน (แบบใหม่)
  Widget _buildIconDetail(
    BuildContext context,
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- 2. ฟังก์ชันสำหรับเรียกใช้งาน Dialog ---
Future<void> showBookingConfirmDialog(
  BuildContext context,
  BookingDetails data,
) {
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      // เรียกใช้ Component ที่เราสร้าง พร้อมส่งข้อมูลเข้าไป
      return BookingConfirmDialog(
        details: data,
        onConfirm: () {
          // BEST PRACTICE: ปิด Dialog ก่อน ค่อย Push หน้าต่างใหม่ เพื่อป้องกัน Stack ขัดข้อง
          Navigator.of(context).pop();
          context.push('/payment/${data.code}');
        },
      );
    },
  );
}

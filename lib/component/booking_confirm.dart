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
                // --- รายละเอียดค่าใช้จ่ายและผู้เล่น ---
                _buildDetailRow(
                  'ค่าสนาม',
                  details.price,
                  'Yonex',
                  details.shuttlecockInfo,
                ),
                SizedBox(height: 8),
                _buildDetailRow('เล่น 21 แต้ม', details.gameInfo, '', ''),
                SizedBox(height: 8),
                _buildDetailRow(
                  'ผู้เล่น',
                  '${details.currentPlayers}',
                  'สำรอง',
                  '10',
                ),
                SizedBox(height: 24),
                // --- ข้อความยืนยัน ---
                Center(
                  child: Text(
                    'จองเป็นผู้เล่นตัวสำรอง',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(height: 16),
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

  // Widget ย่อยสำหรับสร้างแถวของรายละเอียด
  Widget _buildDetailRow(
    String title1,
    String value1,
    String title2,
    String value2,
  ) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Text(
                '$title1 ',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              Text(
                value1,
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Text(
                '$title2 ',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              Text(
                value2,
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
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
          // ฟังก์ชันที่จะทำงานเมื่อกดปุ่ม Confirm
          context.push('/payment/${data.code}');
          Navigator.of(context).pop();
        },
      );
    },
  );
}

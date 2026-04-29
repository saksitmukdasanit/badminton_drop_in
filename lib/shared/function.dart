import 'package:badminton/component/user_profile_dialog.dart';
import 'package:badminton/shared/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


final List<Map<String, dynamic>> dayColors = [
  {"code": "Sun", "display": Color(0xFFFFB3B3)}, // แดงอ่อน
  {"code": "Mon", "display": Color(0xFFFFF2B3)}, // เหลืองอ่อน
  {"code": "Tue", "display": Color(0xFFFFD6E8)}, // ชมพูอ่อน
  {"code": "Wed", "display": Color(0xFFB3FFB3)}, // เขียวอ่อน
  {"code": "Thu", "display": Color(0xFFFFE0B3)}, // ส้มอ่อน
  {"code": "Fri", "display": Color(0xFFCCE5FF)}, // ฟ้าอ่อน
  {"code": "Sat", "display": Color(0xFFE0CCFF)}, // ม่วงอ่อน
];


Map<String, String> formatSessionStart(String sessionStart) {
  try {
    final dateTime = DateTime.parse(
      sessionStart,
    ).toLocal(); // แปลงเป็นเวลาท้องถิ่น
    final dayOfWeek = DateFormat(
      'E',
      'en_US',
    ).format(dateTime); // วันย่อ (เช่น พ.)
    final date = DateFormat('dd/MM/yyyy').format(dateTime);
    final time = DateFormat('HH:mm').format(dateTime); // เวลา 24 ชม.
    return {'day': dayOfWeek, 'date': date, 'time': time};
  } catch (e) {
    return {'day': 'N/A', 'date': 'N/A', 'time': 'N/A'};
  }
}

// ฟังก์ชันสำหรับคำนวณขนาดตัวอักษรตามความกว้างหน้าจอ
double getResponsiveFontSize(BuildContext context, {double fontSize = 18}) {
  // ดึงความกว้างของหน้าจอ
  double screenWidth = MediaQuery.of(context).size.width;

  // ใช้ 390 เป็นขนาดหน้าจอมาตรฐาน (อ้างอิงจาก iPhone ทั่วไป)
  double scaleFactor = screenWidth / 390.0;
  
  // จำกัดไม่ให้ย่อเล็กเกินไป (0.85) และไม่ให้ขยายใหญ่เกินไปบน iPad (1.3)
  double clampedScale = scaleFactor.clamp(0.85, 1.3); 
  
  return fontSize * clampedScale;
}

Future<void> showUserProfileDialog(BuildContext context, {
  required String imageUrl,
  required String name,
  int? hostedCount,
  int? cancelledCount,
  int? organizerId,
  bool? isFollowed,
}) {
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      // เรียกใช้ Component ที่เราสร้าง
      return UserProfileDialog(
        imageUrl: imageUrl.isNotEmpty
            ? imageUrl
            : 'https://gateway.we-builds.com/wb-document/images/banner/banner_251839026.png',
        name: name,
        // ใช้ข้อมูลจริงที่ส่งเข้ามา และแปลงเป็น String
        gamesOrganized: (hostedCount ?? 0).toString(),
        gamesCancelled: (cancelledCount ?? 0).toString(),
        organizerId: organizerId,
        isInitiallyFollowed: isFollowed,
        onPhoneTap: () => UrlLauncherService.makePhoneCall("0876002118"),
        onFacebookTap: () => UrlLauncherService.launchFacebook(
          'https://www.facebook.com/uou.sleep',
        ),
        onLineTap: () => UrlLauncherService.launchLine('otee.saksit'),
      );
    },
  );
}

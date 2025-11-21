import 'package:badminton/component/user_profile_dialog.dart';
import 'package:badminton/model/game_card_model.dart';
import 'package:badminton/shared/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final Map<String, Color> skillLevels = {
  'P+': Colors.red,
  'P': Colors.orange,
  'P-': Colors.amber,
  'S+': Colors.yellow.shade700,
  'S': Colors.lime,
  'S-': Colors.lightGreen,
};

final List<Map<String, dynamic>> dayColors = [
  {"code": "Sun", "display": Color(0xFFFFB3B3)}, // แดงอ่อน
  {"code": "Mon", "display": Color(0xFFFFF2B3)}, // เหลืองอ่อน
  {"code": "Tue", "display": Color(0xFFFFD6E8)}, // ชมพูอ่อน
  {"code": "Wed", "display": Color(0xFFB3FFB3)}, // เขียวอ่อน
  {"code": "Thu", "display": Color(0xFFFFE0B3)}, // ส้มอ่อน
  {"code": "Fri", "display": Color(0xFFCCE5FF)}, // ฟ้าอ่อน
  {"code": "Sat", "display": Color(0xFFE0CCFF)}, // ม่วงอ่อน
];

final List<Map<String, dynamic>> statusColors = [
  {"code": "S", 'display': 'สำเร็จ', "color": Color(0xFF0E9D7A)}, // แดงอ่อน
  {
    "code": "O",
    'display': 'ค้างชำระ',
    "color": Color(0xFFDB2C2C),
  }, // เหลืองอ่อน
  {"code": "W", 'display': 'รอชำระ', "color": Color(0xFFFBBC05)}, // ชมพูอ่อน
  {
    "code": "WR",
    'display': 'รอคืนเงิน',
    "color": Color(0xFFFBBC05),
  }, // ชมพูอ่อน
  {"code": "C", 'display': 'ยกเลิก', "color": Color(0xFF64646D)}, // เขียวอ่อน
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

  // กำหนด Breakpoint ที่ 600 (ค่านี้ปรับได้ตามความเหมาะสม)
  if (screenWidth < 600) {
    // ถ้าความกว้างน้อยกว่า 600 (มองว่าเป็นโทรศัพท์)
    return fontSize;
  } else {
    // ถ้าความกว้างมากกว่าหรือเท่ากับ 600 (มองว่าเป็นแท็บเล็ต)
    return fontSize + 4;
  }
}

Future<void> showUserProfileDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      // เรียกใช้ Component ที่เราสร้าง
      return UserProfileDialog(
        imageUrl:
            'https://gateway.we-builds.com/wb-document/images/banner/banner_251839026.png',
        name: 'สมยศ คงยิ่ง',
        gamesOrganized: '1',
        gamesCancelled: '1',
        onPhoneTap: () => UrlLauncherService.makePhoneCall("0876002118"),
        onFacebookTap: () => UrlLauncherService.launchFacebook(
          'https://www.facebook.com/uou.sleep',
        ),
        onLineTap: () => UrlLauncherService.launchLine('otee.saksit'),
      );
    },
  );
}

//Theme.of(context).colorScheme.primary
//getResponsiveFontSize(context, fontSize: 16),

List<GameCardModel> dataListClass = [
  GameCardModel(
    teamName: 'ก๊วนแมวเหมียว',
    imageUrl:
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
    day: "wed",
    date: 'พุธ 16/05/2025',
    time: '18.00-21.00 น.',
    courtName: 'IM AMPORN BADMINTON COURT',
    location: 'ตลิ่งชัน กรุงเทพ',
    price: '100 บาท',
    shuttlecockInfo: '20 บาท/ลูก',
    gameInfo: '2 เซ็ท',
    currentPlayers: 56,
    maxPlayers: 70,
    organizerName: 'สมยศ คงยิ่ง',
    organizerImageUrl:
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251839026.png',
    isInitiallyBookmarked: true,
  ),
  GameCardModel(
    teamName: 'ตีเล่นๆ พี่ไม่ว่า',
    imageUrl:
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
    day: "thu",
    date: 'พฤหัส 17/05/2025',
    time: '19.00-22.00 น.',
    courtName: 'Nok Court',
    location: 'บางแค กรุงเทพ',
    price: '120 บาท',
    shuttlecockInfo: '25 บาท/ลูก',
    gameInfo: '3 เซ็ท',
    currentPlayers: 32,
    maxPlayers: 50,
    organizerName: 'ธวัชชัย เดชสุวรรณ',
    organizerImageUrl:
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
    isInitiallyBookmarked: false,
  ),
  GameCardModel(
    teamName: 'The Smashers',
    imageUrl:
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
    day: "fri",
    date: 'ศุกร์ 18/05/2025',
    time: '17.00-20.00 น.',
    courtName: 'Smash Badminton',
    location: 'ลาดพร้าว กรุงเทพ',
    price: '150 บาท',
    shuttlecockInfo: '30 บาท/ลูก',
    gameInfo: '2 เซ็ท',
    currentPlayers: 40,
    maxPlayers: 60,
    organizerName: 'อภิวัฒน์ ชัยเดช',
    organizerImageUrl:
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
    isInitiallyBookmarked: false,
  ),
  GameCardModel(
    teamName: 'สายบู๊',
    imageUrl:
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
    day: "sat",
    date: 'เสาร์ 19/05/2025',
    time: '13.00-16.00 น.',
    courtName: 'Badminton Pro Court',
    location: 'บางนา กรุงเทพ',
    price: '130 บาท',
    shuttlecockInfo: '28 บาท/ลูก',
    gameInfo: '2 เซ็ท',
    currentPlayers: 45,
    maxPlayers: 70,
    organizerName: 'ปิติพันธ์ พรหมคุณ',
    organizerImageUrl:
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
    isInitiallyBookmarked: true,
  ),
  GameCardModel(
    teamName: 'SPEED & SPIN',
    imageUrl:
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
    day: "sun",
    date: 'อาทิตย์ 20/05/2025',
    time: '10.00-13.00 น.',
    courtName: 'Spin Badminton',
    location: 'ปทุมธานี',
    price: '110 บาท',
    shuttlecockInfo: '22 บาท/ลูก',
    gameInfo: '3 เซ็ท',
    currentPlayers: 20,
    maxPlayers: 40,
    organizerName: 'ณัฐพล สมจิตร',
    organizerImageUrl:
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251839026.png',
    isInitiallyBookmarked: false,
  ),
  GameCardModel(
    teamName: 'ตีจริงเจ็บจริง',
    imageUrl:
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
    day: "mon",
    date: 'จันทร์ 21/05/2025',
    time: '20.00-23.00 น.',
    courtName: 'Ultimate Court',
    location: 'มีนบุรี กรุงเทพ',
    price: '100 บาท',
    shuttlecockInfo: '20 บาท/ลูก',
    gameInfo: '3 เซ็ท',
    currentPlayers: 38,
    maxPlayers: 60,
    organizerName: 'วันชัย คำหล้า',
    organizerImageUrl:
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
    isInitiallyBookmarked: false,
  ),
  GameCardModel(
    teamName: 'มือใหม่ หัดหวด',
    imageUrl:
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
    day: "tue",
    date: 'อังคาร 22/05/2025',
    time: '14.00-17.00 น.',
    courtName: 'Starter Court',
    location: 'รังสิต ปทุมธานี',
    price: '90 บาท',
    shuttlecockInfo: '18 บาท/ลูก',
    gameInfo: '2 เซ็ท',
    currentPlayers: 15,
    maxPlayers: 30,
    organizerName: 'สุชาติ ทองอร่าม',
    organizerImageUrl:
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
    isInitiallyBookmarked: true,
  ),
  GameCardModel(
    teamName: 'ลุยไม่ยั้ง',
    imageUrl:
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
    day: "wed",
    date: 'พุธ 23/05/2025',
    time: '18.30-21.30 น.',
    courtName: 'City Court',
    location: 'ดินแดง กรุงเทพ',
    price: '140 บาท',
    shuttlecockInfo: '26 บาท/ลูก',
    gameInfo: '3 เซ็ท',
    currentPlayers: 50,
    maxPlayers: 70,
    organizerName: 'สมชาย มณี',
    organizerImageUrl:
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
    isInitiallyBookmarked: true,
  ),
];

List<dynamic> dataList = [
  {
    "teamName": 'ก๊วนแมวเหมียว',
    "imageUrl":
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
    "day": "wed",
    "date": 'พุธ 16/05/2025',
    "time": '18.00-21.00 น.',
    "courtName": 'IM AMPORN BADMINTON COURT',
    "location": 'ตลิ่งชัน กรุงเทพ',
    "price": '100 บาท',
    "shuttlecockInfo": '20 บาท/ลูก',
    "gameInfo": '2 เซ็ท',
    "currentPlayers": 56,
    "maxPlayers": 70,
    "organizerName": 'สมยศ คงยิ่ง',
    "organizerImageUrl":
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251839026.png',
    "isInitiallyBookmarked": true,
    "status": "",
  },
  {
    "teamName": 'ตีเล่นๆ พี่ไม่ว่า',
    "imageUrl":
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
    "day": "thu",
    "date": 'พฤหัส 17/05/2025',
    "time": '19.00-22.00 น.',
    "courtName": 'Nok Court',
    "location": 'บางแค กรุงเทพ',
    "price": '120 บาท',
    "shuttlecockInfo": '25 บาท/ลูก',
    "gameInfo": '3 เซ็ท',
    "currentPlayers": 32,
    "maxPlayers": 50,
    "organizerName": 'ธวัชชัย เดชสุวรรณ',
    "organizerImageUrl":
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
    "isInitiallyBookmarked": false,
    "status": "S",
  },
  {
    "teamName": 'The Smashers',
    "imageUrl":
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
    "day": "fri",
    "date": 'ศุกร์ 18/05/2025',
    "time": '17.00-20.00 น.',
    "courtName": 'Smash Badminton',
    "location": 'ลาดพร้าว กรุงเทพ',
    "price": '150 บาท',
    "shuttlecockInfo": '30 บาท/ลูก',
    "gameInfo": '2 เซ็ท',
    "currentPlayers": 40,
    "maxPlayers": 60,
    "organizerName": 'อภิวัฒน์ ชัยเดช',
    "organizerImageUrl":
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
    "isInitiallyBookmarked": false,
    "status": "W",
  },
  {
    "teamName": 'สายบู๊',
    "imageUrl":
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
    "day": "sat",
    "date": 'เสาร์ 19/05/2025',
    "time": '13.00-16.00 น.',
    "courtName": 'Badminton Pro Court',
    "location": 'บางนา กรุงเทพ',
    "price": '130 บาท',
    "shuttlecockInfo": '28 บาท/ลูก',
    "gameInfo": '2 เซ็ท',
    "currentPlayers": 45,
    "maxPlayers": 70,
    "organizerName": 'ปิติพันธ์ พรหมคุณ',
    "organizerImageUrl":
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
    "isInitiallyBookmarked": true,
    "status": "C",
  },
  {
    "teamName": 'SPEED & SPIN',
    "imageUrl":
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
    "day": "sun",
    "date": 'อาทิตย์ 20/05/2025',
    "time": '10.00-13.00 น.',
    "courtName": 'Spin Badminton',
    "location": 'ปทุมธานี',
    "price": '110 บาท',
    "shuttlecockInfo": '22 บาท/ลูก',
    "gameInfo": '3 เซ็ท',
    "currentPlayers": 20,
    "maxPlayers": 40,
    "organizerName": 'ณัฐพล สมจิตร',
    "organizerImageUrl":
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251839026.png',
    "isInitiallyBookmarked": false,
    "status": "O",
  },
  {
    "teamName": 'ตีจริงเจ็บจริง',
    "imageUrl":
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
    "day": "mon",
    "date": 'จันทร์ 21/05/2025',
    "time": '20.00-23.00 น.',
    "courtName": 'Ultimate Court',
    "location": 'มีนบุรี กรุงเทพ',
    "price": '100 บาท',
    "shuttlecockInfo": '20 บาท/ลูก',
    "gameInfo": '3 เซ็ท',
    "currentPlayers": 38,
    "maxPlayers": 60,
    "organizerName": 'วันชัย คำหล้า',
    "organizerImageUrl":
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
    "isInitiallyBookmarked": false,
    "status": "WR",
  },
  {
    "teamName": 'มือใหม่ หัดหวด',
    "imageUrl":
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
    "day": "tue",
    "date": 'อังคาร 22/05/2025',
    "time": '14.00-17.00 น.',
    "courtName": 'Starter Court',
    "location": 'รังสิต ปทุมธานี',
    "price": '90 บาท',
    "shuttlecockInfo": '18 บาท/ลูก',
    "gameInfo": '2 เซ็ท',
    "currentPlayers": 15,
    "maxPlayers": 30,
    "organizerName": 'สุชาติ ทองอร่าม',
    "organizerImageUrl":
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
    "isInitiallyBookmarked": true,
    "status": "S",
  },
  {
    "teamName": 'ลุยไม่ยั้ง',
    "imageUrl":
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
    "day": "wed",
    "date": 'พุธ 23/05/2025',
    "time": '18.30-21.30 น.',
    "courtName": 'City Court',
    "location": 'ดินแดง กรุงเทพ',
    "price": '140 บาท',
    "shuttlecockInfo": '26 บาท/ลูก',
    "gameInfo": '3 เซ็ท',
    "currentPlayers": 50,
    "maxPlayers": 70,
    "organizerName": 'สมชาย มณี',
    "organizerImageUrl":
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
    "isInitiallyBookmarked": true,
    "status": "",
  },
];

import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/game_card.dart';
import 'package:badminton/component/game_card2.dart';
import 'package:flutter/material.dart';

class FavouritePage extends StatefulWidget {
  const FavouritePage({super.key});

  @override
  FavouritePageState createState() => FavouritePageState();
}

class FavouritePageState extends State<FavouritePage> {
  double gapHeight = 20;
  late bool isBookmarked = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false,
      backgroundColor: Colors.white,
      appBar: AppBarSubMain(title: 'Favourite'),
      body: Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFCBF5EA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          children: [
            // --- ส่วนหัวข้อ "เกมที่บันทึก" ---
            _buildSectionHeader(context, title: 'เกมที่บันทึก'),
            const SizedBox(height: 16),

            // --- การ์ดเกม ---
            GameCard(
              teamName: 'ก๊วนแมวเหมียว',
              imageUrl:
                  'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
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
              isInitiallyBookmarked: true, // Bookmark ไว้
            ),
            const SizedBox(height: 32),
            GameCard2(
              teamName: 'ชื่อก๊วนก๊วนก๊วนก๊วน',
              imageUrl:
                  'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
              day: 'wed',
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
              isInitiallyBookmarked: false,
            ),
            // --- ส่วนหัวข้อ "ผู้จัดที่ชอบ" ---
            _buildSectionHeader(context, title: 'ผู้จัดที่ชอบ'),
            const SizedBox(height: 16),

            // --- รายการผู้จัด ---
            _buildFavoriteOrganizer(context),
          ],
        ),
      ),
    );
  }

  // Widget สำหรับสร้าง Header ของแต่ละ Section
  Widget _buildSectionHeader(BuildContext context, {required String title}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        TextButton(
          onPressed: () {},
          child: Text(
            'ดูเพิ่มเติม',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  // Widget สำหรับสร้างรายการผู้จัดที่ชอบ
  Widget _buildFavoriteOrganizer(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 36,
          backgroundImage: NetworkImage(
            "https://gateway.we-builds.com/wb-document/images/banner/banner_251839026.png",
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "สมัยศ คงยิ่ง",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 4),
            Text("จำนวนครั้งที่จัด 1 ครั้ง"),
            Text("จำนวนที่ยกเลิกจัด 1 ครั้ง"),
          ],
        ),
      ],
    );
  }
}

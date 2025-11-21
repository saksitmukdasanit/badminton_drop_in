import 'dart:math';

import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dropdown.dart';
import 'package:badminton/component/text_box.dart';
import 'package:badminton/page/user/booking_confirm.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// class Gang {
//   final int id;
//   final String gangName;
//   final String organizer;
//   final int price;
//   final String status;
//   final String date;

//   Gang({
//     required this.id,
//     required this.gangName,
//     required this.organizer,
//     required this.price,
//     required this.status,
//     required this.date,
//   });
// }

class HistoryUserPage extends StatefulWidget {
  const HistoryUserPage({super.key});

  @override
  HistoryUserPageState createState() => HistoryUserPageState();
}

class HistoryUserPageState extends State<HistoryUserPage> {
  late TextEditingController searchController;
  String? _selectedItem;
  final List<dynamic> _items = [
    {"code": 1, "value": 'ล่าสุด'},
    {"code": 2, "value": 'ยอดนิยม'},
    {"code": 3, "value": 'วันที่'},
    {"code": 4, "value": 'ใกล้ฉัน'},
    {"code": 5, "value": 'ค่าสนาม'},
    {"code": 6, "value": 'ค่าลูก'},
  ];
  late List<BookingDetails> bookingDetails;
  @override
  void initState() {
    searchController = TextEditingController();
    bookingDetails = _generateMockGangs(15);
    super.initState();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<BookingDetails> _generateMockGangs(int count) {
    final random = Random();
    return List.generate(count, (i) {
      return BookingDetails(
        code: i + 1,
        teamName: 'ก๊วนแมวเหมียว',
        imageUrl:
            'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
        day: 'wed',
        date: '16/05/2025 18.00-21.00 น.',
        time: 'time',
        courtName: 'courtName',
        location: 'location',
        price: '210',
        shuttlecockInfo: 'shuttlecockInfo',
        shuttlecockBrand: 'shuttlecockBrand',
        gameInfo: 'gameInfo',
        courtNumbers:'',
        currentPlayers: 56,
        maxPlayers: 60,
        organizerName: 'สมยศ คงยิ่ง',
        organizerImageUrl:
            'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
        status: [1, 2, 3, 4][random.nextInt([1, 2, 3, 4].length)],
        notes: '',
        courtImageUrls: [
          'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
          'https://gateway.we-builds.com/wb-document/images/banner/banner_251839026.png',
          'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
          'https://gateway.we-builds.com/wb-document/images/banner/banner_251839026.png',
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      appBar: AppBarSubMain(title: 'History', isBack: false),
      body: Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFCBF5EA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CustomTextFormField(
              labelText: 'พิมพ์เพื่อค้นหา...',
              hintText: '',
              controller: searchController,
              suffixIconData: Icons.filter_list,
              onSuffixIconPressed: () {
                // setState(() {
                //   _showFilter(context);
                // });
              },
            ),

            const SizedBox(height: 15),
            CustomDropdown(
              labelText: 'จัดเรียงตาม',
              initialValue: _selectedItem,
              items: _items,
              // isRequired: true,
              onChanged: (value) {
                setState(() {
                  _selectedItem = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณาเลือกเพศ';
                }
                return null;
              },
            ),
            const SizedBox(height: 15),
            _buildHeader(context),
            Expanded(
              child: ListView.builder(
                itemCount: bookingDetails.length,
                itemBuilder: (context, index) {
                  return _buildGangRow(bookingDetails[index]);
                },
              ),
            ),
            _buildPagination(),
          ],
        ),
      ),
    );
  }

  // Widget สำหรับ Header ของตาราง
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'วันเวลา',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'ชื่อก๊วน',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'ผู้จัด',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'จ่าย',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'สถานะ',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget สำหรับแสดงข้อมูลผู้เล่นแต่ละแถว
  Widget _buildGangRow(BookingDetails data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              data.date,
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 10),
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              data.teamName,
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              data.organizerName,
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              data.price,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: GestureDetector(
              onTap: () {
                context.push('/booking-confirm-history', extra: data);
              },
              child: Text(
                statusColors.firstWhere(
                  (d) => d['code'] == data.status,
                )['display'],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: getResponsiveFontSize(context, fontSize: 14),
                  fontWeight: FontWeight.w500,
                  color: statusColors.firstWhere(
                    (d) => d['code'] == data.status,
                  )['color'],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget สำหรับ Pagination ด้านล่าง
  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPageNumber('1', isActive: true),
          _buildPageNumber('2'),
        ],
      ),
    );
  }

  Widget _buildPageNumber(String text, {bool isActive = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: GestureDetector(
        onTap: () {
          setState(() {});
        },
        child: Text(
          text,
          style: TextStyle(
            color: isActive ? Colors.green : Colors.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

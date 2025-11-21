import 'dart:async';
import 'package:badminton/component/Button.dart';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/booking_confirm.dart';
import 'package:badminton/component/qr_dialog.dart';
import 'package:badminton/shared/function.dart';
import 'package:badminton/shared/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BookingDetails {
  final int code;
  final String teamName;
  final String imageUrl;
  final String day;
  final String date;
  final String time;
  final String courtName;
  final String location;
  final String price;
  final String shuttlecockInfo;
  final String shuttlecockBrand;
  final String gameInfo;
  final String courtNumbers;
  final int currentPlayers;
  final int maxPlayers;
  final String organizerName;
  final String organizerImageUrl;
  final List<String> courtImageUrls;
  final String notes;
  final int status;

  BookingDetails({
    required this.code,
    required this.teamName,
    required this.imageUrl,
    required this.day,
    required this.date,
    required this.time,
    required this.courtName,
    required this.location,
    required this.price,
    required this.shuttlecockInfo,
    required this.shuttlecockBrand,
    required this.gameInfo,
    required this.courtNumbers,
    required this.currentPlayers,
    required this.maxPlayers,
    required this.organizerName,
    required this.organizerImageUrl,
    required this.courtImageUrls,
    required this.notes,
    required this.status,
  });
}

class BookingConfirmPage extends StatefulWidget {
  final BookingDetails details;

  const BookingConfirmPage({super.key, required this.details});

  @override
  State<BookingConfirmPage> createState() => _BookingConfirmPageState();
}

class _BookingConfirmPageState extends State<BookingConfirmPage> {
  final PageController _pageController = PageController();
  Timer? _timer;
  int _currentPage = 0;

  // --- (แก้ไข) ใช้ข้อมูลรูปภาพจาก parameter ---
  late final List<String> _imageUrls;

  @override
  void initState() {
    super.initState();
    _imageUrls = widget.details.courtImageUrls; // <-- ใช้ข้อมูลที่ส่งมา

    // --- ตั้งค่า Timer ให้เลื่อนรูปทุก 3 วินาที ---
    if (_imageUrls.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
        if (_currentPage < _imageUrls.length - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeIn,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildbottomBar() {
    switch (widget.details.status) {
      case 1:
        return _buildBottomBar();
      case 6:
        return _buildBottomBarS();
      case 2:
        return _buildBottomBarW();
      case 3 || 4:
        return _buildBottomBarWRC();
      case 5:
        return _buildBottomBarO();
      default:
        return _buildBottomBar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      appBar: AppBarSubMain(title: 'หาก๊วน'),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Container(color: Colors.white, child: _buildbottomBar()),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _imageUrls.length,
              itemBuilder: (context, index) {
                return Image.network(_imageUrls[index], fit: BoxFit.cover);
              },
            ),
          ),
          Expanded(flex: 3, child: _buildContentSection(context)),
          const Spacer(), // ใช้ Spacer เพื่อดันปุ่ม (ใน bottomNavigationBar) ลงไปอีก
        ],
      ),
    );
  }

  // Widget สำหรับสร้างส่วนเนื้อหาทั้งหมด
  Widget _buildContentSection(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- วันที่และเวลา ---
          Chip(
            label: Text(
              // --- (แก้ไข) ใช้ข้อมูลจาก parameter ---
              '${widget.details.date}  ${widget.details.time}',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: dayColors.firstWhere(
              (d) => d['code'] == widget.details.day,
            )['display'],
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(width: 0, color: Colors.transparent),
            ),
          ),
          // --- ชื่อสนามและที่อยู่ ---
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.details.courtName,
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: getResponsiveFontSize(context, fontSize: 18),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      UrlLauncherService.openMapByQuery(
                        widget.details.courtName,
                      );
                    },
                    icon: Icon(
                      Icons.location_on,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                  ),
                ],
              ),
              Text(
                widget.details.location,
                style: TextStyle(
                  color: Color(0xFF64646D),
                  fontSize: getResponsiveFontSize(context, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // --- รูปโปรไฟล์ผู้จัด ---
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage(widget.details.organizerImageUrl),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => showUserProfileDialog(context),
                child: Text(
                  widget.details.organizerName,
                  style: TextStyle(
                    fontSize: getResponsiveFontSize(context, fontSize: 16),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // --- ไอคอนสิ่งอำนวยความสะดวก ---
          Wrap(
            spacing: 8.0, // ระยะห่างระหว่างไอคอนแนวนอน
            runSpacing: 8.0, // ระยะห่างระหว่างบรรทัด
            children: [
              _buildFacilityIcon(Icons.shower),
              _buildFacilityIcon(Icons.wifi),
              _buildFacilityIcon(Icons.ac_unit),
              _buildFacilityIcon(Icons.chair),
              _buildFacilityIcon(Icons.manage_search),
              _buildFacilityIcon(Icons.directions_run),
              _buildFacilityIcon(Icons.shower),
              _buildFacilityIcon(Icons.shower),
            ],
          ),
          const SizedBox(height: 12),
          // --- ดูผู้เล่น และ อ่านเพิ่มเติม ---
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildText('ค่าสนาม ${widget.details.price}'),
                  _buildText(
                    ' ${widget.details.shuttlecockBrand} ${widget.details.shuttlecockInfo}',
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildText('${widget.details.gameInfo}'),
                  _buildText('สนามที่ ${widget.details.courtNumbers}'),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildText(
                        'ผู้เล่น ${widget.details.currentPlayers}/${widget.details.maxPlayers} คน',
                      ),
                      _buildText('สำรอง 00/10 คน'),
                    ],
                  ),
                  GestureDetector(
                    onTap: () =>
                        context.push('/player-list/${widget.details.teamName}'),
                    child: Text(
                      'ดูผู้เล่น',
                      style: TextStyle(
                        color: Colors.teal[600],
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              Text('note : ${widget.details.notes}'),
            ],
          ),
          const SizedBox(height: 130),
        ],
      ),
    );
  }

  // Widget สำหรับสร้างไอคอนสิ่งอำนวยความสะดวก
  Widget _buildFacilityIcon(IconData icon) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: Icon(icon, color: Colors.white),
    );
  }

  Widget _buildText(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: getResponsiveFontSize(context, fontSize: 14),
        fontWeight: FontWeight.w300,
      ),
    );
  }

  Widget _buildBottomBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'จองเป็นผู้เล่นตัวสำรอง',
          style: TextStyle(
            fontSize: getResponsiveFontSize(context, fontSize: 16),
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          'ถ้าไม่ได้รับเลือกจะโอนเงินคืนภายใน 7 วันทำการ',
          style: TextStyle(
            fontSize: getResponsiveFontSize(context, fontSize: 16),
            fontWeight: FontWeight.w300,
            color: Color(0xFF64646D),
          ),
        ),
        Container(
          // width: double.infinity,
          // color: Color(0xFFCBF5EA),
          padding: EdgeInsets.all(15),
          child: CustomElevatedButton(
            text: 'Book Now',
            fontSize: 16,
            onPressed: () {
              showBookingConfirmDialog(context, widget.details);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBarS() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ชำระเงินแล้ว',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 20),
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '190 บาท',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 20),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),

        Container(
          // width: double.infinity,
          // color: Color(0xFFCBF5EA),
          padding: EdgeInsets.all(15),
          child: CustomElevatedButton(
            text: 'รายละเอียดเกม',
            fontSize: 16,
            backgroundColor: Colors.white,
            foregroundColor: Theme.of(context).colorScheme.primary,
            onPressed: () {
              context.push('/history-detail/1');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBarW() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ชำระเงินแล้ว',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 20),
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '130 บาท',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 20),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),

        Row(
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 15),
                child: CustomElevatedButton(
                  text: 'ค่าใช้จ่าย',
                  fontSize: 16,
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  onPressed: () {
                    context.push('/payment-now/1');
                  },
                ),
              ),
            ),
            SizedBox(width: MediaQuery.of(context).size.width * 0.04),
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 15),
                child: CustomElevatedButton(
                  text: 'Check In',
                  fontSize: 16,
                  onPressed: () {
                    showQrDialog(
                      context,
                      data: 'user_id_12345_check_in', // ข้อมูลที่จะใส่ใน QR
                      bottomText:
                          'กรุณายื่น QR Code นี้ให้ผู้จัดสแกน', // ข้อความเสริม (ไม่ใส่ก็ได้)
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
    // return Column(
    //   mainAxisSize: MainAxisSize.min,
    //   crossAxisAlignment: CrossAxisAlignment.stretch,
    //   children: [
    //     Row(
    //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
    //       children: [
    //         Text(
    //           'ชำระเงินแล้ว ตัวจริง',
    //           style: TextStyle(
    //             fontSize: getResponsiveFontSize(context, fontSize: 20),
    //             fontWeight: FontWeight.w700,
    //           ),
    //         ),
    //         Text(
    //           '130 บาท',
    //           style: TextStyle(
    //             fontSize: getResponsiveFontSize(context, fontSize: 20),
    //             fontWeight: FontWeight.w700,
    //           ),
    //         ),
    //       ],
    //     ),

    //     Container(
    //       // width: double.infinity,
    //       // color: Color(0xFFCBF5EA),
    //       padding: EdgeInsets.all(15),
    //       child: CustomElevatedButton(
    //         text: 'ยกเลิก',
    //         backgroundColor: Colors.white,
    //         foregroundColor: Theme.of(context).colorScheme.primary,
    //         fontSize: 16,
    //         onPressed: () {
    //           context.push('/payment-cancel/1');
    //         },
    //       ),
    //     ),
    //   ],
    // );
  }

  Widget _buildBottomBarO() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ค้างชำระ',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 20),
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '90 บาท',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 20),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),

        Row(
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 15),
                child: CustomElevatedButton(
                  text: 'รายละเอียดเกมส์',
                  fontSize: 16,
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  onPressed: () {
                    context.push('/history-detail/1');
                  },
                ),
              ),
            ),
            SizedBox(width: MediaQuery.of(context).size.width * 0.04),
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 15),
                child: CustomElevatedButton(
                  text: 'ชำระเงิน',
                  fontSize: 16,
                  onPressed: () {
                    showBookingConfirmDialog(context, widget.details);
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomBarWRC() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.details.status == "C" ? 'คืนเงินเรียบร้อย' : 'รอคืนเงิน',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 20),
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '210 บาท',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 20),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(width: MediaQuery.of(context).size.width * 0.04),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 15),
                child: CustomElevatedButton(
                  text: 'รายละเอียด',
                  fontSize: 16,
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  onPressed: () {
                    context.push('/payment-history/1');
                  },
                ),
              ),
            ),
            SizedBox(width: MediaQuery.of(context).size.width * 0.04),
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 15),
                child: CustomElevatedButton(
                  text: 'จองอีกครั้ง',
                  fontSize: 16,
                  onPressed: () {},
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

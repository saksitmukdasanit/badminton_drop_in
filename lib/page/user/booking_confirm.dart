import 'dart:async';
import 'package:badminton/component/Button.dart';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/booking_confirm.dart';
import 'package:badminton/component/qr_dialog.dart';
import 'package:badminton/shared/function.dart';
import 'package:badminton/shared/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/shared/api_provider.dart';

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
  final String currentUserStatus; // เพิ่ม field นี้
  final double? courtFee;
  final double? shuttleFee;
  final bool isBuffet; // true = เหมาจ่าย, false = คิดตามเกม
  final String sessionStart;

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
    this.currentUserStatus = 'NotJoined', // ค่า Default
    this.courtFee,
    this.shuttleFee,
    this.isBuffet = false,
    required this.sessionStart,
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
  bool _isCheckedInLocal = false;

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
    // 1. ถ้าก๊วนถูกยกเลิก หรือรอคืนเงิน
    if (widget.details.status == 3 || widget.details.status == 4 || widget.details.currentUserStatus == 'Refund') {
      return _buildBottomBarWRC();
    }

    // 2. ถ้าผู้เล่น Check Out และชำระเงินเรียบร้อยแล้ว
    if (widget.details.currentUserStatus == 'CheckedOut') {
      return _buildBottomBarS();
    }

    // 3. ถ้าผู้เล่นมีส่วนร่วมกับก๊วนนี้ (ตัวจริง, ตัวสำรอง, เช็คอินแล้ว)
    if (widget.details.currentUserStatus == 'Joined' ||
        widget.details.currentUserStatus == 'CheckedIn' ||
        widget.details.currentUserStatus == 'Waitlisted') {
      return _buildPlayerActiveBar();
    }

    // 4. ถ้าผู้เล่นเป็นคนนอก (NotJoined)
    if (widget.details.status == 1) {
      return _buildBookNowBar();
    } else if (widget.details.status == 5) {
      return _buildBottomBarO();
    }

    return _buildBookNowBar(); // Fallback
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      appBar: AppBarSubMain(title: 'รายละเอียดก๊วน'), // แก้ไข: ให้ชื่อสื่อความหมายตรงกลางไม่สับสน
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
          // --- ข้อมูลผู้จัด (ปรับให้เป็น Card สวยงาม) ---
          GestureDetector(
            onTap: () => showUserProfileDialog(
              context,
              imageUrl: widget.details.organizerImageUrl,
              name: widget.details.organizerName,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundImage: NetworkImage(widget.details.organizerImageUrl),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ผู้จัด: ${widget.details.organizerName}',
                    style: TextStyle(
                      fontSize: getResponsiveFontSize(context, fontSize: 14),
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                ],
              ),
            ),
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
          
          // --- รายละเอียดก๊วน (ปรับเป็น Grid ให้อ่านง่าย) ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildInfoItem(context, Icons.score, 'รูปแบบ', widget.details.gameInfo)),
                    Expanded(child: _buildInfoItem(context, Icons.sports_tennis, 'ลูกแบด', '${widget.details.shuttlecockBrand} ${widget.details.shuttlecockInfo}')),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildInfoItem(context, Icons.grid_on, 'สนาม', widget.details.courtNumbers.isNotEmpty ? widget.details.courtNumbers : '-')),
                    Expanded(child: _buildInfoItem(context, Icons.group_outlined, 'ผู้เล่น', '${widget.details.currentPlayers}/${widget.details.maxPlayers} คน')),
                  ],
                ),
                const Divider(height: 24),
                // ปุ่มดูผู้เล่น
                GestureDetector(
                  onTap: () => context.push('/player-list/${widget.details.code}'), // เปลี่ยนเป็น code (sessionId)
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.visibility_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'ดูรายชื่อผู้เล่นทั้งหมด',
                        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // --- โครงสร้างค่าใช้จ่าย (เชื่อมโยงกับฝั่ง Organizer) ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFCBF5EA).withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0E9D7A).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20, color: Color(0xFF0E9D7A)),
                    const SizedBox(width: 8),
                    const Text(
                      'รายละเอียดค่าใช้จ่าย',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0E9D7A)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ค่าสนาม (จ่ายล่วงหน้า)'),
                    Text('${widget.details.courtFee ?? widget.details.price} บาท', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ค่าลูกแบด'),
                    Text(
                      widget.details.isBuffet 
                          ? '${widget.details.shuttleFee ?? 0} บาท (เหมาจ่าย)'
                          : '${widget.details.shuttleFee ?? 0} บาท / เกม',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(color: Colors.black12, height: 1),
                const SizedBox(height: 8),
                const Text(
                  '* หมายเหตุ: ค่าลูกแบดและส่วนต่างอื่นๆ จะถูกคำนวณและเรียกเก็บเพิ่มหลังจบเกม ตามรูปแบบที่ผู้จัดได้ตั้งค่าไว้',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // --- Notes ---
          if (widget.details.notes.isNotEmpty) ...[
            const Text('รายละเอียดเพิ่มเติม:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              widget.details.notes,
              style: TextStyle(color: Colors.grey[700], fontSize: 14, height: 1.5),
            ),
          ],
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

  // Helper สำหรับสร้างไอคอนคู่กับ Text ใน Grid
  Widget _buildInfoItem(BuildContext context, IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
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

  Future<void> _showMyQrCodeDialog() async {
    // แสดง Loading ระหว่างดึงข้อมูล User ID
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // ดึงข้อมูล User ของตัวเองเพื่อเอาไปสร้าง QR Code (ส่ง Public ID หรือ User ID ให้ผู้จัดสแกน)
      final res = await ApiProvider().get('/Profiles/me');
      final qrData = res['data']['userPublicId'] ?? res['data']['userId'] ?? res['data']['id'];

      if (mounted) {
        Navigator.pop(context); // ปิดหน้า Loading
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'QR Code สำหรับเช็คอิน',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'โปรดแสดง QR Code นี้ให้ผู้จัดสแกน\nเพื่อยืนยันการมาถึงของคุณ',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    QrImageView(
                      data: qrData.toString(),
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: CustomElevatedButton(
                        text: 'ปิด',
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // ปิดหน้า Loading
        showDialogMsg(
          context,
          title: 'เกิดข้อผิดพลาด',
          subtitle: 'ไม่สามารถโหลดข้อมูล QR Code ได้',
          btnLeft: 'ตกลง',
          onConfirm: () {},
        );
      }
    }
  }

  Future<void> _cancelBooking() async {
    showDialogMsg(
      context,
      title: 'ยืนยันการยกเลิก',
      subtitle: 'คุณต้องการยกเลิกการเข้าร่วมก๊วนนี้ใช่หรือไม่?',
      isWarning: true,
      btnLeft: 'ยกเลิกก๊วน',
      btnLeftBackColor: Colors.red,
      btnLeftForeColor: Colors.white,
      btnRight: 'ปิด',
      onConfirm: () async {
        try {
          await ApiProvider().delete('/player/gamesessions/${widget.details.code}/cancel');
          if (mounted) {
            showDialogMsg(
              context,
              title: 'สำเร็จ',
              subtitle: 'ยกเลิกการจองเรียบร้อยแล้ว',
              btnLeft: 'ตกลง',
              onConfirm: () {
                context.pop(); // ปิด dialog
                context.pop(); // กลับไปหน้าก่อนหน้า
              },
            );
          }
        } catch (e) {
          if (mounted) {
            showDialogMsg(
              context,
              title: 'เกิดข้อผิดพลาด',
              subtitle: e.toString().replaceFirst('Exception: ', ''),
              btnLeft: 'ตกลง',
              onConfirm: () {},
            );
          }
        }
      },
    );
  }

  // --- Widget ใหม่: แถบสถานะสำหรับคนที่เข้าร่วมแล้ว ---
  Widget _buildPlayerActiveBar() {
    if (widget.details.currentUserStatus == 'Waitlisted') {
      return Container(
        padding: const EdgeInsets.all(15),
        child: const CustomElevatedButton(
          text: 'คุณอยู่ในคิวสำรอง',
          backgroundColor: Colors.orange,
          onPressed: null,
        ),
      );
    }

    // สำหรับคนที่เป็น Joined หรือ CheckedIn
    DateTime startTime;
    try {
      startTime = DateTime.parse(widget.details.sessionStart).toLocal();
    } catch (e) {
      startTime = DateTime.now().add(const Duration(hours: 4));
    }
    final Duration timeUntilStart = startTime.difference(DateTime.now());

    // 1. ถ้ายังเหลือเวลาเกิน 3 ชม. และ ยังไม่ได้เช็คอิน
    if (timeUntilStart.inMinutes > 180 && widget.details.currentUserStatus != 'CheckedIn' && !_isCheckedInLocal) {
      return Container(
        padding: const EdgeInsets.all(15),
        child: CustomElevatedButton(
          text: 'ยกเลิกการจอง',
          backgroundColor: Colors.red,
          onPressed: _cancelBooking,
        ),
      );
    } 
    // 2. ถ้าน้อยกว่า 3 ชม. หรือ เช็คอินเรียบร้อยแล้ว
    else {
      bool isCheckedIn = _isCheckedInLocal || widget.details.currentUserStatus == 'CheckedIn';
      return Container(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Expanded(
              child: CustomElevatedButton(
                text: 'ค่าใช้จ่าย',
                fontSize: 16,
                backgroundColor: Colors.white,
                foregroundColor: Theme.of(context).colorScheme.primary,
                onPressed: () {
                  context.push('/payment-now/${widget.details.code}');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomElevatedButton(
                text: isCheckedIn ? 'คิวการเล่น' : 'Check In',
                backgroundColor: Theme.of(context).colorScheme.primary,
                fontSize: 16,
                onPressed: () {
                  if (isCheckedIn) {
                    context.push('/game-player/${widget.details.code}');
                  } else {
                    _showMyQrCodeDialog();
                  }
                },
              ),
            ),
          ],
        ),
      );
    }
  }

  // --- Widget ใหม่: แถบสถานะสำหรับคนที่ยังไม่ได้เข้าร่วม (จะมาแทน _buildBottomBar เดิม) ---
  Widget _buildBookNowBar() {
    if (widget.details.status == 2) {
      return Container(
        padding: const EdgeInsets.all(15),
        child: const CustomElevatedButton(
          text: 'ก๊วนนี้เริ่มเล่นแล้ว (ปิดรับจอง)',
          backgroundColor: Colors.grey,
          onPressed: null,
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.details.currentPlayers >= widget.details.maxPlayers) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Column(
              children: [
                const Text('คิวเต็มแล้ว! ระบบจะให้คุณจองเป็น "ตัวสำรอง"', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                const Text('หากไม่ได้รับเลื่อนเป็นตัวจริง จะคืนเงินอัตโนมัติภายใน 7 วัน', style: TextStyle(color: Colors.black54, fontSize: 12), textAlign: TextAlign.center),
              ],
            ),
          )
        ],
        Container(
          padding: const EdgeInsets.all(15),
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
              'ชำระเงินและจบเกมแล้ว',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 18),
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0E9D7A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: CustomElevatedButton(
            text: 'ดูประวัติและบิลค่าใช้จ่าย',
            fontSize: 16,
            backgroundColor: Colors.white,
            foregroundColor: Theme.of(context).colorScheme.primary,
            onPressed: () {
              context.push('/history-detail/${widget.details.code}');
            },
          ),
        ),
      ],
    );
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
        const SizedBox(height: 16),
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

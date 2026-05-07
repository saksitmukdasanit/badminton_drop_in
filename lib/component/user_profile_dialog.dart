import 'package:badminton/component/Button.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';

class UserProfileDialog extends StatefulWidget {
  final String imageUrl;
  final String name;
  final String gamesOrganized;
  final String gamesCancelled;
  final VoidCallback? onPhoneTap;
  final VoidCallback? onFacebookTap;
  final VoidCallback? onLineTap;
  // --- NEW: พารามิเตอร์สำหรับฟีเจอร์ติดตาม (เป็น Optional) ---
  final int? organizerId;
  final bool? isInitiallyFollowed;

  const UserProfileDialog({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.gamesOrganized,
    required this.gamesCancelled,
    this.onPhoneTap,
    this.onFacebookTap,
    this.onLineTap,
    this.organizerId,
    this.isInitiallyFollowed,
  });

  @override
  State<UserProfileDialog> createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends State<UserProfileDialog> {
  late bool _isFollowed;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isFollowed = widget.isInitiallyFollowed ?? false;
  }

  Future<void> _toggleFollow() async {
    if (widget.organizerId == null || _isLoading) return;

    setState(() {
      _isLoading = true;
      _isFollowed = !_isFollowed; // Optimistic UI update
    });

    try {
      await ApiProvider().post('/users/${widget.organizerId}/follow');
    } catch (e) {
      // หาก API Error ให้เปลี่ยนสถานะ UI กลับเหมือนเดิม
      if (mounted) {
        setState(() {
          _isFollowed = !_isFollowed;
        });
      }
      debugPrint('Failed to toggle follow: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
      ),
      // ทำให้พื้นหลังโปร่งใส เพื่อให้ Stack แสดงผลนอกกรอบได้
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        // clipBehavior: Clip.none ทำให้ Widget ที่ล้นออกมายังแสดงผลได้
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // --- 1. กล่องเนื้อหาหลัก (สีขาว) ---
          Container(
            // เลื่อนกล่องลงมาครึ่งหนึ่งของความสูงรูปโปรไฟล์
            margin: const EdgeInsets.only(top: 45),
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.name,
                  style: TextStyle(
                    fontSize: getResponsiveFontSize(context,fontSize: 20),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'จำนวนครั้งที่จัด ${widget.gamesOrganized} ครั้ง',
                    style: TextStyle(
                    fontSize: getResponsiveFontSize(context,fontSize: 16),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  'จำนวนที่ยกเลิกจัด ${widget.gamesCancelled} ครั้ง',
                    style: TextStyle(
                    fontSize: getResponsiveFontSize(context,fontSize: 16),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 24),
                // --- NEW: ปุ่มติดตาม (จะแสดงก็ต่อเมื่อมี organizerId ส่งเข้ามา) ---
                if (widget.organizerId != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: CustomElevatedButton(
                        text: _isFollowed ? 'เลิกติดตาม' : 'ติดตาม',
                  backgroundColor: (_isFollowed ? Colors.grey[300] : Theme.of(context).primaryColor) ?? Colors.grey,
                        foregroundColor: _isFollowed ? Colors.black87 : Colors.white,
                        onPressed: _toggleFollow,
                        isLoading: _isLoading,
                      ),
                    ),
                  ),
                // --- ไอคอน Social Media ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSocialButton(
                      path: 'assets/icon/phone.png',
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: widget.onPhoneTap,
                    ),
                    const SizedBox(width: 16),
                    _buildSocialButton(
                      path: 'assets/icon/fb.png',
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: widget.onFacebookTap,
                    ),
                    const SizedBox(width: 16),
                    _buildSocialButton(
                      path: 'assets/icon/line.png',
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: widget.onLineTap,
                    ),
                  ],
                )
              ],
            ),
          ),
          // --- 2. รูปโปรไฟล์ (CircleAvatar) ---
          Positioned(
            top: 0, // จัดให้อยู่ด้านบนสุดของ Stack
            child: CircleAvatar(
              radius: 45,
              backgroundImage: NetworkImage(widget.imageUrl),
            ),
          ),
          // --- 3. ปุ่มปิด (X) ---
          Positioned(
            top: 50,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          // --- 4. ปุ่ม More (รายงาน / บล็อก) ---
          if (widget.organizerId != null)
            Positioned(
              top: 50,
              left: 10,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz, color: Colors.grey),
                tooltip: 'ตัวเลือกเพิ่มเติม',
                onSelected: (value) {
                  if (value == 'report') _handleReport();
                  if (value == 'block') _handleBlock();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'report',
                    child: Row(
                      children: [
                        Icon(Icons.flag_outlined, size: 18, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('รายงานผู้ใช้'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'block',
                    child: Row(
                      children: [
                        Icon(Icons.block, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('บล็อกผู้ใช้'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleReport() async {
    final selectedReason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text('เลือกเหตุผล'),
          children: [
            _reasonTile(ctx, 'spam', 'สแปม / โฆษณา'),
            _reasonTile(ctx, 'harassment', 'คุกคาม / ใช้คำหยาบ'),
            _reasonTile(ctx, 'fraud', 'หลอกลวง / โกงเงิน'),
            _reasonTile(ctx, 'fake_profile', 'โปรไฟล์ปลอม'),
            _reasonTile(ctx, 'inappropriate_content', 'เนื้อหาไม่เหมาะสม'),
            _reasonTile(ctx, 'other', 'อื่น ๆ'),
          ],
        );
      },
    );
    if (selectedReason == null) return;

    try {
      final response = await ApiProvider().post('/user-safety/report', data: {
        'reportedUserId': widget.organizerId,
        'reason': selectedReason,
      });
      if (!mounted) return;
      if (response['status'] == 200) {
        showDialogMsg(
          context,
          title: 'รายงานสำเร็จ',
          subtitle: response['message'] ?? 'ทีมงานจะตรวจสอบโดยเร็วที่สุด',
          btnLeft: 'ตกลง',
          onConfirm: () {},
        );
      }
    } catch (e) {
      if (!mounted) return;
      showDialogMsg(
        context,
        title: 'รายงานไม่สำเร็จ',
        subtitle: e.toString().replaceFirst('Exception: ', ''),
        btnLeft: 'ตกลง',
        onConfirm: () {},
      );
    }
  }

  Widget _reasonTile(BuildContext ctx, String value, String label) {
    return SimpleDialogOption(
      onPressed: () => Navigator.of(ctx).pop(value),
      child: Text(label),
    );
  }

  Future<void> _handleBlock() async {
    showDialogMsg(
      context,
      title: 'ยืนยันการบล็อกผู้ใช้',
      subtitle: 'คุณจะไม่เห็นโปรไฟล์ของผู้ใช้นี้ในระบบอีก '
          '(สามารถยกเลิกการบล็อกได้ในเมนู Settings → Blocked Users)',
      btnLeft: 'บล็อก',
      btnLeftBackColor: const Color(0xFFE53935),
      btnRight: 'ยกเลิก',
      btnRightBackColor: Colors.white,
      btnRightForeColor: Theme.of(context).colorScheme.primary,
      onConfirm: () async {
        try {
          final response = await ApiProvider().post('/user-safety/block', data: {
            'blockedUserId': widget.organizerId,
          });
          if (!mounted) return;
          if (response['status'] == 200) {
            Navigator.of(context).pop(); // ปิด UserProfileDialog
            showDialogMsg(
              context,
              title: 'บล็อกเรียบร้อย',
              subtitle: response['message'] ?? '',
              btnLeft: 'ตกลง',
              onConfirm: () {},
            );
          }
        } catch (e) {
          if (!mounted) return;
          showDialogMsg(
            context,
            title: 'บล็อกไม่สำเร็จ',
            subtitle: e.toString().replaceFirst('Exception: ', ''),
            btnLeft: 'ตกลง',
            onConfirm: () {},
          );
        }
      },
    );
  }

  // Widget สำหรับสร้างปุ่ม Social Media
  Widget _buildSocialButton({
    required String path,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: color,
      child: IconButton(
        icon: Image.asset(path, ),
        onPressed: onPressed,
      ),
    );
  }
}
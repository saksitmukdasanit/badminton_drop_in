import 'package:badminton/component/Button.dart';
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
        ],
      ),
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
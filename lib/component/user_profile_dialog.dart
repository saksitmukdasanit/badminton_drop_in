import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';

class UserProfileDialog extends StatelessWidget {
  final String imageUrl;
  final String name;
  final String gamesOrganized;
  final String gamesCancelled;
  final VoidCallback? onPhoneTap;
  final VoidCallback? onFacebookTap;
  final VoidCallback? onLineTap;

  const UserProfileDialog({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.gamesOrganized,
    required this.gamesCancelled,
    this.onPhoneTap,
    this.onFacebookTap,
    this.onLineTap,
  });

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
                  name,
                  style: TextStyle(
                    fontSize: getResponsiveFontSize(context,fontSize: 20),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'จำนวนครั้งที่จัด $gamesOrganized ครั้ง',
                    style: TextStyle(
                    fontSize: getResponsiveFontSize(context,fontSize: 16),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  'จำนวนที่ยกเลิกจัด $gamesCancelled ครั้ง',
                    style: TextStyle(
                    fontSize: getResponsiveFontSize(context,fontSize: 16),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 24),
                // --- ไอคอน Social Media ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSocialButton(
                      path: 'assets/icon/phone.png',
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: onPhoneTap,
                    ),
                    const SizedBox(width: 16),
                    _buildSocialButton(
                      path: 'assets/icon/fb.png',
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: onFacebookTap,
                    ),
                    const SizedBox(width: 16),
                    _buildSocialButton(
                      path: 'assets/icon/line.png',
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: onLineTap,
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
              backgroundImage: NetworkImage(imageUrl),
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
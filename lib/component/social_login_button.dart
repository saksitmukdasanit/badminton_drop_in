import 'package:flutter/material.dart';

class SocialLoginButton extends StatelessWidget {
  // รับค่า icon หรือ label (อย่างใดอย่างหนึ่ง)
  final IconData? icon;
  final String? label;
  
  // รับฟังก์ชันที่จะทำงานเมื่อกดปุ่ม
  final VoidCallback onTap;

  const SocialLoginButton({
    super.key,
    this.icon,
    this.label,
    required this.onTap,
  }) : assert(icon != null || label != null, 'Either icon or label must be provided.'),
       assert(icon == null || label == null, 'Cannot provide both an icon and a label.');

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        // ใช้ property จาก widget แทน
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: Colors.grey.shade300),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
      child: icon != null
          // ถ้ามี icon ให้แสดง Icon
          ? Icon(icon, color: Colors.black, size: 28)
          // ถ้าไม่มี icon (แสดงว่ามี label) ให้แสดง Text
          : Text(
              label!,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
    );
  }
}
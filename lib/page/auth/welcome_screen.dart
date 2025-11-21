import 'package:badminton/component/button.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // --- 1. การตกแต่งพื้นหลัง (Background Decoration) ---
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF1E8E77), // สีเขียวเข้ม
              Color(0xFFB2DFDB), // สีเขียวอ่อน
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/images/img_bad.png',
                  height: MediaQuery.of(context).size.height * 0.4,
                ),
                Text(
                  'Welcome to\nBadminton Fight',
                  style: TextStyle(
                    fontSize: getResponsiveFontSize(context, fontSize: 40),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Where all player meet :)',
                  style: TextStyle(
                    color: Color(0XFF64646D),
                    fontSize: getResponsiveFontSize(context, fontSize: 16),
                  ),
                ),

                const SizedBox(height: 12),
                CustomElevatedButton(
                  backgroundColor: Colors.white,
                  foregroundColor: Color(0xFF0E9D7A),
                  text: 'Log In',
                  fontSize: getResponsiveFontSize(context, fontSize: 16),
                  onPressed: () {},
                ),
                const SizedBox(height: 16),
                CustomElevatedButton(
                  text: 'Register',
                  fontSize: getResponsiveFontSize(context, fontSize: 16),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

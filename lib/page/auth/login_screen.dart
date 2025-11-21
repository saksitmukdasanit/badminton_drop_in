import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/button.dart';
import 'package:badminton/component/social_login_button.dart';
import 'package:badminton/component/text_box.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/user_role.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>(); // Key สำหรับจัดการ Form
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      // UI ต้องรู้รายละเอียดทั้งหมด: path, data, และวิธีดึง token
      final response = await ApiProvider().post(
        '/Auth/login',
        data: {
          'username': _usernameController.text,
          'password': _passwordController.text,
        },
      );
      if (response['status'] == 200) {
        final token = response['data'];

        if (mounted) {
          Provider.of<AuthProvider>(context, listen: false).login(token);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // กำหนดสีเพื่อการจัดการที่ง่าย

    return Scaffold(
      backgroundColor: Colors.white,
      // AppBar แบบโปร่งใสเพื่อให้เห็นปุ่ม Back
      appBar: AppBarSubMain(title: 'Login', isBack: false),
      body: SingleChildScrollView(
        // ทำให้หน้าจอ scroll ได้ถ้าเนื้อหาล้น
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),

                // --- 1. Header Text ---
                const Text(
                  'Welcome back!',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Glad to see you, Again!',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 48),

                // --- 2. Text Fields ---
                CustomTextFormField(
                  labelText: 'ชื่อผู้ใช้',
                  hintText: 'กรุณากรอกกชื่อผู้ใช้',
                  isRequired: true,
                  controller: _usernameController,
                  prefixIconData: Icons.person_outline,
                ),

                const SizedBox(height: 16),
                CustomTextFormField(
                  labelText: 'รหัสผ่าน',
                  hintText: 'กรุณากรอกกรหัสผ่าน',
                  isRequired: true,
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  prefixIconData: Icons.lock_outline,
                  suffixIconData: _isPasswordVisible
                      ? Icons.visibility_off
                      : Icons.visibility,
                  onSuffixIconPressed: () =>
                      setState(() => _isPasswordVisible = !_isPasswordVisible),
                ),
                const SizedBox(height: 8),

                // --- 3. Forgot Password ---
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                CustomElevatedButton(
                  text: 'เข้าสู่ระบบ',
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  onPressed: _handleLogin,
                  isLoading: _isLoading,
                ),

                const SizedBox(height: 32),

                // --- 5. Social Login Section ---
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        'Or Login with',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SocialLoginButton(icon: Icons.facebook, onTap: () {}),
                    const SizedBox(width: 16),
                    SocialLoginButton(
                      icon: Icons.alternate_email,
                      onTap: () {},
                    ), // ใช้ Text แทนไอคอน Google
                    const SizedBox(width: 16),
                    SocialLoginButton(icon: Icons.apple, onTap: () {}),
                  ],
                ),
                const SizedBox(height: 48),

                // --- 6. Register Now Link ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? "),
                    TextButton(
                      onPressed: () {
                        context.push('/register-screen');
                      },
                      child: Text(
                        'Register Now',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

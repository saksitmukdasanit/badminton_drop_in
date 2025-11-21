import 'package:badminton/component/button.dart';
import 'package:badminton/component/social_login_button.dart';
import 'package:badminton/component/text_box.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>(); // Key สำหรับจัดการ Form
  final _phoneController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  void dispose() {
    _phoneController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      // UI ต้องรู้รายละเอียดทั้งหมด: path, data, และวิธีดึง token
      final response = await ApiProvider().post(
        '/Auth/register',
        data: {
          'phoneNumber': _phoneController.text,
          'username': _usernameController.text,
          'password': _passwordController.text,
        },
      );
      setState(() {
        _isLoading = false;
      });
      if (response['status'] == 201) {
        if (mounted) {
          Provider.of<AuthProvider>(
            context,
            listen: false,
          ).login(response['data']);
          context.push(
            '/otp-verification-screen',
            extra: _phoneController.text,
          );
        }
      } else {
        if (mounted) {
          final errorMessage =
              response['message'] ?? 'เกิดข้อผิดพลาดไม่ทราบสาเหตุ';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.orange, // อาจใช้สีอื่นที่ไม่ใช่แดง
              content: Text(errorMessage),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            context.pop();
          },
          icon: Icon(Icons.arrow_back, color: Colors.black),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Hello!',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Register to get started',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              CustomTextFormField(
                labelText: 'เบอร์โทรศัพท์',
                hintText: 'กรอกเบอร์โทรศัพท์ 10 หลัก',
                controller: _phoneController,
                isRequired: true,
                prefixIconData: Icons.phone_android,
                keyboardType: TextInputType.phone,
                isPhone: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              CustomTextFormField(
                labelText: 'ยืนยันรหัสผ่าน',
                hintText: 'กรุณากรอกกยืนยันรหัสผ่าน',
                isRequired: true,
                controller: _confirmPasswordController,
                obscureText: !_isConfirmPasswordVisible,
                prefixIconData: Icons.lock_outline,
                suffixIconData: _isConfirmPasswordVisible
                    ? Icons.visibility_off
                    : Icons.visibility,
                onSuffixIconPressed: () => setState(
                  () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณายืนยันรหัสผ่าน';
                  }
                  // เปรียบเทียบค่ากับ password controller ตัวแรก
                  if (value != _passwordController.text) {
                    return 'รหัสผ่านไม่ตรงกัน';
                  }
                  // ถ้าทุกอย่างถูกต้อง ให้ return null
                  return null;
                },
              ),

              const SizedBox(height: 32),
              CustomElevatedButton(
                text: 'สมัครสมาชิก',
                backgroundColor: Theme.of(context).colorScheme.primary,
                onPressed: () {
                  _submit();
                },
                isLoading: _isLoading,
              ),

              const SizedBox(height: 32),
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

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? "),
                  TextButton(
                    onPressed: () {
                      context.pop();
                    },
                    child: Text(
                      'Login Now',
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
    );
  }
}

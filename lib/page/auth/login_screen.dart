import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/button.dart';
import 'package:badminton/component/social_login_button.dart';
import 'package:badminton/component/text_box.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/function.dart';
import 'package:badminton/shared/social_login_service.dart';
import 'package:badminton/shared/user_role.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/shared/firebase_messaging_service.dart';

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
  bool _isSocialLoading = false;

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

        // เอา await ออก เพื่อให้ระบบไปอัปเดต Token เบื้องหลัง จะได้ไม่บล็อกหน้าจอให้หมุนค้าง
        FirebaseMessagingService().updateTokenToServer();

        // FIX: ต้อง await login() ให้ prefs เขียนเสร็จก่อน
        // ก่อน navigate ไป Home (กัน race กับ Dio interceptor)
        final authProv = Provider.of<AuthProvider>(context, listen: false);
        if (mounted) {
          await authProv.login(token);
        }
        if (mounted) {
          await authProv.refreshSessionGateAfterLogin();
        }
        if (mounted) {
          context.go('/');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final errorMsg = e.toString().replaceFirst('Exception: ', '');
        showDialogMsg(
          context,
          title: errorMsg.contains('OTP') ? 'บัญชียังไม่ยืนยัน' : 'เกิดข้อผิดพลาด',
          subtitle: errorMsg,
          btnLeft: errorMsg.contains('OTP') ? 'สมัครสมาชิกใหม่' : 'ตกลง',
          btnRight: errorMsg.contains('OTP') ? 'ยกเลิก' : '',
          onConfirm: () {
            if (errorMsg.contains('OTP')) {
              context.push('/register-screen');
            }
          },
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // สั่งหยุดหมุนเสมอไม่ว่าจะสำเร็จหรือพัง
        });
      }
    }
  }

  Future<void> _handleSocialLogin(Future<SocialLoginResult> Function() runner, {required String providerLabel}) async {
    if (_isSocialLoading || _isLoading) return;
    setState(() => _isSocialLoading = true);
    try {
      final result = await runner();

      FirebaseMessagingService().updateTokenToServer();

      if (!mounted) return;
      final authProv = Provider.of<AuthProvider>(context, listen: false);
      await authProv.login(result.toAuthProviderToken());
      await authProv.refreshSessionGateAfterLogin();

      if (!mounted) return;
      if (result.requiresPhoneVerification) {
        // ครั้งแรกของ social signup → ต้องเชื่อมเบอร์โทร
        context.go('/social-phone-link');
      } else {
        context.go('/');
      }
    } on SocialLoginException catch (e) {
      if (e.userCancelled) return; // ผู้ใช้กดยกเลิก ไม่ต้องแจ้ง error
      if (mounted) {
        showDialogMsg(
          context,
          title: 'เข้าสู่ระบบด้วย $providerLabel ไม่สำเร็จ',
          subtitle: e.message,
          btnLeft: 'ตกลง',
          onConfirm: () {},
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        showDialogMsg(
          context,
          title: 'เกิดข้อผิดพลาด',
          subtitle: msg,
          btnLeft: 'ตกลง',
          onConfirm: () {},
        );
      }
    } finally {
      if (mounted) setState(() => _isSocialLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    final apiProvider = ApiProvider();
    await _handleSocialLogin(
      () => SocialLoginService.instance.signInWithGoogle(
        iosClientId: apiProvider.googleIosClientId,
        serverClientId: apiProvider.googleServerClientId,
      ),
      providerLabel: 'Google',
    );
  }

  Future<void> _handleAppleLogin() async {
    await _handleSocialLogin(
      () => SocialLoginService.instance.signInWithApple(),
      providerLabel: 'Apple',
    );
  }

  @override
  Widget build(BuildContext context) {
    // กำหนดสีเพื่อการจัดการที่ง่าย

    return Scaffold(
      backgroundColor: Colors.white,
      // AppBar แบบโปร่งใสเพื่อให้เห็นปุ่ม Back
      appBar: const AppBarSubMain(
        title: 'Login', 
        isBack: true,
        showSettings: false,
        showNotification: false,
      ),
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
                Text(
                  'Welcome back!',
                  style: TextStyle(
                    fontSize: getResponsiveFontSize(context, fontSize: 28),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Glad to see you, Again!',
                  style: TextStyle(
                    fontSize: getResponsiveFontSize(context, fontSize: 28),
                    fontWeight: FontWeight.bold,
                  ),
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
                    Opacity(
                      opacity: _isSocialLoading ? 0.5 : 1,
                      child: SocialLoginButton(
                        icon: Icons.g_mobiledata,
                        onTap: _isSocialLoading ? () {} : _handleGoogleLogin,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Opacity(
                      opacity: _isSocialLoading ? 0.5 : 1,
                      child: SocialLoginButton(
                        icon: Icons.apple,
                        onTap: _isSocialLoading ? () {} : _handleAppleLogin,
                      ),
                    ),
                  ],
                ),
                if (_isSocialLoading) ...[
                  const SizedBox(height: 12),
                  const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ],
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

import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/button.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/text_box.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/function.dart';
import 'package:badminton/shared/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// หน้าให้ user กรอกเบอร์โทรหลัง login ผ่าน Google/Apple ครั้งแรก
/// (ระบบจองก๊วน/Wallet ผูกกับเบอร์โทร verified จึงต้องเชื่อมเบอร์ก่อนใช้งานเต็มรูปแบบ)
class SocialPhoneLinkScreen extends StatefulWidget {
  const SocialPhoneLinkScreen({super.key});

  @override
  State<SocialPhoneLinkScreen> createState() => _SocialPhoneLinkScreenState();
}

class _SocialPhoneLinkScreenState extends State<SocialPhoneLinkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      final response = await ApiProvider().post(
        '/Auth/link-phone',
        data: {'phoneNumber': _phoneController.text},
      );
      if (response['status'] == 200) {
        if (!mounted) return;
        // ส่ง phoneNumber อย่างเดียว (ไม่ส่ง tokens เพราะ user login แล้ว)
        // OTP screen จะ pushReplacement ไป /personal-info-screen หลัง verify สำเร็จ
        context.push(
          '/otp-verification-screen',
          extra: {'phoneNumber': _phoneController.text},
        );
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      showDialogMsg(
        context,
        title: 'เชื่อมเบอร์โทรไม่สำเร็จ',
        subtitle: msg,
        btnLeft: 'ตกลง',
        onConfirm: () {},
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppBarSubMain(
        title: 'เชื่อมเบอร์โทรศัพท์',
        isBack: false,
        showSettings: false,
        showNotification: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text(
                  'อีกขั้นเดียว!',
                  style: TextStyle(
                    fontSize: getResponsiveFontSize(context, fontSize: 26),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'เพื่อใช้งานระบบจองก๊วนและกระเป๋าเงิน เราต้องการเบอร์โทรของคุณเพื่อติดต่อและยืนยันตัวตน',
                  style: TextStyle(
                    fontSize: getResponsiveFontSize(context, fontSize: 14),
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 32),
                CustomTextFormField(
                  labelText: 'เบอร์โทรศัพท์',
                  hintText: 'เช่น 0812345678',
                  isRequired: true,
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  prefixIconData: Icons.phone_outlined,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'กรุณากรอกเบอร์โทรศัพท์';
                    }
                    if (value.length < 10) {
                      return 'เบอร์โทรศัพท์ต้องมี 10 หลัก';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                CustomElevatedButton(
                  text: 'ส่ง OTP',
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  onPressed: _submit,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          await Provider.of<AuthProvider>(context,
                                  listen: false)
                              .logout();
                          if (context.mounted) context.go('/login');
                        },
                  child: Text(
                    'ออกจากระบบแล้วกลับไปเข้าสู่ระบบใหม่',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

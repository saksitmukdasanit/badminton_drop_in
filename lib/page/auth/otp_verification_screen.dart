import 'package:badminton/component/button.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/component/dialog.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import 'package:badminton/shared/user_role.dart';

class OtpVerificationScreen extends StatefulWidget {
  // รับค่าเบอร์โทรมาจากหน้า Register
  final String phoneNumber;
  final dynamic tokens; // รับ Token ที่ส่งมาจากหน้า Register

  const OtpVerificationScreen({super.key, required this.phoneNumber, this.tokens});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final defaultPinTheme = PinTheme(
    width: 60,
    height: 64,
    textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
    decoration: BoxDecoration(
      color: Colors.grey[200],
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.transparent),
    ),
  );

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
    });

    try {
      
      
      final response = await ApiProvider().post('/Auth/verify-otp', data: {
        'phoneNumber': widget.phoneNumber,
        'otp': _pinController.text,
      });

      if (response['status'] == 200) {
        if (mounted) {
          // ยืนยันสำเร็จ -> ค่อยทำการ Login เข้าระบบที่นี่
          if (widget.tokens != null) {
            Provider.of<AuthProvider>(context, listen: false).login(widget.tokens);
          }
          // ใช้ pushReplacement เพื่อไม่ให้กด Back กลับมาหน้า OTP ได้อีก
          context.pushReplacement('/personal-info-screen');
        }
      } else {
        _pinController.clear(); // เคลียร์ PIN เมื่อผิด
        if (mounted) {
          showDialogMsg(
            context,
            title: 'แจ้งเตือน',
            subtitle: response['message'] ?? 'รหัส OTP ไม่ถูกต้อง',
            btnLeft: 'ตกลง',
            onConfirm: () {},
          );
        }
      }
    } catch (e) {
      _pinController.clear(); // เคลียร์ PIN เมื่อเกิด Error
      if (mounted) {
        showDialogMsg(
          context,
          title: 'เกิดข้อผิดพลาด',
          subtitle: e.toString().replaceFirst('Exception: ', ''),
          btnLeft: 'ตกลง',
          onConfirm: () {},
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleResendOtp() async {
    try {
      final response = await ApiProvider().post('/Auth/resend-otp', data: {
        'phoneNumber': widget.phoneNumber,
      });
      if (mounted) {
        showDialogMsg(
          context,
          title: 'สำเร็จ',
          subtitle: response['message'] ?? 'ส่ง OTP ใหม่เรียบร้อยแล้ว',
          btnLeft: 'ตกลง',
          onConfirm: () {},
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
  }

  @override
  Widget build(BuildContext context) {
    // สไตล์ของช่องกรอก OTP
    final defaultPinTheme = PinTheme(
      width: 60,
      height: 64,
      textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.transparent),
      ),
    );

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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'OTP Verification',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the verification code we just sent on your email address.',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 48),

              // --- Pinput Widget ---
              Pinput(
                length: 6,
                controller: _pinController,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: defaultPinTheme.copyWith(
                  decoration: defaultPinTheme.decoration!.copyWith(
                    border: Border.all(color: Colors.teal),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'กรุณากรอก OTP ให้ครบ 6 หลัก';
                  }
                  return null;
                },
                onCompleted: (pin) {
                  _handleVerifyOtp();
                },
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Didn't received code? ",
                    style: TextStyle(color: Colors.grey),
                  ),
                  TextButton(
                    onPressed: _handleResendOtp,
                    child: const Text(
                      'Resend',
                      style: TextStyle(color: Colors.teal),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              CustomElevatedButton(
                text: 'ยืนยัน OTP',
                backgroundColor: Theme.of(context).colorScheme.primary,
                onPressed: _handleVerifyOtp,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

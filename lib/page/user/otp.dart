import 'dart:async';

import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/button.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

class OTPPage extends StatefulWidget {
  final String phoneNumber;
  const OTPPage({super.key, required this.phoneNumber});

  @override
  OTPPageState createState() => OTPPageState();
}

class OTPPageState extends State<OTPPage> {
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late Timer _timer;
  int _start = 60; // เวลาเริ่มต้นสำหรับนับถอยหลัง (วินาที)
  bool _canResend = false;
  bool _isLoading = false;

  @override
  void initState() {
    startTimer();
    super.initState();
  }

  @override
  void dispose() {
    _timer.cancel();
    _pinController.dispose();
    super.dispose();
  }

  void startTimer() {
    _start = 60;
    _canResend = false;
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (_start == 0) {
        setState(() {
          timer.cancel();
          _canResend = true;
        });
      } else {
        setState(() {
          _start--;
        });
      }
    });
  }

  Future<void> _handleVerifyAndUpdatePhone() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // เรียก API เพื่ออัปเดตเบอร์โทร
      await ApiProvider().put(
        '/Profiles/me/phone-number',
        data: {"newPhoneNumber": widget.phoneNumber},
      );

      // --- ถ้าสำเร็จ ---
      // แสดงข้อความว่าสำเร็จ
      if (mounted) {
        showDialogMsg(
          context,
          title: 'แก้ไขเรียบร้อย',
          subtitle: 'บันทึกการแก้ไขข้อมูลของคุณแล้ว',
          btnLeft: 'ไปหน้าโปรไฟล์',
          onConfirm: () {
            context.pop(); // กลับไปหน้าโปรไฟล์
            context.pop(); 
          },
        );
      }
    } catch (e) {
      // --- ถ้าไม่สำเร็จ ---
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w500,
        color: Colors.black,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.primary),
      ),
    );
    return Scaffold(
      extendBody: false,
      backgroundColor: Colors.white,
      appBar: AppBarSubMain(title: 'ชำระเงิน'),
      body: Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFCBF5EA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            // mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'OTP Verification',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: getResponsiveFontSize(context, fontSize: 28),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Enter the verification code we just sent on your email address.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF64646D),
                  fontWeight: FontWeight.w400,
                  fontSize: getResponsiveFontSize(context, fontSize: 16),
                ),
              ),
              const SizedBox(height: 40),

              // --- ช่องกรอก OTP ---
              Pinput(
                controller: _pinController,
                length: 6,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: defaultPinTheme.copyWith(
                  decoration: defaultPinTheme.decoration!.copyWith(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'กรุณากรอก OTP ให้ครบ 6 หลัก';
                  }
                  return null;
                },
                onCompleted: (pin) {
                  _handleVerifyAndUpdatePhone();
                },
              ),
              const SizedBox(height: 20),

              // --- ปุ่ม Resend ---
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    "Didn't received code? ",
                    style: TextStyle(color: Colors.grey),
                  ),
                  TextButton(
                    onPressed: _canResend
                        ? () {
                            startTimer(); // เริ่มนับเวลาใหม่
                            // เพิ่มโค้ดสำหรับส่ง OTP ใหม่อีกครั้ง
                          }
                        : null, // ถ้ายังนับเวลาไม่เสร็จ จะกดไม่ได้
                    child: Text(
                      _canResend ? 'Resend' : 'Resend in $_start s',
                      style: TextStyle(
                        color: _canResend
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // --- ปุ่ม Verify ---
              CustomElevatedButton(
                text: 'ยืนยัน OTP',
                backgroundColor: Theme.of(context).colorScheme.primary,
                onPressed: _handleVerifyAndUpdatePhone,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

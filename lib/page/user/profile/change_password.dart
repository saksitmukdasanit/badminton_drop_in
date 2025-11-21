import 'dart:async';
import 'package:badminton/component/Button.dart';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/text_box.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ChangePasswordPageState createState() => ChangePasswordPageState();
}

class ChangePasswordPageState extends State<ChangePasswordPage> {
  late Future<dynamic> futureModel;
  String profileImageUrl = '';
  bool loadingImage = false;
  String image = '';
  double gapHeight = 20;
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _oldPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void initState() {
    _oldPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final Map<String, dynamic> data = {
        "oldPassword": _oldPasswordController.text,
        "newPassword": _newPasswordController.text,
      };

      await ApiProvider().post('/Auth/change-password', data: data);

      if (mounted) {
        showDialogMsg(
          context,
          title: 'เปลี่ยนรหัสผ่านสำเร็จ',
          subtitle: 'คุณได้เปลี่ยนรหัสผ่านเรียบร้อยแล้ว',
          btnLeft: 'กลับไปหน้าโปรไฟล์',
          onConfirm: () {
            context.pop(); // ปิด Dialog
            context.pop(); // กลับไปหน้า Profile
          },
        );
      }
    } catch (e) {
      // 6. จัดการเมื่อล้มเหลว: แสดง SnackBar พร้อมข้อความ Error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      // 7. สิ้นสุด Loading เสมอ (ไม่ว่าจะสำเร็จหรือล้มเหลว)
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false,
      backgroundColor: Colors.white,
      appBar: AppBarSubMain(title: 'เปลี่ยนรหัสผ่าน'),
      bottomNavigationBar: Container(
        color: Color(0xFFCBF5EA),
        padding: EdgeInsets.all(15),
        child: CustomElevatedButton(
          text: 'เปลี่ยนรหัสผ่าน',
          onPressed: _submitForm,
          isLoading: _isLoading,
        ),
      ),
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
          child: ListView(
            children: [
              SizedBox(height: gapHeight),
              CustomTextFormField(
                labelText: 'รหัสผ่านเดิม',
                hintText: 'กรุณากรอกรหัสผ่านเดิม',
                isRequired: true,
                controller: _oldPasswordController,
                prefixIconData: Icons.lock_outline,
              ),
              SizedBox(height: gapHeight),
              CustomTextFormField(
                labelText: 'รหัสผ่านใหม่',
                hintText: 'กรุณากรอกรหัสผ่านใหม่',
                isRequired: true,
                controller: _newPasswordController,
                obscureText: !_isPasswordVisible,
                prefixIconData: Icons.lock_outline,
                suffixIconData: _isPasswordVisible
                    ? Icons.visibility_off
                    : Icons.visibility,
                onSuffixIconPressed: () =>
                    setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
              SizedBox(height: gapHeight),
              CustomTextFormField(
                labelText: 'ยืนยันรหัสผ่านใหม่',
                hintText: 'กรุณากรอกยืนยันรหัสผ่านใหม่',
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
                    return 'กรุณากรอกข้อมูลช่องนี้';
                  }
                  if (value != _newPasswordController.text) {
                    return 'รหัสผ่านใหม่ไม่ตรงกัน';
                  }
                  return null;
                },
              ),
              SizedBox(height: gapHeight),
            ],
          ),
        ),
      ),
    );
  }
}

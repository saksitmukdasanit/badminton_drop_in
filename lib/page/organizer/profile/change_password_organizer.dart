import 'dart:async';
import 'package:badminton/component/Button.dart';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/text_box.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ChangePasswordOrganizerPage extends StatefulWidget {
  const ChangePasswordOrganizerPage({super.key});

  @override
  ChangePasswordOrganizerPageState createState() => ChangePasswordOrganizerPageState();
}

class ChangePasswordOrganizerPageState extends State<ChangePasswordOrganizerPage> {
  late Future<dynamic> futureModel;
  String profileImageUrl = '';
  bool loadingImage = false;
  String image = '';
  double gapHeight = 20;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _oldPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;
  bool _isPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isSubmitting = false;

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
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
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
            context.pop();
            context.pop();
          },
        );
      }
    } catch (e) {
      if (mounted) {
        showDialogMsg(context, title: 'เกิดข้อผิดพลาด', subtitle: e.toString().replaceFirst('Exception: ', ''), btnLeft: 'ตกลง', onConfirm: () {});
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false,
      backgroundColor: Colors.white,
      appBar: AppBarSubMain(title: 'เปลี่ยนรหัสผ่าน'),
      bottomNavigationBar: Container(
        color: Color(0xFFD5DCF4),
        padding: EdgeInsets.all(15),
        child: CustomElevatedButton(
          text: 'เปลี่ยนรหัสผ่าน',
          onPressed: _submitForm,
          isLoading: _isSubmitting,
        ),
      ),
      body: Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFD5DCF4)],
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
                obscureText: !_isPasswordVisible,
                prefixIconData: Icons.lock_outline,
                suffixIconData: _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                onSuffixIconPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
              SizedBox(height: gapHeight),
              CustomTextFormField(
                labelText: 'รหัสผ่านใหม่',
                hintText: 'กรุณากรอกรหัสผ่านใหม่',
                isRequired: true,
                controller: _newPasswordController,
                obscureText: !_isNewPasswordVisible,
                prefixIconData: Icons.lock_outline,
                suffixIconData: _isNewPasswordVisible ? Icons.visibility_off : Icons.visibility,
                onSuffixIconPressed: () => setState(() => _isNewPasswordVisible = !_isNewPasswordVisible),
              ),
              SizedBox(height: gapHeight),
              CustomTextFormField(
                labelText: 'ยืนยันรหัสผ่านใหม่',
                hintText: 'กรุณากรอกยืนยันรหัสผ่านใหม่',
                isRequired: true,
                controller: _confirmPasswordController,
                obscureText: !_isConfirmPasswordVisible,
                prefixIconData: Icons.lock_outline,
                suffixIconData: _isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility,
                onSuffixIconPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
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

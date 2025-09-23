import 'dart:async';
import 'package:badminton/component/Button.dart';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/text_box.dart';
import 'package:flutter/material.dart';

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

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // เพิ่ม DialogMsg ที่นี้ถ้าข้อมูลถูกต้อง
      showDialogMsg(
        context,
        title: 'แก้ไขเรียบร้อย',
        subtitle: 'บันทึกการแก้ไขรหัสผ่าน',
        btnLeft: 'ไปหน้าโปรโฟล์',
        onConfirm: () {
          // เพิ่มโค้ดสำหรับไปหน้า OTP ที่นี่
        },
      );
    }
    showDialogMsg(
      context,
      title: 'แก้ไขเรียบร้อย',
      subtitle: 'บันทึกการแก้ไขรหัสผ่าน',
      btnLeft: 'ไปหน้าโปรโฟล์',
      onConfirm: () {
        // เพิ่มโค้ดสำหรับไปหน้า OTP ที่นี่
      },
    );
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
              ),
              SizedBox(height: gapHeight),
              CustomTextFormField(
                labelText: 'รหัสผ่านใหม่',
                hintText: 'กรุณากรอกรหัสผ่านใหม่',
                isRequired: true,
                controller: _newPasswordController,
              ),
              SizedBox(height: gapHeight),
              CustomTextFormField(
                labelText: 'ยืนยันรหัสผ่านใหม่',
                hintText: 'กรุณากรอกยืนยันรหัสผ่านใหม่',
                isRequired: true,
                controller: _confirmPasswordController,
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

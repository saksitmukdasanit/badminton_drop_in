import 'dart:io';

import 'package:badminton/component/button.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/dropdown.dart';
import 'package:badminton/component/image_picker.dart';
import 'package:badminton/component/text_box.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
// import 'login_screen.dart'; // import หน้า Login สำหรับตอนจบ Flow

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>(); // Key สำหรับจัดการ Form
  final _nickNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _emergencyContactNameController = TextEditingController();
  final _emergencyContactPhoneController = TextEditingController();
  bool _termsAccepted = false;
  String? _selectedGender;
  bool _isLoading = false;

  bool loadingImage = false;
  String imageUrl = '';

  void dispose() {
    _nickNameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactPhoneController.dispose();
    super.dispose();
  }

  _uploadImage(List<File> file) async {
    try {
      final response = await ApiProvider().uploadFiles(
        files: file,
        folderName: 'Profile',
      );

      if (response.length > 0) {
        if (mounted) {
          setState(() {
            imageUrl = response[0]['imageUrl'];
          });
        }
      } else {
        if (mounted) {
          final errorMessage =
              response['message'] ?? 'เกิดข้อผิดพลาดไม่ทราบสาเหตุ';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.orange,
              content: Text(errorMessage),
            ),
          );
        }
      }
    } catch (e) {
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

  _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      // UI ต้องรู้รายละเอียดทั้งหมด: path, data, และวิธีดึง token
      final response = await ApiProvider().put(
        '/Auth/complete-profile',
        data: {
          "nickname": _nickNameController.text,
          "firstName": _firstNameController.text,
          "lastName": _lastNameController.text,
          "email": _emailController.text,
          "gender": _selectedGender,
          "profilePhotoUrl": imageUrl,
          "emergencyContactName": _emergencyContactNameController.text,
          "emergencyContactPhone": _emergencyContactPhoneController.text,
        },
      );
      setState(() {
        _isLoading = false;
      });
      if (response['status'] == 200) {
        if (mounted) {
          showDialogMsg(
            context,
            title: 'สมัครเป็นผู้เล่นเรียบร้อย',
            subtitle:
                'หากคุณต้องการสมัครเป็นผู้จัด\nสามารถสมัครได้ที่หน้าแก้ไขข้อมูล',
            btnLeft: 'ไปหน้าหลัก',
            onConfirm: () {
              context.go('/');
            },
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
                'Personal Information',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),

              // --- Profile Picture ---
              _buildProfileHeader(),
              const SizedBox(height: 32),

              // --- Form Fields ---
              Row(
                children: [
                  Expanded(
                    child: CustomTextFormField(
                      labelText: 'ชื่อเล่น',
                      hintText: 'กรุณากรอกกชื่อเล่น',
                      isRequired: true,
                      controller: _nickNameController,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomDropdown(
                      labelText: '',
                      initialValue: _selectedGender,
                      items: [
                        {"code": "1", "value": 'ชาย'},
                        {"code": "2", "value": 'หญิง'},
                        {"code": "3", "value": 'อื่นๆ'},
                      ],
                      onChanged: (value) {
                        setState(() => _selectedGender = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CustomTextFormField(
                labelText: 'ชื่อจริง',
                hintText: 'กรุณากรอกกชื่อจริง',
                isRequired: true,
                controller: _firstNameController,
              ),
              const SizedBox(height: 16),
              CustomTextFormField(
                labelText: 'นามสกุล',
                hintText: 'กรุณากรอกกนามสกุล',
                isRequired: true,
                controller: _lastNameController,
              ),

              const SizedBox(height: 16),
              CustomTextFormField(
                labelText: 'อีเมล',
                hintText: 'กรุณากรอกกอีเมล',
                isRequired: true,
                controller: _emailController,
                isEmail: true,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CustomTextFormField(
                      labelText: 'ชื่อผู้ติดต่อฉุกเฉิน',
                      hintText: 'กรุณากรอกกชื่อผู้ติดต่อฉุกเฉิน',
                      isRequired: true,
                      controller: _emergencyContactNameController,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextFormField(
                      labelText: 'เบอร์ผู้ติดต่อฉุกเฉิน',
                      hintText: 'กรุณากรอกกเบอร์ผู้ติดต่อฉุกเฉิน',
                      isRequired: true,
                      controller: _emergencyContactPhoneController,
                      keyboardType: TextInputType.phone,
                      isPhone: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              CheckboxListTile(
                value: _termsAccepted,
                onChanged: (newValue) =>
                    setState(() => _termsAccepted = newValue!),
                title: const Text('ยอมรับข้อกำหนดและเงื่อนไข'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 32),

              CustomElevatedButton(
                text: 'สมัครเป็นผู้เล่น',
                backgroundColor: Theme.of(context).colorScheme.primary,
                onPressed: () {
                  _submit();
                },
                enabled: !_termsAccepted,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  _buildProfileHeader() {
    return Center(
      child: Stack(
        children: [
          ImageUploadPicker(
            callback: (file) => {_uploadImage(file)},
            child: imageUrl != ''
                ? Container(
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                      ),
                      borderRadius: BorderRadius.circular(100.0),
                    ),
                  )
                : Image.asset(
                    'assets/icon/profile.png',
                    fit: BoxFit.cover,
                    height: 120,
                    width: 120,
                    color: Colors.black,
                  ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              radius: 15,
              child: CircleAvatar(
                backgroundColor: Color(0xFF1db954),
                radius: 12,
                child: Icon(Icons.edit, size: 14, color: Colors.white),
              ),
            ),
          ),
          if (loadingImage)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(179),
                  borderRadius: BorderRadius.circular(90),
                ),
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

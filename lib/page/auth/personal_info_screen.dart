import 'dart:io';

import 'package:badminton/component/button.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/dropdown.dart';
import 'package:badminton/component/image_picker.dart';
import 'package:badminton/component/text_box.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/firebase_messaging_service.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/gestures.dart';
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

  /// โหลดจาก /Auth/me (เช่น ชื่อ/เมลจาก Google)
  bool _profileLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExistingProfile());
  }

  /// แปลง gender จาก API ("ชาย" หรือเลข) → code ของ Dropdown ("1","2","3")
  static String? _genderToDropdownCode(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s == '1' || s == 'ชาย') return '1';
    if (s == '2' || s == 'หญิง') return '2';
    if (s == '3' || s == 'อื่นๆ' || s == 'ไม่ระบุ') return '3';
    return null;
  }

  Future<void> _loadExistingProfile() async {
    try {
      final res = await ApiProvider().get('/Auth/me');
      if (!mounted) return;
      if (res['status'] == 200 && res['data'] != null) {
        final raw = res['data'];
        if (raw is! Map) return;
        final d = Map<String, dynamic>.from(raw);
        _nickNameController.text = '${d['nickname'] ?? ''}'.trim();
        _firstNameController.text = '${d['firstName'] ?? ''}'.trim();
        _lastNameController.text = '${d['lastName'] ?? ''}'.trim();
        _emailController.text =
            '${d['primaryContactEmail'] ?? d['primary_contact_email'] ?? ''}'
                .trim();
        _emergencyContactNameController.text =
            '${d['emergencyContactName'] ?? d['emergency_contact_name'] ?? ''}'
                .trim();
        _emergencyContactPhoneController.text =
            '${d['emergencyContactPhone'] ?? d['emergency_contact_phone'] ?? ''}'
                .trim();
        final p =
            '${d['profilePhotoUrl'] ?? d['profile_photo_url'] ?? ''}'.trim();
        if (p.isNotEmpty) {
          imageUrl = p;
        }
        _selectedGender = _genderToDropdownCode(d['gender']);
      }
    } catch (_) {
      // เปิดฟอร์มว่างได้ ถ้า API ล้ม
    } finally {
      if (mounted) {
        setState(() => _profileLoading = false);
      }
    }
  }

  @override
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
          showDialogMsg(
            context,
            title: 'แจ้งเตือน',
            subtitle: errorMessage,
            btnLeft: 'ตกลง',
            onConfirm: () {},
          );
        }
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
          "gender": int.tryParse(_selectedGender ?? '') ?? 0,
          "profilePhotoUrl": imageUrl,
          "emergencyContactName": _emergencyContactNameController.text,
          "emergencyContactPhone": _emergencyContactPhoneController.text,
        },
      );
      setState(() {
        _isLoading = false;
      });
      if (response['status'] == 200) {
        // ส่ง FCM Token ไปที่ Backend หลังจากกรอกข้อมูลสมัครสมาชิกเสร็จสิ้น
        await FirebaseMessagingService().updateTokenToServer();
        
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
          showDialogMsg(
            context,
            title: 'แจ้งเตือน',
            subtitle: errorMessage,
            btnLeft: 'ตกลง',
            onConfirm: () {},
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
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
    if (_profileLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back, color: Colors.black),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
              Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: getResponsiveFontSize(context, fontSize: 26),
                  fontWeight: FontWeight.bold,
                ),
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
                      key: ValueKey('gender_${_selectedGender ?? 'none'}'),
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
                title: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'ยอมรับ '),
                      TextSpan(
                        text: 'ข้อกำหนดและเงื่อนไข',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w600,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => context.push('/terms'),
                      ),
                      const TextSpan(text: ' และ '),
                      TextSpan(
                        text: 'นโยบายความเป็นส่วนตัว',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w600,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => context.push('/privacy-policy'),
                      ),
                    ],
                  ),
                ),
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
                enabled: _termsAccepted,
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

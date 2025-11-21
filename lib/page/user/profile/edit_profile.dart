import 'dart:async';
import 'dart:io';
import 'package:badminton/component/Button.dart';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/dropdown.dart';
import 'package:badminton/component/image_picker.dart';
import 'package:badminton/component/text_box.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class EditProFileUserPage extends StatefulWidget {
  const EditProFileUserPage({super.key});

  @override
  EditProFileUserPageState createState() => EditProFileUserPageState();
}

class EditProFileUserPageState extends State<EditProFileUserPage> {
  late Future<dynamic> futureModel;
  bool loadingImage = false;
  String imageUrl = '';
  double gapHeight = 20;
  final List<dynamic> _items = [
    {"code": "1", "value": 'ชาย'},
    {"code": "2", "value": 'หญิง'},
    {"code": "3", "value": 'ไม่ระบุ'},
  ];
  String? _selectedValue;
  bool isChangePhone = false;
  late String _initialPhoneNumber;

  final _formKey = GlobalKey<FormState>();
  bool _pageIsLoading = true; // State สำหรับโหลดข้อมูลตอนเปิดหน้า
  bool _isSubmitting = false; // State สำหรับตอนกดปุ่มบันทึก
  late TextEditingController nicknameController;
  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController emergencyNameController;
  late TextEditingController emergencyPhoneController;

  @override
  void initState() {
    nicknameController = TextEditingController();
    firstNameController = TextEditingController();
    lastNameController = TextEditingController();
    emailController = TextEditingController();
    phoneController = TextEditingController();
    emergencyNameController = TextEditingController();
    emergencyPhoneController = TextEditingController();

    _getUserProfile();
    super.initState();
  }

  @override
  void dispose() {
    nicknameController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    emergencyNameController.dispose();
    emergencyPhoneController.dispose();
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

  Future<void> _getUserProfile() async {
    try {
      // เรียก API เพื่อดึงข้อมูลโปรไฟล์ปัจจุบัน
      final response = await ApiProvider().get('/Profiles/me');
      final userData = response['data'];

      // นำข้อมูลที่ได้มาใส่ใน Controllers และ State
      setState(() {
        nicknameController.text = userData['nickname'] ?? '';
        firstNameController.text = userData['firstName'] ?? '';
        lastNameController.text = userData['lastName'] ?? '';
        emailController.text = userData['primaryContactEmail'] ?? '';
        phoneController.text = userData['phoneNumber'] ?? '';
        emergencyNameController.text = userData['emergencyContactName'] ?? '';
        emergencyPhoneController.text = userData['emergencyContactPhone'] ?? '';
        _selectedValue = userData['gender'];
        imageUrl = userData['profilePhotoUrl'] ?? '';

        _initialPhoneNumber = userData['phoneNumber'] ?? '';
        _pageIsLoading = false;
      });
    } catch (e) {
      // จัดการ Error
      setState(() {
        _pageIsLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('ไม่สามารถดึงข้อมูลได้: $e'),
          ),
        );
      }
    }
  }

  // --- 2. การอัปเดตข้อมูล (UPDATE) ---
  Future<void> _submitForm() async {
    // ตรวจสอบความถูกต้องของข้อมูลใน Form
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // ตรวจสอบว่าเบอร์โทรศัพท์มีการเปลี่ยนแปลงหรือไม่
    final bool isPhoneChanged = phoneController.text != _initialPhoneNumber;

    // รวบรวมข้อมูลทั้งหมดจากฟอร์ม
    final Map<String, dynamic> updatedData = {
      'nickname': nicknameController.text,
      'firstName': firstNameController.text,
      'lastName': lastNameController.text,
      'primaryContactEmail': emailController.text,
      'phoneNumber': phoneController.text,
      'gender': _selectedValue,
      'profilePhotoUrl': imageUrl,
      'emergencyContactName': emergencyNameController.text,
      'emergencyContactPhone': emergencyPhoneController.text,
    };

    try {
      // เรียก API เพื่ออัปเดตข้อมูล
      await ApiProvider().put('/Profiles/me', data: updatedData);

      // --- จัดการผลลัพธ์หลังอัปเดตสำเร็จ ---
      if (isPhoneChanged) {
        // ถ้ามีการเปลี่ยนเบอร์โทร ให้ไปหน้า OTP
        if (mounted) context.push('/otp', extra: phoneController.text);
      } else {
        // ถ้าไม่มีการเปลี่ยนเบอร์โทร แสดง Dialog ว่าสำเร็จแล้วกลับไปหน้าโปรไฟล์
        if (mounted) {
          showDialogMsg(
            context,
            title: 'แก้ไขเรียบร้อย',
            subtitle: 'บันทึกการแก้ไขข้อมูลของคุณแล้ว',
            btnLeft: 'ไปหน้าโปรไฟล์',
            onConfirm: () {
              context.pop(); // ปิด Dialog
              context.pop(); // กลับไปหน้าโปรไฟล์
            },
          );
        }
      }
    } catch (e) {
      // จัดการ Error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('บันทึกข้อมูลล้มเหลว: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false,
      backgroundColor: Colors.white,
      appBar: AppBarSubMain(title: 'แก้ไขโปรไฟล์'),
      bottomNavigationBar: Container(
        color: Color(0xFFCBF5EA),
        padding: EdgeInsets.all(15),
        child: CustomElevatedButton(
          text: 'บันทึกการแก้ไข',
          onPressed: _submitForm,
          isLoading: _isSubmitting,
        ),
      ),
      body: _pageIsLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
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
                    _buildProfileHeader(),
                    SizedBox(height: gapHeight),
                    CustomTextFormField(
                      labelText: 'ชื่อเล่น',
                      hintText: 'กรุณากรอกชื่อเล่น',
                      isRequired: true,
                      controller: nicknameController,
                    ),
                    SizedBox(height: gapHeight),
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextFormField(
                            labelText: 'ชื่อจริง',
                            hintText: 'กรุณากรอกชื่อจริง',
                            isRequired: true,
                            controller: firstNameController,
                          ),
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.04,
                        ),
                        Expanded(
                          child: CustomTextFormField(
                            labelText: 'นามสกุล',
                            hintText: 'กรุณากรอกนามสกุล',
                            isRequired: true,
                            controller: lastNameController,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: gapHeight),
                    CustomTextFormField(
                      labelText: 'อีเมล',
                      hintText: 'กรุณากรอกอีเมล',
                      isRequired: true,
                      isEmail: true,
                      controller: emailController,
                    ),
                    SizedBox(height: gapHeight),
                    CustomTextFormField(
                      labelText: 'เบอร์โทรศัพท์',
                      hintText: 'กรุณากรอกเบอร์โทรศัพท์',
                      readOnly: isChangePhone ? false : true,
                      isRequired: true,
                      controller: phoneController,
                      suffixIconData: Icons.edit,
                      keyboardType: TextInputType.phone,
                      isPhone: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      onSuffixIconPressed: () {
                        showDialogMsg(
                          context,
                          title: 'คุณต้องการแก้ไขเบอร์มือถือ',
                          subtitle: 'คุณจะต้องทำการยืนยัน OTP อีกครั้ง',
                          btnRight: 'ยกเลิก',
                          btnLeftBackColor: Color(0xFFFFFFFF),
                          btnLeftForeColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          isWarning: true,
                          onConfirm: () {
                            setState(() {
                              isChangePhone = !isChangePhone;
                            });
                          },
                        );
                      },
                    ),
                    SizedBox(height: gapHeight),
                    CustomDropdown(
                      labelText: 'เพศ',
                      initialValue: _selectedValue,
                      items: _items,
                      isRequired: true,
                      onChanged: (value) {
                        setState(() {
                          _selectedValue = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'กรุณาเลือกเพศ';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: gapHeight),
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextFormField(
                            labelText: 'ชื่อผู้ติดต่อฉุกเฉิน',
                            hintText: 'กรุณากรอกชื่อผู้ติดต่อฉุกเฉิน',
                            controller: emergencyNameController,
                          ),
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.04,
                        ),
                        Expanded(
                          child: CustomTextFormField(
                            labelText: 'เบอร์ผู้ติดต่อฉุกเฉิน',
                            hintText: 'กรุณากรอกเบอร์ผู้ติดต่อฉุกเฉิน',
                            controller: emergencyPhoneController,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: gapHeight),
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
            callback: (file) => {
              setState(() {
                _uploadImage(file);
              }),
            },
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

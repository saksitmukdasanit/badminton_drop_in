import 'dart:async';
import 'package:badminton/component/Button.dart';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/dropdown.dart';
import 'package:badminton/component/image_picker.dart';
import 'package:badminton/component/text_box.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EditProFileOrganizerPage extends StatefulWidget {
  const EditProFileOrganizerPage({super.key});

  @override
  EditProFileOrganizerPageState createState() =>
      EditProFileOrganizerPageState();
}

class EditProFileOrganizerPageState extends State<EditProFileOrganizerPage> {
  late Future<dynamic> futureModel;
  String profileImageUrl = '';
  bool loadingImage = false;
  String image = '';
  double gapHeight = 20;
  final List<String> _items = ['ชาย', 'หญิง', 'ไม่ระบุ'];
  String? _selectedValue;
  bool isChangePhone = false;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController nicknameController;
  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController emergencyNameController;
  late TextEditingController emergencyPhoneController;

  late TextEditingController publicPhoneController;
  late TextEditingController facebookController;
  late TextEditingController lineIdController;

  @override
  void initState() {
    nicknameController = TextEditingController();
    firstNameController = TextEditingController();
    lastNameController = TextEditingController();
    emailController = TextEditingController();
    phoneController = TextEditingController();
    emergencyNameController = TextEditingController();
    emergencyPhoneController = TextEditingController();
    publicPhoneController = TextEditingController();
    facebookController = TextEditingController();
    lineIdController = TextEditingController();
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
    publicPhoneController.dispose();
    facebookController.dispose();
    lineIdController.dispose();
    super.dispose();
  }

  _uploadImage(file) async {}

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // เพิ่ม DialogMsg ที่นี้ถ้าข้อมูลถูกต้อง
      showDialogMsg(
        context,
        title: 'แก้ไขเรียบร้อย',
        subtitle: 'บันทึกการแก้ไข',
        btnLeft: 'ไปหน้าโปรโฟล์',
        onConfirm: () {},
      );
    }
    if (isChangePhone) {
      context.push('/otp').then((p) {
        showDialogMsg(
          context,
          title: 'แก้ไขเรียบร้อย',
          subtitle: 'บันทึกการแก้ไข',

          onConfirm: () {
            // เพิ่มโค้ดสำหรับไปหน้า OTP ที่นี่
          },
        );
      });
    } else {
      showDialogMsg(
        context,
        title: 'แก้ไขเรียบร้อย',
        subtitle: 'บันทึกการแก้ไข',

        onConfirm: () {
          // เพิ่มโค้ดสำหรับไปหน้า OTP ที่นี่
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false,
      backgroundColor: Colors.white,
      appBar: AppBarSubMain(title: 'แก้ไขโปรไฟล์'),
      bottomNavigationBar: Container(
        color: Color(0xFFD5DCF4),
        padding: EdgeInsets.all(15),
        child: CustomElevatedButton(
          text: 'บันทึกการแก้ไข',
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
              Text(
                'ข้อมูลส่วนตัว',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: getResponsiveFontSize(context, fontSize: 16),
                ),
              ),
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
                  SizedBox(width: MediaQuery.of(context).size.width * 0.04),
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
                onSuffixIconPressed: () {
                  showDialogMsg(
                    context,
                    title: 'คุณต้องการแก้ไขเบอร์มือถือ',
                    subtitle: 'คุณจะต้องทำการยืนยัน OTP อีกครั้ง',
                    btnRight: 'ยกเลิก',
                    btnLeftBackColor: Color(0xFFFFFFFF),
                    btnLeftForeColor: Theme.of(context).colorScheme.primary,
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
                  SizedBox(width: MediaQuery.of(context).size.width * 0.04),
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
              Text(
                'ข้อมูลติดต่อส่วนตัว',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: getResponsiveFontSize(context, fontSize: 16),
                ),
              ),
              SizedBox(height: gapHeight),
              CustomTextFormField(
                controller: publicPhoneController,
                labelText: 'เบอร์โทรศัพท์ติดต่อ',
              ),
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      title: Text(
                        'แสดงข้อมูลก่อนจอง',
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 16,
                        ),
                      ),
                      value: false,
                      onChanged: (bool? value) => {},
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: CheckboxListTile(
                      title: Text(
                        'แสดงข้อมูลหลังจอง',
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 16,
                        ),
                      ),
                      value: false,
                      onChanged: (bool? value) => {},
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              SizedBox(height: gapHeight),
              CustomTextFormField(
                controller: publicPhoneController,
                labelText: 'เบอร์โทรศัพท์สำรอง',
                isRequired: true,
              ),
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      title: Text(
                        'แสดงข้อมูลก่อนจอง',
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 16,
                        ),
                      ),
                      value: false,
                      onChanged: (bool? value) => {},
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: CheckboxListTile(
                      title: Text(
                        'แสดงข้อมูลก่อนจอง',
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 16,
                        ),
                      ),
                      value: false,
                      onChanged: (bool? value) => {},
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              SizedBox(height: gapHeight),
              CustomTextFormField(
                controller: facebookController,
                labelText: 'Facebook link',
              ),
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      title: Text(
                        'แสดงข้อมูลก่อนจอง',
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 16,
                        ),
                      ),
                      value: false,
                      onChanged: (bool? value) => {},
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: CheckboxListTile(
                      title: Text(
                        'แสดงข้อมูลก่อนจอง',
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 16,
                        ),
                      ),
                      value: false,
                      onChanged: (bool? value) => {},
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              SizedBox(height: gapHeight),
              CustomTextFormField(
                controller: lineIdController,
                labelText: 'Line ID',
              ),
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      title: Text(
                        'แสดงข้อมูลก่อนจอง',
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 16,
                        ),
                      ),
                      value: false,
                      onChanged: (bool? value) => {},
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: CheckboxListTile(
                      title: Text(
                        'แสดงข้อมูลก่อนจอง',
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 16,
                        ),
                      ),
                      value: false,
                      onChanged: (bool? value) => {},
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              SizedBox(height: gapHeight + 20),
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
            child: image != ''
                ? Container(
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(image),
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

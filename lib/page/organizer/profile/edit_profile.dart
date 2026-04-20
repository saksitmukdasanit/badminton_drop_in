import 'dart:async';
import 'dart:io';
import 'package:badminton/component/Button.dart';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/dropdown.dart';
import 'package:badminton/component/image_picker.dart';
import 'package:badminton/component/text_box.dart';
import 'package:badminton/shared/function.dart';
import 'package:badminton/shared/api_provider.dart';
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
  bool _isLoading = true;
  bool _isSubmitting = false;
  int _phoneVisibility = 0;
  int _facebookVisibility = 0;
  int _lineVisibility = 0;
  final List<dynamic> _items = [
    {"code": "1", "value": 'ชาย'},
    {"code": "2", "value": 'หญิง'},
    {"code": "3", "value": 'ไม่ระบุ'},
  ];
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
    _fetchData();
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

  Future<void> _fetchData() async {
    try {
      final response = await ApiProvider().get('/Organizer/profile');
      final userData = response['data'];
      if (mounted) {
        setState(() {
          nicknameController.text = userData['nickname'] ?? '';
          firstNameController.text = userData['firstName'] ?? '';
          lastNameController.text = userData['lastName'] ?? '';
          emailController.text = userData['email'] ?? '';
          phoneController.text = userData['phoneNumber'] ?? '';
          emergencyNameController.text = userData['emergencyContactName'] ?? '';
          emergencyPhoneController.text = userData['emergencyContactPhone'] ?? '';
          publicPhoneController.text = userData['publicPhoneNumber'] ?? '';
          facebookController.text = userData['facebookLink'] ?? '';
          lineIdController.text = userData['lineId'] ?? '';
          _selectedValue = (userData['gender'] ?? "1").toString();
          image = userData['profilePhotoUrl'] ?? '';
          _phoneVisibility = userData['phoneVisibility'] ?? 0;
          _facebookVisibility = userData['facebookVisibility'] ?? 0;
          _lineVisibility = userData['lineVisibility'] ?? 0;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  _uploadImage(List<File> file) async {
    try {
      final response = await ApiProvider().uploadFiles(
        files: file,
        folderName: 'ProfileOrganizer',
      );
      if (response.length > 0 && mounted) {
        setState(() {
          image = response[0]['imageUrl'];
        });
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _submitForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    try {
      final Map<String, dynamic> data = {
        // ข้อมูลส่วนตัว (User Profile)
        'nickname': nicknameController.text,
        'firstName': firstNameController.text,
        'lastName': lastNameController.text,
        'primaryContactEmail': emailController.text,
        "gender": int.tryParse(_selectedValue ?? '1') ?? 1,
        "profilePhotoUrl": image,
        'emergencyContactName': emergencyNameController.text,
        'emergencyContactPhone': emergencyPhoneController.text,
        // ข้อมูลผู้จัด (Organizer Profile)
        'publicPhoneNumber': publicPhoneController.text,
        'facebookLink': facebookController.text,
        'lineId': lineIdController.text,
        "phoneVisibility": _phoneVisibility,
        "facebookVisibility": _facebookVisibility,
        "lineVisibility": _lineVisibility,
      };
      await ApiProvider().put('/Organizer/profileUserAndOrganizer', data: data);
      
      if (mounted) {
        showDialogMsg(
          context,
          title: 'แก้ไขเรียบร้อย',
          subtitle: 'บันทึกการแก้ไขข้อมูลสำเร็จ',
          btnLeft: 'ไปหน้าโปรไฟล์',
          onConfirm: () {
            context.pop();
            context.pop();
          },
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
          isLoading: _isSubmitting,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
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
                      value: _phoneVisibility == 2, // 2 = สาธารณะ (ก่อนจอง)
                      onChanged: (bool? value) {
                        if (value == true) setState(() => _phoneVisibility = 2);
                        else setState(() => _phoneVisibility = 0); // 0 = ไม่แสดง
                      },
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
                      value: _phoneVisibility == 1, // 1 = แสดงหลังจอง
                      onChanged: (bool? value) {
                        if (value == true) setState(() => _phoneVisibility = 1);
                        else setState(() => _phoneVisibility = 0);
                      },
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
                      value: _facebookVisibility == 2,
                      onChanged: (bool? value) {
                        if (value == true) setState(() => _facebookVisibility = 2);
                        else setState(() => _facebookVisibility = 0);
                      },
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
                      value: _facebookVisibility == 1,
                      onChanged: (bool? value) {
                        if (value == true) setState(() => _facebookVisibility = 1);
                        else setState(() => _facebookVisibility = 0);
                      },
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
                      value: _lineVisibility == 2,
                      onChanged: (bool? value) {
                        if (value == true) setState(() => _lineVisibility = 2);
                        else setState(() => _lineVisibility = 0);
                      },
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
                      value: _lineVisibility == 1,
                      onChanged: (bool? value) {
                        if (value == true) setState(() => _lineVisibility = 1);
                        else setState(() => _lineVisibility = 0);
                      },
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

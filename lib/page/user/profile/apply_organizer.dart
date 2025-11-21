import 'dart:async';
import 'dart:io';
import 'package:badminton/component/Button.dart';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/dropdown.dart';
import 'package:badminton/component/image_picker.dart';
import 'package:badminton/component/image_picker_form.dart';
import 'package:badminton/component/text_box.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class ApplyOrganizerPage extends StatefulWidget {
  const ApplyOrganizerPage({super.key});

  @override
  ApplyOrganizerPageState createState() => ApplyOrganizerPageState();
}

class ApplyOrganizerPageState extends State<ApplyOrganizerPage> {
  late Future<dynamic> futureModel;
  bool loadingImage = false;
  String imageUrl = '';
  double gapHeight = 20;
  String? _selectedBank;
  String bookbankUrl = '';
  final List<dynamic> _banks = [
    {"code": "1", "value": 'ธนาคารกสิกรไทย'},
    {"code": "2", "value": 'ธนาคารไทยพาณิชย์'},
    {"code": "3", "value": 'ธนาคารกรุงเทพ'},
    {"code": "4", "value": 'ธนาคารกรุงไทย'},
  ];

  final _formKey = GlobalKey<FormState>();
  late TextEditingController idcardController;
  late TextEditingController bookBankNoController;
  late TextEditingController publicPhoneController;
  late TextEditingController facebookController;
  late TextEditingController lineController;

  bool _isLoading = false;

  @override
  void initState() {
    idcardController = TextEditingController();
    bookBankNoController = TextEditingController();
    publicPhoneController = TextEditingController();
    facebookController = TextEditingController();
    lineController = TextEditingController();

    _callRead();
    super.initState();
  }

  @override
  void dispose() {
    idcardController.dispose();
    bookBankNoController.dispose();

    publicPhoneController.dispose();
    facebookController.dispose();
    lineController.dispose();
    super.dispose();
  }

  Future<void> _callRead() async {
    try {
      final response = await ApiProvider().get('/Profiles/me');
      final userData = response['data'];
      setState(() {
        // ดึงเบอร์โทรและรูปโปรไฟล์เดิมมาแสดง
        publicPhoneController.text = userData['phoneNumber'] ?? '';
        imageUrl = userData['profilePhotoUrl'] ?? '';
        if (userData['isOrganizer'] == false) {
          showDialogMsg(
            context,
            title: 'คุณได้สมัครเป็นผู้จัดแล้ว',
            subtitle: 'รอผลพิจารณาเป็นผู้จัดใช้เวลา 3-7 วัน',
            btnLeft: 'กลับไปหน้าโปรไฟล์',
            onConfirm: () {
              context.pop(); // ปิด Dialog
              context.pop(); // กลับไปหน้าโปรไฟล์
            },
          );
        }
      });
    } catch (e) {
      // จัดการ Error หากดึงข้อมูลไม่ได้
      print('Failed to fetch initial data: $e');
    }
  }

  _uploadImageProfile(List<File> file) async {
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

  _uploadImage(List<File> file) async {
    try {
      final response = await ApiProvider().uploadFiles(
        files: file,
        folderName: 'Bookbank',
      );

      if (response.length > 0) {
        if (mounted) {
          setState(() {
            bookbankUrl = response[0]['imageUrl'];
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

  Future<void> _submitForm() async {
    // 1. ตรวจสอบ Form และรูปภาพที่จำเป็น
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 3. รวบรวมข้อมูลทั้งหมดเพื่อส่งให้ API
      final Map<String, dynamic> data = {
        "profilePhotoUrl": imageUrl,
        "nationalId": idcardController.text,
        "bankId": int.tryParse(_selectedBank ?? "0"),
        "bankAccountNumber": bookBankNoController.text,
        "bankAccountPhotoUrl": bookbankUrl,
        "publicPhoneNumber": publicPhoneController.text,
        "facebookLink": facebookController.text,
        "lineId": lineController.text,
        "phoneVisibility": 0,
        "facebookVisibility": 0,
        "lineVisibility": 0,
      };

      final response = await ApiProvider().post(
        '/Organizer/register',
        data: data,
      );

      if (response['status'] == 201) {
        if (mounted) {
          showDialogMsg(
            context,
            title: 'สมัครเป็นผู้จัดเรียบร้อย',
            subtitle: 'หมายเหตุ: \nรอผลพิจารณาเป็นผู้จัดใช้เวลา 3-7 วัน',
            btnLeft: 'กลับไปหน้าโปรไฟล์',
            onConfirm: () {
              context.pop(); // ปิด Dialog
              context.pop(); // กลับไปหน้าโปรไฟล์
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text(e.toString())),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false,
      backgroundColor: Colors.white,
      appBar: AppBarSubMain(title: 'สมัครเป็นผู้จัด'),
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
              _buildSectionTitle(context, 'ข้อมูลส่วนตัว'),
              SizedBox(height: gapHeight),
              _buildProfileHeader(),
              SizedBox(height: gapHeight),
              CustomTextFormField(
                labelText: 'เลขบัตรประจำตัวประชาชน',
                hintText: 'กรุณากรอกเลขบัตรประจำตัวประชาชน',
                isRequired: true,
                controller: idcardController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(13),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) return 'กรุณากรอกข้อมูล';
                  if (value.length != 13) return 'เลขบัตรต้องมี 13 หลัก';
                  return null;
                },
              ),
              SizedBox(height: gapHeight),
              CustomDropdown(
                labelText: 'ธนาคาร',
                initialValue: _selectedBank,
                items: _banks,
                isRequired: true,
                onChanged: (value) {
                  setState(() {
                    _selectedBank = value;
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
              CustomTextFormField(
                labelText: 'เลขบัญชี',
                hintText: 'กรุณากรอกเลขบัญชี',
                isRequired: true,
                controller: bookBankNoController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              SizedBox(height: gapHeight),
              ImagePickerFormField(
                labelText: 'รูป Bookbank',
                isRequired: true,
                onImageSelected: (File image) {
                  _uploadImage([image]);
                },
              ),
              SizedBox(height: gapHeight),
              _buildSectionTitle(
                context,
                'ข้อมูลติดต่อสาธารณะ (ต้องแสดงให้ผู้เล่นเห็น)',
              ),
              SizedBox(height: gapHeight),
              CustomTextFormField(
                labelText: 'เบอร์โทรติดต่อสาธารณะ',
                hintText: 'กรุณากรอกเบอร์โทรติดต่อสาธารณะ',
                isRequired: true,
                controller: publicPhoneController,
                keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              SizedBox(height: gapHeight),
              CustomTextFormField(
                labelText: 'Facebook',
                hintText: 'กรุณากรอกFacebook',
                controller: facebookController,
              ),
              SizedBox(height: gapHeight),
              CustomTextFormField(
                labelText: 'Line',
                hintText: 'กรุณากรอกLine',
                controller: lineController,
              ),
              SizedBox(height: gapHeight + 20),
              CustomElevatedButton(
                text: 'สมัครเป็นผู้จัด',
                onPressed: _submitForm,
                isLoading: _isLoading,
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
                _uploadImageProfile(file);
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

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: getResponsiveFontSize(context, fontSize: 16),
            color: Color(0XFF64646D),
          ),
        ),
        const Divider(thickness: 1, height: 16, color: Color(0XFF64646D)),
      ],
    );
  }
}

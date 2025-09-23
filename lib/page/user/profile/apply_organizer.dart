import 'dart:async';
import 'package:badminton/component/Button.dart';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/dropdown.dart';
import 'package:badminton/component/image_picker.dart';
import 'package:badminton/component/image_picker_form.dart';
import 'package:badminton/component/text_box.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ApplyOrganizerPage extends StatefulWidget {
  const ApplyOrganizerPage({super.key});

  @override
  ApplyOrganizerPageState createState() => ApplyOrganizerPageState();
}

class ApplyOrganizerPageState extends State<ApplyOrganizerPage> {
  late Future<dynamic> futureModel;
  String profileImageUrl = '';
  bool loadingImage = false;
  String image = '';
  double gapHeight = 20;
  String? _selectedBank;
  XFile? _bookbankImage;
  final List<String> _banks = [
    'ธนาคารกสิกรไทย',
    'ธนาคารไทยพาณิชย์',
    'ธนาคารกรุงเทพ',
    'ธนาคารกรุงไทย',
  ];

  final _formKey = GlobalKey<FormState>();
  late TextEditingController idcardController;
  late TextEditingController bookBankNoController;

  late TextEditingController phoneController;
  late TextEditingController facebookController;
  late TextEditingController lineController;

  @override
  void initState() {
    idcardController = TextEditingController();
    bookBankNoController = TextEditingController();

    phoneController = TextEditingController();
    facebookController = TextEditingController();
    lineController = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    idcardController.dispose();
    bookBankNoController.dispose();

    phoneController.dispose();
    facebookController.dispose();
    lineController.dispose();
    super.dispose();
  }

  _uploadImage(file) async {}

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // เพิ่ม DialogMsg ที่นี้ถ้าข้อมูลถูกต้อง
      showDialogMsg(
        context,
        title: 'สมัครเป็นผู้จัดเรียบร้อย',
        subtitle: 'หมายเหตุ: \nรอผลพิจารณาเป็นผู้จัดใช้เวลา 3-7 วัน',
        btnLeft: 'ไปหน้าโปรโฟล์',
        onConfirm: () {},
      );
    }
    showDialogMsg(
      context,
      title: 'สมัครเป็นผู้จัดเรียบร้อย',
      subtitle: 'หมายเหตุ: \nรอผลพิจารณาเป็นผู้จัดใช้เวลา 3-7 วัน',
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
              ),
              SizedBox(height: gapHeight),
              ImagePickerFormField(
                labelText: 'รูป Bookbank',
                isRequired: true,
                onImageSelected: (XFile? image) {
                  // รับไฟล์ที่เลือกกลับมาเก็บใน State ของหน้านี้
                  setState(() {
                    _bookbankImage = image;
                  });
                  print('Image selected: ${_bookbankImage?.path}');
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
                controller: bookBankNoController,
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: gapHeight),
              CustomTextFormField(
                labelText: 'Facebook',
                hintText: 'กรุณากรอกFacebook',
                controller: bookBankNoController,
              ),
              SizedBox(height: gapHeight),
              CustomTextFormField(
                labelText: 'Line',
                hintText: 'กรุณากรอกLine',
                controller: bookBankNoController,
              ),
              SizedBox(height: gapHeight + 20),
              CustomElevatedButton(
                text: 'สมัครเป็นผู้จัด',
                onPressed: _submitForm,
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

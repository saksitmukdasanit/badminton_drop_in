import 'dart:async';
import 'dart:io';
import 'package:badminton/component/Button.dart';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/dropdown.dart';
import 'package:badminton/component/image_picker.dart';
import 'package:badminton/component/image_picker_form.dart';
import 'package:badminton/component/text_box.dart';
import 'package:badminton/shared/function.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

class EditTransferPage extends StatefulWidget {
  const EditTransferPage({super.key});

  @override
  EditTransferPageState createState() => EditTransferPageState();
}

class EditTransferPageState extends State<EditTransferPage> {
  late Future<dynamic> futureModel;
  String profileImageUrl = '';
  bool loadingImage = false;
  String image = '';
  double gapHeight = 20;
  String? _selectedBank;
  bool _isLoading = true;
  bool _isSubmitting = false;
  File? _bookbankImage;
  final List<dynamic> _banks = [
    {"code": "1", "value": 'ธนาคารกสิกรไทย'},
    {"code": "2", "value": 'ธนาคารไทยพาณิชย์'},
    {"code": "3", "value": 'ธนาคารกรุงเทพ'},
    {"code": "4", "value": 'ธนาคารกรุงไทย'},
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
    _fetchData();
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

  Future<void> _fetchData() async {
    try {
      final response = await ApiProvider().get('/Organizer/profile');
      final userData = response['data'];
      if (mounted) {
        setState(() {
          idcardController.text = userData['nationalId'] ?? '';
          bookBankNoController.text = userData['bankAccountNumber'] ?? '';
          _selectedBank = userData['bankId']?.toString();
          image = userData['bankAccountPhotoUrl'] ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  _uploadImage(List<File> file) async {
    try {
      final response = await ApiProvider().uploadFiles(
        files: file,
        folderName: 'Bookbank',
      );
      if (response.length > 0 && mounted) {
        setState(() {
          image = response[0]['imageUrl'];
        });
      }
    } catch (e) {
       // error handling
    }
  }

  Future<void> _submitForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    try {
      final Map<String, dynamic> data = {
        'nationalId': idcardController.text,
        'bankId': int.tryParse(_selectedBank ?? '0'),
        'bankAccountNumber': bookBankNoController.text,
        'bankAccountPhotoUrl': image,
      };
      await ApiProvider().put('/Organizer/updateTransferBooking', data: data);
      
      if (mounted) {
        showDialogMsg(
          context,
          title: 'แก้ไขเรียบร้อย',
          subtitle: 'บันทึกข้อมูลการโอนเงินสำเร็จ',
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
      appBar: AppBarSubMain(title: 'แก้ไขข้อมูลการโอน'),
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
              _buildSectionTitle(context, 'ข้อมูลโอนเงิน'),
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
                onImageSelected: (File? image) {
                  // รับไฟล์ที่เลือกกลับมาเก็บใน State ของหน้านี้
                  setState(() {
                    _bookbankImage = image;
                  });
                  print('Image selected: ${_bookbankImage?.path}');
                },
              ),
              SizedBox(height: gapHeight + 20),
              CustomElevatedButton(
                text: 'แก้ไขข้อมูลผู้โอน',
                onPressed: _submitForm,
                isLoading: _isSubmitting,
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

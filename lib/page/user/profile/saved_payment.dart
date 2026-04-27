import 'dart:async';
import 'dart:io';
import 'package:badminton/component/Button.dart';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/dropdown.dart';
import 'package:badminton/component/text_box.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class SavedPaymentPage extends StatefulWidget {
  const SavedPaymentPage({super.key});

  @override
  SavedPaymentPageState createState() => SavedPaymentPageState();
}

class SavedPaymentPageState extends State<SavedPaymentPage> {
  bool _isLoading = false;
  double gapHeight = 20;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _accountNumberController;
  late TextEditingController _accountNameController;
  
  String? _selectedBankId;
  List<dynamic> _banks = [];
  
  File? _imageFile;
  String? _existingImageUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    _accountNumberController = TextEditingController();
    _accountNameController = TextEditingController();
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      // 1. โหลดรายชื่อธนาคาร
      final bankRes = await ApiProvider().get('/Dropdown/banks');
      if (bankRes['data'] != null) {
        _banks = (bankRes['data'] as List).map((b) => {
          "code": b['id'].toString(),
          "value": b['name']
        }).toList();
      }

      // 2. โหลดข้อมูล Profile ปัจจุบัน (เพื่อดึงบัญชีเก่ามาแสดง)
      final profileRes = await ApiProvider().get('/Profiles/me');
      final data = profileRes['data'];
      if (data != null) {
        _accountNumberController.text = data['bankAccountNumber'] ?? '';
        _accountNameController.text = data['bankAccountName'] ?? '';
        if (data['bankId'] != null) {
           _selectedBankId = data['bankId'].toString();
        }
        _existingImageUrl = data['bankAccountPhotoUrl'];
      }
    } catch (e) {
      debugPrint("Error fetching bank data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedBankId == null) {
        showDialogMsg(context, title: 'แจ้งเตือน', subtitle: 'กรุณาเลือกธนาคาร', btnLeft: 'ตกลง', onConfirm: () {});
        return;
      }

      setState(() => _isLoading = true);
      try {
        String? finalImageUrl = _existingImageUrl;

        // --- หากมีการเลือกรูปใหม่ ให้ทำการอัปโหลดไฟล์ไปที่ Server ก่อน ---
        if (_imageFile != null) {
          final uploadRes = await ApiProvider().uploadFiles(
            files: [_imageFile!],
            folderName: 'Bookbank',
          );
          
          if (uploadRes != null && uploadRes.length > 0) {
            finalImageUrl = uploadRes[0]['imageUrl'];
          } else {
            throw Exception('ไม่สามารถอัปโหลดรูปหน้าสมุดบัญชีได้ โปรดลองอีกครั้ง');
          }
        }

        // --- ยิง API อัปเดตข้อมูลบัญชีธนาคาร ---
        await ApiProvider().put(
          '/Profiles/me/bank',
          data: {
            'bankId': int.parse(_selectedBankId!),
            'bankAccountNumber': _accountNumberController.text.trim(),
            'bankAccountName': _accountNameController.text.trim(),
            'bankAccountPhotoUrl': finalImageUrl,
          },
        );
        
        if (mounted) {
          showDialogMsg(
            context, title: 'บันทึกสำเร็จ', subtitle: 'ข้อมูลบัญชีรับเงินถูกอัปเดตแล้ว', btnLeft: 'ตกลง',
            onConfirm: () => Navigator.pop(context),
          );
        }
      } catch (e) {
        if (mounted) {
          showDialogMsg(context, title: 'เกิดข้อผิดพลาด', subtitle: e.toString().replaceFirst('Exception: ', ''), btnLeft: 'ตกลง', onConfirm: () {});
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _deleteData() {
    showDialogMsg(
      context,
      title: 'ยืนยันการลบ',
      subtitle: 'คุณต้องการลบข้อมูลบัญชีรับเงินนี้หรือไม่?',
      isWarning: true,
      btnLeft: 'ลบข้อมูล',
      btnLeftBackColor: Colors.red,
      btnLeftForeColor: Colors.white,
      btnRight: 'ยกเลิก',
      onConfirm: () async {
        setState(() => _isLoading = true);
        try {
          // ลบข้อมูลโดยการส่งค่า null ไปอัปเดตแทน
          await ApiProvider().put(
            '/Profiles/me/bank',
            data: {
              'bankId': null,
              'bankAccountNumber': null,
              'bankAccountName': null,
              'bankAccountPhotoUrl': null,
            },
          );

          if (mounted) {
            setState(() {
              _selectedBankId = null;
              _accountNumberController.clear();
              _accountNameController.clear();
              _imageFile = null;
              _existingImageUrl = null;
            });
            Navigator.pop(context); // ปิด Dialog ยืนยันการลบ
            showDialogMsg(context, title: 'สำเร็จ', subtitle: 'ลบข้อมูลบัญชีเรียบร้อยแล้ว', btnLeft: 'ตกลง', onConfirm: () {});
          }
        } catch (e) {
          if (mounted) {
            Navigator.pop(context); // ปิด Dialog ยืนยันการลบ
            showDialogMsg(context, title: 'เกิดข้อผิดพลาด', subtitle: e.toString().replaceFirst('Exception: ', ''), btnLeft: 'ตกลง', onConfirm: () {});
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      appBar: AppBarSubMain(title: 'บัญชีรับเงิน (ถอนเงิน)'),
      bottomNavigationBar: Container(
        color: Colors.transparent,
        padding: EdgeInsets.all(15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomElevatedButton(
              text: 'บันทึกข้อมูลบัญชี',
              onPressed: _submitForm,
              isLoading: _isLoading,
            ),
            SizedBox(height: gapHeight),
            CustomElevatedButton(
              text: 'ลบข้อมูล',
              onPressed: _deleteData,
              backgroundColor: Colors.white,
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
          ],
        ),
      ),
      body: Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFCBF5EA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading && _banks.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                'ข้อมูลบัญชีสำหรับรับเงินคืนและถอนเงิน Wallet',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              SizedBox(height: gapHeight),
              CustomDropdown(
                labelText: 'ธนาคาร',
                initialValue: _selectedBankId,
                items: _banks,
                isRequired: true,
                onChanged: (val) => setState(() => _selectedBankId = val),
              ),
              SizedBox(height: gapHeight),
              CustomTextFormField(
                labelText: 'เลขที่บัญชี',
                hintText: 'กรุณากรอกเลขบัญชีธนาคาร',
                isRequired: true,
                controller: _accountNumberController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
              ),
              SizedBox(height: gapHeight),
              CustomTextFormField(
                labelText: 'ชื่อบัญชี',
                hintText: 'กรุณากรอกชื่อบัญชี',
                isRequired: true,
                controller: _accountNameController,
              ),
              SizedBox(height: gapHeight),
              const Text(
                'รูปสมุดบัญชี (ตัวเลือก)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_imageFile!, fit: BoxFit.cover),
                        )
                      : _existingImageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(_existingImageUrl!, fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text('แตะเพื่ออัปโหลดรูปหน้าสมุดบัญชี', style: TextStyle(color: Colors.grey.shade600)),
                              ],
                            ),
                ),
                    ),
              const SizedBox(height: 80), // เผื่อระยะปุ่มด้านล่าง
            ],
          ),
        ),
      ),
    );
  }
}

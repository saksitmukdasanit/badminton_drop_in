import 'dart:async';
import 'package:badminton/component/Button.dart';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/text_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SavedPaymentPage extends StatefulWidget {
  const SavedPaymentPage({super.key});

  @override
  SavedPaymentPageState createState() => SavedPaymentPageState();
}

class SavedPaymentPageState extends State<SavedPaymentPage> {
  late Future<dynamic> futureModel;
  String profileImageUrl = '';
  bool loadingImage = false;
  String image = '';
  double gapHeight = 20;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _cardNumberController;
  late TextEditingController _cardNameController;
  late TextEditingController _expiryMonthController;
  late TextEditingController _expiryYearController;
  late TextEditingController _cvvController;

  @override
  void initState() {
    _cardNumberController = TextEditingController();
    _cardNameController = TextEditingController();
    _expiryMonthController = TextEditingController();
    _expiryYearController = TextEditingController();
    _cvvController = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardNameController.dispose();
    _expiryMonthController.dispose();
    _expiryYearController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // final cardNumber = _cardNumberController.text;
      // final cardName = _cardNameController.text;
      // final expiryDate =
      //     '${_expiryMonthController.text}/${_expiryYearController.text}';
      // final cvv = _cvvController.text;

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

  void _deleteData() {
    showDialogMsg(
      context,
      title: 'ลบข้อมูลบัตรเรียบร้อย',
      subtitle: '',
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
      appBar: AppBarSubMain(title: 'Saved Payment'),
      bottomNavigationBar: Container(
        color: Color(0xFFCBF5EA),
        padding: EdgeInsets.all(15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomElevatedButton(
              text: 'บันทึกการแก้ไข',
              onPressed: _submitForm,
            ),
            SizedBox(height: gapHeight),
            CustomElevatedButton(
              text: 'ลบข้อมูล',
              onPressed: _deleteData,
              backgroundColor: Colors.white,
              foregroundColor: Theme.of(context).colorScheme.primary,
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
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              SizedBox(height: gapHeight),
              CustomTextFormField(
                labelText: 'หมายเลขบัตร',
                hintText: 'กรุณากรอกหมายเลขบัตร',
                isRequired: true,
                controller: _cardNumberController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                  // CardNumberInputFormatter(),
                ],
                suffixIconData: Icons.credit_card,
              ),
              SizedBox(height: gapHeight),
              CustomTextFormField(
                labelText: 'ชื่อบนบัตร',
                hintText: 'กรุณากรอกชื่อบนบัตร',
                isRequired: true,
                controller: _cardNameController,
              ),
              SizedBox(height: gapHeight),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CustomTextFormField(
                      labelText: 'เดือน',
                      hintText: 'MM',
                      isRequired: true,
                      controller: _expiryMonthController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                    ),
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.04),
                  Expanded(
                    child: CustomTextFormField(
                      labelText: 'ปี',
                      hintText: 'YY',
                      isRequired: true,
                      controller: _expiryYearController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: gapHeight),
              CustomTextFormField(
                labelText: 'CVV',
                isRequired: true,
                controller: _cvvController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
              ),
              SizedBox(height: gapHeight),
            ],
          ),
        ),
      ),
    );
  }
}

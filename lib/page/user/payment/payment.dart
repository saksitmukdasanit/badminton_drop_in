import 'dart:async';

import 'package:badminton/component/Button.dart';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/dropdown.dart';
import 'package:badminton/component/text_box.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:go_router/go_router.dart';

class PaymentPage extends StatefulWidget {
  // --- (เพิ่มใหม่) Parameter สำหรับรับข้อมูล ---
  final String bookingId;

  const PaymentPage({super.key, required this.bookingId});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  bool _autoConfirm = true;
  bool isMemCard = true;
  String? _selectedPaymentMethod;
  final List<dynamic> _paymentMethods = [
    {"code": 1, "value": 'Credit/Debit Card'},
    {"code": 2, "value": 'Mobile Banking'},
    {"code": 3, "value": 'QR Code'},
  ];

  // -----Credit/Debit Card----
  final _formKeyCard = GlobalKey<FormState>();
  late TextEditingController _cardNumberController;
  late TextEditingController _cardNameController;
  late TextEditingController _expiryMonthController;
  late TextEditingController _expiryYearController;
  late TextEditingController _cvvController;

  // --- State สำหรับตัวนับเวลาถอยหลัง ---
  Timer? _timer;
  Duration _remainingTime = const Duration(minutes: 10);

  bool _isLoading = false;

  @override
  void initState() {
    _cardNumberController = TextEditingController();
    _cardNameController = TextEditingController();
    _expiryMonthController = TextEditingController();
    _expiryYearController = TextEditingController();
    _cvvController = TextEditingController();
    _startTimer();
    super.initState();
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardNameController.dispose();
    _expiryMonthController.dispose();
    _expiryYearController.dispose();
    _cvvController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _remainingTime = const Duration(minutes: 10);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingTime.inSeconds == 0) {
        timer.cancel();
      } else {
        setState(() {
          _remainingTime = _remainingTime - const Duration(seconds: 1);
        });
      }
    });
  }

  Future<void> _handlePayment() async {
    // // --- 1. จัดการกรณี QR Code (ซึ่งไม่ยิง API นี้) ---
    // if (_selectedPaymentMethod == 'QR Code') {
    //   // TODO: เพิ่ม Logic การดาวน์โหลดรูป QR Code
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(
    //       content: Text('กำลังดาวน์โหลด QR Code... (Logicยังไม่เสร็จ)'),
    //     ),
    //   );
    //   return; // หยุดทำงาน
    // }

    // // --- 2. ตรวจสอบว่าเลือกวิธีชำระเงินหรือยัง ---
    // if (_selectedPaymentMethod == null) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text('กรุณาเลือกวิธีการชำระเงิน')),
    //   );
    //   return;
    // }

    // // --- 3. ตรวจสอบ Form บัตรเครดิต (ถ้าเลือก) ---
    // if (_selectedPaymentMethod == 'Credit/Debit Card') {
    //   if (!(_formKeyCard.currentState?.validate() ?? false)) {
    //     return; // หยุดถ้ากรอกบัตรไม่ถูกต้อง
    //   }
    // }

    // --- 4. เริ่ม Loading ---
    setState(() {
      _isLoading = true;
    });

    try {
      // 5. รวบรวมข้อมูลการชำระเงิน (นี่เป็นข้อมูลตัวอย่าง คุณต้องปรับแก้ให้ตรงกับ DTO ที่ API ต้องการ)
      // dynamic paymentData;
      // if (_selectedPaymentMethod == 'Credit/Debit Card') {
      //   paymentData = {
      //     'method': 'CreditCard',
      //     'cardNumber': _cardNumberController.text,
      //     'cardName': _cardNameController.text,
      //     'expiryMonth': _expiryMonthController.text,
      //     'expiryYear': _expiryYearController.text,
      //     'cvv': _cvvController.text,
      //     'saveCard': isMemCard,
      //   };
      // } else if (_selectedPaymentMethod == 'Mobile Banking') {
      //   paymentData = {'method': 'MobileBanking', 'bank': 'KBank'}; // ตัวอย่าง
      // }

      // --- 6. ยิง API ---
      // (ApiProvider จะแนบ Token ไปใน Header ให้เอง)
      await ApiProvider().post(
        '/GameSessions/${widget.bookingId}/join',
        // data: paymentData,
      );

      // --- 7. ถ้าสำเร็จ: แสดง Dialog ---
      if (mounted) {
        showDialogMsg(
          context,
          title: 'ชำระเงินเรียบร้อย',
          subtitle: 'คุณได้ชำระเงินจำนวน 130 บาท \n ยืนยันการจอง ก๊วนแมวเหมียว',
          btnLeft: 'ไปหน้าการจอง',
          onConfirm: () {
            context.pop(); // ปิด Dialog
            context.go('/my-game-user'); // กลับไปหน้า "เกมของฉัน"
          },
        );
      }
    } catch (e) {
      // --- 8. ถ้าล้มเหลว: แสดง Error ---
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      // --- 9. สิ้นสุด Loading เสมอ ---
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildPaymentDetails() {
    switch (_selectedPaymentMethod) {
      case 'Credit/Debit Card':
        return _buildCreditCardForm();
      case 'Mobile Banking':
        return _buildMobileBankingForm();
      case 'QR Code':
        return _buildQrCodeView();
      default:
        return const SizedBox.shrink(); // ถ้ายังไม่เลือก ให้แสดง Widget ว่างๆ
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBarSubMain(title: 'จ่ายเงิน'),
      // --- ใช้ bottomNavigationBar เพื่อให้ปุ่มอยู่ด้านล่างเสมอ ---
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),

        child: CustomElevatedButton(
          text: _selectedPaymentMethod == 'QR Code' ? 'Download QR' : 'Pay Now',
          isLoading: _isLoading,
          onPressed: _handlePayment, // <<< CHANGED: เรียกใช้ฟังก์ชันใหม่
          backgroundColor: _selectedPaymentMethod == 'QR Code'
              ? Colors.white
              : Colors.black,
          foregroundColor: _selectedPaymentMethod == 'QR Code'
              ? Theme.of(context).colorScheme.primary
              : Colors.white,
          side: _selectedPaymentMethod == 'QR Code'
              ? const BorderSide(color: Colors.black)
              : null,

          // onPressed: () {
          //   showDialogMsg(
          //     context,
          //     title: 'ชำระเงินเรียบร้อย',
          //     subtitle:
          //         'คุณได้ชำระเงินจำนวน 130 บาท \n ยืนยันการจอง ก๊วนแมวเหมียว',
          //     btnLeft: 'ไปหน้าการจอง',
          //     onConfirm: () {
          //       // เพิ่มโค้ดสำหรับไปหน้า OTP ที่นี่
          //     },
          //   );
          // },
          // backgroundColor: _selectedPaymentMethod == 'QR Code'
          //     ? Colors.white
          //     : Colors.black,
          // foregroundColor: _selectedPaymentMethod == 'QR Code'
          //     ? Theme.of(context).colorScheme.primary
          //     : Colors.white,
          // side: _selectedPaymentMethod == 'QR Code'
          //     ? const BorderSide(color: Colors.black)
          //     : null,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ListView(
            // crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- T&C Link ---
              Text(
                'จองเป็นผู้เล่นตัวสำรอง',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: getResponsiveFontSize(context, fontSize: 16),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ถ้าไม่ได้รับเลือกจะโอนเงินคืนภายใน 7 วันทำการ ',
                        style: TextStyle(
                          fontWeight: FontWeight.w300,
                          fontSize: getResponsiveFontSize(
                            context,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'T&C',
                      style: TextStyle(
                        // --- (แก้ไข) ปรับสีให้เข้ากับ Theme ใหม่ ---
                        color: Theme.of(context).primaryColor,
                        decoration: TextDecoration.underline,
                        decorationColor: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // --- Checkbox ---
              CheckboxListTile(
                title: Text(
                  'เปลี่ยนเป็นตัวจริงอัตโนมัติ',
                  style: TextStyle(
                    color: Color(0xFF64646D),
                    fontWeight: FontWeight.w400,
                    fontSize: getResponsiveFontSize(context, fontSize: 16),
                  ),
                ),
                value: _autoConfirm,
                onChanged: (bool? newValue) {
                  setState(() {
                    _autoConfirm = newValue!;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: Theme.of(context).primaryColor,
                checkColor: Colors.white,
              ),
              _buildPriceRow(context, 'ค่าสนาน', '120 บาท'),
              _buildPriceRow(context, 'ค่าธรรมเนียม', '10 บาท'),
              _buildPriceRow(context, 'ราคารวม', '130 บาท', isBold: true),
              SizedBox(height: 20),
              // --- เวลานับถอยหลัง ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'วิธีการชำระเงิน',
                    style: TextStyle(
                      fontSize: getResponsiveFontSize(context, fontSize: 20),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // --- Dropdown เลือกวิธีชำระเงิน ---
              CustomDropdown(
                labelText: '',
                initialValue: _selectedPaymentMethod,
                items: _paymentMethods,
                onChanged: (value) {
                  setState(() {
                    _selectedPaymentMethod = value;
                    if (value == 'QR Code') {
                      _startTimer();
                    }
                  });
                },
              ),
              const SizedBox(height: 15),
              _buildPaymentDetails(),
              const Spacer(), // ใช้ Spacer เพื่อดันปุ่ม (ใน bottomNavigationBar) ลงไปอีก
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceRow(
    BuildContext context,
    String title,
    String amount, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: getResponsiveFontSize(context, fontSize: 20),
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: getResponsiveFontSize(context, fontSize: 20),
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // --- Widget สำหรับฟอร์มบัตรเครดิต ---
  Widget _buildCreditCardForm() {
    final sizedbox = SizedBox(height: 10);
    return Form(
      key: _formKeyCard,
      child: Column(
        children: [
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
          sizedbox,
          CustomTextFormField(
            labelText: 'ชื่อบนบัตร',
            hintText: 'กรุณากรอกชื่อบนบัตร',
            isRequired: true,
            controller: _cardNameController,
          ),
          sizedbox,
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
          sizedbox,
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
          sizedbox,
          CheckboxListTile(
            title: Text(
              'บันทึกสำหรับใช้ครั้งถัดไป',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 16),
                fontWeight: FontWeight.w400,
                color: Color(0xFF64646D),
              ),
            ),
            value: isMemCard,
            onChanged: (val) {
              setState(() {
                isMemCard = !isMemCard;
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  // --- Widget สำหรับ Mobile Banking ---
  Widget _buildMobileBankingForm() {
    return Column(
      children: [
        CustomDropdown(
          labelText: 'เลือกธนาคาร',
          // initialValue: _selectedPaymentMethod,
          items: [
            {"code": 1, "value": 'KBank'},
            {"code": 2, "value": 'SCB'},
            {"code": 3, "value": 'BBL'},
          ],
          onChanged: (val) {},
        ),
      ],
    );
  }

  // --- Widget สำหรับ QR Code ---
  Widget _buildQrCodeView() {
    String formattedTime =
        '${_remainingTime.inMinutes.toString().padLeft(2, '0')}:${(_remainingTime.inSeconds % 60).toString().padLeft(2, '0')}';
    return Column(
      children: [
        const Center(
          child: Icon(Icons.qr_code_2, size: 150, color: Colors.black87),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'วิธีการชำระเงิน',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 20),
                fontWeight: FontWeight.w400,
              ),
            ),
            Text(
              'เวลาเหลือ $formattedTime นาที',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w300,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

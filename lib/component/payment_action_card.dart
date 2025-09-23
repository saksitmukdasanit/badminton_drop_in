import 'dart:async';

import 'package:badminton/component/Button.dart';
import 'package:badminton/component/dropdown.dart';
import 'package:badminton/component/text_box.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PaymentActionCard extends StatefulWidget {
  // 1. กำหนด Parameters ที่จะรับจากภายนอก
  final VoidCallback onPayNowPressed;

  const PaymentActionCard({super.key, required this.onPayNowPressed});

  @override
  State<PaymentActionCard> createState() => _PaymentActionCardState();
}

class _PaymentActionCardState extends State<PaymentActionCard> {
  bool isMemCard = true;

  Timer? _timer;
  String? _selectedPaymentMethod;
  Duration _remainingTime = const Duration(minutes: 10);
  final List<String> _paymentMethods = [
    'Credit/Debit Card',
    'Mobile Banking',
    'QR Code',
  ];
  final _formKeyCard = GlobalKey<FormState>();
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
    // 3. ย้าย UI ทั้งหมดมาไว้ใน build method ของ Component
    return Card(
      // margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            priceRow(title: 'ค่าลูก', amount: '60 บาท'),
            priceRow(title: 'ราคารวม', amount: '60 บาท', isBold: true),
            const SizedBox(height: 12),
            priceRow(title: 'วิธีการชำระเงิน', amount: ''),
            const SizedBox(height: 12),
            CustomDropdown(
              labelText: '',
              initialValue: _selectedPaymentMethod,
              items: _paymentMethods,
              onChanged: (value) {
                setState(() {
                  _selectedPaymentMethod = value;
                  if (value == 'QR Code') {
                    // _startTimer();
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            _buildPaymentDetails(),
            const SizedBox(height: 12),
            CustomElevatedButton(
              text: _selectedPaymentMethod == 'QR Code'
                  ? 'Download QR'
                  : 'Pay Now',
              onPressed: widget.onPayNowPressed,
              backgroundColor: _selectedPaymentMethod == 'QR Code'
                  ? Colors.white
                  : Colors.black,
              foregroundColor: _selectedPaymentMethod == 'QR Code'
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white,
              side: _selectedPaymentMethod == 'QR Code'
                  ? const BorderSide(color: Colors.black)
                  : null,
            ),
          ],
        ),
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
          items: ['KBank', 'SCB', 'BBL'],
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
            Expanded(
              child: Text(
                'วิธีการชำระเงิน',
                style: TextStyle(
                  fontSize: getResponsiveFontSize(context, fontSize: 20),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Expanded(
              child: Text(
                'เวลาเหลือ $formattedTime นาที',
                style: TextStyle(
                  fontSize: getResponsiveFontSize(context, fontSize: 14),
                  fontWeight: FontWeight.w300,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  priceRow({String title = '', String amount = '', bool isBold = false}) {
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
}

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
import 'package:badminton/component/qr_payment_dialog.dart';

class PaymentPage extends StatefulWidget {
  // --- (เพิ่มใหม่) Parameter สำหรับรับข้อมูล ---
  final String bookingId;

  const PaymentPage({super.key, required this.bookingId});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  bool _autoConfirm = true;
  String? _selectedPaymentMethod;
  final List<dynamic> _paymentMethods = [
    {"code": 'QR Code', "value": 'สแกน QR Code (PromptPay)'},
    {"code": 'Wallet', "value": 'กระเป๋าเงิน (Wallet)'},
  ];

  // --- State สำหรับตัวนับเวลาถอยหลัง ---
  Timer? _timer;
  Duration _remainingTime = const Duration(minutes: 10);

  bool _isLoading = false;
  bool _isLoadingData = true;
  double _courtFee = 0.0;
  double _serviceFee = 10.0;

  @override
  void initState() {
    _fetchSessionData();
    super.initState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- ดึงข้อมูลค่าใช้จ่ายจริงจาก API ---
  Future<void> _fetchSessionData() async {
    try {
      final response = await ApiProvider().get('/GameSessions/${widget.bookingId}');
      if (mounted && response['data'] != null) {
        setState(() {
          _courtFee = double.tryParse(response['data']['courtFeePerPerson']?.toString() ?? '0') ?? 0;
          _serviceFee = double.tryParse(response['data']['serviceFee']?.toString() ?? '10') ?? 10.0; // ดึงค่าบริการจาก API
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
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
        _handleTimeout(); // เรียกฟังก์ชันเมื่อเวลาหมด
      } else {
        setState(() {
          _remainingTime = _remainingTime - const Duration(seconds: 1);
        });
      }
    });
  }

  // --- ฟังก์ชันจัดการเมื่อเวลาชำระเงินหมด ---
  void _handleTimeout() {
    if (!mounted) return;
    showDialogMsg(
      context,
      title: 'หมดเวลาทำรายการ',
      subtitle: 'เวลาในการชำระเงินของคุณหมดแล้ว\nกรุณาทำรายการจองใหม่อีกครั้ง',
      btnLeft: 'ตกลง',
      onConfirm: () {
        context.pop(); // ปิด Dialog
        context.go('/search-user'); // กลับไปหน้าค้นหา
      },
    );
  }

  Future<void> _handlePayment() async {
    // --- 1. ตรวจสอบว่าเลือกวิธีชำระเงินหรือยัง ---
    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกวิธีการชำระเงิน')),
      );
      return;
    }

    // --- 4. เริ่ม Loading ---
    setState(() {
      _isLoading = true;
    });

    try {
      // 5. รวบรวมข้อมูลการชำระเงิน
      Map<String, dynamic> paymentData = {
        'paymentMethod': _selectedPaymentMethod,
        'autoPromote': _autoConfirm, // ส่งข้อมูลว่าต้องการเป็นตัวจริงอัตโนมัติหรือไม่
      };

      // --- 6. ยิง API ---
      final response = await ApiProvider().post(
        '/player/gamesessions/${widget.bookingId}/join',
        data: paymentData,
      );

      // --- 7. จัดการผลลัพธ์ตามประเภทการชำระเงิน ---
      if (mounted) {
        if (_selectedPaymentMethod == 'QR Code') {
          // --- รอรับ QR Code จาก Backend (ใส่ Mock ไว้ก่อนเพื่อทดสอบ UI) ---
          final qrCode = response['data']?['qrCode'] ?? '00020101021129370016A000000677010111011300668000000005802TH530376454045.006304E612';
          final billId = response['data']?['billId'] ?? 0;

          final confirmed = await showQrPaymentDialog(
            context,
            _courtFee + _serviceFee,
            qrData: qrCode,
            sessionId: int.parse(widget.bookingId),
            billId: billId,
          );
          
          if (!mounted) return;

          if (confirmed == true) {
            _showSuccessDialog();
          } else {
            // --- NEW: ทางเลือกที่ 2 กดยกเลิก/ปิดหน้า QR ให้ยิง API ยกเลิกการจองทันที ---
            try {
              await ApiProvider().delete('/player/gamesessions/${widget.bookingId}/cancel');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ยกเลิกรายการจองแล้ว เนื่องจากยังไม่ได้ชำระเงิน')),
                );
              }
            } catch (e) {
              debugPrint('Cancel booking failed: $e');
            }
          }
        } else {
          // ถ้าจ่ายด้วย Wallet หรือช่องทางอื่น ถือว่าจองสำเร็จทันที
          _showSuccessDialog();
        }
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

  void _showSuccessDialog() {
    // แจ้งเตือนและเปลี่ยนหน้าอัตโนมัติ ไม่ต้องรอให้ผู้ใช้กดปุ่ม
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ชำระเงินสำเร็จ! ยืนยันการเข้าร่วมก๊วนเรียบร้อย'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
    context.go('/my-game-user');
  }

  Widget _buildPaymentDetails() {
    switch (_selectedPaymentMethod) {
      case 'Wallet':
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
              child: Text('หักเงินจากกระเป๋าเงินในระบบของคุณอัตโนมัติ',
                  style: TextStyle(color: Colors.grey))),
        );
      default:
        return const SizedBox.shrink(); // ถ้ายังไม่เลือก ให้แสดง Widget ว่างๆ
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      appBar: AppBarSubMain(title: 'จ่ายเงิน'),
      // --- ใช้ bottomNavigationBar เพื่อให้ปุ่มอยู่ด้านล่างเสมอ ---
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),

        child: CustomElevatedButton(
          text: _selectedPaymentMethod == 'QR Code' 
              ? 'สร้าง QR Code ยืนยันการจอง'
              : 'ชำระเงินด้วย Wallet',
          isLoading: _isLoading,
          onPressed: _handlePayment,
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
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFCBF5EA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: ListView(
              children: [
                // --- รายละเอียดการจอง ---
                Text(
                  'จองเป็นผู้เล่นตัวสำรอง',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: getResponsiveFontSize(context, fontSize: 16),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ถ้าไม่ได้รับเลือกจะโอนเงินคืนภายใน 7 วันทำการ ',
                            style: TextStyle(
                              fontWeight: FontWeight.w300,
                              fontSize: getResponsiveFontSize(context, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {},
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          'T&C',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            decoration: TextDecoration.underline,
                            decorationColor: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

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
                
                const SizedBox(height: 12),
                
                // --- การ์ดสรุปค่าใช้จ่าย ---
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'รายละเอียดค่าใช้จ่าย',
                          style: TextStyle(
                            fontSize: 18,
                            color: Color(0xFF0E9D7A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_isLoadingData)
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else ...[
                          _buildPriceRow(context, 'ค่าสนาม', '${_courtFee.toStringAsFixed(0)} บาท'),
                          _buildPriceRow(context, 'ค่าบริการ', '${_serviceFee.toStringAsFixed(0)} บาท'),
                          const Divider(height: 24),
                          _buildPriceRow(context, 'ราคารวม', '${(_courtFee + _serviceFee).toStringAsFixed(0)} บาท', isBold: true),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                
                // --- เวลานับถอยหลัง ---
                const Text(
                  'วิธีการชำระเงิน',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
                      // นำ _startTimer() ออก เพื่อให้รอจับเวลาตอนที่ได้ QR Code มาจริงๆ
                    });
                  },
                ),
                const SizedBox(height: 15),
                _buildPaymentDetails(),
              ],
            ),
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
}

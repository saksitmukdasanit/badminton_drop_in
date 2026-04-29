import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/button.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/dropdown.dart';
import 'package:badminton/component/qr_payment_dialog.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PaymentNowPage extends StatefulWidget {
  final String code;

  const PaymentNowPage({super.key, required this.code});

  @override
  State<PaymentNowPage> createState() => _PaymentNowPageState();
}

class _PaymentNowPageState extends State<PaymentNowPage> {
  bool _isLoading = true;
  dynamic _billData;
  String? _selectedPaymentMethod;
  List<Map<String, dynamic>> _customItems = []; // เก็บรายการที่เพิ่ม/ลดเอง
  final List<dynamic> _paymentMethods = [
    {"code": 'QR Code', "value": 'QR Code'},
    {"code": 'Cash', "value": 'เงินสด'},
    {"code": 'Wallet', "value": 'กระเป๋าเงิน (Wallet)'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchMyBill();
  }

  Future<void> _fetchMyBill() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final res =
          await ApiProvider().get('/player/gamesessions/${widget.code}/my-bill');
      if (mounted) {
        setState(() {
          _billData = res['data'];
        });
      }
    } catch (e) {
      if (mounted) {
        showDialogMsg(
          context,
          title: 'เกิดข้อผิดพลาด',
          subtitle: 'ไม่สามารถดึงข้อมูลค่าใช้จ่ายได้: $e',
          btnLeft: 'ตกลง',
          onConfirm: () => context.pop(),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // คำนวณยอดรวมทั้งหมด
  double get _netTotal {
    double baseTotal = 0;
    if (_billData != null && _billData['lineItems'] is List) {
      baseTotal = (_billData['lineItems'] as List)
          .fold(0.0, (sum, item) => sum + (item['amount'] ?? 0.0));
    }
    double customTotal =
        _customItems.fold(0.0, (sum, item) => sum + (item['amount'] ?? 0.0));
    double total = baseTotal + customTotal;
    return total < 0 ? 0 : total; // ป้องกันยอดติดลบ
  }

  Future<void> _handlePayment() async {
    if (_selectedPaymentMethod == null) {
      showDialogMsg(context,
          title: 'แจ้งเตือน',
          subtitle: 'กรุณาเลือกวิธีการชำระเงิน',
          btnLeft: 'ตกลง',
          onConfirm: () {});
      return;
    }

    setState(() => _isLoading = true);

    try {
      double totalAmount = _netTotal;

      // Call the new backend endpoint ก่อน เพื่อไปเอา String QR
      final response = await ApiProvider().post(
        '/player/gamesessions/${widget.code}/checkout-and-pay',
        data: {
          'paymentMethod': _selectedPaymentMethod,
          'amount': totalAmount,
          'customItems': _customItems
              .map((e) =>
                  {'description': e['description'], 'amount': e['amount']})
              .toList(),
        },
      );

      // ถ้าเลือก QR ให้ดึงข้อความมาเปิด Dialog
      if (_selectedPaymentMethod == 'QR Code' && response['data'] != null && response['data']['qrCode'] != null) {
        String qrString = response['data']['qrCode'];
        int billId = response['data']['billId'];
        final confirmed = await showQrPaymentDialog(
          context, 
          totalAmount, 
          qrData: qrString,
          sessionId: int.parse(widget.code),
          billId: billId,
        );
        
        if (confirmed != true) {
          setState(() => _isLoading = false);
          return; // ถ้ายกเลิก/กดปิดเอง ไม่ต้องโชว์ Success
        }
      }

      if (mounted) {
        // แจ้งเตือนและเปลี่ยนหน้าอัตโนมัติ ไม่ต้องรอให้ผู้ใช้กดปุ่ม
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ชำระเงินสำเร็จ! ขอบคุณที่ใช้บริการ'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        context.go('/'); // Go to home page after payment
      }
    } catch (e) {
      if (mounted) {
        showDialogMsg(
          context,
          title: 'ชำระเงินล้มเหลว',
          subtitle: e.toString().replaceFirst('Exception: ', ''),
          btnLeft: 'ตกลง',
          onConfirm: () {},
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddCustomItemDialog() {
    final descController = TextEditingController();
    final amountController = TextEditingController();
    bool isAddition = true; // true = เพิ่ม, false = ลด

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('เพิ่ม / ลด ค่าใช้จ่าย',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<bool>(
                          title: const Text('เพิ่ม (+)', style: TextStyle(color: Colors.red)),
                          value: true,
                          groupValue: isAddition,
                          onChanged: (val) =>
                              setDialogState(() => isAddition = val!),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<bool>(
                          title: const Text('ลด (-)', style: TextStyle(color: Colors.green)),
                          value: false,
                          groupValue: isAddition,
                          onChanged: (val) =>
                              setDialogState(() => isAddition = val!),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                        labelText: 'ชื่อรายการ (เช่น น้ำดื่ม, ส่วนลด)',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'จำนวนเงิน',
                        suffixText: 'บาท',
                        border: OutlineInputBorder()),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                  onPressed: () {
                    double? amount = double.tryParse(amountController.text);
                    if (amount != null && descController.text.isNotEmpty) {
                      setState(() {
                        _customItems.add({
                          'description': descController.text,
                          'amount': isAddition ? amount : -amount,
                        });
                      });
                      context.pop();
                    }
                  },
                  child: const Text('บันทึก', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      appBar: AppBarSubMain(title: 'ชำระเงิน', isBack: true),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: CustomElevatedButton(
          text: _selectedPaymentMethod == 'QR Code'
              ? 'แสดง QR Code'
              : 'ยืนยันการชำระเงิน',
          isLoading: _isLoading,
          onPressed: _handlePayment,
        ),
      ),
      body: Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFCBF5EA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _billData == null
                ? const Center(child: Text('ไม่พบข้อมูลค่าใช้จ่าย'))
                : ListView(
                    children: [
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('ค่าใช้จ่ายพื้นฐาน',
                                  style: TextStyle(
                                      fontSize: 18,
                                      color: Color(0xFF0E9D7A),
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              ...(_billData['lineItems'] as List).map((item) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(item['description'] ?? '-', style: const TextStyle(fontSize: 15)),
                              Text('${(num.tryParse('${item['amount'] ?? 0}') ?? 0).toStringAsFixed(0)} ฿', style: const TextStyle(fontSize: 15)),
                                    ],
                                  ),
                                );
                              }).toList(),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('รายการเพิ่มเติม',
                                      style: TextStyle(fontSize: 18, color: Colors.orange, fontWeight: FontWeight.bold)),
                                  TextButton.icon(
                                    onPressed: _showAddCustomItemDialog,
                                    icon: const Icon(Icons.add_circle_outline, size: 18),
                                    label: const Text('เพิ่ม/ลด'),
                                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                                  )
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (_customItems.isEmpty)
                                const Text('ไม่มีรายการเพิ่มเติม', style: TextStyle(color: Colors.grey)),
                              ..._customItems.asMap().entries.map((entry) {
                                int idx = entry.key;
                                var item = entry.value;
                                bool isPositive = item['amount'] >= 0;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(item['description'], style: const TextStyle(fontSize: 15)),
                                      ),
                                      Text(
                                '${isPositive ? '+' : ''}${(num.tryParse('${item['amount'] ?? 0}') ?? 0).toStringAsFixed(0)} ฿',
                                        style: TextStyle(
                                            fontSize: 15,
                                            color: isPositive ? Colors.red : Colors.green,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                                        onPressed: () {
                                          setState(() {
                                            _customItems.removeAt(idx);
                                          });
                                        },
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      )
                                    ],
                                  ),
                                );
                              }).toList(),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('ยอดรวมที่ต้องชำระ',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                  Text('${_netTotal.toStringAsFixed(0)} บาท',
                                      style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0E9D7A))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('เลือกวิธีการชำระเงิน',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      CustomDropdown(
                        labelText: '',
                        initialValue: _selectedPaymentMethod,
                        items: _paymentMethods,
                        onChanged: (value) {
                          setState(() {
                            _selectedPaymentMethod = value;
                          });
                        },
                      ),
                    ],
                  ),
      ),
    );
  }
}

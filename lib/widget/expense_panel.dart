import 'package:badminton/component/button.dart';
import 'package:badminton/component/dropdown.dart';
import 'package:badminton/component/text_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:badminton/component/qr_payment_dialog.dart';

// (สมมติว่า Custom Widgets ของคุณถูก import เข้ามา)
// import 'custom_dropdown.dart';
// import 'custom_text_form_field.dart';
// import 'custom_elevated_button.dart';

// --- Data Models & Enums (จากข้อ 1) ---
enum AdjustmentType { addition, subtraction }

class ExpenseAdjustment {
  final String name;
  final double amount;
  final AdjustmentType type;

  ExpenseAdjustment({
    required this.name,
    required this.amount,
    required this.type,
  });
}

class ExpensePanelWidget extends StatefulWidget {
  final dynamic billData;
  final dynamic onConfirmPayment; // รองรับ Function(String, List) และ Function(List)
  final double courtFee; // NEW: รับค่าสนามเริ่มต้น
  final double shuttlecockFee; // NEW: รับราคาลูกแบด
  final int totalGames; // NEW: รับจำนวนเกมที่เล่น
  final double serviceFee; // NEW: รับค่าบริการ
  final double paidAmount; // NEW: รับยอดที่จ่ายไปแล้ว
  final bool isHistoryMode; // NEW: แยกโหมดหน้าประวัติ vs หน้าคิดเงิน
  final bool isBuffet; // NEW: รับค่าบอกว่าคิดแบบเหมาจ่ายหรือไม่

  const ExpensePanelWidget({
    super.key,
    this.billData,
    this.onConfirmPayment,
    this.courtFee = 0.0,
    this.shuttlecockFee = 0.0,
    this.totalGames = 0,
    this.serviceFee = 0.0, // NEW
    this.paidAmount = 0.0,
    this.isHistoryMode = false, // ค่าเริ่มต้นคือหน้าคิดเงินปกติ
    this.isBuffet = false,
  });

  @override
  State<ExpensePanelWidget> createState() => _ExpensePanelWidgetState();
}

class _ExpensePanelWidgetState extends State<ExpensePanelWidget> {
  final List<ExpenseAdjustment> _adjustments = []; // List เก็บรายการที่เพิ่ม/ลด
  late TextEditingController _expenseNameController;
  late TextEditingController _expenseAmountController;
  final _formKey = GlobalKey<FormState>(); // Key สำหรับ validation

  String? _selectedPaymentMethod;
  
  List<dynamic> get _paymentMethods {
    return [
      {"code": 'QR Code', "value": 'QR Code'},
      {"code": 'Cash', "value": 'เงินสด'},
      {"code": 'ยังไม่จ่าย', "value": 'บันทึกค้างชำระ (ส่งบิลให้ผู้เล่น)'},
    ];
  }

  @override
  void initState() {
    _expenseNameController = TextEditingController();
    _expenseAmountController = TextEditingController();
    _initData();
    super.initState();
  }

  @override
  void dispose() {
    _expenseNameController.dispose();
    _expenseAmountController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ExpensePanelWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.billData != widget.billData) {
      _initData();
    }
  }

  void _initData() {
    _adjustments.clear();

    if (widget.billData != null && widget.billData['lineItems'] != null) {
      final items = widget.billData['lineItems'] as List;
      for (var item in items) {
        final desc = item['description'] ?? '';
        // FIX: กรองค่าธรรมเนียมและค่าลูกแบดรูปแบบต่างๆ ออกจากรายการปรับปรุง (Adjustments)
        // เพื่อไม่ให้แสดงซ้ำซ้อนในรายการที่แก้ไขได้
        if (desc != 'ค่าคอร์ท' && desc != 'ค่าสนาม' && desc != 'ค่าธรรมเนียม' && !desc.startsWith('ค่าลูกแบด')) {
          final amount = (item['amount'] ?? 0.0).toDouble();
          _adjustments.add(ExpenseAdjustment(
            name: desc,
            amount: amount.abs(),
            type: amount >= 0 ? AdjustmentType.addition : AdjustmentType.subtraction,
          ));
        }
      }
    }
    setState(() {});
  }

  // --- ฟังก์ชันสำหรับเพิ่ม/ลดรายการ ---
  void _addAdjustment(AdjustmentType type) {
    // ตรวจสอบว่าข้อมูลในฟอร์มถูกต้องหรือไม่
    if (_formKey.currentState!.validate()) {
      final String name = _expenseNameController.text;
      final double? amount = double.tryParse(_expenseAmountController.text);
      if (amount != null) {
        setState(() {
          _adjustments.add(
            ExpenseAdjustment(name: name, amount: amount, type: type),
          );
          // เคลียร์ค่าในช่องกรอก
          _expenseNameController.clear();
          _expenseAmountController.clear();
          // ซ่อนคีย์บอร์ด
          FocusScope.of(context).unfocus();
        });
      }
    }
  }

  // --- ฟังก์ชันสำหรับลบรายการออกจาก List ---
  void _deleteAdjustment(int index) {
    setState(() {
      _adjustments.removeAt(index);
    });
  }

  // --- คำนวณยอดรวมใหม่ ---
  double get _apiCourtFee {
    // ถ้ามีข้อมูล billData จาก API ให้ยึดตามนั้นเป็นหลัก
    if (widget.billData != null && widget.billData['lineItems'] != null) {
      final items = widget.billData['lineItems'] as List;
      final item = items.firstWhere((i) => i['description'] == 'ค่าคอร์ท' || i['description'] == 'ค่าสนาม', orElse: () => null);
      // ถ้าไม่เจอใน lineItems แสดงว่าจ่ายไปแล้ว ให้เป็น 0
      return item != null ? (item['amount'] ?? 0.0).toDouble() : 0.0;
    }
    // ถ้าไม่มีข้อมูล billData (เช่น API error) ให้ใช้ค่าเริ่มต้นที่ส่งมา
    return widget.courtFee;
  }

  // --- NEW: ดึงค่าธรรมเนียมจาก API ---
  double get _apiServiceFee {
    // ถ้ามีข้อมูล billData จาก API ให้ยึดตามนั้นเป็นหลัก
    if (widget.billData != null && widget.billData['lineItems'] != null) {
      final items = widget.billData['lineItems'] as List;
      final item = items.firstWhere((i) => i['description'] == 'ค่าธรรมเนียม', orElse: () => null);
      // ถ้าไม่เจอ 'ค่าธรรมเนียม' ใน lineItems แสดงว่าจ่ายไปแล้ว ให้เป็น 0
      return item != null ? (item['amount'] ?? 0.0).toDouble() : 0.0;
    }
    // ถ้าไม่มีข้อมูล billData ให้ใช้ค่าเริ่มต้นที่ส่งมา
    return widget.serviceFee;
  }

  double get _apiShuttleFee {
    if (widget.billData == null || widget.billData['lineItems'] == null) return 0.0;
    final items = widget.billData['lineItems'] as List;
    final item = items.firstWhere(
      // FIX: ใช้ startsWith เพราะ Server อาจส่งมาว่า "ค่าลูกแบด (4 เกม)" หรือ "ค่าลูกแบด (เหมาจ่าย)"
      (i) => (i['description'] ?? '').toString().startsWith('ค่าลูกแบด'),
      orElse: () => null,
    );
    return item != null ? (item['amount'] ?? 0.0).toDouble() : 0.0;
  }

  // --- NEW: Helper properties แยกการแสดงผลตามโหมด ---
  double get _displayCourtFee => widget.isHistoryMode ? widget.courtFee : _apiCourtFee;
  double get _displayServiceFee => widget.isHistoryMode ? widget.serviceFee : _apiServiceFee;
  
  // เชื่อถือยอดค่าลูกแบดจาก API (Backend) 100% หน้าบ้านไม่ต้องคำนวณเอง
  // ยกเว้นโหมดประวัติ ที่บิลพรีวิวอาจเหลือยอดเป็น 0 (เพราะจ่ายไปแล้ว) จึงต้องใช้ยอดเต็มมาแสดง
  double get _displayShuttleFee {
    if (widget.isHistoryMode) {
      return widget.isBuffet ? widget.shuttlecockFee : widget.totalGames * widget.shuttlecockFee;
    }
    // ถ้ามีข้อมูลบิลจาก API ให้ใช้ยอดจาก API
    if (widget.billData != null && widget.billData['lineItems'] != null && 
        (widget.billData['lineItems'] as List).any((i) => (i['description'] ?? '').toString().startsWith('ค่าลูกแบด'))) {
      return _apiShuttleFee;
    }
    // Fallback: ถ้า API โหลดบิลพรีวิวไม่สำเร็จ หรือยังไม่มีข้อมูล ให้แสดงผลจากการคำนวณหน้าบ้าน
    return widget.isBuffet ? widget.shuttlecockFee : widget.totalGames * widget.shuttlecockFee;
  }

  // ดึงชื่อรายการ (Description) จาก API มาแสดงเลย เพื่อให้ตรงกับ Database 100%
  String get _displayShuttleFeeDescription {
    if (!widget.isHistoryMode && widget.billData != null && widget.billData['lineItems'] != null) {
      final items = widget.billData['lineItems'] as List;
      final item = items.firstWhere(
        (i) => (i['description'] ?? '').toString().startsWith('ค่าลูกแบด'),
        orElse: () => null,
      );
      if (item != null) {
        return item['description'].toString();
      }
    }
    return widget.isBuffet ? 'ค่าลูกแบด (เหมาจ่าย)' : 'ค่าลูกแบด (${widget.totalGames} เกม)';
  }

  double get _totalShuttlecockFee {
    // ดึงค่าเริ่มต้นมาจาก API
    double total = _displayShuttleFee;

    for (var adj in _adjustments) {
      if (adj.type == AdjustmentType.addition) {
        total += adj.amount;
      } else {
        total -= adj.amount;
      }
    }
    return total;
  }

  // --- 3. MAIN BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    // ใช้ ListView เพื่อให้เนื้อหาทั้งหมดสามารถ scroll ได้หากหน้าจอมีขนาดเล็ก
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildCourtFeeSection(),
        const SizedBox(height: 16),
        _buildShuttlecockFeeSection(),
      ],
    );
  }

  // --- 4. UI BUILDERS (ฟังก์ชันย่อยสำหรับสร้าง UI) ---
  // Widget สำหรับสรุปค่าสนาม
  Widget _buildCourtFeeSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              _buildInfoRow(
                'ค่าสนาม${(!widget.isHistoryMode && _apiCourtFee <= 0) ? ' (ชำระแล้ว)' : ''}', 
                '${_displayCourtFee.toStringAsFixed(0)} บาท',
                color: (!widget.isHistoryMode && _apiCourtFee <= 0) ? Colors.grey : null,
              ),
              _buildInfoRow(
                'ค่าธรรมเนียม${(!widget.isHistoryMode && _apiServiceFee <= 0) ? ' (ชำระแล้ว)' : ''}', 
                '${_displayServiceFee.toStringAsFixed(0)} บาท',
                color: (!widget.isHistoryMode && _apiServiceFee <= 0) ? Colors.grey : null,
              ),
              _buildInfoRow(
                'ราคารวม', 
                '${(_displayCourtFee + _displayServiceFee).toStringAsFixed(0)} บาท', 
                isBold: true,
              ),
            const SizedBox(height: 16),
            const Text(
              'ชำระผ่าน',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 8,
                  backgroundColor: Colors.green,
                  child: Text(
                    'K+',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  '236 - **** - **** - 0',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
                ),
                Spacer(),
                Text(
                  '16/05/25 14:43 น.',
                  style: TextStyle(
                    color: Color(0xFF64646D),
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Widget สำหรับสรุปค่าลูกแบดและฟอร์ม
  Widget _buildShuttlecockFeeSection() {
    double grandTotal = _displayCourtFee + _displayServiceFee + _totalShuttlecockFee;
    double due = grandTotal - widget.paidAmount;
    bool isFullyPaid = due <= 0; // ตรวจสอบว่าจ่ายครบแล้วหรือยัง

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // แสดงรายการและยอดค่าลูกแบดที่ได้จาก API
            _buildInfoRow(
              _displayShuttleFeeDescription,
              '${_displayShuttleFee.toStringAsFixed(0)} บาท'
            ),
              ..._adjustments.asMap().entries.map((entry) {
                ExpenseAdjustment adj = entry.value;
                bool isAddition = adj.type == AdjustmentType.addition;
                return _buildInfoRowExpenses(
                  adj.name,
                  '${isAddition ? '+' : '-'}${adj.amount.toStringAsFixed(0)} บาท',
                  color: isAddition ? Colors.green : Colors.red,
                  idx: entry.key,
                  isReadOnly: isFullyPaid, // NEW: ส่งสถานะไปเพื่อซ่อนปุ่มลบ
                );
              }),
              
              _buildInfoRow(
                'รวมค่าใช้จ่ายส่วนตัว',
                '${_totalShuttlecockFee.toStringAsFixed(0)} บาท',
                isBold: true,
              ),
              const Divider(height: 24),
              _buildGrandTotalSection(),

              // --- FIX: ถ้าจ่ายครบแล้ว ให้ซ่อนส่วนฟอร์มและการชำระเงิน ---
              if (!isFullyPaid) ...[
              const SizedBox(height: 16),
              // --- ฟอร์มสำหรับกรอกข้อมูล ---
              CustomTextFormField(
                controller: _expenseNameController,
                labelText: 'ชื่อค่าใช้จ่าย',
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'กรุณาระบุชื่อ' : null,
              ),
              const SizedBox(height: 12),
              CustomTextFormField(
                controller: _expenseAmountController,
                labelText: 'จำนวนเงิน',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) => (value == null || value.isEmpty)
                    ? 'กรุณาระบุจำนวนเงิน'
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CustomElevatedButton(
                      text: 'เพิ่มค่าใช้จ่าย',
                      backgroundColor: Color(0xFFFFFFFF),
                      foregroundColor: Color(0xFF0E9D7A),
                      fontSize: 12,
                      padding: EdgeInsetsGeometry.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      onPressed: () => _addAdjustment(AdjustmentType.addition),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomElevatedButton(
                      text: 'ลดค่าใช้จ่าย',
                      backgroundColor: Color(0xFFFFFFFF),
                      foregroundColor: Color(0xFF0E9D7A),
                      fontSize: 12,
                      padding: EdgeInsetsGeometry.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      onPressed: () =>
                          _addAdjustment(AdjustmentType.subtraction),
                    ),
                  ),
                ],
              ),
              if (widget.onConfirmPayment != null) ...[
                const SizedBox(height: 24),
                const Text(
                  'วิธีการชำระเงิน',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                // --- ช่องทางชำระเงิน ---
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
                const SizedBox(height: 12),
              ],

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: CustomElevatedButton(
                  text: _selectedPaymentMethod == 'QR Code' ? 'แสดง QR Code' : (_selectedPaymentMethod == 'ยังไม่จ่าย' ? 'บันทึกค้างชำระ' : (widget.isHistoryMode ? 'ชำระเงิน' : 'ชำระเงินและจบเกม')),
                  onPressed: () async {
                    if (widget.onConfirmPayment != null) {
                      if (_selectedPaymentMethod == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('กรุณาเลือกวิธีการชำระเงิน')),
                        );
                        return;
                      }

                      // คำนวณยอดที่ต้องชำระ (เพื่อส่งไปแสดงบน QR)
                      double grandTotal = _displayCourtFee + _displayServiceFee + _totalShuttlecockFee;
                      double due = grandTotal - widget.paidAmount;
                      
                      try {
                        widget.onConfirmPayment(_selectedPaymentMethod, _adjustments);
                      } catch (e) {
                        // ถ้าฟังก์ชันปลายทางรับแค่ 1 parameter (List) ระบบจะ Fallback มาเรียกแบบนี้
                        widget.onConfirmPayment(_adjustments);
                      }
                    }
                  },
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(12),
                ),
              ),
              ], // End if (!isFullyPaid)
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrandTotalSection() {
      double grandTotal = _displayCourtFee + _displayServiceFee + _totalShuttlecockFee;
      double paid = widget.paidAmount;
      double due = grandTotal - paid;
      
      if (paid <= 0) {
         // เปลี่ยนเป็นสีแดงและข้อความ "ยอดที่ต้องชำระ" เพื่อให้ชัดเจนว่ายังค้างจ่าย
         return _buildInfoRow('ยอดที่ต้องชำระ', '${grandTotal.toStringAsFixed(0)} บาท', fontSize: 20, isBold: true, color: Colors.red);
      }

      return Column(
          children: [
              _buildInfoRow('ยอดสุทธิทั้งหมด', '${grandTotal.toStringAsFixed(0)} บาท', fontSize: 16),
              _buildInfoRow('จ่ายแล้ว', '${paid.toStringAsFixed(0)} บาท', fontSize: 16, color: Colors.green),
              
              // แสดงเฉพาะเมื่อมียอดส่วนต่าง (ไม่เท่ากับ 0)
              if (due.abs() >= 1) ...[
                const SizedBox(height: 4),
                _buildInfoRow(
                    due > 0 ? 'ต้องจ่ายเพิ่ม' : 'ต้องคืนเงิน', 
                    '${due.abs().toStringAsFixed(0)} บาท', 
                    fontSize: 22, 
                    isBold: true, 
                    color: due > 0 ? Colors.red : Colors.blue
                ),
              ] else ...[
                 // กรณีจ่ายครบแล้ว (0 บาท) แสดงสถานะว่าครบถ้วน
                 const SizedBox(height: 4),
                 _buildInfoRow('สถานะ', 'ชำระครบถ้วน', fontSize: 18, isBold: true, color: Colors.green),
              ]
          ],
      );
  }

  // Helper สำหรับสร้างแถวข้อมูล
  Widget _buildInfoRow(
    String title,
    String value, {
    double fontSize = 20,
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRowExpenses(
    String title,
    String value, {
    double fontSize = 20,
    bool isBold = false,
    Color? color,
    int idx = 0,
    bool isReadOnly = false, // NEW
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            // --- FIX: ซ่อนปุ่มลบถ้าอยู่ในโหมด Read-only ---
            if (!isReadOnly)
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: Colors.red),
                onPressed: () => _deleteAdjustment(idx),
              ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }
}

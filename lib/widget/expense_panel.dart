import 'package:badminton/component/button.dart';
import 'package:badminton/component/dropdown.dart';
import 'package:badminton/component/text_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  const ExpensePanelWidget({super.key});

  @override
  State<ExpensePanelWidget> createState() => _ExpensePanelWidgetState();
}

class _ExpensePanelWidgetState extends State<ExpensePanelWidget> {
  final List<ExpenseAdjustment> _adjustments = []; // List เก็บรายการที่เพิ่ม/ลด
  late TextEditingController _expenseNameController;
  late TextEditingController _expenseAmountController;
  final _formKey = GlobalKey<FormState>(); // Key สำหรับ validation

  String? _selectedPaymentMethod;
  final List<String> _paymentMethods = ['QR Code', 'เงินสด'];

  @override
  void initState() {
    _expenseNameController = TextEditingController();
    _expenseAmountController = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    _expenseNameController.dispose();
    _expenseAmountController.dispose();
    super.dispose();
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
  double get _totalShuttlecockFee {
    double total = 20.0; // ค่าลูกตั้งต้น
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
            _buildInfoRow('ค่าสนาม', '120 บาท'),
            _buildInfoRow('ค่าธรรมเนียม', '10 บาท'),
            _buildInfoRow('ราคารวม', '130 บาท', isBold: true),
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
              _buildInfoRow('ค่าลูก', '20 บาท'),
              ..._adjustments.asMap().entries.map((entry) {
                ExpenseAdjustment adj = entry.value;
                bool isAddition = adj.type == AdjustmentType.addition;
                return _buildInfoRowExpenses(
                  adj.name,
                  '${adj.amount.toStringAsFixed(0)} บาท',
                  color: isAddition ? Colors.green : Colors.red,
                  idx: entry.key,
                );
              }),

              _buildInfoRow(
                'ราคารวม',
                '${_totalShuttlecockFee.toStringAsFixed(0)} บาท',
                isBold: true,
              ),
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
                    if (value == 'QR Code') {
                      // _startTimer();
                    }
                  });
                },
              ),
              const SizedBox(height: 12),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: CustomElevatedButton(
                  text: _selectedPaymentMethod == 'QR Code'
                      ? 'แสดง QR Code'
                      : 'จ่ายเงินสด',
                  onPressed: () {},
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: EdgeInsetsGeometry.all(12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper สำหรับสร้างแถวข้อมูล
  Widget _buildInfoRow(
    String title,
    String value, {
    double fontSize = 20,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
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

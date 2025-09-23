import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/dropdown.dart';
import 'package:badminton/component/text_box.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AddGamePage extends StatefulWidget {
  final String code;
  const AddGamePage({super.key, required this.code});

  @override
  AddGamePageState createState() => AddGamePageState();
}

class AddGamePageState extends State<AddGamePage> {
  // --- ประกาศ Controllers ทั้งหมด ---
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _teamNameController;
  late final TextEditingController _dateController;
  late final TextEditingController _startTimeController;
  late final TextEditingController _endTimeController;
  late final TextEditingController _slotsController;
  late final TextEditingController _shuttlePriceController;
  late final TextEditingController _shuttleCostController;
  late final TextEditingController _courtPriceController;
  late final TextEditingController _courtTotalCostController;
  late final TextEditingController _openCourtsController;
  late final TextEditingController _notesController;

  // --- ตัวแปรสำหรับจัดการ State อื่นๆ ---
  String? _selectedCourt;
  String? _selectedGameType;
  String? _selectedQueueType;
  String? _selectedShuttleBrand;
  String? _selectedShuttleModel;
  int? _shuttleChargeMethod = 1; // 1 = เก็บเพิ่ม, 2 = บุฟเฟ่ต์
  final List<TextEditingController> _courtNumberControllers = [];

  final Map<String, bool> _facilities = {
    'ไฟสนามด้านบน': false,
    'ไฟสนามด้านข้าง': false,
    'ห้องอาบน้ำ': false,
    'ห้องรับรอง': false,
    'เช่ารองเท้า': false,
    'เช่าไม้แบด': false,
    'สนามติดแอร์': false,
    'Wifi': false,
  };

  @override
  void initState() {
    _teamNameController = TextEditingController();
    _dateController = TextEditingController();
    _startTimeController = TextEditingController();
    _endTimeController = TextEditingController();
    _slotsController = TextEditingController();
    _shuttlePriceController = TextEditingController();
    _shuttleCostController = TextEditingController();
    _courtPriceController = TextEditingController();
    _courtTotalCostController = TextEditingController();
    _openCourtsController = TextEditingController();
    _notesController = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    // --- Dispose Controllers ทั้งหมด ---
    _teamNameController.dispose();
    _dateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _slotsController.dispose();
    _shuttlePriceController.dispose();
    _shuttleCostController.dispose();
    _courtPriceController.dispose();
    _courtTotalCostController.dispose();
    _openCourtsController.dispose();
    _notesController.dispose();
    for (final controller in _courtNumberControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updateCourtFields(String value) {
    // แปลง String ที่รับเข้ามาเป็น int (ถ้าแปลงไม่ได้ให้เป็น 0)
    final int count = int.tryParse(value) ?? 0;

    // ถ้าจำนวนเท่าเดิม ไม่ต้องทำอะไร
    if (count == _courtNumberControllers.length) return;

    setState(() {
      // กรณีที่จำนวนที่กรอก > จำนวนช่องปัจจุบัน -> ให้สร้างเพิ่ม
      while (_courtNumberControllers.length < count) {
        _courtNumberControllers.add(TextEditingController());
      }
      // กรณีที่จำนวนที่กรอก < จำนวนช่องปัจจุบัน -> ให้ลบออก
      while (_courtNumberControllers.length > count) {
        // .removeLast() คือการลบตัวสุดท้ายออกจาก List
        // และต้อง .dispose() controller ที่ลบออกไปด้วย
        _courtNumberControllers.removeLast().dispose();
      }
    });
  }

  // ---  สร้างฟังก์ชันสำหรับเลือกวัน ---
  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(), // วันที่แรกที่เลือกได้คือวันนี้
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      // จัดรูปแบบวันที่แล้วนำไปใส่ใน Controller
      final String formattedDate = DateFormat('dd/MM/yyyy').format(picked);
      setState(() {
        controller.text = formattedDate;
      });
    }
  }

  // ---  สร้างฟังก์ชันสำหรับเลือกเวลา ---
  Future<void> _selectTime(TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      // จัดรูปแบบเวลาแล้วนำไปใส่ใน Controller
      final String formattedTime = picked.format(context);
      setState(() {
        controller.text = formattedTime;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      appBar: AppBarSubMain(title: 'New Game', isBack: false),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFD5DCF4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    spreadRadius: 2,
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 600) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildLeftColumn(context)),
                          const SizedBox(width: 24),
                          Expanded(child: _buildRightColumn(context)),
                        ],
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLeftColumn(context),
                          const SizedBox(height: 24), // เพิ่มระยะห่างแนวตั้ง
                          _buildRightColumn(context),
                        ],
                      );
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Widget สำหรับคอลัมน์ด้านซ้าย ---
  Widget _buildLeftColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('เพิ่มได้สูงสุด 5 รูป'),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: 5,
          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.add, color: Colors.grey[600]),
            );
          },
        ),
        const SizedBox(height: 16),
        CustomTextFormField(
          labelText: 'ชื่อทีม',
          controller: _teamNameController,
        ),
        const SizedBox(height: 16),
        CustomDropdown(
          labelText: 'สนาม',
          initialValue: _selectedCourt,
          items: const ['สนาม A', 'สนาม B', 'สนาม C'],
          onChanged: (value) => setState(() => _selectedCourt = value),
        ),
        const SizedBox(height: 16),
        CustomTextFormField(
          labelText: 'วัน',
          controller: _dateController,
          suffixIconData: Icons.calendar_today,
          readOnly: true,
          onSuffixIconPressed: () => _selectDate(_dateController),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CustomTextFormField(
                labelText: 'เวลาเริ่มต้น',
                controller: _startTimeController,
                suffixIconData: Icons.access_time,
                readOnly: true, // <<< สำคัญมาก
                onSuffixIconPressed: () =>
                    _selectTime(_startTimeController), // <<< เรียกใช้ฟังก์ชัน
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomTextFormField(
                labelText: 'เวลาสิ้นสุด',
                controller: _endTimeController,
                suffixIconData: Icons.access_time,
                readOnly: true, // <<< สำคัญมาก
                onSuffixIconPressed: () =>
                    _selectTime(_endTimeController), // <<< เรียกใช้ฟังก์ชัน
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CustomDropdown(
          labelText: 'เล่นเกมละ/เซต',
          initialValue: _selectedGameType,
          items: const ['21 แต้ม', '15 แต้ม'],
          onChanged: (value) => setState(() => _selectedGameType = value),
        ),
        const SizedBox(height: 16),
        CustomTextFormField(
          labelText: 'จำนวนที่เปิดรับจอง',
          controller: _slotsController,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        CustomDropdown(
          labelText: 'วิธีจัดคิว',
          initialValue: _selectedQueueType,
          items: const ['จับคู่แบบสุ่ม', 'เรียงตามลำดับ'],
          onChanged: (value) => setState(() => _selectedQueueType = value),
        ),
        const SizedBox(height: 16),
        Text(
          'สิ่งอำนวยความสะดวก',
          style: TextStyle(
            fontSize: getResponsiveFontSize(context, fontSize: 12),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          children: _facilities.keys.map((String key) {
            return SizedBox(
              width: 180, // กำหนดความกว้างเพื่อให้จัดเรียงสวยงาม
              child: CheckboxListTile(
                title: Text(key),
                value: _facilities[key],
                onChanged: (bool? value) =>
                    setState(() => _facilities[key] = value!),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- Widget สำหรับคอลัมน์ด้านขวา ---
  Widget _buildRightColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'การคิดเงินลูกแบด',
          style: TextStyle(
            fontSize: getResponsiveFontSize(context, fontSize: 16),
            fontWeight: FontWeight.w400,
          ),
        ),
        RadioGroup<int>(
          groupValue: _shuttleChargeMethod,
          onChanged: (value) {
            setState(() {
              _shuttleChargeMethod = value;
            });
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: RadioListTile<int>(
                  title: Text(
                    'เก็บเพิ่มจำนวนลูก',
                    style: TextStyle(
                      fontSize: getResponsiveFontSize(context, fontSize: 12),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  value: 1,
                ),
              ),
              Expanded(
                child: RadioListTile<int>(
                  title: Text(
                    'เก็บตามรอบ',
                    style: TextStyle(
                      fontSize: getResponsiveFontSize(context, fontSize: 12),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  value: 2,
                ),
              ),
            ],
          ),
        ),

        Row(
          children: [
            Expanded(
              child: CustomTextFormField(
                labelText: 'ราคาค่าลูก/คน',
                controller: _shuttlePriceController,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomTextFormField(
                labelText: 'ต้นทุนลูกแบด/คน',
                controller: _shuttleCostController,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CustomDropdown(
                labelText: 'ลูกแบดที่ใช้ยี่ห้อ',
                initialValue: _selectedShuttleBrand,
                items: const ['Lining', 'Yonex', 'Victor'],
                onChanged: (v) => setState(() => _selectedShuttleBrand = v),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomDropdown(
                labelText: 'รุ่น',
                initialValue: _selectedShuttleModel,
                items: const ['A+100', 'AS-50', 'Master No.1'],
                onChanged: (v) => setState(() => _selectedShuttleModel = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CustomTextFormField(
                labelText: 'ราคาค่าสนาม/คน',
                controller: _courtPriceController,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomTextFormField(
                labelText: 'ต้นทุนสนามทั้งหมด',
                controller: _courtTotalCostController,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CustomTextFormField(
          labelText: 'จำนวนสนามที่เปิด',
          controller: _openCourtsController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ], // บังคับให้กรอกแต่ตัวเลข
          onChanged: _updateCourtFields,
        ),
        const SizedBox(height: 16),
        Wrap(
          // กำหนดระยะห่างในแนวนอนระหว่างแต่ละช่อง
          spacing: 11.0,
          // กำหนดระยะห่างในแนวตั้งระหว่างบรรทัด
          runSpacing: 12.0,
          // สร้าง List ของ Widget จาก controllers ที่มี
          children: _courtNumberControllers.asMap().entries.map((entry) {
            int index = entry.key;
            TextEditingController controller = entry.value;

            // ใช้ SizedBox เพื่อกำหนดความกว้างของ TextFormField
            return SizedBox(
              width: 100,
              child: CustomTextFormField(
                labelText: 'สนามที่ ${index + 1}',
                controller: controller,
                // คุณสามารถเพิ่ม validator หรืออื่นๆ ได้ตามต้องการ
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Text(
          'รายละเอียดเพิ่มเติม',
          style: TextStyle(
            fontSize: getResponsiveFontSize(context, fontSize: 12),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        CustomTextFormField(
          labelText: '',
          controller: _notesController,
          minLines: 6,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              showDialogMsg(
                context,
                title: 'สร้างก๊วนใหม่เรียบร้อย',
                subtitle: 'ยืนยันการสร้าง ก๊วนแมวเหมียว',
                btnLeft: 'ไปหน้าข้อมูลก๊วน',
                onConfirm: () {},
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create Game'),
          ),
        ),
      ],
    );
  }
}

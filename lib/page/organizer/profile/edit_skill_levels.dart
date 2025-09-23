import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/button.dart';
import 'package:badminton/component/dropdown.dart';
import 'package:badminton/component/text_box.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; // <<< 1. Import แพ็กเกจ

// Model สำหรับเก็บข้อมูลของแต่ละระดับฝีมือ
class SkillLevel {
  final TextEditingController nameController;
  Color selectedColor;

  SkillLevel({required String name, this.selectedColor = Colors.white})
    : nameController = TextEditingController(text: name);

  // ฟังก์ชันสำหรับ dispose controller เมื่อไม่ใช้งานแล้ว
  void dispose() {
    nameController.dispose();
  }
}

class EditSkillLevelsPage extends StatefulWidget {
  const EditSkillLevelsPage({super.key});

  @override
  State<EditSkillLevelsPage> createState() => _EditSkillLevelsPageState();
}

class _EditSkillLevelsPageState extends State<EditSkillLevelsPage> {
  String _numberOfLevels = '6'; // ค่าเริ่มต้น

  // List สำหรับเก็บข้อมูล SkillLevel ทั้งหมด
  List<SkillLevel> _skillLevels = [];

  @override
  void initState() {
    super.initState();
    _generateSkillLevels(int.parse(_numberOfLevels));
  }

  // ฟังก์ชันสำหรับสร้าง/อัปเดต List ของ SkillLevel
  void _generateSkillLevels(int count) {
    if (_skillLevels.isNotEmpty) {
      for (var level in _skillLevels) {
        level.dispose();
      }
    }
    _skillLevels = List.generate(
      count,
      (index) => SkillLevel(
        name: index == 0 ? 'มือใหม่' : 'ระดับ ${index + 1}',
        // กำหนดสีเริ่มต้นแบบสุ่มหรือแบบไล่สีก็ได้
        selectedColor: HSLColor.fromAHSL(
          1.0,
          (360 / 10) * index,
          0.8,
          0.6,
        ).toColor(),
      ),
    );
  }

  void _showColorPickerDialog(SkillLevel level) {
    Color pickerColor = level.selectedColor; // สีเริ่มต้นใน picker

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('เลือกสี'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (Color color) {
                pickerColor = color; // อัปเดตสีชั่วคราวเมื่อผู้ใช้เลื่อน
              },
              pickerAreaHeightPercent: 0.8,
              enableAlpha: false, // ปิดตัวเลือกความโปร่งใส
              displayThumbColor: true,
              paletteType: PaletteType.hsv,
              pickerAreaBorderRadius: const BorderRadius.all(
                Radius.circular(8.0),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('ยกเลิก'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('ยืนยัน'),
              onPressed: () {
                setState(() {
                  level.selectedColor =
                      pickerColor; // อัปเดตสีจริงเมื่อกดยืนยัน
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    // Dispose controller ทั้งหมดเมื่อปิดหน้า
    for (var level in _skillLevels) {
      level.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false,
      backgroundColor: Colors.transparent,
      appBar: AppBarSubMain(title: 'แก้ไขเกณฑ์ระดับมือ'),
      bottomNavigationBar: Container(
        color: Color(0xFFD5DCF4),
        padding: EdgeInsets.all(15),
        child: CustomElevatedButton(
          text: 'บันทึกข้อมูลเรียบร้อย',
          onPressed: () {},
        ),
      ),
      body: Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFD5DCF4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          children: [
            Text(
              'แก้ไขระดับทักษะฝีมือ',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 16),
              ),
            ),
            const SizedBox(height: 8),
            // --- Dropdown สำหรับเลือกจำนวนระดับ ---
            CustomDropdown(
              labelText: '',
              initialValue: _numberOfLevels,
              items: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10'],
              onChanged: (value) {
                setState(() {
                  _numberOfLevels = value ?? '0';
                  _generateSkillLevels(int.parse(value ?? ''));
                });
              },
            ),
            const SizedBox(height: 24),
            // --- ส่วนหัวของตาราง ---
            Row(
              children: const [
                Expanded(
                  flex: 2,
                  child: Text(
                    'ความเก่ง',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'ชื่อ',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'สี',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // --- ListView สำหรับสร้างรายการแก้ไขระดับ ---
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _skillLevels.length,
              itemBuilder: (context, index) {
                final level = _skillLevels[index];
                final levelName = index == 0
                    ? 'น้อยสุด'
                    : (index == _skillLevels.length - 1
                          ? 'มากสุด'
                          : '${index + 1}');

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          levelName,
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: CustomTextFormField(
                          labelText: '',
                          hintText: '',
                          controller: level.nameController,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 3,
                        child: GestureDetector(
                          onTap: () => _showColorPickerDialog(level),
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: level.selectedColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Center(
                              child: Text(
                                // แปลงรหัสสีเป็น Hex code เพื่อแสดงผล
                                '#${level.selectedColor.value.toRadixString(16).substring(2).toUpperCase()}',
                                style: TextStyle(
                                  color:
                                      level.selectedColor.computeLuminance() >
                                          0.5
                                      ? Colors.black
                                      : Colors.white,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

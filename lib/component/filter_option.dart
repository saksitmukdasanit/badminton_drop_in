import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';

// --- Model สำหรับเก็บค่า Checkbox ---
class FilterOption {
  final String title;
  bool value;

  FilterOption({required this.title, this.value = false});
}

// --- Widget สำหรับแสดง Filter Bottom Sheet ---
class FilterBottomSheet extends StatefulWidget {
  FilterBottomSheet({super.key});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  // --- สร้าง List ของข้อมูล Filter ---
  final Map<String, List<FilterOption>> _filterGroups = {
    'สิ่งอำนวยความสะดวก': [
      FilterOption(title: 'ไฟสนามด้านข้าง'),
      FilterOption(title: 'ไฟสนามด้านบน'),
      FilterOption(title: 'ห้องอาบน้ำ'),
      FilterOption(title: 'ห้องรับรอง'),
      FilterOption(title: 'เช่ารองเท้า'),
      FilterOption(title: 'เช่าไม้แบด'),
      FilterOption(title: 'สนามติดแอร์'),
      FilterOption(title: 'Wifi'),
    ],
    'วันที่จัด': [
      FilterOption(title: 'จันทร์'),
      FilterOption(title: 'อังคาร'),
      FilterOption(title: 'พุธ'),
      FilterOption(title: 'พฤหัสบดี'),
      FilterOption(title: 'ศุกร์'),
      FilterOption(title: 'เสาร์'),
      FilterOption(title: 'อาทิตย์'),
    ],
    'ลูกแบด': [
      FilterOption(title: 'บุฟเฟ่ต์'),
      FilterOption(title: 'ราคาต่อลูก'),
    ],
    'แบรนด์ลูกแบด': [
      FilterOption(title: 'Yonex'),
      FilterOption(title: 'Willson'),
      FilterOption(title: 'Victor'),
      FilterOption(title: 'S Sport'),
      FilterOption(title: 'Magnum'),
      FilterOption(title: 'Pro Touch'),
    ],
    'Walk-In': [FilterOption(title: 'รับ'), FilterOption(title: 'ไม่รับ')],
  };

  void _clearFilters() {
    setState(() {
      _filterGroups.forEach((key, value) {
        for (var option in value) {
          option.value = false;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // กำหนดความสูงให้เกือบเต็มจอ
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          // --- เนื้อหา Filter ที่สามารถ Scroll ได้ ---
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _buildFilterGroup(context, 'สิ่งอำนวยความสะดวก'),
                      ),
                      Expanded(child: _buildFilterGroup(context, 'วันที่จัด')),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _buildFilterGroup(context, 'ลูกแบด'),
                            SizedBox(height: 16),
                            _buildFilterGroup(context, 'Walk-In'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _buildFilterGroup(context, 'แบรนด์ลูกแบด'),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                ],
              ),
            ),
          ),
          // --- Footer ที่มีปุ่ม ---
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _clearFilters,
                    child: Text(
                      'CLEAR FILTER',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final Map<String, List<String>> appliedFilters = {};
                      _filterGroups.forEach((groupTitle, options) {
                        final selectedOptions = options
                            .where(
                              (option) => option.value,
                            ) // หาเฉพาะอันที่ถูกติ๊ก (value == true)
                            .map((option) => option.title) // เอาเฉพาะชื่อ
                            .toList();

                        if (selectedOptions.isNotEmpty) {
                          appliedFilters[groupTitle] = selectedOptions;
                        }
                      });

                      // 2. ส่งข้อมูลกลับไปพร้อมกับการปิด Bottom Sheet
                      Navigator.of(context).pop(appliedFilters);
                    },
                    child: Text('APPLY FILTER'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget สำหรับสร้างกลุ่มของ Checkbox
  Widget _buildFilterGroup(BuildContext context, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: getResponsiveFontSize(context, fontSize: 16),
          ),
        ),
        SizedBox(height: 4),
        ..._filterGroups[title]!.map((option) {
          return SizedBox(
            height: 27,
            child: CheckboxListTile(
              title: Text(
                option.title,
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: getResponsiveFontSize(context, fontSize: 16),
                  color: Color(0xFF64646D),
                ),
              ),
              value: option.value,
              onChanged: (bool? newValue) {
                setState(() {
                  option.value = newValue!;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              visualDensity: VisualDensity.compact,
            ),
          );
        }),
      ],
    );
  }
}

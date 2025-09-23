import 'package:flutter/material.dart';

class CustomDropdown extends StatelessWidget {
  final String labelText;
  final String? initialValue;
  final List<String> items;
  final Function(String?) onChanged;
  final String? Function(String?)? validator;
  final bool isRequired;

  const CustomDropdown({
    super.key,
    this.labelText = '',
    this.initialValue,
    required this.items,
    required this.onChanged,
    this.validator,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        label: labelText == ''
            ? null
            : RichText(
                text: TextSpan(
                  text: labelText,
                  style: TextStyle(
                    color: Colors.black54, // สีของ Label ปกติ
                    fontSize: 16,
                  ),
                  children: isRequired
                      ? [
                          const TextSpan(
                            text: ' *', // เพิ่ม * ต่อท้าย
                            style: TextStyle(
                              color: Colors.red, // ทำให้ * เป็นสีแดง
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ]
                      : [], // ถ้าไม่ isRequired ก็ไม่ต้องมี *
                ),
              ),
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
      ),
      hint: const Text('กรุณาเลือก'),
      initialValue: initialValue, // แก้ไขจาก initialValue เป็น value
      items: items.map((String item) {
        return DropdownMenuItem<String>(value: item, child: Text(item));
      }).toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }
}

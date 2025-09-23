import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomTextFormField extends StatelessWidget {
  final String labelText;
  final String hintText;
  final bool enabled;
  final bool readOnly;
  final bool isRequired;
  final bool isEmail;
  final TextEditingController? controller;
  final IconData? suffixIconData;
  final VoidCallback? onSuffixIconPressed;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final int? minLines;
  final int? maxLines;

  const CustomTextFormField({
    super.key,
    required this.labelText,
    this.hintText = '',
    this.enabled = true,
    this.readOnly = false,
    this.isRequired = false,
    this.isEmail = false,
    this.controller,
    this.suffixIconData,
    this.onSuffixIconPressed,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.minLines,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      minLines: minLines,
      maxLines: maxLines,
      enabled: enabled,
      readOnly: readOnly,
      onChanged: onChanged,
      decoration: InputDecoration(
        label: RichText(
          text: TextSpan(
            text: labelText,
            style: TextStyle(
              color: enabled ? Colors.black54 : Colors.grey,
              fontSize: 16,
            ),
            children: isRequired
                ? [
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ]
                : [],
          ),
        ),
        hintText: hintText,
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        suffixIcon: suffixIconData != null
            ? IconButton(
                icon: Icon(suffixIconData),
                onPressed: onSuffixIconPressed, // <-- ใช้ฟังก์ชันที่รับเข้ามา
              )
            : null,
      ),
      validator:
          validator ??
          (String? value) {
            if (isRequired && (value == null || value.trim().isEmpty)) {
              return 'กรุณากรอกข้อมูลช่องนี้';
            }
            if (isEmail && value != null && value.isNotEmpty) {
              final bool emailValid = RegExp(
                r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
              ).hasMatch(value);
              if (!emailValid) {
                return 'รูปแบบอีเมลไม่ถูกต้อง';
              }
            }
            return null;
          },
    );
  }
}

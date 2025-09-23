import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';

class CustomElevatedButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final double fontSize;
  final FontWeight fontWeight;
  final Color backgroundColor;
  final Color foregroundColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final BorderSide? side;
  final bool enabled;

  const CustomElevatedButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.fontSize = 20,
    this.fontWeight = FontWeight.bold,
    this.backgroundColor = Colors.black,
    this.foregroundColor = Colors.white,
    this.borderRadius = 6.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    this.side,
    this.enabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      
      onPressed: !enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        padding: padding,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        side: side,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: getResponsiveFontSize(context, fontSize: fontSize),
          fontWeight: fontWeight,
        ),
      ),
    );
  }
}

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
  final IconData? icon;
  final Color iconBackgroundColor;

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
    this.icon,
    this.iconBackgroundColor = Colors.white,
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
      child: icon != null
          ? Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontSize: getResponsiveFontSize(
                      context,
                      fontSize: fontSize,
                    ),
                    fontWeight: fontWeight,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(2.0),
                  decoration: BoxDecoration(
                    color: iconBackgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: backgroundColor,size: fontSize +4,),
                ),
              ],
            )
          : Text(
              text,
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: fontSize),
                fontWeight: fontWeight,
              ),
            ),
    );
  }
}

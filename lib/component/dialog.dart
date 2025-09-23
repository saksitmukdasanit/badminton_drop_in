import 'package:flutter/material.dart';
import 'package:slide_to_act/slide_to_act.dart';

class CustomAlertDialog extends StatelessWidget {
  final Widget icon;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showCloseIcon;

  const CustomAlertDialog({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.actions,
    this.showCloseIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 64, 32, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  icon,
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0XFF393941),
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: actions,
                  ),
                ],
              ),
            ),
          ),
          if (showCloseIcon)
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> showDialogMsg(
  BuildContext context, {
  required String title,
  required String subtitle,
  String btnLeft = 'ยืนยัน',
  String btnRight = '',
  Color btnLeftBackColor = const Color(0xFF0E9D7A),
  Color btnLeftForeColor = Colors.white,
  Color btnRightBackColor = const Color(0xFF0E9D7A),
  Color btnRightForeColor = Colors.white,
  bool isWarning = false,
  bool isSlideAction = false,
  required VoidCallback onConfirm,
}) {
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return CustomAlertDialog(
        icon: isWarning
            ? Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                ),
                child: const Icon(
                  Icons.priority_high,
                  color: Colors.white,
                  size: 50,
                ),
              )
            : Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF0E9D7A),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 50),
              ),
        title: title,
        subtitle: subtitle,
        actions: [
          if (!isSlideAction)
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: btnLeftBackColor,
                  foregroundColor: btnLeftForeColor,
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  btnLeft,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  onConfirm();
                },
              ),
            ),
          if (btnRight != '') const SizedBox(width: 16),
          if (btnRight != '')
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: btnRightBackColor,
                  foregroundColor: btnRightForeColor,
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  btnRight,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
          if (isSlideAction)
            Expanded(
              child: SlideAction(
                text: 'Drag to Confirm',
                textStyle: const TextStyle(fontSize: 16, color: Colors.black54),
                sliderButtonIcon: const Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                ),
                innerColor: const Color(0xFF0E9D7A), // สีเขียวของปุ่ม
                outerColor: Colors.grey[200], // สีพื้นหลังของแถบ
                elevation: 2,
                borderRadius: 16,
                onSubmit: () {
                  Navigator.of(context).pop();
                  onConfirm();
                  return null;
                },
              ),
            ),
        ],
      );
    },
  );
}

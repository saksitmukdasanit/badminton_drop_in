import 'package:flutter/material.dart';

class StackTap extends StatefulWidget {
  const StackTap({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.splashColor,
  });

  final Widget child;
  final Function()? onTap;
  final BorderRadius? borderRadius;
  final Color? splashColor;

  @override
  StackTapState createState() => StackTapState();
}

class StackTapState extends State<StackTap> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: widget.borderRadius,
              onTap: widget.onTap,
              hoverColor: Colors.white.withAlpha(77),
              splashColor: widget.splashColor ?? Theme.of(context).colorScheme.secondary.withAlpha(77),
              highlightColor: Colors.white.withAlpha(77),
            ),
          ),
        ),
      ],
    );
  }
}

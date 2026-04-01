import 'dart:async';
import 'package:badminton/component/manage_game_models.dart';
import 'package:flutter/material.dart';

class CourtTimerWidget extends StatefulWidget {
  final PlayingCourt court;
  const CourtTimerWidget({super.key, required this.court});

  @override
  State<CourtTimerWidget> createState() => _CourtTimerWidgetState();
}

class _CourtTimerWidgetState extends State<CourtTimerWidget> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && widget.court.status == CourtStatus.playing) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatDuration(widget.court.elapsedTime),
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    );
  }
}
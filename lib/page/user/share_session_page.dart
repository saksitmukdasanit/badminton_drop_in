import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/booking_details_mapper.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Resolves `sessionPublicId` via API then opens booking confirm (same flow as search).
class ShareSessionPage extends StatefulWidget {
  final String publicId;

  const ShareSessionPage({super.key, required this.publicId});

  @override
  State<ShareSessionPage> createState() => _ShareSessionPageState();
}

class _ShareSessionPageState extends State<ShareSessionPage> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    setState(() => _error = null);
    try {
      final res = await ApiProvider().get(
        '/player/gamesessions/share/${widget.publicId}',
      );
      if (!mounted) return;
      if (res['status'] == 200 && res['data'] != null) {
        final data = Map<String, dynamic>.from(res['data'] as Map);
        final details = bookingDetailsFromUpcomingCardMap(data);
        context.go('/booking-confirm', extra: details);
        return;
      }
      setState(() {
        _error = res['message']?.toString() ?? 'ไม่พบก๊วนหรือปิดรับจองแล้ว';
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'โหลดลิงก์ไม่สำเร็จ ลองใหม่อีกครั้ง');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_error == null) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('กำลังเปิดลิงก์ก๊วน...'),
              ] else ...[
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _resolve,
                  child: const Text('ลองอีกครั้ง'),
                ),
                TextButton(
                  onPressed: () => context.go('/'),
                  child: const Text('กลับหน้าหลัก'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

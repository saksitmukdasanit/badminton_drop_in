import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

bool hasExpandableNetworkImageUrl(String? url) =>
    url != null && url.trim().isNotEmpty;

/// เปิดรูปจากไฟล์ในเครื่องแบบเต็มจอ (ฟอร์มอัปโหลดรูปก๊วน)
void showFullscreenLocalImageFile(BuildContext context, File file) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        return Scaffold(
          backgroundColor: Colors.black,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.black54,
            foregroundColor: Colors.white,
          ),
          body: SafeArea(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 6,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: Image.file(file, fit: BoxFit.contain),
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// เปิดรูปเครือข่ายเต็มจอ พร้อมซูม/ลากด้วย [InteractiveViewer]
void showFullscreenNetworkImage(BuildContext context, String? imageUrl) {
  if (!hasExpandableNetworkImageUrl(imageUrl)) return;
  final url = imageUrl!.trim();

  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      barrierDismissible: true,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return _FullscreenNetworkImagePage(imageUrl: url);
      },
    ),
  );
}

class _FullscreenNetworkImagePage extends StatelessWidget {
  final String imageUrl;

  const _FullscreenNetworkImagePage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SizedBox.expand(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 6,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              width: size.width,
              height: size.height,
              alignment: Alignment.center,
              placeholder: (_, __) => SizedBox.expand(
                child: Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => const SizedBox.expand(
                child: Center(
                  child: Icon(Icons.broken_image, color: Colors.white54, size: 72),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

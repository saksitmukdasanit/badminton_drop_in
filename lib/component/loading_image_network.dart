import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class LoadingImageNetwork extends StatelessWidget {
  final String url;
  final BoxFit? fit;
  final double? height;
  final double? width;
  final Color? color;
  final bool isProfile;

  const LoadingImageNetwork(
    this.url, {
    super.key,
    this.fit,
    this.height,
    this.width,
    this.color,
    this.isProfile = false,
  });

  @override
  Widget build(BuildContext context) {
    if (url == '' && isProfile) {
      return Container(
        height: height ?? 30,
        width: width ?? 30,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          border: Border.all(width: 1, color: Colors.white),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Image.asset(
          'assets/images/user_not_found.png',
          color: Colors.white,
        ),
      );
    }
    if (url == '') {
      return Container(
        height: height,
        width: width,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      height: height,
      width: width,
      color: color,
      placeholder: (_, __) => TweenAnimationBuilder(
        duration: const Duration(seconds: 1),
        tween: Tween<double>(begin: 0.5, end: 1.0),
        builder: (_, double opacity, __) {
          return Opacity(
            opacity: opacity,
            child: Container(
              height: height ?? 30,
              width: width ?? 30,
              alignment: Alignment.center,
              child: Image.asset('assets/images/no_image.png'),
            ),
          );
        },
      ),
      errorWidget: (_, __, ___) => Container(
        height: height ?? 30,
        width: width ?? 30,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border.all(width: 1, color: Colors.white),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Image.asset('assets/images/no_image.png'),
      ),
    );
  }
}
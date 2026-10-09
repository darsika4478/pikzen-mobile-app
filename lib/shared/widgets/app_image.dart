import 'package:flutter/material.dart';

import 'profile_photo.dart';

/// Shows an image from any source the app stores: a bundled `assets/` path,
/// an `https://` URL, or an uploaded photo kept inline as a
/// `data:image/...;base64,` URI. Anything else, or a load failure, shows
/// [fallback].
class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.source,
    required this.fallback,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String? source;
  final Widget fallback;
  final double? width;
  final double? height;
  final BoxFit fit;

  static bool isUsable(String? source) {
    final value = source?.trim() ?? '';
    return value.startsWith('assets/') ||
        value.startsWith('https://') ||
        ProfilePhotoData.isData(value);
  }

  @override
  Widget build(BuildContext context) {
    final value = source?.trim() ?? '';
    Widget failed(BuildContext _, Object _, StackTrace? _) => fallback;
    if (ProfilePhotoData.isData(value)) {
      final bytes = ProfilePhotoData.decode(value);
      if (bytes == null) return fallback;
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: failed,
      );
    }
    if (value.startsWith('https://')) {
      return Image.network(
        value,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: failed,
      );
    }
    if (value.startsWith('assets/')) {
      return Image.asset(
        value,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: failed,
      );
    }
    return fallback;
  }
}

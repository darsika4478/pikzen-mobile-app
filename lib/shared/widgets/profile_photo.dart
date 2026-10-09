import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Profile photos are either a web URL (for example a Google account photo)
/// or a small JPEG/PNG stored in Firestore as a `data:image/...;base64,` URI.
/// The data form keeps uploads free of Firebase Storage on the Spark plan.
abstract final class ProfilePhotoData {
  /// Upper bound for the encoded photo; matches firestore.rules.
  static const maxEncodedLength = 150000;

  static bool isData(String source) => source.startsWith('data:image/');

  /// Encodes picked image bytes, or returns null if they are not JPEG/PNG.
  static String? encode(Uint8List bytes) {
    final mime = _mimeOf(bytes);
    if (mime == null) return null;
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  static Uint8List? decode(String source) {
    final comma = source.indexOf(',');
    if (!isData(source) || comma < 0) return null;
    try {
      return base64Decode(source.substring(comma + 1));
    } on FormatException {
      return null;
    }
  }

  static String? _mimeOf(Uint8List bytes) {
    if (bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return 'image/jpeg';
    }
    if (bytes.length > 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    return null;
  }
}

/// Shows [source] (URL or data URI), or [fallback] when it is empty/broken.
class ProfilePhoto extends StatelessWidget {
  const ProfilePhoto({super.key, required this.source, required this.fallback});

  final String source;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    if (source.isEmpty) return fallback;
    if (ProfilePhotoData.isData(source)) {
      final bytes = ProfilePhotoData.decode(source);
      if (bytes == null) return fallback;
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return Image.network(
      source,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

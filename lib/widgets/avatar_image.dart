import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AvatarImage extends StatelessWidget {
  final String? avatarUrl;
  final double size;
  final BoxFit fit;

  const AvatarImage({
    super.key,
    required this.avatarUrl,
    required this.size,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (avatarUrl == null || avatarUrl!.isEmpty) {
      return Icon(
        Icons.person_rounded,
        size: size / 2,
        color: AppTheme.subtitleText,
      );
    }

    // Check if the avatar is base64
    if (avatarUrl!.startsWith('data:image') || !avatarUrl!.startsWith('http')) {
      try {
        final base64Part = avatarUrl!.contains(',') ? avatarUrl!.split(',')[1] : avatarUrl!;
        final bytes = base64Decode(base64Part);
        return Image.memory(
          bytes,
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (c, e, s) => Icon(
            Icons.person_rounded,
            size: size / 2,
            color: AppTheme.subtitleText,
          ),
        );
      } catch (e) {
        // Fail silently and fall through to network image
      }
    }

    return Image.network(
      avatarUrl!,
      width: size,
      height: size,
      fit: fit,
      errorBuilder: (c, e, s) => Icon(
        Icons.person_rounded,
        size: size / 2,
        color: AppTheme.subtitleText,
      ),
    );
  }
}

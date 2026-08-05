import 'package:flutter/material.dart';
import '../core/config.dart';

/// Universal avatar widget — upload-only system.
///
/// Priority:
///   1. avatarUrl (user-uploaded photo from server)
///   2. Fallback: colored circle with user's initial letter
///
/// No more preset avatar assets — users upload their own photo.
class AvatarImage extends StatelessWidget {
  final String? avatarUrl;     // server path like "/avatars/abc.jpg"
  final String? displayName;   // for fallback initial
  final int     avatarId;      // kept for backward compat (unused in display)
  final double  size;
  final BoxFit  fit;
  final BorderRadius? borderRadius;

  const AvatarImage({
    this.avatarUrl,
    this.displayName,
    this.avatarId = 1,
    this.size     = 60,
    this.fit      = BoxFit.cover,
    this.borderRadius,
    super.key,
  });

  String get _fullUrl {
    if (avatarUrl == null || avatarUrl!.isEmpty) return '';
    if (avatarUrl!.startsWith('http')) return avatarUrl!;
    return '${AppConfig.apiUrl}$avatarUrl';
  }

  String get _initial {
    if (displayName == null || displayName!.isEmpty) return '?';
    return displayName![0].toUpperCase();
  }

  // Generate a consistent color from the displayName
  Color get _bgColor {
    final colors = [
      const Color(0xFF7B2FBE),
      const Color(0xFF4361EE),
      const Color(0xFFFF6B35),
      const Color(0xFF06D6A0),
      const Color(0xFFEF476F),
      const Color(0xFF118AB2),
      const Color(0xFFFFD166),
      const Color(0xFF073B4C),
    ];
    final hash = (displayName ?? 'X').codeUnits.fold(0, (a, b) => a + b);
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(size * 0.35);
    final hasPhoto = avatarUrl != null && avatarUrl!.isNotEmpty;

    if (!hasPhoto) {
      return _initialFallback(br);
    }

    return ClipRRect(
      borderRadius: br,
      child: Image.network(
        _fullUrl,
        width: size,
        height: size,
        fit: fit,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return _initialFallback(br);
        },
        errorBuilder: (_, __, ___) => _initialFallback(br),
      ),
    );
  }

  /// Fallback: colored circle with user's initial letter
  Widget _initialFallback(BorderRadius br) {
    return ClipRRect(
      borderRadius: br,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: br,
        ),
        child: Center(
          child: Text(
            _initial,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.42,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

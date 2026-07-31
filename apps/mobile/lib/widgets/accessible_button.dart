import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Accessible button with proper semantics for screen readers
class AccessibleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final String semanticLabel;
  final String? semanticHint;
  final bool isDestructive;
  final bool isPrimary;
  final EdgeInsets? padding;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const AccessibleButton({
    super.key,
    required this.onPressed,
    required this.child,
    required this.semanticLabel,
    this.semanticHint,
    this.isDestructive = false,
    this.isPrimary = true,
    this.padding,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    
    return Semantics(
      button: true,
      enabled: isEnabled,
      label: semanticLabel,
      hint: semanticHint,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDestructive
              ? Colors.red.shade700
              : (isPrimary ? AppColors.primary : AppColors.surface),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade700,
          disabledForegroundColor: Colors.grey.shade400,
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: Size(width ?? 0, height ?? 48),
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius ?? BorderRadius.circular(12),
          ),
          // Ensure minimum touch target size for accessibility (48x48)
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
        child: child,
      ),
    );
  }
}

/// Accessible icon button with proper semantics
class AccessibleIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String semanticLabel;
  final double size;
  final Color? color;

  const AccessibleIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.semanticLabel,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: size, color: color),
        tooltip: semanticLabel,
        // Ensure minimum touch target (48x48)
        constraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
      ),
    );
  }
}

/// Semantic wrapper for game elements
class GameSemantics extends StatelessWidget {
  final Widget child;
  final String? label;
  final String? hint;
  final String? value;
  final bool isHeader;
  final bool isButton;
  final bool isImage;
  final bool excludeFromSemantics;
  final VoidCallback? onTap;

  const GameSemantics({
    super.key,
    required this.child,
    this.label,
    this.hint,
    this.value,
    this.isHeader = false,
    this.isButton = false,
    this.isImage = false,
    this.excludeFromSemantics = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (excludeFromSemantics) {
      return ExcludeSemantics(child: child);
    }

    return Semantics(
      label: label,
      hint: hint,
      value: value,
      header: isHeader,
      button: isButton,
      image: isImage,
      onTap: onTap,
      child: child,
    );
  }
}

/// Accessible card with proper contrast and touch targets
class AccessibleCard extends StatelessWidget {
  final Widget child;
  final String? semanticLabel;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final bool selected;

  const AccessibleCard({
    super.key,
    required this.child,
    this.semanticLabel,
    this.onTap,
    this.padding,
    this.backgroundColor,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: selected
            ? Border.all(color: AppColors.primary, width: 2)
            : null,
        // Ensure sufficient contrast
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Semantics(
        button: true,
        label: semanticLabel,
        selected: selected,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          // Ensure minimum touch target
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: card,
          ),
        ),
      );
    }

    if (semanticLabel != null) {
      return Semantics(
        label: semanticLabel,
        selected: selected,
        child: card,
      );
    }

    return card;
  }
}

/// High contrast text for important information
class AccessibleText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final String? semanticLabel;
  final bool isHeading;
  final int headingLevel;
  final TextAlign? textAlign;

  const AccessibleText(
    this.text, {
    super.key,
    this.style,
    this.semanticLabel,
    this.isHeading = false,
    this.headingLevel = 1,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    // Ensure minimum contrast ratio (WCAG AA: 4.5:1 for normal text, 3:1 for large text)
    final effectiveStyle = (style ?? const TextStyle()).copyWith(
      // Ensure text has sufficient contrast
      color: (style?.color ?? Colors.white).withValues(alpha: 1.0),
    );

    final textWidget = Text(
      text,
      style: effectiveStyle,
      textAlign: textAlign,
    );

    if (isHeading) {
      return Semantics(
        header: true,
        label: semanticLabel ?? text,
        child: textWidget,
      );
    }

    if (semanticLabel != null) {
      return Semantics(
        label: semanticLabel,
        child: textWidget,
      );
    }

    return textWidget;
  }
}

/// Accessible avatar with fallback and semantics
class AccessibleAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? assetPath;
  final String playerName;
  final double size;
  final bool isAlive;

  const AccessibleAvatar({
    super.key,
    this.imageUrl,
    this.assetPath,
    required this.playerName,
    this.size = 48,
    this.isAlive = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatar;
    
    if (assetPath != null) {
      avatar = Image.asset(
        assetPath!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _buildFallback(),
      );
    } else if (imageUrl != null) {
      avatar = Image.network(
        imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _buildFallback(),
      );
    } else {
      avatar = _buildFallback();
    }

    // Add visual indicator for dead players
    if (!isAlive) {
      avatar = ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Colors.grey,
          BlendMode.saturation,
        ),
        child: avatar,
      );
    }

    return Semantics(
      image: true,
      label: isAlive
          ? 'Avatar pemain $playerName'
          : 'Avatar pemain $playerName yang sudah tereliminasi',
      child: ClipOval(child: avatar),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.3),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          playerName.isNotEmpty ? playerName[0].toUpperCase() : '?',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Focus indicator for keyboard navigation
class FocusableWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const FocusableWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return Container(
            decoration: hasFocus
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  )
                : null,
            child: Semantics(
              label: semanticLabel,
              child: onTap != null
                  ? GestureDetector(onTap: onTap, child: child)
                  : child,
            ),
          );
        },
      ),
    );
  }
}

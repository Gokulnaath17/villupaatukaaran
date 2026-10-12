import 'package:flutter/material.dart';
import '../theme/theme_controller.dart';

/// Modern translucent glass card with rounded corners and subtle border
class BoxyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const BoxyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.color,
    this.borderColor,
    this.borderWidth = 1.0,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? AppTheme.radiusMedium;
    final border = Border.all(
      color: borderColor ?? AppTheme.borderSubtle,
      width: borderWidth,
    );

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppTheme.cardSurface,
        border: border,
        borderRadius: effectiveRadius,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveRadius,
          splashColor: AppTheme.blueAccent.withOpacity(0.12),
          highlightColor: AppTheme.blueAccent.withOpacity(0.06),
          child: content,
        ),
      );
    }
    return content;
  }
}

/// Modern translucent flat button with rounded corners
class BoxyButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;

  const BoxyButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isPrimary = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(100);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: effectiveRadius,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isPrimary ? AppTheme.blueAccent : Colors.white.withOpacity(0.06),
            border: Border.all(
              color: isPrimary ? AppTheme.blueAccent : AppTheme.borderSubtle,
              width: 1.0,
            ),
            borderRadius: effectiveRadius,
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: AppTheme.blueGlow,
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: isPrimary ? Colors.white : AppTheme.textPrimary,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: isPrimary ? Colors.white : AppTheme.textPrimary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

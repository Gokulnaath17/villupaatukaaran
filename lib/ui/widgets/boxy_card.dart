import 'package:flutter/material.dart';
import '../theme/theme_controller.dart';

/// Minimalist boxy container with 1px border and optional highlight
class BoxyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;

  const BoxyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.color,
    this.borderColor,
    this.borderWidth = 1.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = Border.all(
      color: borderColor ?? AppTheme.border,
      width: borderWidth,
    );

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppTheme.cardSurface,
        border: border,
        borderRadius: BorderRadius.zero,
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        splashColor: AppTheme.yellowAccent.withOpacity(0.12),
        highlightColor: AppTheme.yellowAccent.withOpacity(0.06),
        child: content,
      );
    }
    return content;
  }
}

/// Minimalist boxy flat button
class BoxyButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final EdgeInsetsGeometry padding;

  const BoxyButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isPrimary = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.zero,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: isPrimary ? AppTheme.yellowAccent : Colors.transparent,
          border: Border.all(
            color: isPrimary ? AppTheme.yellowAccent : AppTheme.border,
            width: 1.0,
          ),
          borderRadius: BorderRadius.zero,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isPrimary ? AppTheme.black : AppTheme.textPrimary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: isPrimary ? AppTheme.black : AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


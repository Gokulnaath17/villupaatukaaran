import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../utils/app_assets.dart';

/// A traditional Tamil brass bell (மணி) loading indicator widget.
///
/// Provides a swinging animation with optional golden sound ripples and aura,
/// honoring the Villupaatukaran folk musical tradition.
class TamilBellLoader extends StatefulWidget {
  /// The size (width and height) of the loader.
  final double size;

  /// Optional message displayed below the bell (e.g. "Buffering...", "Loading...").
  final String? message;

  /// Style for the optional message text.
  final TextStyle? messageStyle;

  /// Whether to render pulsating golden sound ripples around the bell.
  final bool showGlow;

  /// Use the pre-rendered animated GIF for zero-CPU rendering or custom smooth canvas swing.
  final bool useGif;

  const TamilBellLoader({
    super.key,
    this.size = 64.0,
    this.message,
    this.messageStyle,
    this.showGlow = true,
    this.useGif = false,
  });

  @override
  State<TamilBellLoader> createState() => _TamilBellLoaderState();
}

class _TamilBellLoaderState extends State<TamilBellLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _swingAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Natural pendulum oscillation curve: angle = A * sin(t)
    _swingAnimation = Tween<double>(begin: -0.22, end: 0.22).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutSine,
      ),
    );

    // Glowing aura pulse
    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveSize = widget.size;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: effectiveSize * 1.5,
            height: effectiveSize * 1.5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Golden Ambient Aura / Sound Wave Ripples
                if (widget.showGlow)
                  AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Container(
                        width: effectiveSize * (1.1 + 0.3 * _glowAnimation.value),
                        height: effectiveSize * (1.1 + 0.3 * _glowAnimation.value),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFB800).withOpacity(
                                0.25 * _glowAnimation.value,
                              ),
                              blurRadius: 24 * _glowAnimation.value,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                // Swinging Bell
                if (widget.useGif)
                  Image.asset(
                    AppAssets.bellLoaderGif,
                    width: effectiveSize,
                    height: effectiveSize,
                    fit: BoxFit.contain,
                  )
                else
                  AnimatedBuilder(
                    animation: _swingAnimation,
                    builder: (context, child) {
                      // Swing around the top ring hanging pivot (top center of bell)
                      return Transform(
                        alignment: const Alignment(0.0, -0.65),
                        transform: Matrix4.identity()
                          ..rotateZ(
                            math.sin(_controller.value * 2 * math.pi) * 0.20,
                          ),
                        child: child,
                      );
                    },
                    child: Image.asset(
                      AppAssets.tamilBell,
                      width: effectiveSize,
                      height: effectiveSize,
                      fit: BoxFit.contain,
                    ),
                  ),
              ],
            ),
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.message!,
              style: widget.messageStyle ??
                  const TextStyle(
                    color: Color(0xFFFFD54F),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

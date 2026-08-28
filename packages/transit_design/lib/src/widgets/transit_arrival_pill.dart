import 'package:flutter/material.dart';
import '../transit_colors.dart';

/// Bold, prominent arrival countdown badge (e.g. "3 min", "15 min", "Due")
/// with pulsing real-time indicator.
class TransitArrivalPill extends StatefulWidget {
  const TransitArrivalPill({
    super.key,
    required this.minutes,
    this.isRealTime = true,
    this.accentColor = TransitColors.brandGreen,
    this.fontSize = 20,
  });

  /// Countdown minutes or custom text (e.g., "3", "14", "Now", "Scheduled").
  final String minutes;
  final bool isRealTime;
  final Color accentColor;
  final double fontSize;

  @override
  State<TransitArrivalPill> createState() => _TransitArrivalPillState();
}

class _TransitArrivalPillState extends State<TransitArrivalPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isRealTime) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(TransitArrivalPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRealTime && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isRealTime && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? widget.accentColor.withValues(alpha: 0.18)
        : widget.accentColor.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.accentColor.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.isRealTime) ...[
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.accentColor.withValues(alpha: _pulseAnimation.value),
                    boxShadow: [
                      BoxShadow(
                        color: widget.accentColor.withValues(alpha: _pulseAnimation.value * 0.7),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 6),
          ],
          Text(
            widget.minutes.endsWith('min') || widget.minutes == 'Now' || widget.minutes == 'Due'
                ? widget.minutes
                : '${widget.minutes} min',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

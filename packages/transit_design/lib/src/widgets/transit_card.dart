import 'package:flutter/material.dart';
import '../transit_colors.dart';

/// Reusable Transit-styled card with rounded corners, optional route accent strip,
/// smooth shadows, and fluid tap ripple.
class TransitCard extends StatelessWidget {
  const TransitCard({
    super.key,
    required this.child,
    this.onTap,
    this.accentColor,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    this.borderRadius = 18,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? accentColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? TransitColors.darkCard : TransitColors.lightCard;
    final defaultBorder = isDark ? TransitColors.darkBorder : TransitColors.lightBorder;

    return Padding(
      padding: margin,
      child: Material(
        color: cardBg,
        elevation: isDark ? 0 : 2,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: BorderSide(
            color: borderColor ?? defaultBorder,
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Stack(
            children: [
              if (accentColor != null)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  width: 6,
                  child: Container(color: accentColor),
                ),
              Padding(
                padding: accentColor != null
                    ? padding.add(const EdgeInsets.only(left: 6))
                    : padding,
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

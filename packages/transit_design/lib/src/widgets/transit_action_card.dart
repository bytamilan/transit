import 'package:flutter/material.dart';
import '../transit_colors.dart';

/// Clean rounded action card used throughout Transit iOS (e.g. search sheets, profile tiles).
class TransitActionCard extends StatelessWidget {
  const TransitActionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.iconColor,
    this.onTap,
    this.trailing,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  });

  final String title;
  final String? subtitle;
  final Widget icon;
  final Color? iconColor;
  final VoidCallback? onTap;
  final Widget? trailing;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? TransitColors.darkCard : Colors.white;

    return Padding(
      padding: margin,
      child: Material(
        color: bg,
        elevation: isDark ? 0 : 2,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? TransitColors.darkBorder : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                icon,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : TransitColors.lightSubtext,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                trailing ??
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Colors.grey,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

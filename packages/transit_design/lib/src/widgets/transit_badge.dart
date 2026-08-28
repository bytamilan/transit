import 'package:flutter/material.dart';
import '../transit_colors.dart';

/// Enum representing transport modes supported across the design system.
enum TransitMode {
  bus,
  subway,
  train,
  tram,
  ferry,
  bike,
  scooter,
  walk,
  rideshare,
}

/// Icon helper for transit modes.
class TransitModeIcon extends StatelessWidget {
  const TransitModeIcon({
    super.key,
    required this.mode,
    this.size = 18,
    this.color,
  });

  final TransitMode mode;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconData = switch (mode) {
      TransitMode.bus => Icons.directions_bus_rounded,
      TransitMode.subway => Icons.subway_rounded,
      TransitMode.train => Icons.train_rounded,
      TransitMode.tram => Icons.tram_rounded,
      TransitMode.ferry => Icons.directions_boat_rounded,
      TransitMode.bike => Icons.pedal_bike_rounded,
      TransitMode.scooter => Icons.electric_scooter_rounded,
      TransitMode.walk => Icons.directions_walk_rounded,
      TransitMode.rideshare => Icons.local_taxi_rounded,
    };

    return Icon(iconData, size: size, color: color);
  }
}

/// High-contrast, color-coded route badge (e.g. "B", "70", "E Line", "217").
class TransitLineBadge extends StatelessWidget {
  const TransitLineBadge({
    super.key,
    required this.label,
    this.color = TransitColors.brandGreen,
    this.textColor,
    this.mode,
    this.size = TransitBadgeSize.medium,
    this.isPill = false,
  });

  final String label;
  final Color color;
  final Color? textColor;
  final TransitMode? mode;
  final TransitBadgeSize size;
  final bool isPill;

  @override
  Widget build(BuildContext context) {
    final fg = textColor ?? TransitColors.contrastingTextColor(color);

    final (padding, fontSize, height, minWidth, radius) = switch (size) {
      TransitBadgeSize.small => (
          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          11.0,
          22.0,
          22.0,
          isPill ? 11.0 : 6.0,
        ),
      TransitBadgeSize.medium => (
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          14.0,
          32.0,
          32.0,
          isPill ? 16.0 : 8.0,
        ),
      TransitBadgeSize.large => (
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          18.0,
          44.0,
          44.0,
          isPill ? 22.0 : 12.0,
        ),
    };

    return Container(
      constraints: BoxConstraints(minHeight: height, minWidth: minWidth),
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (mode != null) ...[
            TransitModeIcon(mode: mode!, size: fontSize + 2, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

enum TransitBadgeSize { small, medium, large }

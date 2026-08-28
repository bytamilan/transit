import 'package:flutter/material.dart';
import '../transit_colors.dart';

/// Full-bleed, solid color-coded transit line tile inspired by Transit iOS home map.
class TransitFullBleedLineTile extends StatelessWidget {
  const TransitFullBleedLineTile({
    super.key,
    required this.lineCode,
    required this.destination,
    required this.stationSubtitle,
    required this.minutes,
    required this.tileColor,
    this.textColor,
    this.badgeColor,
    this.badgeTextColor,
    this.isPill = false,
    this.onTap,
    this.hasAlert = false,
    this.isLive = true,
  });

  final String lineCode;
  final String destination;
  final String stationSubtitle;
  final String minutes;
  final Color tileColor;
  final Color? textColor;
  final Color? badgeColor;
  final Color? badgeTextColor;
  final bool isPill;
  final VoidCallback? onTap;
  final bool hasAlert;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final fg = textColor ?? TransitColors.contrastingTextColor(tileColor);
    final bgBadge = badgeColor ?? (fg == Colors.white ? Colors.white : Colors.black);
    final fgBadge = badgeTextColor ?? (fg == Colors.white ? tileColor : Colors.white);

    return Material(
      color: tileColor,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Line Badge (Circle or Square or Pill)
              Container(
                width: isPill ? null : 48,
                height: 48,
                padding: isPill ? const EdgeInsets.symmetric(horizontal: 12) : EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: bgBadge,
                  shape: isPill ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: isPill ? BorderRadius.circular(12) : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  lineCode,
                  style: TextStyle(
                    color: fgBadge,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Destination and Stop Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (hasAlert) ...[
                          Icon(Icons.warning_amber_rounded, size: 16, color: fg.withValues(alpha: 0.9)),
                          const SizedBox(width: 4),
                        ],
                        Icon(Icons.arrow_forward_rounded, size: 16, color: fg),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            destination,
                            style: TextStyle(
                              color: fg,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stationSubtitle,
                      style: TextStyle(
                        color: fg.withValues(alpha: 0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Giant Countdown Minutes Column
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        minutes,
                        style: TextStyle(
                          color: fg,
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          letterSpacing: -1.0,
                        ),
                      ),
                      if (isLive) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.wifi_tethering_rounded, size: 14, color: fg.withValues(alpha: 0.9)),
                      ],
                    ],
                  ),
                  Text(
                    minutes == '1' ? 'minute' : 'minutes',
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

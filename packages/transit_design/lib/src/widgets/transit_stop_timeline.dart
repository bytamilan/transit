import 'package:flutter/material.dart';
import '../transit_colors.dart';

/// Data class representing a stop on the timeline.
class TimelineStopItem {
  const TimelineStopItem({
    required this.id,
    required this.name,
    this.time,
    this.isPassed = false,
    this.isCurrent = false,
    this.isTerminal = false,
    this.transferRoutes = const [],
  });

  final String id;
  final String name;
  final String? time;
  final bool isPassed;
  final bool isCurrent;
  final bool isTerminal;
  final List<String> transferRoutes;
}

/// Interactive vertical stop timeline widget matching Transit iOS design.
class TransitStopTimeline extends StatelessWidget {
  const TransitStopTimeline({
    super.key,
    required this.stops,
    this.lineColor = TransitColors.brandGreen,
    this.onStopTap,
  });

  final List<TimelineStopItem> stops;
  final Color lineColor;
  final ValueChanged<TimelineStopItem>? onStopTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: stops.length,
      itemBuilder: (context, index) {
        final stop = stops[index];
        final isFirst = index == 0;
        final isLast = index == stops.length - 1;

        final textColor = stop.isPassed
            ? (isDark ? Colors.white38 : Colors.black38)
            : (isDark ? Colors.white : Colors.black87);

        return InkWell(
          onTap: onStopTap != null ? () => onStopTap!(stop) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Stop time
                SizedBox(
                  width: 50,
                  child: Text(
                    stop.time ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: stop.isCurrent ? FontWeight.w800 : FontWeight.w500,
                      color: stop.isCurrent
                          ? lineColor
                          : (isDark ? Colors.white54 : Colors.black54),
                    ),
                  ),
                ),

                // Vertical track + node
                SizedBox(
                  width: 32,
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Top connecting line
                      if (!isFirst)
                        Positioned(
                          top: 0,
                          bottom: 24,
                          width: 4,
                          child: Container(
                            color: stop.isPassed
                                ? lineColor.withValues(alpha: 0.35)
                                : lineColor,
                          ),
                        ),

                      // Bottom connecting line
                      if (!isLast)
                        Positioned(
                          top: 24,
                          bottom: 0,
                          width: 4,
                          child: Container(
                            color: stop.isPassed || stop.isCurrent
                                ? lineColor.withValues(alpha: 0.35)
                                : lineColor,
                          ),
                        ),

                      // Station dot / Vehicle marker
                      if (stop.isCurrent)
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: lineColor, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: lineColor.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        )
                      else if (stop.isTerminal)
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: stop.isPassed
                                ? lineColor.withValues(alpha: 0.4)
                                : lineColor,
                            border: Border.all(
                              color: isDark ? Colors.black : Colors.white,
                              width: 2.5,
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: stop.isPassed
                                ? lineColor.withValues(alpha: 0.3)
                                : (isDark ? Colors.white70 : lineColor),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Stop Name + Transfer chips
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        stop.name,
                        style: TextStyle(
                          fontSize: stop.isCurrent ? 15 : 14,
                          fontWeight: stop.isCurrent ? FontWeight.w800 : FontWeight.w600,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (stop.transferRoutes.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 4,
                          children: stop.transferRoutes.map((r) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                r,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

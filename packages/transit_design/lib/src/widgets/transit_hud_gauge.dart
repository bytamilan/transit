import 'package:flutter/material.dart';
import '../transit_colors.dart';

/// High-visibility cockpit HUD gauge for the Driver App with safety interlock banner.
class DriverSpeedHud extends StatelessWidget {
  const DriverSpeedHud({
    super.key,
    required this.speedKmh,
    required this.isLocked,
    this.isNight = false,
    this.unit = 'km/h',
    this.statusMessage,
  });

  final double? speedKmh;
  final bool isLocked;
  final bool isNight;
  final String unit;
  final String? statusMessage;

  @override
  Widget build(BuildContext context) {
    final fg = isNight ? Colors.white : Colors.black87;
    final speedText = speedKmh != null ? speedKmh!.toStringAsFixed(0) : '0';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Safety Interlock Status Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isLocked
                ? TransitColors.cockpitAmber.withValues(alpha: 0.18)
                : TransitColors.cockpitPhosphor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isLocked ? TransitColors.cockpitAmber : TransitColors.cockpitPhosphor,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isLocked ? Icons.lock_rounded : Icons.check_circle_rounded,
                size: 16,
                color: isLocked ? TransitColors.cockpitAmber : TransitColors.cockpitPhosphor,
              ),
              const SizedBox(width: 8),
              Text(
                statusMessage ??
                    (isLocked
                        ? 'Moving — Controls locked for safety'
                        : 'Stopped — Ready for action'),
                style: TextStyle(
                  color: isLocked ? TransitColors.cockpitAmber : TransitColors.cockpitPhosphor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Large Speed Readout
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              speedText,
              style: TextStyle(
                fontSize: 84,
                fontWeight: FontWeight.w900,
                color: fg,
                letterSpacing: -3.0,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              unit,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isNight ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../transit_colors.dart';

/// Levels of passenger crowding on transit vehicles.
enum CrowdingLevel {
  empty,
  manySeats,
  fewSeats,
  standingRoom,
  crushed,
  full,
}

/// Selector widget for reporting or viewing vehicle crowding.
class TransitOccupancySelector extends StatelessWidget {
  const TransitOccupancySelector({
    super.key,
    this.selectedLevel,
    required this.onLevelSelected,
    this.enabled = true,
  });

  final CrowdingLevel? selectedLevel;
  final ValueChanged<CrowdingLevel> onLevelSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final options = [
      (CrowdingLevel.empty, 'Empty', Icons.airline_seat_recline_normal_rounded, TransitColors.statusOnTime),
      (CrowdingLevel.manySeats, 'Many Seats', Icons.airline_seat_recline_extra_rounded, TransitColors.statusOnTime),
      (CrowdingLevel.fewSeats, 'Few Seats', Icons.people_outline_rounded, TransitColors.statusWarning),
      (CrowdingLevel.standingRoom, 'Standing', Icons.groups_outlined, TransitColors.metroOrange),
      (CrowdingLevel.full, 'Full', Icons.group_off_rounded, TransitColors.statusDelayed),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final (level, label, icon, color) = opt;
        final isSelected = selectedLevel == level;

        return Material(
          color: isSelected
              ? color
              : (isDark ? TransitColors.darkCard : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: enabled ? () => onLevelSelected(level) : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? color
                      : (isDark ? TransitColors.darkBorder : Colors.grey.shade300),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

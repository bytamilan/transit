import 'package:flutter/material.dart';
import '../transit_colors.dart';

/// Floating pill search input bar matching Transit iOS design.
class TransitSearchBar extends StatelessWidget {
  const TransitSearchBar({
    super.key,
    this.hintText = 'Where to?',
    this.controller,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.leadingIcon,
    this.trailingAction,
    this.readOnly = false,
    this.autoFocus = false,
  });

  final String hintText;
  final TextEditingController? controller;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final Widget? leadingIcon;
  final Widget? trailingAction;
  final bool readOnly;
  final bool autoFocus;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? TransitColors.darkSurface : TransitColors.lightSurface;
    final border = isDark ? TransitColors.darkBorder : TransitColors.lightBorder;

    return Container(
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                leadingIcon ??
                    const Icon(
                      Icons.search_rounded,
                      color: TransitColors.brandGreen,
                      size: 24,
                    ),
                const SizedBox(width: 10),
                Expanded(
                  child: readOnly
                      ? Text(
                          controller?.text.isNotEmpty == true
                              ? controller!.text
                              : hintText,
                          style: TextStyle(
                            color: controller?.text.isNotEmpty == true
                                ? (isDark ? Colors.white : Colors.black87)
                                : (isDark ? Colors.white54 : TransitColors.lightSubtext),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : TextField(
                          controller: controller,
                          readOnly: readOnly,
                          autofocus: autoFocus,
                          onChanged: onChanged,
                          onSubmitted: onSubmitted,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: hintText,
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white54 : TransitColors.lightSubtext,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                ),
                if (controller?.text.isNotEmpty == true && onClear != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: onClear,
                    color: isDark ? Colors.white54 : TransitColors.lightSubtext,
                  ),
                if (trailingAction != null) trailingAction!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

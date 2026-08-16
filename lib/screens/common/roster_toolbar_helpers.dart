import 'package:flutter/material.dart';

/// Navy primary for filter popup [Apply] (reference UI).
const Color kRosterFilterApplyColor = Color(0xFF1E3A5F);

/// Shared height for Filters, dropdowns, search field, and Search — **not** a fixed pixel:
/// scales with viewport ([MediaQuery.size]) and text scaling so it stays consistent on resize.
double rosterToolbarHeightFor(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final textScale = MediaQuery.textScalerOf(context).scale(1.0).clamp(0.85, 1.25);
  // Blend window height + width so any resize updates the bar; clamp keeps readable bounds
  final blended = size.height * 0.054 + size.width * 0.007;
  return (blended * textScale).clamp(42.0, 60.0);
}

/// Filters button with optional count badge; matches [toolbarHeight].
Widget rosterFiltersButton({
  Key? filterButtonKey,
  required double toolbarHeight,
  required VoidCallback onPressed,
  required int activeAdvancedCount,
}) {
  final child = SizedBox(
    key: filterButtonKey,
    height: toolbarHeight,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(Icons.filter_list_outlined, size: 20, color: Colors.green.shade800),
      label: Text('Filters', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.green.shade800)),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.grey.shade100,
        foregroundColor: Colors.green.shade800,
        side: BorderSide(color: Colors.grey.shade300),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        minimumSize: Size(0, toolbarHeight),
        maximumSize: Size(double.infinity, toolbarHeight),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );
  if (activeAdvancedCount <= 0) return child;
  return Badge(
    label: Text('$activeAdvancedCount'),
    child: child,
  );
}

/// Search field — height matches [toolbarHeight].
Widget rosterSearchField({
  required double toolbarHeight,
  required TextEditingController controller,
  required String hintText,
  required ValueChanged<String> onSubmitted,
}) {
  return SizedBox(
    height: toolbarHeight,
    child: TextField(
      controller: controller,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey.shade600),
        prefixIconConstraints: BoxConstraints(minWidth: 44, minHeight: toolbarHeight),
        isDense: true,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade500),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        alignLabelWithHint: true,
      ),
      textAlignVertical: TextAlignVertical.center,
      onSubmitted: onSubmitted,
    ),
  );
}

/// Green Search button — same height as the search field.
Widget rosterSearchButton({
  required double toolbarHeight,
  required VoidCallback onPressed,
}) {
  return SizedBox(
    height: toolbarHeight,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF16A34A),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        minimumSize: Size(88, toolbarHeight),
        maximumSize: Size(double.infinity, toolbarHeight),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text('Search', style: TextStyle(fontWeight: FontWeight.w800)),
    ),
  );
}

Future<void> pickRosterDate({
  required BuildContext context,
  required DateTime? current,
  required ValueChanged<DateTime?> onChanged,
}) async {
  final now = DateTime.now();
  final initial = current ?? now;
  final d = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime(now.year + 1, 12, 31),
  );
  if (d != null) onChanged(d);
}

/// Reference-style date row: labels + outlined fields with MM/DD/YYYY and calendar icon.
class RosterFilterDateRow extends StatelessWidget {
  const RosterFilterDateRow({
    super.key,
    required this.startLabel,
    required this.endLabel,
    required this.start,
    required this.end,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final String startLabel;
  final String endLabel;
  final DateTime? start;
  final DateTime? end;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  static String _fmt(DateTime? d) {
    if (d == null) return '';
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$m/$day/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(startLabel, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onPickStart,
          borderRadius: BorderRadius.circular(8),
          child: InputDecorator(
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              suffixIcon: Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey.shade600),
            ),
            child: Text(
              start == null ? 'MM/DD/YYYY' : _fmt(start),
              style: TextStyle(
                fontSize: 14,
                color: start == null ? theme.hintColor : theme.textTheme.bodyLarge?.color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(endLabel, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onPickEnd,
          borderRadius: BorderRadius.circular(8),
          child: InputDecorator(
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              suffixIcon: Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey.shade600),
            ),
            child: Text(
              end == null ? 'MM/DD/YYYY' : _fmt(end),
              style: TextStyle(
                fontSize: 14,
                color: end == null ? theme.hintColor : theme.textTheme.bodyLarge?.color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Popup footer: Reset (outlined) + Apply (navy), full width row.
class RosterFilterPopupActions extends StatelessWidget {
  const RosterFilterPopupActions({
    super.key,
    required this.onReset,
    required this.onApply,
  });

  final VoidCallback onReset;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onReset,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade900,
              side: BorderSide(color: Colors.grey.shade400),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: onApply,
            style: FilledButton.styleFrom(
              backgroundColor: kRosterFilterApplyColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

/// Shows a white card under the [anchorKey] widget (Filters button). Tap scrim to dismiss.
Future<T?> showAnchoredFilterPopup<T>({
  required BuildContext context,
  required GlobalKey anchorKey,
  required Widget Function(BuildContext dialogContext, StateSetter setDialog) builder,
}) async {
  final ctx = anchorKey.currentContext;
  if (ctx == null) return null;
  final renderBox = ctx.findRenderObject() as RenderBox;
  final offset = renderBox.localToGlobal(Offset.zero);
  final size = renderBox.size;
  final media = MediaQuery.of(context);
  final cardW = 400.0;
  var left = offset.dx;
  if (left + cardW > media.size.width - 8) left = (media.size.width - 8 - cardW).clamp(8.0, double.infinity);
  if (left < 8) left = 8;
  var top = offset.dy + size.height + 8;
  if (top > media.size.height - 120) top = (offset.dy - 8 - 320).clamp(8.0, double.infinity);

  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.22),
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (dialogCtx, setDialog) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: SizedBox(
              width: media.size.width,
              height: media.size.height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => Navigator.of(dialogCtx).pop(),
                      behavior: HitTestBehavior.opaque,
                      child: const ColoredBox(color: Colors.transparent),
                    ),
                  ),
                  Positioned(
                    left: left,
                    top: top,
                    width: cardW,
                    child: Material(
                      elevation: 12,
                      shadowColor: Colors.black45,
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                      child: builder(dialogCtx, setDialog),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

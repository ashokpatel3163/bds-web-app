import 'package:flutter/material.dart';

/// Shared header + filter row + pagination for student / staff directory screens.
class SchoolRosterHeader extends StatelessWidget {
  const SchoolRosterHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final List<Widget>? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...trailing!,
          ],
        ),
      ],
    );
  }
}

class SchoolPaginationBar extends StatelessWidget {
  const SchoolPaginationBar({
    super.key,
    required this.totalItems,
    required this.pageIndex,
    required this.pageSize,
    required this.onPageChanged,
    required this.onPageSizeChanged,
    required this.itemLabel,
  });

  final int totalItems;
  final int pageIndex;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;
  final String itemLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final totalPages = totalItems == 0 ? 1 : ((totalItems + pageSize - 1) / pageSize).ceil();
    final start = totalItems == 0 ? 0 : pageIndex * pageSize + 1;
    final end = (pageIndex + 1) * pageSize > totalItems ? totalItems : (pageIndex + 1) * pageSize;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              totalItems == 0 ? 'No $itemLabel' : '$start – $end of $totalItems $itemLabel',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, fontWeight: FontWeight.w600),
            ),
          ),
          Text('Rows per page', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: DropdownButtonFormField<int>(
              initialValue: pageSize,
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
              items: const [
                DropdownMenuItem(value: 5, child: Text('5')),
                DropdownMenuItem(value: 10, child: Text('10')),
                DropdownMenuItem(value: 25, child: Text('25')),
              ],
              onChanged: (v) {
                if (v != null) onPageSizeChanged(v);
              },
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Page ${pageIndex + 1} of $totalPages',
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: cs.primary),
            ),
          ),
          IconButton(
            tooltip: 'First page',
            onPressed: pageIndex > 0 ? () => onPageChanged(0) : null,
            icon: const Icon(Icons.first_page_outlined),
          ),
          IconButton(
            tooltip: 'Previous',
            onPressed: pageIndex > 0 ? () => onPageChanged(pageIndex - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Next',
            onPressed: pageIndex < totalPages - 1 ? () => onPageChanged(pageIndex + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            tooltip: 'Last page',
            onPressed: pageIndex < totalPages - 1 ? () => onPageChanged(totalPages - 1) : null,
            icon: const Icon(Icons.last_page_outlined),
          ),
        ],
      ),
    );
  }
}

/// Grey table header row.
class SchoolTableHeaderRow extends StatelessWidget {
  const SchoolTableHeaderRow({super.key, required this.cells});

  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: cells,
      ),
    );
  }
}

/// Green "View" pill button like reference.
class SchoolViewButton extends StatelessWidget {
  const SchoolViewButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF16A34A),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: const Size(0, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      child: const Text('View', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../staff/staff_repository.dart';

/// Loads [GET /staff-attendance/me] for one staff member (vendorCode).
class StaffAttendanceTab extends StatefulWidget {
  const StaffAttendanceTab({
    super.key,
    required this.repo,
    required this.vendorCode,
  });

  final StaffRepository repo;
  final String vendorCode;

  @override
  State<StaffAttendanceTab> createState() => _StaffAttendanceTabState();
}

class _StaffAttendanceTabState extends State<StaffAttendanceTab> {
  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  _Range _range = _Range.defaultBackend;
  bool _loading = true;
  String? _error;
  List<StaffAttendanceRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final String? from;
      final String? to;
      final now = DateTime.now();
      switch (_range) {
        case _Range.defaultBackend:
          from = null;
          to = null;
          break;
        case _Range.week:
          from = _ymd(now.subtract(const Duration(days: 7)));
          to = _ymd(now);
          break;
        case _Range.month:
          from = _ymd(now.subtract(const Duration(days: 30)));
          to = _ymd(now);
          break;
        case _Range.quarter:
          from = _ymd(now.subtract(const Duration(days: 90)));
          to = _ymd(now);
          break;
      }
      final rows = await widget.repo.fetchStaffAttendance(
        widget.vendorCode,
        from: from,
        to: to,
      );
      rows.sort((a, b) => b.workDate.compareTo(a.workDate));
      if (mounted) {
        setState(() {
          _rows = rows;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat('EEE, dd MMM yyyy');
    final timeFmt = DateFormat('hh:mm a');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Clock-in and clock-out from the staff app are listed here.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor, height: 1.35),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Range', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
            ChoiceChip(
              label: const Text('~3 months (default)'),
              selected: _range == _Range.defaultBackend,
              onSelected: (_) {
                setState(() => _range = _Range.defaultBackend);
                _load();
              },
            ),
            ChoiceChip(
              label: const Text('7 days'),
              selected: _range == _Range.week,
              onSelected: (_) {
                setState(() => _range = _Range.week);
                _load();
              },
            ),
            ChoiceChip(
              label: const Text('30 days'),
              selected: _range == _Range.month,
              onSelected: (_) {
                setState(() => _range = _Range.month);
                _load();
              },
            ),
            ChoiceChip(
              label: const Text('90 days'),
              selected: _range == _Range.quarter,
              onSelected: (_) {
                setState(() => _range = _Range.quarter);
                _load();
              },
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loading ? null : _load,
              icon: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_error != null)
          Material(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline_rounded, color: Colors.red.shade800),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade900, height: 1.35),
                    ),
                  ),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            ),
          )
        else if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No attendance records for this range.',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, c) {
              final narrow = c.maxWidth < 640;
              if (narrow) {
                return Column(
                  children: [
                    for (final r in _rows) ...[
                      _AttendanceCard(
                        workDate: r.workDate,
                        dateFmt: dateFmt,
                        timeFmt: timeFmt,
                        checkInAt: r.checkInAt,
                        checkOutAt: r.checkOutAt,
                        checkInLocation: r.checkInLocation,
                        checkOutLocation: r.checkOutLocation,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              }
              return _AttendanceTable(
                rows: _rows,
                dateFmt: dateFmt,
                timeFmt: timeFmt,
              );
            },
          ),
      ],
    );
  }
}

enum _Range { defaultBackend, week, month, quarter }

class _AttendanceTable extends StatelessWidget {
  const _AttendanceTable({
    required this.rows,
    required this.dateFmt,
    required this.timeFmt,
  });

  final List<StaffAttendanceRow> rows;
  final DateFormat dateFmt;
  final DateFormat timeFmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 720),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(1.4),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1.6),
            },
            border: TableBorder.all(color: const Color(0xFFE2E8F0)),
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade50),
                children: [
                  _th('Work date'),
                  _th('Check-in'),
                  _th('Check-out'),
                  _th('Location notes'),
                ],
              ),
              for (final r in rows)
                TableRow(
                  children: [
                    _td(_formatWorkDate(r.workDate, dateFmt), theme),
                    _td(_formatTime(r.checkInAt, timeFmt), theme),
                    _td(_formatTime(r.checkOutAt, timeFmt), theme),
                    _td(_locationLine(r.checkInLocation, r.checkOutLocation), theme),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _th(String s) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          s,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.2),
        ),
      );

  Widget _td(String s, ThemeData theme) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(s, style: theme.textTheme.bodyMedium?.copyWith(height: 1.35)),
      );
}

String _formatWorkDate(String workDate, DateFormat dateFmt) {
  final d = DateTime.tryParse(workDate.length >= 10 ? workDate.substring(0, 10) : workDate);
  if (d == null) return workDate;
  return dateFmt.format(d);
}

String _formatTime(DateTime? t, DateFormat timeFmt) {
  if (t == null) return '—';
  return timeFmt.format(t.toLocal());
}

String _locationLine(String inLoc, String outLoc) {
  final parts = <String>[];
  if (inLoc.isNotEmpty) parts.add('In: $inLoc');
  if (outLoc.isNotEmpty) parts.add('Out: $outLoc');
  if (parts.isEmpty) return '—';
  return parts.join('\n');
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({
    required this.workDate,
    required this.dateFmt,
    required this.timeFmt,
    required this.checkInAt,
    required this.checkOutAt,
    required this.checkInLocation,
    required this.checkOutLocation,
  });

  final String workDate;
  final DateFormat dateFmt;
  final DateFormat timeFmt;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final String checkInLocation;
  final String checkOutLocation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatWorkDate(workDate, dateFmt),
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text('In: ${_formatTime(checkInAt, timeFmt)}', style: theme.textTheme.bodyMedium),
            Text('Out: ${_formatTime(checkOutAt, timeFmt)}', style: theme.textTheme.bodyMedium),
            if (checkInLocation.isNotEmpty || checkOutLocation.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                _locationLine(checkInLocation, checkOutLocation),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, height: 1.35),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

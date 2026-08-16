import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../students/student_repository.dart';
import '../common/roster_toolbar_helpers.dart' show
    pickRosterDate,
    rosterFiltersButton,
    rosterSearchButton,
    rosterSearchField,
    rosterToolbarHeightFor,
    RosterFilterDateRow,
    RosterFilterPopupActions,
    showAnchoredFilterPopup;
import '../common/school_roster_listing.dart';
import 'widgets/filter_dropdown.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({
    super.key,
    required this.onViewStudent,
    required this.onEditStudent,
    required this.onToggleActive,
    required this.repo,
  });

  final ValueChanged<Student> onViewStudent;
  final ValueChanged<Student> onEditStudent;
  final ValueChanged<Student> onToggleActive;
  final StudentRepository repo;

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  /// Space between table columns (header + rows stay aligned).
  static const double _tableColGap = 12;
  static Widget _tableGap() => const SizedBox(width: _tableColGap);

  String _gradeFilter = 'All classes';
  String _statusFilter = 'All statuses';
  String _yearFilter = 'All years';
  String _sortLabel = 'Newest first';
  DateTime? _admittedFrom;
  DateTime? _admittedTo;
  final _searchController = TextEditingController();
  String _appliedQuery = '';
  int _pageIndex = 0;
  int _pageSize = 10;

  static final _dateFmt = DateFormat('dd MMM yyyy');
  final GlobalKey _filterAnchorKey = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _inAdmittedDateRange(Student s) {
    if (_admittedFrom == null && _admittedTo == null) return true;
    final ca = s.createdAt;
    if (ca == null) return false;
    final day = DateTime(ca.year, ca.month, ca.day);
    if (_admittedFrom != null) {
      final start = DateTime(_admittedFrom!.year, _admittedFrom!.month, _admittedFrom!.day);
      if (day.isBefore(start)) return false;
    }
    if (_admittedTo != null) {
      final end = DateTime(_admittedTo!.year, _admittedTo!.month, _admittedTo!.day);
      if (day.isAfter(end)) return false;
    }
    return true;
  }

  int get _advancedFilterCount {
    var n = 0;
    if (_statusFilter != 'All statuses') n++;
    if (_sortLabel != 'Newest first') n++;
    if (_admittedFrom != null) n++;
    if (_admittedTo != null) n++;
    return n;
  }

  List<Student> _filterAndSort(List<Student> all) {
    final q = _appliedQuery.toLowerCase();
    var list = all.where((s) {
      final byGrade = _gradeFilter == 'All classes' || s.className == _gradeFilter;
      final byStatus = _statusFilter == 'All statuses' || s.enrollmentStatus == _statusFilter;
      final byYear = _yearFilter == 'All years' || s.admissionYear == _yearFilter;
      final bySearch = q.isEmpty
          ? true
          : [
              s.admissionId,
              s.fullName,
              s.email,
              s.phone,
              s.className,
              s.section,
              s.enrollmentStatus,
              s.admissionYear,
              s.guardianName,
            ].join(' ').toLowerCase().contains(q);
      return byGrade && byStatus && byYear && bySearch && _inAdmittedDateRange(s);
    }).toList();

    switch (_sortLabel) {
      case 'Name A–Z':
        list.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
      case 'Admission ID':
        list.sort((a, b) => a.admissionId.compareTo(b.admissionId));
      default:
        list.sort((a, b) {
          final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return tb.compareTo(ta);
        });
    }
    return list;
  }

  Future<void> _openAdvancedFilters(BuildContext context) async {
    var status = _statusFilter;
    var sort = _sortLabel;
    var from = _admittedFrom;
    var to = _admittedTo;

    await showAnchoredFilterPopup<void>(
      context: context,
      anchorKey: _filterAnchorKey,
      builder: (ctx, setDialog) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Filters',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                RosterFilterDateRow(
                  startLabel: 'Start date',
                  endLabel: 'End date',
                  start: from,
                  end: to,
                  onPickStart: () => pickRosterDate(
                    context: ctx,
                    current: from,
                    onChanged: (d) => setDialog(() => from = d),
                  ),
                  onPickEnd: () => pickRosterDate(
                    context: ctx,
                    current: to,
                    onChanged: (d) => setDialog(() => to = d),
                  ),
                ),
                const SizedBox(height: 18),
                FilterDropdown(
                  label: 'Enrolment status',
                  value: status,
                  options: const ['All statuses', 'Active', 'On hold', 'On Leave', 'Probation'],
                  onChanged: (v) => setDialog(() => status = v),
                ),
                const SizedBox(height: 12),
                FilterDropdown(
                  label: 'Sort',
                  value: sort,
                  options: const ['Newest first', 'Name A–Z', 'Admission ID'],
                  onChanged: (v) => setDialog(() => sort = v),
                ),
                const SizedBox(height: 20),
                RosterFilterPopupActions(
                  onReset: () {
                    setDialog(() {
                      status = 'All statuses';
                      sort = 'Newest first';
                      from = null;
                      to = null;
                    });
                  },
                  onApply: () {
                    setState(() {
                      _statusFilter = status;
                      _sortLabel = sort;
                      _admittedFrom = from;
                      _admittedTo = to;
                      if (_admittedFrom != null &&
                          _admittedTo != null &&
                          _admittedFrom!.isAfter(_admittedTo!)) {
                        final a = _admittedFrom;
                        _admittedFrom = _admittedTo;
                        _admittedTo = a;
                      }
                      _pageIndex = 0;
                    });
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<List<Student>>(
      stream: widget.repo.watchStudents(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final allStudents = snap.data!;
        final grades = <String>{for (final s in allStudents) if (s.className.isNotEmpty) s.className}.toList()..sort();
        final gradeOptions = <String>[
          'All classes',
          ...grades.where((g) => g != 'All classes'),
        ];
        final years = <String>{for (final s in allStudents) if (s.admissionYear.isNotEmpty) s.admissionYear}.toList()
          ..sort((a, b) => b.compareTo(a));
        final yearOptions = <String>[
          'All years',
          ...years.where((y) => y != 'All years'),
        ];

        final filtered = _filterAndSort(allStudents);
        final total = filtered.length;
        final totalPages = total == 0 ? 1 : ((total + _pageSize - 1) / _pageSize).ceil();
        final pageIdx = total == 0 ? 0 : _pageIndex.clamp(0, totalPages - 1);
        final start = pageIdx * _pageSize;
        final pageRows = filtered.skip(start).take(_pageSize).toList();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, c) {
                  final narrow = c.maxWidth < 760;
                  final th = rosterToolbarHeightFor(context);

                  final searchField = rosterSearchField(
                    toolbarHeight: th,
                    controller: _searchController,
                    hintText: 'Search name, admission ID, phone…',
                    onSubmitted: (_) => setState(() {
                      _appliedQuery = _searchController.text.trim();
                      _pageIndex = 0;
                    }),
                  );

                  final filtersBtn = rosterFiltersButton(
                    toolbarHeight: th,
                    filterButtonKey: _filterAnchorKey,
                    activeAdvancedCount: _advancedFilterCount,
                    onPressed: () => _openAdvancedFilters(context),
                  );

                  final yearDd = SizedBox(
                    width: narrow ? 148 : 152,
                    child: FilterDropdown(
                      toolbarDense: true,
                      toolbarHeight: th,
                      label: 'Year',
                      value: _yearFilter,
                      options: yearOptions,
                      onChanged: (v) => setState(() {
                        _yearFilter = v;
                        _pageIndex = 0;
                      }),
                    ),
                  );

                  final classDd = SizedBox(
                    width: narrow ? 148 : 152,
                    child: FilterDropdown(
                      toolbarDense: true,
                      toolbarHeight: th,
                      label: 'Class',
                      value: _gradeFilter,
                      options: gradeOptions,
                      onChanged: (v) => setState(() {
                        _gradeFilter = v;
                        _pageIndex = 0;
                      }),
                    ),
                  );

                  final searchBtn = rosterSearchButton(
                    toolbarHeight: th,
                    onPressed: () => setState(() {
                      _appliedQuery = _searchController.text.trim();
                      _pageIndex = 0;
                    }),
                  );

                  if (narrow) {
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        filtersBtn,
                        yearDd,
                        classDd,
                        SizedBox(width: 260, child: searchField),
                        searchBtn,
                      ],
                    );
                  }

                  return SizedBox(
                    height: th,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        filtersBtn,
                        const SizedBox(width: 10),
                        yearDd,
                        const SizedBox(width: 10),
                        classDd,
                        const Spacer(),
                        Expanded(flex: 2, child: searchField),
                        const SizedBox(width: 10),
                        searchBtn,
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final tableW = math.max(c.maxWidth, 1200.0);
                    return Scrollbar(
                      thumbVisibility: c.maxWidth < 1200,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: tableW,
                          height: c.maxHeight,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                SchoolTableHeaderRow(
                                  cells: [
                                    _hCell('Admitted', flex: 2),
                                    _tableGap(),
                                    _hCell('Admission ID', flex: 2),
                                    _tableGap(),
                                    _hCell('Student', flex: 3),
                                    _tableGap(),
                                    _hCell('Class / Sec', flex: 2),
                                    _tableGap(),
                                    _hCell('Roll', flex: 2),
                                    _tableGap(),
                                    _hCell('Guardian / contact', flex: 3),
                                    _tableGap(),
                                    SizedBox(width: 88, child: _hText('Action')),
                                  ],
                                ),
                                Expanded(
                                  child: pageRows.isEmpty
                                      ? Center(
                                          child: Text(
                                            'No students match your filters.',
                                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                                          ),
                                        )
                                      : ListView.separated(
                                          itemCount: pageRows.length,
                                          separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                                          itemBuilder: (context, i) {
                                            final s = pageRows[i];
                                            final admitted = s.createdAt != null ? _dateFmt.format(s.createdAt!) : '—';
                                            return Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  _tableDataCell(
                                                    flex: 2,
                                                    child: Text(admitted, style: const TextStyle(fontSize: 13)),
                                                  ),
                                                  _tableGap(),
                                                  _tableDataCell(
                                                    flex: 2,
                                                    child: Text(
                                                      s.admissionId.isEmpty ? '—' : s.admissionId,
                                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                                    ),
                                                  ),
                                                  _tableGap(),
                                                  _tableDataCell(
                                                    flex: 3,
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                                        if (s.email.isNotEmpty)
                                                          Text(s.email, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                                                      ],
                                                    ),
                                                  ),
                                                  _tableGap(),
                                                  _tableDataCell(
                                                    flex: 2,
                                                    child: Text(
                                                      s.className.isEmpty
                                                          ? '—'
                                                          : '${s.className} · Sec ${s.section.isEmpty ? '—' : s.section}',
                                                    ),
                                                  ),
                                                  _tableGap(),
                                                  _tableDataCell(
                                                    flex: 2,
                                                    child: Text(
                                                      s.rollNo.isEmpty ? '—' : s.rollNo,
                                                      style: const TextStyle(fontSize: 13),
                                                    ),
                                                  ),
                                                  _tableGap(),
                                                  _tableDataCell(
                                                    flex: 3,
                                                    child: Text(
                                                      s.guardianName.isNotEmpty ? '${s.guardianName}\n${s.phone}' : s.phone,
                                                      style: const TextStyle(fontSize: 12, height: 1.35),
                                                    ),
                                                  ),
                                                  _tableGap(),
                                                  SizedBox(
                                                    width: 88,
                                                    child: SchoolViewButton(
                                                      onPressed: () => widget.onViewStudent(s),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SchoolPaginationBar(
                totalItems: total,
                pageIndex: pageIdx,
                pageSize: _pageSize,
                itemLabel: 'students',
                onPageChanged: (p) => setState(() => _pageIndex = p),
                onPageSizeChanged: (n) => setState(() {
                  _pageSize = n;
                  _pageIndex = 0;
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Same horizontal inset as data cells so header lines up with body.
  static Widget _hCell(String t, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: _hText(t),
      ),
    );
  }

  static Widget _tableDataCell({required int flex, required Widget child}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: child,
      ),
    );
  }

  static Widget _hText(String t) {
    return Text(
      t.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        color: Colors.grey.shade700,
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../staff/staff_repository.dart';
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
import '../students/widgets/filter_dropdown.dart';

class StaffDirectoryPage extends StatefulWidget {
  const StaffDirectoryPage({
    super.key,
    required this.repo,
    required this.onViewStaff,
  });

  final StaffRepository repo;
  final ValueChanged<StaffMember> onViewStaff;

  @override
  State<StaffDirectoryPage> createState() => _StaffDirectoryPageState();
}

class _StaffDirectoryPageState extends State<StaffDirectoryPage> {
  String _deptFilter = 'All departments';
  String _joinYearFilter = 'All years';
  String _roleFilter = 'All roles';
  String _statusFilter = 'All statuses';
  String _sortLabel = 'Newest first';
  DateTime? _joinedFrom;
  DateTime? _joinedTo;
  final _searchController = TextEditingController();
  String _appliedQuery = '';
  int _pageIndex = 0;
  int _pageSize = 10;

  static final _dateFmt = DateFormat('dd MMM yyyy');
  final GlobalKey _filterAnchorKey = GlobalKey();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _inJoinedDateRange(StaffMember s) {
    if (_joinedFrom == null && _joinedTo == null) return true;
    final j = s.joinedOn;
    if (j == null) return false;
    final day = DateTime(j.year, j.month, j.day);
    if (_joinedFrom != null) {
      final start = DateTime(_joinedFrom!.year, _joinedFrom!.month, _joinedFrom!.day);
      if (day.isBefore(start)) return false;
    }
    if (_joinedTo != null) {
      final end = DateTime(_joinedTo!.year, _joinedTo!.month, _joinedTo!.day);
      if (day.isAfter(end)) return false;
    }
    return true;
  }

  int get _advancedFilterCount {
    var n = 0;
    if (_roleFilter != 'All roles') n++;
    if (_statusFilter != 'All statuses') n++;
    if (_sortLabel != 'Newest first') n++;
    if (_joinedFrom != null) n++;
    if (_joinedTo != null) n++;
    return n;
  }

  List<StaffMember> _filterAndSort(List<StaffMember> all) {
    final q = _appliedQuery.toLowerCase();
    var list = all.where((s) {
      final byDept = _deptFilter == 'All departments' || s.department == _deptFilter;
      final byJoinYear =
          _joinYearFilter == 'All years' || (s.joinedOn != null && '${s.joinedOn!.year}' == _joinYearFilter);
      final byRole = _roleFilter == 'All roles' || s.role.label == _roleFilter;
      final statusLabel = s.isActive ? 'Active' : 'Inactive';
      final byStatus = _statusFilter == 'All statuses' || statusLabel == _statusFilter;
      final bySearch = q.isEmpty
          ? true
          : [
              s.employeeId,
              s.id,
              s.fullName,
              s.email,
              s.phone,
              s.department,
              s.designation,
              s.role.label,
              s.address,
              s.emergencyContact,
              s.qualification,
              s.notes,
            ].join(' ').toLowerCase().contains(q);
      return byDept && byJoinYear && byRole && byStatus && bySearch && _inJoinedDateRange(s);
    }).toList();

    switch (_sortLabel) {
      case 'Name A–Z':
        list.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
      case 'Employee ID':
        list.sort((a, b) {
          final ea = a.employeeId.isNotEmpty ? a.employeeId : a.id;
          final eb = b.employeeId.isNotEmpty ? b.employeeId : b.id;
          return ea.compareTo(eb);
        });
      default:
        list.sort((a, b) {
          final ta = a.joinedOn ?? DateTime.fromMillisecondsSinceEpoch(0);
          final tb = b.joinedOn ?? DateTime.fromMillisecondsSinceEpoch(0);
          return tb.compareTo(ta);
        });
    }
    return list;
  }

  Future<void> _openAdvancedFilters(BuildContext context) async {
    var role = _roleFilter;
    var status = _statusFilter;
    var sort = _sortLabel;
    var from = _joinedFrom;
    var to = _joinedTo;

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
                  startLabel: 'Join from',
                  endLabel: 'Join to',
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
                  label: 'Role',
                  value: role,
                  options: const [
                    'All roles',
                    'Teacher',
                    'Admin',
                    'Support',
                  ],
                  onChanged: (v) => setDialog(() => role = v),
                ),
                const SizedBox(height: 12),
                FilterDropdown(
                  label: 'Employment status',
                  value: status,
                  options: const ['All statuses', 'Active', 'Inactive'],
                  onChanged: (v) => setDialog(() => status = v),
                ),
                const SizedBox(height: 12),
                FilterDropdown(
                  label: 'Sort',
                  value: sort,
                  options: const ['Newest first', 'Name A–Z', 'Employee ID'],
                  onChanged: (v) => setDialog(() => sort = v),
                ),
                const SizedBox(height: 20),
                RosterFilterPopupActions(
                  onReset: () {
                    setDialog(() {
                      role = 'All roles';
                      status = 'All statuses';
                      sort = 'Newest first';
                      from = null;
                      to = null;
                    });
                  },
                  onApply: () {
                    setState(() {
                      _roleFilter = role;
                      _statusFilter = status;
                      _sortLabel = sort;
                      _joinedFrom = from;
                      _joinedTo = to;
                      if (_joinedFrom != null && _joinedTo != null && _joinedFrom!.isAfter(_joinedTo!)) {
                        final a = _joinedFrom;
                        _joinedFrom = _joinedTo;
                        _joinedTo = a;
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

    return StreamBuilder<List<StaffMember>>(
      stream: widget.repo.watchStaff(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final all = snap.data!;
        final depts = <String>{for (final s in all) if (s.department.isNotEmpty) s.department}.toList()..sort();
        final deptOptions = <String>[
          'All departments',
          ...depts.where((d) => d != 'All departments'),
        ];
        final joinYears = <String>{
          for (final s in all)
            if (s.joinedOn != null) '${s.joinedOn!.year}',
        }.toList()
          ..sort((a, b) => b.compareTo(a));
        final joinYearOptions = <String>[
          'All years',
          ...joinYears.where((y) => y != 'All years'),
        ];

        final filtered = _filterAndSort(all);
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
                    hintText: 'Search name, employee ID, email…',
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
                    width: narrow ? 132 : 136,
                    child: FilterDropdown(
                      toolbarDense: true,
                      toolbarHeight: th,
                      label: 'Year',
                      value: _joinYearFilter,
                      options: joinYearOptions,
                      onChanged: (v) => setState(() {
                        _joinYearFilter = v;
                        _pageIndex = 0;
                      }),
                    ),
                  );
                  final deptDd = SizedBox(
                    width: narrow ? 168 : 172,
                    child: FilterDropdown(
                      toolbarDense: true,
                      toolbarHeight: th,
                      label: 'Department',
                      value: _deptFilter,
                      options: deptOptions,
                      onChanged: (v) => setState(() {
                        _deptFilter = v;
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
                        deptDd,
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
                        deptDd,
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
                    final tableW = math.max(c.maxWidth, 1100.0);
                    return Scrollbar(
                      thumbVisibility: c.maxWidth < 1100,
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
                                    _hCell('Joined', flex: 2),
                                    _hCell('Employee ID', flex: 2),
                                    _hCell('Staff', flex: 3),
                                    _hCell('Contact', flex: 3),
                                    _hCell('Department', flex: 2),
                                    _hCell('Role', flex: 2),
                                    SizedBox(width: 88, child: _hText('Action')),
                                  ],
                                ),
                                Expanded(
                                  child: pageRows.isEmpty
                                      ? Center(
                                          child: Text(
                                            'No staff match your filters.',
                                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                                          ),
                                        )
                                      : ListView.separated(
                                          itemCount: pageRows.length,
                                          separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                                          itemBuilder: (context, i) {
                                            final s = pageRows[i];
                                            final joined = s.joinedOn != null ? _dateFmt.format(s.joinedOn!) : '—';
                                            return Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(joined, style: const TextStyle(fontSize: 13)),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      s.employeeId.isNotEmpty ? s.employeeId : s.id,
                                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 3,
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                                        if (s.designation.isNotEmpty)
                                                          Text(
                                                            s.designation,
                                                            style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 3,
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        if (s.phone.isNotEmpty)
                                                          Text(s.phone, style: const TextStyle(fontSize: 13)),
                                                        if (s.email.isNotEmpty)
                                                          Text(
                                                            s.email,
                                                            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                                          ),
                                                        if (s.phone.isEmpty && s.email.isEmpty) const Text('—'),
                                                      ],
                                                    ),
                                                  ),
                                                  Expanded(flex: 2, child: Text(s.department)),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(s.role.label),
                                                  ),
                                                  SizedBox(
                                                    width: 88,
                                                    child: SchoolViewButton(
                                                      onPressed: () => widget.onViewStaff(s),
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
                itemLabel: 'staff',
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

  static Widget _hCell(String t, {required int flex}) {
    return Expanded(
      flex: flex,
      child: _hText(t),
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

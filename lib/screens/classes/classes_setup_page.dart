import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../classes/school_class_repository.dart';
import '../common/roster_toolbar_helpers.dart'
    show rosterSearchButton, rosterSearchField, rosterToolbarHeightFor;
import '../common/school_roster_listing.dart';
import '../students/widgets/filter_dropdown.dart';

/// Define classes and annual fees — used when admitting students and on fee collection.
class ClassesSetupPage extends StatefulWidget {
  const ClassesSetupPage({super.key, required this.repo});

  final SchoolClassRepository repo;

  @override
  State<ClassesSetupPage> createState() => _ClassesSetupPageState();
}

class _ClassesSetupPageState extends State<ClassesSetupPage> {
  final _searchController = TextEditingController();
  String _appliedQuery = '';
  String _statusFilter = 'All statuses';
  int _pageIndex = 0;
  int _pageSize = 10;

  static final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SchoolClass> _filterAndSort(List<SchoolClass> all) {
    final q = _appliedQuery.toLowerCase();
    var list = all.where((c) {
      final byStatus = _statusFilter == 'All statuses'
          ? true
          : _statusFilter == 'Active'
              ? c.isActive
              : !c.isActive;
      final bySearch = q.isEmpty
          ? true
          : [
              c.code,
              c.name,
              c.displayLabel,
              c.totalAnnualFee.round().toString(),
            ].join(' ').toLowerCase().contains(q);
      return byStatus && bySearch;
    }).toList();

    list.sort((a, b) => a.displayLabel.toLowerCase().compareTo(b.displayLabel.toLowerCase()));
    return list;
  }

  Future<void> _confirmDelete(BuildContext context, SchoolClassRepository repo, SchoolClass c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete class?'),
        content: Text('Remove ${c.displayLabel} (${c.code})? This is blocked if any student still uses it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await repo.deleteClass(c.code);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Class removed.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _openEditor(
    BuildContext context, {
    required SchoolClassRepository repo,
    SchoolClass? existing,
  }) async {
    await showDialog<bool>(
      context: context,
      builder: (ctx) => _ClassEditorDialog(repo: repo, existing: existing),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<List<SchoolClass>>(
      stream: widget.repo.watchClasses(includeInactive: true),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final all = snap.data!;
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
                    hintText: 'Search class name, code, fee…',
                    onSubmitted: (_) => setState(() {
                      _appliedQuery = _searchController.text.trim();
                      _pageIndex = 0;
                    }),
                  );
                  final searchBtn = rosterSearchButton(
                    toolbarHeight: th,
                    onPressed: () => setState(() {
                      _appliedQuery = _searchController.text.trim();
                      _pageIndex = 0;
                    }),
                  );
                  final statusDd = SizedBox(
                    width: narrow ? 148 : 152,
                    child: FilterDropdown(
                      toolbarDense: true,
                      toolbarHeight: th,
                      label: 'Status',
                      value: _statusFilter,
                      options: const ['All statuses', 'Active', 'Inactive'],
                      onChanged: (v) => setState(() {
                        _statusFilter = v;
                        _pageIndex = 0;
                      }),
                    ),
                  );
                  final addBtn = FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: narrow ? 12 : 16, vertical: 12),
                    ),
                    onPressed: () => _openEditor(context, repo: widget.repo, existing: null),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Add class'),
                  );

                  if (narrow) {
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        statusDd,
                        SizedBox(width: 260, child: searchField),
                        searchBtn,
                        addBtn,
                      ],
                    );
                  }

                  return SizedBox(
                    height: th,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        statusDd,
                        const Spacer(),
                        Expanded(flex: 2, child: searchField),
                        const SizedBox(width: 10),
                        searchBtn,
                        const SizedBox(width: 10),
                        addBtn,
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
                                    _hCell('Class', flex: 3),
                                    _hCell('Code', flex: 2),
                                    _hCell('Annual fee', flex: 2),
                                    _hCell('Status', flex: 2),
                                    SizedBox(width: 132, child: _hText('Actions')),
                                  ],
                                ),
                                Expanded(
                                  child: pageRows.isEmpty
                                      ? Center(
                                          child: Text(
                                            all.isEmpty
                                                ? 'No classes yet. Add one before new admissions.'
                                                : 'No classes match your filters.',
                                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                                          ),
                                        )
                                      : ListView.separated(
                                          itemCount: pageRows.length,
                                          separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                                          itemBuilder: (context, i) {
                                            final row = pageRows[i];
                                            return Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    flex: 3,
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          row.name,
                                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                                        ),
                                                        if (row.section.isNotEmpty)
                                                          Text(
                                                            row.section,
                                                            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      row.code.isEmpty ? '—' : row.code,
                                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      _money.format(row.totalAnnualFee),
                                                      style: const TextStyle(fontSize: 13),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      row.isActive ? 'Active' : 'Inactive',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w600,
                                                        color: row.isActive ? const Color(0xFF15803D) : Colors.grey.shade600,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 132,
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: FilledButton(
                                                            onPressed: () =>
                                                                _openEditor(context, repo: widget.repo, existing: row),
                                                            style: FilledButton.styleFrom(
                                                              backgroundColor: const Color(0xFF16A34A),
                                                              foregroundColor: Colors.white,
                                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                              minimumSize: const Size(0, 32),
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.circular(8),
                                                              ),
                                                              elevation: 0,
                                                            ),
                                                            child: const Text(
                                                              'Edit',
                                                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                                            ),
                                                          ),
                                                        ),
                                                        IconButton(
                                                          tooltip: 'Delete',
                                                          onPressed: () => _confirmDelete(context, widget.repo, row),
                                                          icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                                                        ),
                                                      ],
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
                itemLabel: 'classes',
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

class _ClassEditorDialog extends StatefulWidget {
  const _ClassEditorDialog({required this.repo, this.existing});

  final SchoolClassRepository repo;
  final SchoolClass? existing;

  @override
  State<_ClassEditorDialog> createState() => _ClassEditorDialogState();
}

class _ClassEditorDialogState extends State<_ClassEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _fee;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _fee = TextEditingController(text: e != null ? e.totalAnnualFee.round().toString() : '');
    _active = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _fee.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repo = widget.repo;
    final name = _name.text.trim();
    final fee = double.tryParse(_fee.text.trim()) ?? -1;
    if (name.isEmpty || fee < 0) return;
    const section = '';
    const sort = 0;
    final e = widget.existing;
    try {
      if (e == null) {
        await repo.createClass(name: name, section: section, totalAnnualFee: fee, sortOrder: sort);
      } else {
        await repo.updateClass(
          e.code,
          name: name,
          section: section,
          totalAnnualFee: fee,
          sortOrder: sort,
          isActive: _active,
        );
      }
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved.')));
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.existing;
    return AlertDialog(
      title: Text(e == null ? 'Add class' : 'Edit class'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (e != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Code: ${e.code}', style: TextStyle(color: Colors.grey.shade700)),
                ),
              ),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Class name *', hintText: 'e.g. Class 5'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _fee,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Total annual fee *', prefixText: '₹ '),
            ),
            if (e != null) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: _active,
                onChanged: (v) => setState(() => _active = v ?? true),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

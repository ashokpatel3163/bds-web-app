import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../fees/fee_repository.dart';
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
import 'fee_receipt_dialog.dart';

/// Fee receipts listing — toolbar + table + pagination (aligned with students / staff).
class FeesListingPage extends StatefulWidget {
  const FeesListingPage({super.key, required this.repo});

  final FeeRepository repo;

  @override
  State<FeesListingPage> createState() => _FeesListingPageState();
}

class _FeesListingPageState extends State<FeesListingPage> {
  String _yearFilter = 'All years';
  String _sortLabel = 'Newest first';
  DateTime? _paidFrom;
  DateTime? _paidTo;
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

  bool _inPaidRange(FeeReceipt f) {
    if (_paidFrom == null && _paidTo == null) return true;
    final p = f.paidOn;
    if (p == null) return false;
    final day = DateTime(p.year, p.month, p.day);
    if (_paidFrom != null) {
      final start = DateTime(_paidFrom!.year, _paidFrom!.month, _paidFrom!.day);
      if (day.isBefore(start)) return false;
    }
    if (_paidTo != null) {
      final end = DateTime(_paidTo!.year, _paidTo!.month, _paidTo!.day);
      if (day.isAfter(end)) return false;
    }
    return true;
  }

  int get _advancedFilterCount {
    var n = 0;
    if (_sortLabel != 'Newest first') n++;
    if (_paidFrom != null) n++;
    if (_paidTo != null) n++;
    return n;
  }

  List<FeeReceipt> _filterAndSort(List<FeeReceipt> all) {
    final q = _appliedQuery.toLowerCase();
    var list = all.where((f) {
      final y = f.paidOn != null ? '${f.paidOn!.year}' : '';
      final byYear = _yearFilter == 'All years' || y == _yearFilter;
      final bySearch = q.isEmpty
          ? true
          : [
              f.receiptNo,
              f.studentName,
              f.admissionId,
              f.feeHead,
              f.feeHeadSummary,
              f.notes,
            ].join(' ').toLowerCase().contains(q);
      return byYear && bySearch && _inPaidRange(f);
    }).toList();

    switch (_sortLabel) {
      case 'Receipt no.':
        list.sort((a, b) => a.receiptNo.compareTo(b.receiptNo));
      case 'Amount (high)':
        list.sort((a, b) => b.amount.compareTo(a.amount));
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
    var sort = _sortLabel;
    var from = _paidFrom;
    var to = _paidTo;

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
                  startLabel: 'Paid from',
                  endLabel: 'Paid to',
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
                  label: 'Sort',
                  value: sort,
                  options: const ['Newest first', 'Amount (high)', 'Receipt no.'],
                  onChanged: (v) => setDialog(() => sort = v),
                ),
                const SizedBox(height: 20),
                RosterFilterPopupActions(
                  onReset: () {
                    setDialog(() {
                      sort = 'Newest first';
                      from = null;
                      to = null;
                    });
                  },
                  onApply: () {
                    setState(() {
                      _sortLabel = sort;
                      _paidFrom = from;
                      _paidTo = to;
                      if (_paidFrom != null && _paidTo != null && _paidFrom!.isAfter(_paidTo!)) {
                        final a = _paidFrom;
                        _paidFrom = _paidTo;
                        _paidTo = a;
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
    final money = NumberFormat.currency(locale: 'en_IN', symbol: 'INR ');

    return StreamBuilder<List<FeeReceipt>>(
      stream: widget.repo.watchFees(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final all = snap.data!;
        final years = <String>{
          for (final f in all)
            if (f.paidOn != null) '${f.paidOn!.year}',
        }.toList()
          ..sort((a, b) => b.compareTo(a));
        final yearOptions = <String>[
          'All years',
          ...years.where((y) => y != 'All years'),
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
                    hintText: 'Search receipt, student, admission ID…',
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
                                    _hCell('Paid', flex: 2),
                                    _hCell('Receipt', flex: 2),
                                    _hCell('Student', flex: 3),
                                    _hCell('Admission', flex: 2),
                                    _hCell('Class / Sec', flex: 2),
                                    _hCell('Amount', flex: 2),
                                    _hCell('Particulars', flex: 3),
                                    SizedBox(width: 88, child: _hText('Action')),
                                  ],
                                ),
                                Expanded(
                                  child: pageRows.isEmpty
                                      ? Center(
                                          child: Text(
                                            'No fee receipts match your filters.',
                                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                                          ),
                                        )
                                      : ListView.separated(
                                          itemCount: pageRows.length,
                                          separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                                          itemBuilder: (context, i) {
                                            final f = pageRows[i];
                                            final paid = f.paidOn != null ? _dateFmt.format(f.paidOn!) : '—';
                                            final cls = f.className.isEmpty && f.section.isEmpty
                                                ? '—'
                                                : '${f.className}${f.section.isNotEmpty ? ' / ${f.section}' : ''}';
                                            return Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(flex: 2, child: Text(paid, style: const TextStyle(fontSize: 13))),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      f.receiptNo,
                                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 3,
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(f.studentName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                                        if (f.notes.isNotEmpty)
                                                          Text(
                                                            f.notes,
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      f.admissionId.isEmpty ? '—' : f.admissionId,
                                                      style: const TextStyle(fontSize: 13),
                                                    ),
                                                  ),
                                                  Expanded(flex: 2, child: Text(cls, style: const TextStyle(fontSize: 13))),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      money.format(f.amount),
                                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 3,
                                                    child: Text(
                                                      f.feeHeadSummary,
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(color: Colors.grey.shade800, fontSize: 12),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 88,
                                                    child: SchoolViewButton(
                                                      onPressed: () => showFeeReceiptDialog(context, f),
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
                itemLabel: 'receipts',
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

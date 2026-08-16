import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../classes/school_class_repository.dart';
import '../../fees/fee_repository.dart';
import '../../students/student_repository.dart';
import 'fee_receipt_dialog.dart';

/// Record a new fee — search any student, see ledger (due / paid / balance + history), then collect.
class FeeCollectionPage extends StatefulWidget {
  const FeeCollectionPage({
    super.key,
    required this.feeRepo,
    required this.studentRepo,
    required this.classRepo,
    required this.onBack,
  });

  final FeeRepository feeRepo;
  final StudentRepository studentRepo;
  final SchoolClassRepository classRepo;
  final VoidCallback onBack;

  @override
  State<FeeCollectionPage> createState() => _FeeCollectionPageState();
}

class _FeeCollectionPageState extends State<FeeCollectionPage> {
  static const _mint = Color(0xFF0D9488);

  static const _feeHeads = <String>[
    'Admission Fee',
    'Tuition Fee',
    'Computer Class',
    'Books',
    'Registers',
    'Smart Class Fee',
    'Conveyance Fee',
    'Celebration Fee',
    'School Magazine Fee',
    'Examination Fee',
    'Library Fee',
    'Day Hostel Fee',
    'Other Fee',
  ];

  final _studentSearch = TextEditingController();
  final _searchFocus = FocusNode();
  final _notes = TextEditingController();
  DateTime _paidOn = DateTime.now();
  String? _selectedStudentId;
  bool _saving = false;
  final List<_FeeLineDraft> _feeLines = [_FeeLineDraft.initial()];

  @override
  void dispose() {
    _studentSearch.dispose();
    _searchFocus.dispose();
    _notes.dispose();
    for (final line in _feeLines) {
      line.amountController.dispose();
    }
    super.dispose();
  }

  void _clearStudent() {
    setState(() {
      _selectedStudentId = null;
      _studentSearch.clear();
    });
  }

  void _selectStudent(Student s) {
    setState(() {
      _selectedStudentId = s.id;
      _studentSearch.text = s.fullName;
    });
    _searchFocus.unfocus();
  }

  void _addFeeLine() {
    setState(() {
      _feeLines.add(_FeeLineDraft.initial());
    });
  }

  void _removeFeeLine(int index) {
    if (_feeLines.length == 1) return;
    setState(() {
      final removed = _feeLines.removeAt(index);
      removed.amountController.dispose();
    });
  }

  void _applyRemainingToTuition(double balance) {
    if (balance <= 0 || _feeLines.isEmpty) return;
    _feeLines.first.feeHead = 'Tuition Fee';
    _feeLines.first.amountController.text = balance.toStringAsFixed(0);
    setState(() {});
  }

  Future<void> _pickPaidOn() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _paidOn,
    );
    if (picked != null) {
      setState(() => _paidOn = picked);
    }
  }

  Future<void> _createReceipt(Student student) async {
    final feeItems = <FeeItem>[];
    for (final line in _feeLines) {
      final amt = double.tryParse(line.amountController.text.trim()) ?? 0;
      if (amt > 0) {
        feeItems.add(FeeItem(feeHead: line.feeHead, amount: amt));
      }
    }
    if (feeItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one valid fee amount.')),
      );
      return;
    }
    final totalAmount = feeItems.fold<double>(0, (sum, item) => sum + item.amount);
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final receiptNo = 'FEE-${now.year}-${now.millisecondsSinceEpoch % 1000000}';
      await widget.feeRepo.addReceipt(
        FeeDraft(
          receiptNo: receiptNo,
          studentId: student.id,
          studentName: student.fullName,
          fatherName: student.guardianName,
          admissionId: student.admissionId,
          className: student.className,
          section: student.section,
          rollNo: student.rollNo,
          feeHead: feeItems.first.feeHead,
          feeItems: feeItems,
          amount: totalAmount,
          notes: _notes.text.trim(),
          paidOn: _paidOn,
        ),
      );
      if (!mounted) return;
      _notes.clear();
      for (final line in _feeLines) {
        line.amountController.dispose();
      }
      _feeLines
        ..clear()
        ..add(_FeeLineDraft.initial());
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fee receipt created.')),
      );
      widget.onBack();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _studentMatchesQuery(Student s, String q) {
    if (q.isEmpty) return false;
    final bag = [
      s.fullName,
      s.admissionId,
      s.className,
      s.section,
      s.rollNo,
      s.phone,
      s.email,
      s.guardianName,
    ].join(' ').toLowerCase();
    return bag.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat('dd MMM yyyy');
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return StreamBuilder<List<Student>>(
      stream: widget.studentRepo.watchStudents(),
      builder: (context, studentSnap) {
        if (studentSnap.hasError) {
          return Center(child: Text('Error: ${studentSnap.error}'));
        }
        if (!studentSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final students = studentSnap.data!;
        final q = _studentSearch.text.trim().toLowerCase();
        final suggestions = q.isEmpty
            ? <Student>[]
            : students.where((s) => _studentMatchesQuery(s, q)).take(8).toList(growable: false);

        final selected = students.where((s) => s.id == _selectedStudentId);
        final selectedStudent = selected.isEmpty ? null : selected.first;

        return StreamBuilder<List<FeeReceipt>>(
          stream: widget.feeRepo.watchFees(),
          builder: (context, feeSnap) {
            final allFees = feeSnap.data ?? [];
            List<FeeReceipt> receipts = [];
            var totalPaid = 0.0;
            if (selectedStudent != null) {
              receipts = allFees.where((r) => r.studentId == selectedStudent.id).toList();
              receipts.sort((a, b) {
                final ta = a.paidOn ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                final tb = b.paidOn ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                return tb.compareTo(ta);
              });
              totalPaid = receipts.fold<double>(0, (sum, r) => sum + r.amount);
            }

            final wide = MediaQuery.sizeOf(context).width >= 920;
            final cs = theme.colorScheme;
            final collectionHeader = Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.08),
                    blurRadius: 28,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                // Stack avoids Row+stretch under unbounded scroll height (see Flutter flex assert).
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [cs.primary, const Color(0xFF0D9488)],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 5),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Material(
                              color: cs.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              child: IconButton(
                                tooltip: 'Back',
                                onPressed: _saving ? null : widget.onBack,
                                icon: Icon(Icons.arrow_back_rounded, color: cs.primary),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Record collection',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    wide
                                        ? 'Search on the left — student ledger stays on the left; record this payment on the right.'
                                        : 'Search a student to open their fee ledger, then add this payment.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.hintColor,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );

            final searchCard = _SearchCard(
              controller: _studentSearch,
              focusNode: _searchFocus,
              onChanged: (_) => setState(() {}),
              onClear: _selectedStudentId != null ? _clearStudent : null,
              suggestions: suggestions,
              onPick: _selectStudent,
              selectedLabel: selectedStudent?.fullName,
              railMode: wide,
            );

            Widget buildFeeScaffold(double annualDue) {
              final balance = math.max(0.0, annualDue - totalPaid);
              final double pctPaid = annualDue > 0 ? math.min(1.0, totalPaid / annualDue) : 0.0;

              final mainColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                collectionHeader,
                const SizedBox(height: 22),
                if (!wide) ...[
                  searchCard,
                  if (selectedStudent != null) ...[
                    const SizedBox(height: 20),
                    _StudentHeroCard(
                      student: selectedStudent,
                      money: money,
                      annualPlanAmount: annualDue,
                    ),
                    const SizedBox(height: 16),
                    _FeeStatsRow(
                      annualDue: annualDue,
                      totalPaid: totalPaid,
                      balance: balance,
                      pctPaid: pctPaid,
                      money: money,
                    ),
                    if (balance > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _applyRemainingToTuition(balance),
                            icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
                            label: Text(
                              'Prefill Tuition Fee with remaining ${money.format(balance)}',
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    _PaymentHistoryCard(
                      receipts: receipts,
                      dateFmt: dateFmt,
                      money: money,
                      onView: (r) => showFeeReceiptDialog(context, r),
                    ),
                    const SizedBox(height: 22),
                  ],
                  _NewPaymentCard(
                    theme: theme,
                    dateFmt: dateFmt,
                    feeHeads: _feeHeads,
                    feeLines: _feeLines,
                    notes: _notes,
                    paidOn: _paidOn,
                    onPickDate: _pickPaidOn,
                    onAddLine: _addFeeLine,
                    onRemoveLine: _removeFeeLine,
                    onLineChanged: () => setState(() {}),
                    saving: _saving,
                    canSubmit: selectedStudent != null,
                    onSubmit: selectedStudent == null ? null : () => _createReceipt(selectedStudent),
                  ),
                ],
                if (wide) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: _SearchRailStrip.columnWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SearchRailStrip(child: searchCard),
                            const SizedBox(height: 16),
                            if (selectedStudent != null) ...[
                              _StudentHeroCard(
                                student: selectedStudent,
                                money: money,
                                compactRail: true,
                                annualPlanAmount: annualDue,
                              ),
                              const SizedBox(height: 14),
                              _FeeStatsRow(
                                annualDue: annualDue,
                                totalPaid: totalPaid,
                                balance: balance,
                                pctPaid: pctPaid,
                                money: money,
                                dense: true,
                              ),
                              const SizedBox(height: 14),
                              _PaymentHistoryCard(
                                receipts: receipts,
                                dateFmt: dateFmt,
                                money: money,
                                onView: (r) => showFeeReceiptDialog(context, r),
                                compact: true,
                              ),
                            ] else
                              _LedgerPlaceholder(theme: theme, compact: true),
                          ],
                        ),
                      ),
                      const SizedBox(width: 22),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (selectedStudent != null && balance > 0)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () => _applyRemainingToTuition(balance),
                                    icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
                                    label: Text(
                                      'Prefill Tuition Fee = ${money.format(balance)} (remaining)',
                                    ),
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'New payment',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ),
                            _NewPaymentCard(
                              theme: theme,
                              dateFmt: dateFmt,
                              feeHeads: _feeHeads,
                              feeLines: _feeLines,
                              notes: _notes,
                              paidOn: _paidOn,
                              onPickDate: _pickPaidOn,
                              onAddLine: _addFeeLine,
                              onRemoveLine: _removeFeeLine,
                              onLineChanged: () => setState(() {}),
                              saving: _saving,
                              canSubmit: selectedStudent != null,
                              onSubmit: selectedStudent == null ? null : () => _createReceipt(selectedStudent),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );

              // SizedBox.expand ensures the background paints before inner scroll layout (web hit-test).
              return ColoredBox(
                color: const Color(0xFFF0F4F8),
                child: SizedBox.expand(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1320),
                        child: mainColumn,
                      ),
                    ),
                  ),
                ),
              );
            }

            if (selectedStudent == null) {
              return buildFeeScaffold(0.0);
            }
            final sel = selectedStudent;
            return FutureBuilder<double>(
              key: ValueKey('${sel.id}-${sel.schoolClassCode}-${sel.className}'),
              future: widget.classRepo.resolveAnnualFeeFromClassMaster(
                schoolClassCode: sel.schoolClassCode,
                className: sel.className,
                fallbackAnnualFeeDue: sel.annualFeeDue,
              ),
              builder: (context, snap) {
                final annualDue = snap.data ?? sel.annualFeeDue;
                return buildFeeScaffold(annualDue);
              },
            );
          },
        );
      },
    );
  }
}

/// Left rail: gradient strip + search card (wide layout).
/// Uses [Stack] instead of [IntrinsicHeight] to avoid web mouse-tracker assertions
/// during hover hit-testing.
class _SearchRailStrip extends StatelessWidget {
  const _SearchRailStrip({required this.child});

  final Widget child;

  static const double _stripW = 6;
  /// Total width of search strip (matches [columnWidth]).
  static const double _railTotalW = 440;
  /// Left column width for ledger + search (same as rail total).
  static const double columnWidth = _railTotalW;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: _railTotalW,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: _stripW),
              child: child,
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: _stripW,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    bottomLeft: Radius.circular(22),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [cs.primary, const Color(0xFF0D9488)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LedgerPlaceholder extends StatelessWidget {
  const _LedgerPlaceholder({required this.theme, this.compact = false});

  final ThemeData theme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: compact ? 0 : 20),
      padding: EdgeInsets.symmetric(vertical: compact ? 20 : 36, horizontal: compact ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.touch_app_rounded, size: compact ? 32 : 40, color: Colors.grey.shade400),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select a student',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  'Use the search panel on the left to find a student by name, admission ID, or phone. Their ledger will load here.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.suggestions,
    required this.onPick,
    this.onClear,
    this.selectedLabel,
    this.railMode = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final List<Student> suggestions;
  final void Function(Student) onPick;
  final VoidCallback? onClear;
  final String? selectedLabel;
  final bool railMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final radius = railMode
        ? const BorderRadius.only(
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
            topLeft: Radius.circular(4),
            bottomLeft: Radius.circular(4),
          )
        : BorderRadius.circular(20);

    return Material(
      elevation: 0,
      color: Colors.white,
      borderRadius: radius,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: railMode ? 0.06 : 0.04),
              blurRadius: railMode ? 18 : 24,
              offset: Offset(0, railMode ? 6 : 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(railMode ? 14 : 16, railMode ? 16 : 14, railMode ? 12 : 12, 8),
              child: Row(
                children: [
                  Icon(Icons.person_search_rounded, color: cs.primary, size: railMode ? 22 : 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      railMode ? 'Search' : 'Find student',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: railMode ? 16 : null,
                      ),
                    ),
                  ),
                  if (onClear != null)
                    TextButton.icon(
                      onPressed: onClear,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: Icon(Icons.close_rounded, size: railMode ? 16 : 18),
                      label: Text(railMode ? 'Clear' : 'Clear'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(railMode ? 14 : 16, 0, railMode ? 14 : 16, 12),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                decoration: InputDecoration(
                  hintText: 'Name, ID, phone…',
                  filled: true,
                  fillColor: railMode ? const Color(0xFFF8FAFC) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 22),
                  isDense: railMode,
                ),
              ),
            ),
            if (suggestions.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: railMode ? 360 : 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.fromLTRB(railMode ? 10 : 12, 0, railMode ? 10 : 12, 12),
                  itemCount: suggestions.length,
                  separatorBuilder: (_, __) => SizedBox(height: railMode ? 8 : 6),
                  itemBuilder: (context, i) {
                    final s = suggestions[i];
                    return Material(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(railMode ? 12 : 14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(railMode ? 12 : 14),
                        onTap: () => onPick(s),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: railMode ? 10 : 14, vertical: railMode ? 10 : 12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: railMode ? 18 : 20,
                                backgroundColor: const Color(0xFF4D4A84).withValues(alpha: 0.15),
                                foregroundColor: const Color(0xFF4D4A84),
                                child: Text(s.fullName.isNotEmpty ? s.fullName[0].toUpperCase() : '?'),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.fullName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: railMode ? 13.5 : 14,
                                      ),
                                    ),
                                    Text(
                                      '${s.admissionId} · ${s.className}${s.section.isNotEmpty ? ' · Sec ${s.section}' : ''}',
                                      style: TextStyle(color: Colors.grey.shade700, fontSize: railMode ? 11 : 12),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: railMode ? 20 : 24),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (selectedLabel != null && suggestions.isEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(railMode ? 14 : 16, 0, railMode ? 14 : 16, 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          selectedLabel!,
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (railMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                child: Text(
                  'Tip: search narrows as you type.',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor, height: 1.3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StudentHeroCard extends StatelessWidget {
  const _StudentHeroCard({
    required this.student,
    required this.money,
    required this.annualPlanAmount,
    this.compactRail = false,
  });

  final Student student;
  final NumberFormat money;
  /// From class master (by class name); not the stale value on [student.annualFeeDue].
  final double annualPlanAmount;
  final bool compactRail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pad = compactRail ? 14.0 : 20.0;
    final av = compactRail ? 52.0 : 64.0;
    final nameStyle = compactRail
        ? theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)
        : theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compactRail ? 18 : 22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4D4A84),
            Color(0xFF2D2A55),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4D4A84).withValues(alpha: 0.35),
            blurRadius: compactRail ? 14 : 20,
            offset: Offset(0, compactRail ? 6 : 10),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: av,
              height: av,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(compactRail ? 14 : 18),
                border: Border.all(color: Colors.white24),
              ),
              alignment: Alignment.center,
              child: Text(
                student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : '?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compactRail ? 22 : 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            SizedBox(width: compactRail ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.fullName, style: nameStyle),
                  SizedBox(height: compactRail ? 4 : 6),
                  Wrap(
                    spacing: compactRail ? 6 : 8,
                    runSpacing: compactRail ? 4 : 6,
                    children: [
                      _ChipLight(icon: Icons.badge_outlined, label: student.admissionId, small: compactRail),
                      _ChipLight(
                        icon: Icons.school_outlined,
                        label:
                            'Cls ${student.className}${student.section.isNotEmpty ? ' · Sec ${student.section}' : ''} · R${student.rollNo}',
                        small: compactRail,
                      ),
                      _ChipLight(icon: Icons.circle_outlined, label: student.enrollmentStatus, small: compactRail),
                    ],
                  ),
                  SizedBox(height: compactRail ? 8 : 10),
                  Text(
                    'Guardian: ${student.guardianName.isEmpty ? '—' : student.guardianName} · ${student.phone}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: compactRail ? 11.5 : 13),
                  ),
                  if (student.email.isNotEmpty)
                    Text(
                      student.email,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: compactRail ? 10.5 : 12),
                    ),
                  SizedBox(height: compactRail ? 4 : 6),
                  Text(
                    'Annual plan: ${money.format(annualPlanAmount)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: compactRail ? 11.5 : 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipLight extends StatelessWidget {
  const _ChipLight({required this.icon, required this.label, this.small = false});

  final IconData icon;
  final String label;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: small ? 4 : 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: small ? 12 : 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: Colors.white, fontSize: small ? 10.5 : 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _FeeStatsRow extends StatelessWidget {
  const _FeeStatsRow({
    required this.annualDue,
    required this.totalPaid,
    required this.balance,
    required this.pctPaid,
    required this.money,
    this.dense = false,
  });

  final double annualDue;
  final double totalPaid;
  final double balance;
  final double pctPaid;
  final NumberFormat money;
  /// When true, always stack stat tiles (for narrow left rail).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = dense || c.maxWidth < 560;
        final tiles = [
          _StatTile(
            label: 'Total fee (plan)',
            value: money.format(annualDue),
            icon: Icons.account_balance_wallet_outlined,
            color: const Color(0xFF4D4A84),
          ),
          _StatTile(
            label: 'Paid so far',
            value: money.format(totalPaid),
            icon: Icons.payments_outlined,
            color: _FeeCollectionPageState._mint,
          ),
          _StatTile(
            label: 'Balance due',
            value: money.format(balance),
            icon: Icons.hourglass_bottom_rounded,
            color: balance > 0 ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
          ),
        ];
        if (narrow) {
          return Column(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                tiles[i],
              ],
              const SizedBox(height: 14),
              _ProgressBar(pct: pctPaid),
            ],
          );
        }
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: tiles[0]),
                const SizedBox(width: 12),
                Expanded(child: tiles[1]),
                const SizedBox(width: 12),
                Expanded(child: tiles[2]),
              ],
            ),
            const SizedBox(height: 14),
            _ProgressBar(pct: pctPaid),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.pct});

  final double pct;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress toward annual plan',
              style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w700, fontSize: 12),
            ),
            Text(
              '${(pct * 100).clamp(0, 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: Colors.grey.shade200,
            color: _FeeCollectionPageState._mint,
          ),
        ),
      ],
    );
  }
}

class _PaymentHistoryCard extends StatelessWidget {
  const _PaymentHistoryCard({
    required this.receipts,
    required this.dateFmt,
    required this.money,
    required this.onView,
    this.compact = false,
  });

  final List<FeeReceipt> receipts;
  final DateFormat dateFmt;
  final NumberFormat money;
  final void Function(FeeReceipt) onView;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pad = compact ? 12.0 : 18.0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 16 : 20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Payment history',
                  style: (compact ? theme.textTheme.titleSmall : theme.textTheme.titleMedium)
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                Text(
                  '${receipts.length} receipt${receipts.length == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (receipts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No payments recorded yet for this student.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              ...List.generate(receipts.length, (i) {
                final r = receipts[i];
                final isLast = i == receipts.length - 1;
                return _TimelineReceiptRow(
                  receipt: r,
                  dateFmt: dateFmt,
                  money: money,
                  onView: () => onView(r),
                  showLine: !isLast,
                  compact: compact,
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _TimelineReceiptRow extends StatelessWidget {
  const _TimelineReceiptRow({
    required this.receipt,
    required this.dateFmt,
    required this.money,
    required this.onView,
    required this.showLine,
    this.compact = false,
  });

  final FeeReceipt receipt;
  final DateFormat dateFmt;
  final NumberFormat money;
  final VoidCallback onView;
  final bool showLine;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final paid = receipt.paidOn ?? receipt.createdAt ?? DateTime.now();
    final dotSize = compact ? 10.0 : 12.0;
    final lineGap = compact ? 3.0 : 4.0;
    final rowPad = compact ? 10.0 : 14.0;
    final bottomPad = compact ? 10.0 : 16.0;

    final timeline = Column(
      children: [
        Container(
          width: dotSize,
          height: dotSize,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF0D9488),
            boxShadow: [
              BoxShadow(color: Color(0x660D9488), blurRadius: 6),
            ],
          ),
        ),
        if (showLine)
          Container(
            width: 2,
            height: compact ? 36 : 48,
            margin: EdgeInsets.symmetric(vertical: lineGap),
            color: Colors.grey.shade300,
          ),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        timeline,
        SizedBox(width: compact ? 10 : 14),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomPad),
            child: Container(
              padding: EdgeInsets.all(rowPad),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        dateFmt.format(paid),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          receipt.receiptNo,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade800, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        money.format(receipt.amount),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF16A34A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    receipt.feeHeadSummary,
                    style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                  ),
                  if (receipt.notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        receipt.notes,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onView,
                      icon: Icon(Icons.visibility_outlined, size: compact ? 16 : 18),
                      style: compact
                          ? TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            )
                          : null,
                      label: const Text('View receipt'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NewPaymentCard extends StatelessWidget {
  const _NewPaymentCard({
    required this.theme,
    required this.dateFmt,
    required this.feeHeads,
    required this.feeLines,
    required this.notes,
    required this.paidOn,
    required this.onPickDate,
    required this.onAddLine,
    required this.onRemoveLine,
    required this.onLineChanged,
    required this.saving,
    required this.canSubmit,
    required this.onSubmit,
  });

  final ThemeData theme;
  final DateFormat dateFmt;
  final List<String> feeHeads;
  final List<_FeeLineDraft> feeLines;
  final TextEditingController notes;
  final DateTime paidOn;
  final VoidCallback onPickDate;
  final VoidCallback onAddLine;
  final void Function(int index) onRemoveLine;
  final VoidCallback onLineChanged;
  final bool saving;
  final bool canSubmit;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.add_card_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'This payment',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              canSubmit
                  ? 'Enter particulars and amounts for the receipt you are recording now.'
                  : 'Search and select a student above to enable fee lines.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: canSubmit ? onPickDate : null,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Paid date'),
                child: Text(dateFmt.format(paidOn)),
              ),
            ),
            const SizedBox(height: 10),
            Opacity(
              opacity: canSubmit ? 1 : 0.45,
              child: AbsorbPointer(
                absorbing: !canSubmit,
                child: Column(
                  children: [
                    ...List.generate(feeLines.length, (index) {
                      final line = feeLines[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 4,
                              child: DropdownButtonFormField<String>(
                                initialValue: line.feeHead,
                                decoration: const InputDecoration(labelText: 'Particular'),
                                items: feeHeads
                                    .map(
                                      (h) => DropdownMenuItem<String>(
                                        value: h,
                                        child: Text(h),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    line.feeHead = v;
                                    onLineChanged();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: line.amountController,
                                onChanged: (_) => onLineChanged(),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Amount',
                                  prefixText: '₹ ',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Remove',
                              onPressed: feeLines.length == 1 ? null : () => onRemoveLine(index),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                          ],
                        ),
                      );
                    }),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: onAddLine,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add line'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notes,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        hintText: 'UPI ref., cheque no., etc.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: saving || !canSubmit ? null : onSubmit,
                icon: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.receipt_long_rounded),
                label: Text(saving ? 'Saving…' : 'Create receipt'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeeLineDraft {
  _FeeLineDraft({
    required this.feeHead,
    required this.amountController,
  });

  factory _FeeLineDraft.initial() {
    return _FeeLineDraft(
      feeHead: 'Tuition Fee',
      amountController: TextEditingController(),
    );
  }

  String feeHead;
  final TextEditingController amountController;
}

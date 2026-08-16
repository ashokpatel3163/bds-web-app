import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../fees/fee_repository.dart';
import '../../students/student_repository.dart';
import '../common/profile_detail_widgets.dart';
import '../fees/fee_receipt_dialog.dart';

/// Student profile — tabbed layout (Details, Fee, Academic, Family & health).
class StudentDetailPage extends StatelessWidget {
  const StudentDetailPage({
    super.key,
    required this.repo,
    required this.feeRepo,
    required this.studentId,
    required this.onBack,
    required this.onEdit,
  });

  final StudentRepository repo;
  final FeeRepository feeRepo;
  final String studentId;
  final VoidCallback onBack;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Student?>(
      stream: repo.watchStudent(studentId),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final student = snap.data;
        if (student == null) return const Center(child: Text('Student not found.'));
        return _StudentDetailBody(
          student: student,
          repo: repo,
          feeRepo: feeRepo,
          onBack: onBack,
          onEdit: onEdit,
        );
      },
    );
  }
}

class _StudentDetailBody extends StatefulWidget {
  const _StudentDetailBody({
    required this.student,
    required this.repo,
    required this.feeRepo,
    required this.onBack,
    required this.onEdit,
  });

  final Student student;
  final StudentRepository repo;
  final FeeRepository feeRepo;
  final VoidCallback onBack;
  final VoidCallback onEdit;

  @override
  State<_StudentDetailBody> createState() => _StudentDetailBodyState();
}

class _StudentDetailBodyState extends State<_StudentDetailBody> {
  static const _tabs = ['Details', 'Fee', 'Academic', 'Family & health'];
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final theme = Theme.of(context);
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final dateFmt = DateFormat('dd MMM yyyy');

    return StreamBuilder<List<FeeReceipt>>(
      stream: widget.feeRepo.watchFees(),
      builder: (context, feeSnap) {
        final all = feeSnap.data ?? [];
        var receipts = all.where((r) => r.studentId == s.id).toList();
        receipts.sort((a, b) {
          final ta = a.paidOn ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final tb = b.paidOn ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return tb.compareTo(ta);
        });
        final totalPaid = receipts.fold<double>(0, (sum, r) => sum + r.amount);
        final annual = s.annualFeeDue;
        final balance = math.max(0.0, annual - totalPaid);

        final statusBadge = s.isActive ? 'ENROLLED' : 'INACTIVE';
        final statusColor = s.isActive ? const Color(0xFF16A34A) : Colors.grey.shade600;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            ProfilePageHeader(onBack: widget.onBack, title: s.fullName),
            const SizedBox(height: 18),
            ProfileHeroCard(
              initial: s.fullName,
              name: s.fullName,
              idLabel: 'Admission',
              idValue: s.admissionId,
              rolePill:
                  '${s.enrollmentStatus} · ${s.className}${s.section.isNotEmpty ? '-${s.section}' : ''}'.toUpperCase(),
              statusBadge: statusBadge,
              statusColor: statusColor,
              onEdit: widget.onEdit,
              deactivateLabel: s.isActive ? 'Mark inactive' : 'Activate student',
              onDeactivate: () => _toggleActive(context, s),
            ),
            const SizedBox(height: 22),
            ProfileUnderlineTabs(
              labels: _tabs,
              selectedIndex: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            const SizedBox(height: 20),
            _tabPanel(
              context,
              s,
              theme,
              dateFmt,
              money,
              receipts,
              totalPaid,
              annual,
              balance,
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleActive(BuildContext context, Student s) async {
    final activate = !s.isActive;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(activate ? 'Activate student?' : 'Mark student inactive?'),
        content: Text(
          activate
              ? 'They will show as active in registers and fee workflows.'
              : 'They remain on file but show as inactive until you activate again.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await widget.repo.setStudentActive(s.id, activate);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(activate ? 'Student activated.' : 'Student marked inactive.')),
      );
    }
  }

  Widget _tabPanel(
    BuildContext context,
    Student s,
    ThemeData theme,
    DateFormat dateFmt,
    NumberFormat money,
    List<FeeReceipt> receipts,
    double totalPaid,
    double annual,
    double balance,
  ) {
    switch (_tab) {
      case 0:
        return LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 900;
            final personal = ProfileInfoSectionCard(
              icon: Icons.person_outline_rounded,
              title: 'Personal',
              rows: [
                (label: 'Date of birth', value: s.dateOfBirth),
                (label: 'Gender', value: s.gender),
                (label: 'Nationality', value: s.nationality),
                (label: 'Languages', value: s.languagesSpoken),
                (label: 'Email', value: s.email),
                (label: 'Address', value: s.address),
              ],
            );
            final academic = ProfileInfoSectionCard(
              icon: Icons.school_outlined,
              title: 'Academic snapshot',
              rows: [
                (label: 'Medium', value: s.medium),
                (label: 'Admission year', value: s.admissionYear),
                (label: 'Previous school', value: s.previousInstitution),
                (label: 'Last grade', value: s.lastGradeCompleted),
              ],
            );
            if (!wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  personal,
                  const SizedBox(height: 14),
                  academic,
                ],
              );
            }
            final gap = 16.0;
            final half = (c.maxWidth - gap) / 2;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: half, child: personal),
                SizedBox(width: gap),
                SizedBox(width: half, child: academic),
              ],
            );
          },
        );
      case 1:
        return _FeeTabPanel(
          theme: theme,
          dateFmt: dateFmt,
          money: money,
          annual: annual,
          totalPaid: totalPaid,
          balance: balance,
          receipts: receipts,
          onViewReceipt: (r) => showFeeReceiptDialog(context, r),
        );
      case 2:
        return ProfileInfoSectionCard(
          icon: Icons.menu_book_outlined,
          title: 'Academic record',
          rows: [
            (label: 'Enrollment', value: s.enrollmentStatus),
            (label: 'Admission year', value: s.admissionYear),
            (label: 'Class / section / roll', value: '${s.className} · Sec ${s.section} · ${s.rollNo}'),
            (label: 'Previous institution', value: s.previousInstitution),
            (label: 'Last grade completed', value: s.lastGradeCompleted),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileInfoSectionCard(
              icon: Icons.family_restroom_outlined,
              title: 'Guardian',
              rows: [
                (label: 'Name', value: s.guardianName),
                (label: 'Relationship', value: s.guardianRelation),
                (label: 'Mobile', value: s.phone.isEmpty ? '—' : s.phone),
                (label: 'Email (optional)', value: s.guardianEmail.isEmpty ? '—' : s.guardianEmail),
              ],
            ),
            const SizedBox(height: 14),
            ProfileInfoSectionCard(
              icon: Icons.health_and_safety_outlined,
              title: 'Medical',
              rows: [
                (label: 'Notes', value: s.medicalNotes),
              ],
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _FeeTabPanel extends StatelessWidget {
  const _FeeTabPanel({
    required this.theme,
    required this.dateFmt,
    required this.money,
    required this.annual,
    required this.totalPaid,
    required this.balance,
    required this.receipts,
    required this.onViewReceipt,
  });

  final ThemeData theme;
  final DateFormat dateFmt;
  final NumberFormat money;
  final double annual;
  final double totalPaid;
  final double balance;
  final List<FeeReceipt> receipts;
  final void Function(FeeReceipt) onViewReceipt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.payments_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Session fee summary',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _feeRow('Annual plan (session)', money.format(annual)),
              _feeRow('Paid to date', money.format(totalPaid)),
              _feeRow('Balance due', money.format(balance), emphasize: balance > 0),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt_long_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Receipts',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  Text(
                    '${receipts.length} total',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (receipts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No fee receipts yet for this student.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              else
                ...List.generate(receipts.length, (i) {
                  final r = receipts[i];
                  final paid = r.paidOn ?? r.createdAt ?? DateTime.now();
                  return Padding(
                    padding: EdgeInsets.only(bottom: i < receipts.length - 1 ? 12 : 0),
                    child: Material(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => onViewReceipt(r),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dateFmt.format(paid),
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      r.feeHeadSummary,
                                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                money.format(r.amount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _feeRow(String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: emphasize ? const Color(0xFFEA580C) : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

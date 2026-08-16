import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../staff/staff_repository.dart';
import '../common/profile_detail_widgets.dart';
import 'staff_attendance_tab.dart';

/// Staff profile — tabbed layout aligned with the school dashboard reference.
class StaffDetailPage extends StatelessWidget {
  const StaffDetailPage({
    super.key,
    required this.repo,
    required this.staffId,
    required this.onBack,
    required this.onEdit,
  });

  final StaffRepository repo;
  final String staffId;
  final VoidCallback onBack;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<StaffMember?>(
      stream: repo.watchStaffMember(staffId),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final m = snap.data;
        if (m == null) return const Center(child: Text('Staff member not found.'));
        return _StaffDetailBody(member: m, repo: repo, onBack: onBack, onEdit: onEdit);
      },
    );
  }
}

class _StaffDetailBody extends StatefulWidget {
  const _StaffDetailBody({
    required this.member,
    required this.repo,
    required this.onBack,
    required this.onEdit,
  });

  final StaffMember member;
  final StaffRepository repo;
  final VoidCallback onBack;
  final VoidCallback onEdit;

  @override
  State<_StaffDetailBody> createState() => _StaffDetailBodyState();
}

class _StaffDetailBodyState extends State<_StaffDetailBody> {
  static const _tabs = ['Details', 'Finance', 'Attendance', 'Security'];
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final dateFmt = DateFormat('dd MMM yyyy');
    final joined = m.joinedOn != null ? dateFmt.format(m.joinedOn!) : '—';
    final statusBadge = m.isActive ? 'ACTIVE' : 'INACTIVE';
    final statusColor = m.isActive ? const Color(0xFF16A34A) : Colors.grey.shade600;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        ProfilePageHeader(onBack: widget.onBack, title: m.fullName),
        const SizedBox(height: 18),
        ProfileHeroCard(
          initial: m.fullName,
          name: m.fullName,
          idLabel: 'Employee ID',
          idValue: m.employeeId.isNotEmpty ? m.employeeId : m.id,
          rolePill: m.role.label.toUpperCase(),
          statusBadge: statusBadge,
          statusColor: statusColor,
          onEdit: widget.onEdit,
          deactivateLabel: m.isActive ? 'Deactivate account' : 'Activate account',
          onDeactivate: () async {
            await _confirmToggleActive(context, m);
          },
        ),
        const SizedBox(height: 22),
        ProfileUnderlineTabs(
          labels: _tabs,
          selectedIndex: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: 20),
        _tabBody(context, m, dateFmt, joined),
      ],
    );
  }

  Future<void> _confirmToggleActive(BuildContext context, StaffMember m) async {
    final activate = !m.isActive;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(activate ? 'Activate account?' : 'Deactivate account?'),
        content: Text(
          activate
              ? 'This person will show as active in the directory and rosters.'
              : 'They will be marked inactive. You can activate again later.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await widget.repo.setStaffActive(m.id, activate);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(activate ? 'Staff activated.' : 'Staff deactivated.')),
      );
    }
  }

  Widget _tabBody(
    BuildContext context,
    StaffMember m,
    DateFormat dateFmt,
    String joined,
  ) {
    switch (_tab) {
      case 0:
        return LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 900;
            final contact = ProfileInfoSectionCard(
              icon: Icons.person_outline_rounded,
              title: 'Contact',
              rows: [
                (label: 'Work email', value: m.email),
                (label: 'Phone', value: m.phone),
                if (m.guardianName.isNotEmpty || m.guardianPhone.isNotEmpty) ...[
                  (label: 'Guardian name', value: m.guardianName.isNotEmpty ? m.guardianName : '—'),
                  (label: 'Guardian mobile', value: m.guardianPhone.isNotEmpty ? m.guardianPhone : '—'),
                ],
                if (m.emergencyContactName.isNotEmpty || m.emergencyContactPhone.isNotEmpty) ...[
                  (label: 'Emergency name', value: m.emergencyContactName.isNotEmpty ? m.emergencyContactName : '—'),
                  (label: 'Emergency mobile', value: m.emergencyContactPhone.isNotEmpty ? m.emergencyContactPhone : '—'),
                ] else if (m.emergencyContact.isNotEmpty)
                  (label: 'Emergency', value: m.emergencyContact),
              ],
            );
            final employment = ProfileInfoSectionCard(
              icon: Icons.work_outline_rounded,
              title: 'Employment',
              rows: [
                (label: 'Department', value: m.department),
                (label: 'Designation', value: m.designation),
                (label: 'Role', value: m.role.label),
                (label: 'Shift', value: m.shiftTiming),
                if (m.monthlySalary.isNotEmpty) (label: 'Monthly salary', value: m.monthlySalary),
                (label: 'Joined on', value: joined),
                (label: 'Qualification', value: m.qualification),
              ],
            );
            final address = ProfileInfoSectionCard(
              icon: Icons.place_outlined,
              title: 'Address & notes',
              rows: [
                (label: 'Address', value: m.address),
                (label: 'Notes', value: m.notes),
              ],
            );
            if (!wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  contact,
                  const SizedBox(height: 14),
                  employment,
                  const SizedBox(height: 14),
                  address,
                ],
              );
            }
            final gap = 16.0;
            final half = (c.maxWidth - gap) / 2;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: half, child: contact),
                    SizedBox(width: gap),
                    SizedBox(width: half, child: employment),
                  ],
                ),
                const SizedBox(height: 16),
                address,
              ],
            );
          },
        );
      case 1:
        return ProfilePlaceholderPanel(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Finance & payroll',
          body:
              'Salary bands, advances, reimbursements and payslips can plug in here. For now this screen is a structured placeholder so finance workflows stay consistent with the rest of the app.',
        );
      case 2:
        return StaffAttendanceTab(repo: widget.repo, vendorCode: m.id);
      case 3:
        final portalSet = widget.repo.hasPortalPassword(m.id);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileInfoSectionCard(
              icon: Icons.lock_outline_rounded,
              title: 'Portal access',
              rows: [
                (
                  label: 'Staff portal password',
                  value: portalSet ? 'Set on file (demo)' : 'Not set yet',
                ),
                (
                  label: 'Last password change',
                  value: portalSet ? 'Tracked when HR module is on' : '—',
                ),
                (
                  label: 'Recommended',
                  value: 'Use a strong passphrase and rotate each term',
                ),
              ],
            ),
            const SizedBox(height: 14),
            ProfilePlaceholderPanel(
              icon: Icons.security_rounded,
              title: 'Security policies',
              body:
                  'Optional 2FA, device limits and audit logs can be surfaced here for compliance — same layout as your reference “Security” area.',
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

import 'package:flutter/material.dart';

import '../../staff/staff_repository.dart';
import 'add_staff_page.dart';

/// Loads staff from [repo] and opens [AddStaffPage] in edit mode (same form as add).
class StaffEditPage extends StatelessWidget {
  const StaffEditPage({
    super.key,
    required this.repo,
    required this.staffId,
    required this.onBack,
    required this.onSaved,
  });

  final StaffRepository repo;
  final String staffId;
  final VoidCallback onBack;
  final VoidCallback onSaved;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<StaffMember?>(
      stream: repo.watchStaffMember(staffId),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final m = snap.data;
        if (m == null) return const Center(child: Text('Staff member not found.'));
        return AddStaffPage(
          repo: repo,
          initial: m,
          onBack: onBack,
          onSaved: onSaved,
        );
      },
    );
  }
}

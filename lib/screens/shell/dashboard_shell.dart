import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../auth/app_user.dart';
import '../../classes/school_class_repository.dart';
import '../fees/fee_collection_page.dart';
import '../fees/fees_listing_page.dart';
import '../students/new_admission_page.dart';
import '../students/students_page.dart';
import '../students/student_detail_page.dart';
import '../students/student_edit_page.dart';
import '../../staff/staff_repository.dart';
import '../../students/student_repository.dart';
import '../../fees/fee_repository.dart';
import '../staff/add_staff_page.dart';
import '../staff/staff_detail_page.dart';
import '../staff/staff_directory_page.dart';
import '../staff/staff_edit_page.dart';
import '../classes/classes_setup_page.dart';
import 'app_sidebar.dart';
import 'top_bar.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key, required this.user, required this.onLogout});

  final AppUser user;
  final VoidCallback onLogout;

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  ShellSection _section = ShellSection.dashboard;
  StudentsRoute _studentsRoute = StudentsRoute.list;
  StaffRoute _staffRoute = StaffRoute.list;
  FeesRoute _feesRoute = FeesRoute.list;
  String? _selectedStudentId;
  String? _selectedStaffId;
  late final StudentRepository _studentRepo;
  late final StaffRepository _staffRepo;
  late final FeeRepository _feeRepo;
  late final SchoolClassRepository _classRepo;

  @override
  void initState() {
    super.initState();
    _studentRepo = StudentRepository();
    _staffRepo = StaffRepository();
    _feeRepo = FeeRepository();
    _classRepo = SchoolClassRepository();
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 980;

    final content = switch (_section) {
      ShellSection.dashboard => _DashboardHome(
          studentRepo: _studentRepo,
          staffRepo: _staffRepo,
          classRepo: _classRepo,
          feeRepo: _feeRepo,
          onOpenStudents: () => setState(() {
            _section = ShellSection.students;
            _studentsRoute = StudentsRoute.list;
          }),
          onNewAdmission: () => setState(() {
            _section = ShellSection.students;
            _studentsRoute = StudentsRoute.newAdmission;
          }),
          onOpenStaff: () => setState(() {
            _section = ShellSection.staff;
            _staffRoute = StaffRoute.list;
          }),
          onAddStaff: () => setState(() {
            _section = ShellSection.staff;
            _staffRoute = StaffRoute.addStaff;
          }),
          onOpenFees: () => setState(() {
            _section = ShellSection.fees;
            _feesRoute = FeesRoute.list;
          }),
          onNewCollection: () => setState(() {
            _section = ShellSection.fees;
            _feesRoute = FeesRoute.newCollection;
          }),
          onOpenClasses: () => setState(() => _section = ShellSection.classes),
        ),
      ShellSection.students => switch (_studentsRoute) {
          StudentsRoute.list => StudentsPage(
              onViewStudent: (s) => setState(() {
                _selectedStudentId = s.id;
                _studentsRoute = StudentsRoute.view;
              }),
              onEditStudent: (s) => setState(() {
                _selectedStudentId = s.id;
                _studentsRoute = StudentsRoute.edit;
              }),
              onToggleActive: (s) async {
                await _studentRepo.setStudentActive(s.id, !s.isActive);
              },
              repo: _studentRepo,
            ),
          StudentsRoute.newAdmission => NewAdmissionPage(
              repo: _studentRepo,
              classRepo: _classRepo,
              nextAdmissionCode: '#SCH-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch % 900 + 100}',
              onBack: () => setState(() => _studentsRoute = StudentsRoute.list),
            ),
          StudentsRoute.view => StudentDetailPage(
              repo: _studentRepo,
              feeRepo: _feeRepo,
              studentId: _selectedStudentId!,
              onBack: () => setState(() => _studentsRoute = StudentsRoute.list),
              onEdit: () => setState(() => _studentsRoute = StudentsRoute.edit),
            ),
          StudentsRoute.edit => StudentEditPage(
              repo: _studentRepo,
              classRepo: _classRepo,
              studentId: _selectedStudentId!,
              onBack: () => setState(() => _studentsRoute = StudentsRoute.view),
              onSaved: () => setState(() => _studentsRoute = StudentsRoute.view),
            ),
        },
      ShellSection.staff => switch (_staffRoute) {
          StaffRoute.list => StaffDirectoryPage(
              repo: _staffRepo,
              onViewStaff: (m) => setState(() {
                _selectedStaffId = m.id;
                _staffRoute = StaffRoute.view;
              }),
            ),
          StaffRoute.view => StaffDetailPage(
              repo: _staffRepo,
              staffId: _selectedStaffId!,
              onBack: () => setState(() => _staffRoute = StaffRoute.list),
              onEdit: () => setState(() => _staffRoute = StaffRoute.edit),
            ),
          StaffRoute.edit => StaffEditPage(
              repo: _staffRepo,
              staffId: _selectedStaffId!,
              onBack: () => setState(() => _staffRoute = StaffRoute.view),
              onSaved: () => setState(() => _staffRoute = StaffRoute.view),
            ),
          StaffRoute.addStaff => AddStaffPage(
              repo: _staffRepo,
              onBack: () => setState(() => _staffRoute = StaffRoute.list),
            ),
        },
      ShellSection.fees => switch (_feesRoute) {
          FeesRoute.list => FeesListingPage(repo: _feeRepo),
          FeesRoute.newCollection => FeeCollectionPage(
              feeRepo: _feeRepo,
              studentRepo: _studentRepo,
              classRepo: _classRepo,
              onBack: () => setState(() => _feesRoute = FeesRoute.list),
            ),
        },
      ShellSection.classes => ClassesSetupPage(repo: _classRepo),
    };

    void onNav(ShellSection s) {
      setState(() {
        _section = s;
        if (_section != ShellSection.students) _studentsRoute = StudentsRoute.list;
        if (_section == ShellSection.students) _studentsRoute = StudentsRoute.list;
        if (_section != ShellSection.staff) {
          _staffRoute = StaffRoute.list;
          _selectedStaffId = null;
        }
        if (_section != ShellSection.fees) _feesRoute = FeesRoute.list;
      });
    }

    Widget topBar() =>
        _studentsTopBar() ?? _staffTopBar() ?? _feesTopBar() ?? _classesTopBar() ?? _defaultTopBar();

    if (isNarrow) {
      return Scaffold(
        drawer: Drawer(
          child: AppSidebar(
            selected: _section,
            onSelect: onNav,
            onLogout: widget.onLogout,
          ),
        ),
        body: Column(
          children: [
            topBar(),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          AppSidebar(
            selected: _section,
            onSelect: onNav,
            onLogout: widget.onLogout,
          ),
          Expanded(
            child: Column(
              children: [
                topBar(),
                Expanded(child: content),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Students section uses its own title, optional subtitle, and list shows [New admission].
  TopBar? _studentsTopBar() {
    if (_section != ShellSection.students) return null;
    return switch (_studentsRoute) {
      StudentsRoute.list => TopBar(
          title: 'Students & admissions',
          subtitle: 'Search and filter the school register — add a fresh admission when you enrol someone new.',
          right: [
            FilledButton.icon(
              onPressed: () => setState(() => _studentsRoute = StudentsRoute.newAdmission),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
              label: const Text('New admission', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      StudentsRoute.newAdmission => const TopBar(
          title: 'New admission',
          subtitle: 'Complete the form below to register a student for the current session.',
        ),
      StudentsRoute.view => const TopBar(
          title: 'Student profile',
          subtitle: 'Tabbed overview — details, fees, academic and family records.',
        ),
      StudentsRoute.edit => const TopBar(
          title: 'Edit student',
          subtitle: 'Update records and save changes.',
        ),
    };
  }

  /// Staff listing: same pattern as students — title, subtitle, primary action.
  TopBar? _staffTopBar() {
    if (_section != ShellSection.staff) return null;
    return switch (_staffRoute) {
      StaffRoute.list => TopBar(
          title: 'Staff & directory',
          subtitle:
              'Teachers and support staff on record. Filter by department and join year; open Filters for role, status and join dates.',
          right: [
            FilledButton.icon(
              onPressed: () => setState(() => _staffRoute = StaffRoute.addStaff),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
              label: const Text('Add staff', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      StaffRoute.addStaff => const TopBar(
          title: 'Add staff',
          subtitle: 'Collect employment details and optionally set a portal password for their login.',
        ),
      StaffRoute.view => const TopBar(
          title: 'Staff profile',
          subtitle: 'Details, finance placeholders, attendance and portal security.',
        ),
      StaffRoute.edit => const TopBar(
          title: 'Edit staff',
          subtitle: 'Update employment, contacts and salary — same flow as new staff, without portal password.',
        ),
    };
  }

  TopBar? _classesTopBar() {
    if (_section != ShellSection.classes) return null;
    return const TopBar(
      title: 'Classes & fee setup',
      subtitle: 'Add each class with its total annual fee. Admissions and fee collection read from this list.',
    );
  }

  TopBar? _feesTopBar() {
    if (_section != ShellSection.fees) return null;
    return switch (_feesRoute) {
      FeesRoute.list => TopBar(
          title: 'Fees & collections',
          subtitle: 'Browse recorded receipts by year and paid date — open Filters for sort and date range.',
          right: [
            FilledButton.icon(
              onPressed: () => setState(() => _feesRoute = FeesRoute.newCollection),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.receipt_long_outlined, size: 20),
              label: const Text('New collection', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      FeesRoute.newCollection => const TopBar(
          title: 'Record collection',
          subtitle: 'Choose a student, add fee heads and amounts, then create the receipt.',
        ),
    };
  }

  TopBar _defaultTopBar() {
    if (_section == ShellSection.dashboard) {
      return TopBar(
        title: 'Overview',
        subtitle:
            'Students, staff, classes and fees at a glance — tap a card or shortcut below to jump in.',
      );
    }
    return TopBar(
      title: _sectionTitle(_section),
    );
  }

  String _sectionTitle(ShellSection s) {
    return switch (s) {
      ShellSection.dashboard => 'Overview',
      ShellSection.students => 'Students',
      ShellSection.staff => 'Staff',
      ShellSection.fees => 'Fees',
      ShellSection.classes => 'Classes & setup',
    };
  }
}

enum StudentsRoute { list, newAdmission, view, edit }

enum StaffRoute { list, addStaff, view, edit }

enum FeesRoute { list, newCollection }

class _DashboardHome extends StatelessWidget {
  const _DashboardHome({
    required this.studentRepo,
    required this.staffRepo,
    required this.classRepo,
    required this.feeRepo,
    required this.onOpenStudents,
    required this.onNewAdmission,
    required this.onOpenStaff,
    required this.onAddStaff,
    required this.onOpenFees,
    required this.onNewCollection,
    required this.onOpenClasses,
  });

  final StudentRepository studentRepo;
  final StaffRepository staffRepo;
  final SchoolClassRepository classRepo;
  final FeeRepository feeRepo;
  final VoidCallback onOpenStudents;
  final VoidCallback onNewAdmission;
  final VoidCallback onOpenStaff;
  final VoidCallback onAddStaff;
  final VoidCallback onOpenFees;
  final VoidCallback onNewCollection;
  final VoidCallback onOpenClasses;

  static final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DashboardHeader(theme: theme, cs: cs),
          const SizedBox(height: 16),
          StreamBuilder<List<Student>>(
            stream: studentRepo.watchStudents(),
            builder: (context, snapS) {
              if (snapS.connectionState == ConnectionState.waiting && !snapS.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return StreamBuilder<List<StaffMember>>(
                stream: staffRepo.watchStaff(),
                builder: (context, snapSt) {
                  return StreamBuilder<List<SchoolClass>>(
                    stream: classRepo.watchClasses(),
                    builder: (context, snapC) {
                      return StreamBuilder<List<FeeReceipt>>(
                        stream: feeRepo.watchFees(),
                        builder: (context, snapF) {
                          final students = snapS.data ?? [];
                          final staff = snapSt.data ?? [];
                          final classes = snapC.data ?? [];
                          final fees = snapF.data ?? [];

                          final activeStudents = students.where((e) => e.isActive).length;
                          final activeStaff = staff.where((e) => e.isActive).length;
                          final activeClasses = classes.where((e) => e.isActive).length;
                          final totalCollected = fees.fold<double>(0, (a, b) => a + b.amount);

                          return LayoutBuilder(
                            builder: (context, c) {
                              final wide = c.maxWidth >= 960;
                              final kpiRow = wide
                                  ? Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: _CompactStatTile(
                                            icon: Icons.groups_outlined,
                                            title: 'Students',
                                            value: '${students.length}',
                                            caption: '$activeStudents active in register',
                                            accent: cs.primary,
                                            onTap: onOpenStudents,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _CompactStatTile(
                                            icon: Icons.badge_outlined,
                                            title: 'Staff',
                                            value: '${staff.length}',
                                            caption: '$activeStaff active',
                                            accent: const Color(0xFF7C3AED),
                                            onTap: onOpenStaff,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _CompactStatTile(
                                            icon: Icons.school_outlined,
                                            title: 'Classes',
                                            value: '$activeClasses',
                                            caption: '${classes.length} in master list',
                                            accent: const Color(0xFF0369A1),
                                            onTap: onOpenClasses,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _CompactStatTile(
                                            icon: Icons.account_balance_wallet_outlined,
                                            title: 'Fees collected',
                                            value: _money.format(totalCollected),
                                            caption: '${fees.length} receipts',
                                            accent: const Color(0xFF0D9488),
                                            onTap: onOpenFees,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        _CompactStatTile(
                                          icon: Icons.groups_outlined,
                                          title: 'Students',
                                          value: '${students.length}',
                                          caption: '$activeStudents active in register',
                                          accent: cs.primary,
                                          onTap: onOpenStudents,
                                        ),
                                        const SizedBox(height: 10),
                                        _CompactStatTile(
                                          icon: Icons.badge_outlined,
                                          title: 'Staff',
                                          value: '${staff.length}',
                                          caption: '$activeStaff active',
                                          accent: const Color(0xFF7C3AED),
                                          onTap: onOpenStaff,
                                        ),
                                        const SizedBox(height: 10),
                                        _CompactStatTile(
                                          icon: Icons.school_outlined,
                                          title: 'Classes',
                                          value: '$activeClasses',
                                          caption: '${classes.length} in master list',
                                          accent: const Color(0xFF0369A1),
                                          onTap: onOpenClasses,
                                        ),
                                        const SizedBox(height: 10),
                                        _CompactStatTile(
                                          icon: Icons.account_balance_wallet_outlined,
                                          title: 'Fees collected',
                                          value: _money.format(totalCollected),
                                          caption: '${fees.length} receipts',
                                          accent: const Color(0xFF0D9488),
                                          onTap: onOpenFees,
                                        ),
                                      ],
                                    );

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  kpiRow,
                                  const SizedBox(height: 22),
                                  Text(
                                    'Shortcuts',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _DashboardShortcut(
                                    icon: Icons.person_add_alt_1_outlined,
                                    title: 'New admission',
                                    subtitle: 'Register a student for the current session',
                                    accent: const Color(0xFF16A34A),
                                    onTap: onNewAdmission,
                                  ),
                                  const SizedBox(height: 8),
                                  _DashboardShortcut(
                                    icon: Icons.receipt_long_outlined,
                                    title: 'Record fee collection',
                                    subtitle: 'Create a receipt against fee heads',
                                    accent: const Color(0xFFEA580C),
                                    onTap: onNewCollection,
                                  ),
                                  const SizedBox(height: 8),
                                  _DashboardShortcut(
                                    icon: Icons.group_add_outlined,
                                    title: 'Add staff member',
                                    subtitle: 'Teachers and support on payroll',
                                    accent: const Color(0xFF7C3AED),
                                    onTap: onAddStaff,
                                  ),
                                  const SizedBox(height: 8),
                                  _DashboardShortcut(
                                    icon: Icons.menu_book_outlined,
                                    title: 'Classes & annual fees',
                                    subtitle: 'Edit the class master used in admissions',
                                    accent: const Color(0xFF0369A1),
                                    onTap: onOpenClasses,
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.theme, required this.cs});

  final ThemeData theme;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: 0.08),
            Colors.white,
            const Color(0xFF0D9488).withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.insights_rounded, color: cs.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overview',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Students, staff, classes and fee receipts — tap a card to open that area.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactStatTile extends StatelessWidget {
  const _CompactStatTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.caption,
    required this.accent,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String caption;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.hintColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      caption,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.hintColor,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardShortcut extends StatelessWidget {
  const _DashboardShortcut({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

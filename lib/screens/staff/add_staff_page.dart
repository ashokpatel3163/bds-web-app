import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../staff/staff_repository.dart';

/// Add staff — layout aligned with [NewAdmissionPage] (header, progress rail, steps, bottom submit).
/// When [initial] is set, the page works as **edit** (save via [StaffRepository.updateStaff]).
class AddStaffPage extends StatefulWidget {
  const AddStaffPage({
    super.key,
    required this.repo,
    required this.onBack,
    this.initial,
    this.onSaved,
  });

  final StaffRepository repo;
  final VoidCallback onBack;
  /// Non-null ⇒ edit existing staff ([StaffEditPage]).
  final StaffMember? initial;
  final VoidCallback? onSaved;

  @override
  State<AddStaffPage> createState() => _AddStaffPageState();
}

class _AddStaffPageState extends State<AddStaffPage> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  final _profileKey = GlobalKey();
  final _employmentKey = GlobalKey();
  final _contactsKey = GlobalKey();
  final _extraKey = GlobalKey();

  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _department = TextEditingController();
  final _designation = TextEditingController();
  StaffRole _role = StaffRole.teacher;
  var _isActive = true;
  final _joinDate = TextEditingController();
  final _address = TextEditingController();
  final _guardianName = TextEditingController();
  final _guardianPhone = TextEditingController();
  final _emergencyName = TextEditingController();
  final _emergencyPhone = TextEditingController();
  final _qualification = TextEditingController();
  final _notes = TextEditingController();
  final _shiftTiming = TextEditingController();
  final _monthlySalary = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  var _obscurePassword = true;
  var _obscureConfirm = true;
  var _saving = false;
  int _activeStep = 0;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    final ed = widget.initial;
    if (ed != null) {
      _fullName.text = ed.fullName;
      _email.text = ed.email;
      _phone.text = ed.phone;
      _department.text = ed.department;
      _designation.text = ed.designation;
      _role = ed.role;
      _isActive = ed.isActive;
      _address.text = ed.address;
      _guardianName.text = ed.guardianName;
      _guardianPhone.text = ed.guardianPhone;
      _emergencyName.text = ed.emergencyContactName;
      _emergencyPhone.text = ed.emergencyContactPhone;
      _qualification.text = ed.qualification;
      _notes.text = ed.notes;
      _shiftTiming.text = ed.shiftTiming.isNotEmpty ? ed.shiftTiming : kDefaultStaffShiftTiming;
      _monthlySalary.text = _salaryDigitsForForm(ed.monthlySalary);
      if (ed.joinedOn != null) {
        final j = ed.joinedOn!;
        _joinDate.text =
            '${j.day.toString().padLeft(2, '0')}/${j.month.toString().padLeft(2, '0')}/${j.year}';
      } else {
        final now = DateTime.now();
        _joinDate.text =
            '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
      }
    } else {
      final now = DateTime.now();
      final dd = now.day.toString().padLeft(2, '0');
      final mm = now.month.toString().padLeft(2, '0');
      _joinDate.text = '$dd/$mm/${now.year}';
      _shiftTiming.text = kDefaultStaffShiftTiming;
    }
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  String _salaryDigitsForForm(String display) {
    if (display.isEmpty) return '';
    return display.replaceAll(RegExp(r'[^\d]'), '');
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _department.dispose();
    _designation.dispose();
    _joinDate.dispose();
    _address.dispose();
    _guardianName.dispose();
    _guardianPhone.dispose();
    _emergencyName.dispose();
    _emergencyPhone.dispose();
    _qualification.dispose();
    _notes.dispose();
    _shiftTiming.dispose();
    _monthlySalary.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _onScroll() {
    final positions = <double>[
      _dyFor(_profileKey),
      _dyFor(_employmentKey),
      _dyFor(_contactsKey),
      _dyFor(_extraKey),
    ];
    if (positions.any((p) => p.isNaN)) return;

    const threshold = 140.0;
    var step = 0;
    for (var i = 0; i < positions.length; i++) {
      if (positions[i] <= threshold) step = i;
    }

    final maxScroll = _scrollController.position.hasContentDimensions ? _scrollController.position.maxScrollExtent : 0.0;
    final raw = maxScroll <= 0 ? 0.0 : (_scrollController.offset / maxScroll).clamp(0.0, 1.0);

    if (step != _activeStep || raw != _progress) {
      setState(() {
        _activeStep = step;
        _progress = raw;
      });
    }
  }

  double _dyFor(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return double.nan;
    final box = ctx.findRenderObject();
    if (box is! RenderBox) return double.nan;
    return box.localToGlobal(Offset.zero).dy;
  }

  Future<void> _scrollTo(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic, alignment: 0.08);
  }

  Future<void> _pickJoinDate() async {
    final now = DateTime.now();
    final initial = _parseDob(_joinDate.text) ?? now;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1990),
      lastDate: DateTime(now.year + 1),
      initialDate: initial,
    );
    if (picked == null) return;
    final dd = picked.day.toString().padLeft(2, '0');
    final mm = picked.month.toString().padLeft(2, '0');
    _joinDate.text = '$dd/$mm/${picked.year}';
    setState(() {});
  }

  DateTime? _parseDob(String raw) {
    final p = raw.trim().split('/');
    if (p.length != 3) return null;
    final d = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final y = int.tryParse(p[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }

  String? _validatePassword(String? _) {
    final a = _password.text;
    final b = _confirmPassword.text;
    if (a.isEmpty && b.isEmpty) return null;
    if (a.length < 8) return 'At least 8 characters if setting a password';
    if (a != b) return 'Passwords do not match';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final email = _email.text.trim();
      if (email.isNotEmpty && !email.contains('@')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid email.')));
        }
        return;
      }
      final pw = _password.text.trim();
      final cw = _confirmPassword.text.trim();
      if (pw.isNotEmpty || cw.isNotEmpty) {
        if (pw.length < 8 || pw != cw) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fix password fields or clear both.')));
          }
          return;
        }
      }

      final draft = StaffDraft(
        fullName: _fullName.text,
        email: _email.text,
        phone: _phone.text,
        department: _department.text,
        designation: _designation.text,
        role: _role,
        isActive: _isActive,
        joinedOn: _parseDob(_joinDate.text),
        address: _address.text,
        guardianName: _guardianName.text,
        guardianPhone: _guardianPhone.text,
        emergencyContactName: _emergencyName.text,
        emergencyContactPhone: _emergencyPhone.text,
        qualification: _qualification.text,
        notes: _notes.text,
        shiftTiming: _shiftTiming.text,
        monthlySalary: _monthlySalary.text,
      );

      final initial = widget.initial;
      if (initial != null) {
        final err = await widget.repo.updateStaff(
          vendorCode: initial.id,
          draft: draft,
          current: initial,
        );
        if (err != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
          }
          return;
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff updated.')));
        widget.onSaved?.call();
        return;
      }

      final (err, newEmployeeId) = await widget.repo.addStaff(draft, portalPassword: pw.isEmpty ? null : pw);
      if (err != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        }
        return;
      }

      if (!mounted) return;
      final okMsg = (newEmployeeId != null && newEmployeeId.isNotEmpty)
          ? 'Staff member added. Employee ID: $newEmployeeId'
          : 'Staff member added.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(okMsg)));
      widget.onBack();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isWide = MediaQuery.of(context).size.width >= 1100;
    final isNarrow = MediaQuery.of(context).size.width < 760;
    final isEdit = widget.initial != null;

    final stepsColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.primary.withValues(alpha: 0.12),
                    const Color(0xFF0D9488).withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.badge_outlined, color: cs.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEdit ? 'Edit staff' : 'Add staff',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEdit ? 'Update checklist' : 'Onboarding checklist',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _StepItem(
          index: '01',
          label: 'Profile & contact',
          active: _activeStep == 0,
          onTap: () => _scrollTo(_profileKey),
        ),
        _StepItem(
          index: '02',
          label: 'Employment',
          active: _activeStep == 1,
          onTap: () => _scrollTo(_employmentKey),
        ),
        _StepItem(
          index: '03',
          label: 'Guardian & emergency',
          active: _activeStep == 2,
          onTap: () => _scrollTo(_contactsKey),
        ),
        _StepItem(
          index: '04',
          label: 'Address & portal',
          active: _activeStep == 3,
          onTap: () => _scrollTo(_extraKey),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
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
                  Icon(Icons.tips_and_updates_outlined, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Text('Tips', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                isEdit
                    ? 'Portal password is unchanged here — use HR tools or a future reset flow if needed.'
                    : 'Set a portal password so they can sign in later, or leave blank and assign later.',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade700, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );

    final leftSteps = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: isWide ? SingleChildScrollView(child: stepsColumn) : stepsColumn,
      ),
    );

    final header = Container(
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
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [cs.primary, const Color(0xFF0D9488)],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
                  child: Row(
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
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isEdit ? 'Edit staff member' : 'Add staff member',
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.3),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isEdit
                                  ? 'Update employment and contact details — save from the bottom bar.'
                                  : 'Capture details and optionally set their portal password — submit from the bottom bar.',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, height: 1.4),
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
      ),
    );

    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: header,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: _StaffProgressRail(progress: _progress),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isWide) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 20, right: 14, bottom: 16),
                        child: SizedBox(width: 320, child: leftSteps),
                      ),
                    ],
                    Expanded(
                      child: ListView(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(20, 0, 20, isNarrow ? 110 : 96),
                        children: [
                          if (!isNarrow) ...[] else ...[
                            leftSteps,
                            const SizedBox(height: 14),
                          ],
                          _buildSections(cs, isEdit),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _StaffBottomBar(
              saving: _saving,
              onBack: widget.onBack,
              onSubmit: _save,
              submitLabel: widget.initial != null ? 'Save changes' : 'Add to directory',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSections(ColorScheme cs, bool isEdit) {
    final theme = Theme.of(context);
    return Column(
      children: [
        _SectionCard(
          key: _profileKey,
          title: '01. Profile & contact',
          trailing: _Pill(text: 'REQUIRED', color: cs.primary),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Employee ID is generated automatically when you save.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700, height: 1.35),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _fullName,
                decoration: const InputDecoration(labelText: 'Full name *', hintText: 'e.g. Ananya Rao'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              _TwoCol(
                left: TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Work email *', hintText: 'name@school.edu'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
                right: TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone *', hintText: '+91 …'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          key: _employmentKey,
          title: '02. Employment',
          trailing: _Pill(text: 'REQUIRED', color: cs.primary),
          child: Column(
            children: [
              _TwoCol(
                left: TextFormField(
                  controller: _department,
                  decoration: const InputDecoration(labelText: 'Department *', hintText: 'e.g. Science'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
                right: TextFormField(
                  controller: _designation,
                  decoration: const InputDecoration(labelText: 'Designation *', hintText: 'e.g. PGT Physics'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _shiftTiming,
                decoration: const InputDecoration(
                  labelText: 'Shift timing',
                  hintText: '7:30 AM — 1:00 PM',
                  helperText: 'Default filled — adjust if needed (India time)',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _monthlySalary,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monthly salary (INR)',
                  hintText: 'e.g. 45000',
                  helperText: 'Optional — visible to staff in the mobile app',
                ),
              ),
              const SizedBox(height: 16),
              _TwoCol(
                left: isEdit
                    ? InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          helperText: 'Account type (teacher/worker) is fixed after creation',
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 4),
                          child: Text(
                            _role.label,
                            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      )
                    : DropdownButtonFormField<StaffRole>(
                        initialValue: _role,
                        decoration: const InputDecoration(labelText: 'Role *'),
                        items: const [
                          DropdownMenuItem(value: StaffRole.teacher, child: Text('Teacher')),
                          DropdownMenuItem(value: StaffRole.adminStaff, child: Text('Admin')),
                          DropdownMenuItem(value: StaffRole.support, child: Text('Support')),
                        ],
                        onChanged: (v) => setState(() => _role = v ?? StaffRole.teacher),
                      ),
                right: TextFormField(
                  controller: _joinDate,
                  readOnly: true,
                  onTap: _pickJoinDate,
                  decoration: const InputDecoration(
                    labelText: 'Join date',
                    hintText: 'DD/MM/YYYY',
                    suffixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilterChip(
                  label: Text(_isActive ? 'Active on roster' : 'Inactive'),
                  selected: _isActive,
                  onSelected: (v) => setState(() => _isActive = v),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          key: _contactsKey,
          title: '03. Guardian & emergency',
          trailing: _Pill(text: 'OPTIONAL', color: Colors.grey.shade600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SubsectionHeading(
                icon: Icons.family_restroom_outlined,
                title: 'Guardian / family contact',
                subtitle: 'Same idea as student admissions — who to reach for personal matters.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _guardianName,
                decoration: const InputDecoration(
                  labelText: 'Guardian name',
                  hintText: 'e.g. Parent or spouse',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _guardianPhone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Guardian mobile',
                  hintText: '10-digit number',
                ),
              ),
              const SizedBox(height: 22),
              Divider(height: 1, color: Colors.grey.shade200),
              const SizedBox(height: 18),
              _SubsectionHeading(
                icon: Icons.health_and_safety_outlined,
                title: 'Emergency contact',
                subtitle: 'Someone we can call in an urgent situation at work.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emergencyName,
                decoration: const InputDecoration(
                  labelText: 'Emergency contact name',
                  hintText: 'Full name',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emergencyPhone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Emergency mobile',
                  hintText: '10-digit number',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          key: _extraKey,
          title: isEdit ? '04. Address & notes' : '04. Address, notes & portal',
          trailing: _Pill(text: 'OPTIONAL', color: Colors.grey.shade600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _address,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Residential address',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _qualification,
                decoration: const InputDecoration(
                  labelText: 'Qualification',
                  hintText: 'Degrees, certifications',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Internal notes',
                  hintText: 'Visa, background check, etc.',
                ),
              ),
              if (!isEdit) ...[
                const SizedBox(height: 20),
                Text('Portal password', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  'Optional. Min 8 characters. They can use this to sign in to the staff portal when enabled.',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                _TwoCol(
                  left: TextFormField(
                    controller: _password,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        tooltip: 'Show',
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      ),
                    ),
                    validator: _validatePassword,
                  ),
                  right: TextFormField(
                    controller: _confirmPassword,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm password',
                      suffixIcon: IconButton(
                        tooltip: 'Show',
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      ),
                    ),
                    validator: _validatePassword,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SubsectionHeading extends StatelessWidget {
  const _SubsectionHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StaffProgressRail extends StatelessWidget {
  const _StaffProgressRail({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = progress.clamp(0.0, 1.0);
    return SizedBox(
      height: 8,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth * v;
          return ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: Colors.grey.shade200),
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  tween: Tween<double>(end: w),
                  builder: (context, animW, _) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: animW.clamp(0.0, constraints.maxWidth),
                        height: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [cs.primary, const Color(0xFF0D9488)],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StaffBottomBar extends StatelessWidget {
  const _StaffBottomBar({
    required this.saving,
    required this.onBack,
    required this.onSubmit,
    this.submitLabel = 'Add to directory',
  });

  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onSubmit;
  final String submitLabel;

  static const _green = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9).withValues(alpha: 0.82),
            border: Border(top: BorderSide(color: Colors.grey.shade300.withValues(alpha: 0.6))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                offset: const Offset(0, -6),
                blurRadius: 18,
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: saving ? null : onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      elevation: saving ? 0 : 2,
                      shadowColor: _green.withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: saving ? null : onSubmit,
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_rounded, size: 22),
                    label: Text(
                      saving ? 'Please wait…' : submitLabel,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({super.key, required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _TwoCol extends StatelessWidget {
  const _TwoCol({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 760;
    if (narrow) {
      return Column(
        children: [
          left,
          const SizedBox(height: 12),
          right,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11),
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({
    required this.index,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String index;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bg = active ? cs.primary.withValues(alpha: 0.10) : Colors.transparent;
    final fg = active ? cs.primary : Colors.grey.shade700;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? cs.primary.withValues(alpha: 0.25) : Colors.transparent,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active ? cs.primary : Colors.grey.shade200,
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: cs.primary.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      index,
                      style: TextStyle(
                        color: active ? Colors.white : Colors.grey.shade800,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 13.5))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

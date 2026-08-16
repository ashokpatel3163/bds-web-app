import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../classes/school_class_repository.dart';
import '../../students/student_repository.dart';

/// Section is stored on the student profile as one of these (add + view).
const _kStudentSectionOptions = ['A', 'B', 'C', 'D'];

String _normalizeStudentSection(String? raw) {
  final t = (raw ?? '').trim();
  if (_kStudentSectionOptions.contains(t)) return t;
  return 'A';
}

enum StudentFormMode { create, edit }

class NewAdmissionPage extends StatelessWidget {
  const NewAdmissionPage({
    super.key,
    required this.repo,
    required this.classRepo,
    required this.nextAdmissionCode,
    required this.onBack,
  });

  final StudentRepository repo;
  final SchoolClassRepository classRepo;
  final String nextAdmissionCode;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return StudentFormPage(
      mode: StudentFormMode.create,
      repo: repo,
      classRepo: classRepo,
      nextAdmissionCode: nextAdmissionCode,
      onBack: onBack,
      onSaved: onBack,
    );
  }
}

class StudentFormPage extends StatefulWidget {
  const StudentFormPage({
    super.key,
    required this.mode,
    required this.repo,
    required this.classRepo,
    required this.onBack,
    required this.onSaved,
    this.nextAdmissionCode,
    this.studentId,
    this.initial,
  });

  final StudentFormMode mode;
  final StudentRepository repo;
  final SchoolClassRepository classRepo;
  final VoidCallback onBack;
  final VoidCallback onSaved;

  // create-mode
  final String? nextAdmissionCode;

  // edit-mode
  final String? studentId;
  final StudentDraft? initial;

  @override
  State<StudentFormPage> createState() => _StudentFormPageState();
}

class _StudentFormPageState extends State<StudentFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  final _personalKey = GlobalKey();
  final _academicKey = GlobalKey();
  final _guardianKey = GlobalKey();
  final _medicalKey = GlobalKey();

  final _admissionId = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _dateOfBirth = TextEditingController();
  String _gender = 'Prefer not to say';
  final _nationality = TextEditingController();
  final _languages = TextEditingController();
  String _medium = 'English';
  final _className = TextEditingController();
  final _annualFeeDue = TextEditingController();
  final _rollNo = TextEditingController();
  String _status = 'Active';
  final _admissionYear = TextEditingController(text: '${DateTime.now().year}');
  final _previousInstitution = TextEditingController();
  final _lastGradeCompleted = TextEditingController();
  final _guardianName = TextEditingController();
  final _guardianRelation = TextEditingController();
  final _guardianEmail = TextEditingController();
  final _guardianPhone = TextEditingController();
  final _address = TextEditingController();
  final _medicalNotes = TextEditingController();

  var _saving = false;
  int _activeStep = 0;
  double _progress = 0;

  List<SchoolClass> _classes = [];
  var _classesLoading = true;
  String? _selectedClassCode;

  /// One of [_kStudentSectionOptions].
  String _section = 'A';

  @override
  void initState() {
    super.initState();
    if (widget.mode == StudentFormMode.create) {
      _admissionId.text = widget.nextAdmissionCode ?? '';
    } else {
      final initial = widget.initial;
      if (initial != null) {
        _admissionId.text = initial.admissionId;
        _email.text = initial.email;
        _dateOfBirth.text = initial.dateOfBirth;
        _gender = initial.gender.isEmpty ? _gender : initial.gender;
        _nationality.text = initial.nationality;
        _languages.text = initial.languagesSpoken;
        _medium = initial.medium.isEmpty ? _medium : initial.medium;
        _className.text = initial.className;
        _section = _normalizeStudentSection(initial.section);
        _rollNo.text = initial.rollNo;
        _status = initial.enrollmentStatus.isEmpty ? _status : initial.enrollmentStatus;
        _admissionYear.text = initial.admissionYear.isEmpty ? _admissionYear.text : initial.admissionYear;
        _previousInstitution.text = initial.previousInstitution;
        _lastGradeCompleted.text = initial.lastGradeCompleted;
        _annualFeeDue.text = initial.annualFeeDue > 0 ? initial.annualFeeDue.round().toString() : '';
        _guardianName.text = initial.guardianName;
        _guardianRelation.text = initial.guardianRelation;
        _guardianEmail.text = initial.guardianEmail;
        _guardianPhone.text = initial.phone;
        _address.text = initial.address;
        _medicalNotes.text = initial.medicalNotes;

        // Split full name into first/last best-effort
        final parts = initial.fullName.trim().split(RegExp(r'\s+'));
        if (parts.isNotEmpty) {
          _firstName.text = parts.first;
          if (parts.length > 1) _lastName.text = parts.sublist(1).join(' ');
        }
      }
    }
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    try {
      final list = await widget.classRepo.fetchClasses();
      if (!mounted) return;
      setState(() {
        _classes = list;
        _classesLoading = false;
        _applyInitialClassSelection();
      });
    } catch (_) {
      if (mounted) setState(() => _classesLoading = false);
    }
  }

  void _applyInitialClassSelection() {
    if (widget.mode != StudentFormMode.edit || widget.initial == null) return;
    final i = widget.initial!;
    if (i.schoolClassCode.isNotEmpty) {
      final exists = _classes.any((c) => c.code == i.schoolClassCode);
      if (exists) {
        _selectedClassCode = i.schoolClassCode;
        _alignClassNameWithMaster(i.schoolClassCode);
        return;
      }
    }
    for (final c in _classes) {
      if (c.name == i.className.trim()) {
        _selectedClassCode = c.code;
        _alignClassNameWithMaster(c.code);
        return;
      }
    }
  }

  /// On edit load only: set class name from master without overwriting saved annual fee.
  void _alignClassNameWithMaster(String code) {
    if (code.isEmpty) return;
    for (final x in _classes) {
      if (x.code == code) {
        _className.text = x.name;
        return;
      }
    }
  }

  void _syncFieldsFromClass(String code) {
    if (code.isEmpty) return;
    SchoolClass? found;
    for (final x in _classes) {
      if (x.code == code) {
        found = x;
        break;
      }
    }
    if (found == null) return;
    _className.text = found.name;
    // Do not auto-fill tuition / annual fee from class master.
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _admissionId.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _dateOfBirth.dispose();
    _nationality.dispose();
    _languages.dispose();
    _className.dispose();
    _rollNo.dispose();
    _admissionYear.dispose();
    _previousInstitution.dispose();
    _lastGradeCompleted.dispose();
    _guardianName.dispose();
    _guardianRelation.dispose();
    _guardianEmail.dispose();
    _guardianPhone.dispose();
    _address.dispose();
    _medicalNotes.dispose();
    _annualFeeDue.dispose();
    super.dispose();
  }

  void _onScroll() {
    final positions = <double>[
      _dyFor(_personalKey),
      _dyFor(_academicKey),
      _dyFor(_guardianKey),
      _dyFor(_medicalKey),
    ];

    // Ignore until layout is ready.
    if (positions.any((p) => p.isNaN)) return;

    // Active step is the last section whose top is above a threshold.
    final threshold = 140.0;
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
    final pos = box.localToGlobal(Offset.zero);
    return pos.dy;
  }

  Future<void> _scrollTo(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic, alignment: 0.08);
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1980),
      lastDate: DateTime(now.year + 1),
      initialDate: DateTime(now.year - 10, 1, 1),
    );
    if (picked == null) return;
    final dd = picked.day.toString().padLeft(2, '0');
    final mm = picked.month.toString().padLeft(2, '0');
    final yyyy = picked.year.toString();
    _dateOfBirth.text = '$dd/$mm/$yyyy';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final email = _email.text.trim();
      if (email.isNotEmpty && !email.contains('@')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid student email.')));
        }
        return;
      }
      final guardianPhone = _guardianPhone.text.trim();
      if (guardianPhone.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardian mobile number is required.')));
          await _scrollTo(_guardianKey);
        }
        return;
      }
      if (!RegExp(r'^[6-9]\d{9}$').hasMatch(guardianPhone)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid 10-digit guardian mobile number.')));
          await _scrollTo(_guardianKey);
        }
        return;
      }
      final guardianEmail = _guardianEmail.text.trim();
      if (guardianEmail.isNotEmpty && !guardianEmail.contains('@')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid guardian email or leave it empty.')));
        }
        return;
      }

      final annualFeeDue = widget.mode == StudentFormMode.create
          ? 0.0
          : (double.tryParse(_annualFeeDue.text.trim()) ?? 0);
      final draft = StudentDraft(
        admissionId: _admissionId.text,
        fullName: '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim(),
        email: _email.text,
        dateOfBirth: _dateOfBirth.text,
        gender: _gender,
        nationality: _nationality.text,
        languagesSpoken: _languages.text,
        medium: _medium,
        schoolClassCode: _selectedClassCode ?? '',
        className: _className.text,
        section: _section,
        rollNo: _rollNo.text,
        enrollmentStatus: _status,
        admissionYear: _admissionYear.text,
        previousInstitution: _previousInstitution.text,
        lastGradeCompleted: _lastGradeCompleted.text,
        guardianName: _guardianName.text,
        guardianRelation: _guardianRelation.text,
        guardianEmail: _guardianEmail.text,
        phone: _guardianPhone.text,
        address: _address.text,
        medicalNotes: _medicalNotes.text,
        annualFeeDue: annualFeeDue,
      );

      if (widget.mode == StudentFormMode.create) {
        await widget.repo.addStudent(draft);
      } else {
        await widget.repo.updateStudent(widget.studentId!, draft);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.mode == StudentFormMode.create ? 'Student added successfully.' : 'Student updated.')),
      );
      widget.onSaved();
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
    final isCreate = widget.mode == StudentFormMode.create;
    final pageTitle = isCreate ? 'New admission' : 'Edit student';
    final pageSubtitle = isCreate
        ? 'Fill every section — submit once from the bar at the bottom.'
        : 'Update the fields you need, then save from the bottom bar.';

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
              child: Icon(
                isCreate ? Icons.person_add_alt_1_rounded : Icons.edit_note_rounded,
                color: cs.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pageTitle,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isCreate ? 'Registry checklist' : 'Student record',
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
          label: 'Personal info',
          active: _activeStep == 0,
          onTap: () => _scrollTo(_personalKey),
        ),
        _StepItem(
          index: '02',
          label: 'Academic',
          active: _activeStep == 1,
          onTap: () => _scrollTo(_academicKey),
        ),
        _StepItem(
          index: '03',
          label: 'Guardian',
          active: _activeStep == 2,
          onTap: () => _scrollTo(_guardianKey),
        ),
        _StepItem(
          index: '04',
          label: 'Medical',
          active: _activeStep == 3,
          onTap: () => _scrollTo(_medicalKey),
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
                  Text(
                    'Guidelines',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const _Guideline(text: 'Use legal naming conventions.'),
              const _Guideline(text: 'High-resolution profile photo recommended.'),
              const _Guideline(text: 'Verify academic records/transcripts.'),
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
                              pageTitle,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pageSubtitle,
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
              child: _AnimatedProgressRail(progress: _progress),
            ),
          // Scrollable content
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
                        if (!isWide) ...[
                          leftSteps,
                          const SizedBox(height: 14),
                        ],
                        _buildFormSections(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Single primary submit — only here (not duplicated in header)
          _BottomActionBar(
            saving: _saving,
            primaryLabel: isCreate ? 'Submit admission' : 'Save changes',
            onBack: widget.onBack,
            onSubmit: _save,
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildFormSections() {
    return Column(
      children: [
        _SectionCard(
          key: _personalKey,
          title: '01. Personal Identity',
          trailing: const _Pill(text: 'REQUIRED SECTION'),
          child: Column(
            children: [
              _TwoCol(
                left: _PhotoUploadCard(onTap: () {}),
                right: Column(
                  children: [
                    _TwoCol(
                      left: TextFormField(
                        controller: _firstName,
                        decoration: const InputDecoration(labelText: 'First name *', hintText: 'e.g. Julian'),
                        validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                      ),
                      right: TextFormField(
                        controller: _lastName,
                        decoration: const InputDecoration(labelText: 'Last name *', hintText: 'e.g. Sterling'),
                        validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _TwoCol(
                      left: TextFormField(
                        controller: _dateOfBirth,
                        readOnly: true,
                        onTap: _pickDob,
                        decoration: const InputDecoration(
                          labelText: 'Date of birth',
                          hintText: 'DD/MM/YYYY',
                          suffixIcon: Icon(Icons.calendar_month_outlined),
                        ),
                      ),
                      right: DropdownButtonFormField<String>(
                        initialValue: _gender,
                        decoration: const InputDecoration(labelText: 'Gender identity'),
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(value: 'Female', child: Text('Female')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                          DropdownMenuItem(value: 'Prefer not to say', child: Text('Prefer not to say')),
                        ],
                        onChanged: (v) => setState(() => _gender = v ?? 'Prefer not to say'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _TwoCol(
                left: TextFormField(
                  controller: _admissionId,
                  decoration: const InputDecoration(labelText: 'Admission ID *'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
                right: TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email address'),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(labelText: 'Residential address', hintText: 'Street, Building, Unit Number...'),
                minLines: 1,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              _TwoCol(
                left: TextFormField(
                  controller: _nationality,
                  decoration: const InputDecoration(labelText: 'Nationality', hintText: 'e.g. British'),
                ),
                right: TextFormField(
                  controller: _languages,
                  decoration: const InputDecoration(labelText: 'Language(s) spoken', hintText: 'e.g. English, French'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          key: _academicKey,
          title: '02. Academic Background',
          trailing: const _Pill(text: 'ARCHIVE DATA'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.mode == StudentFormMode.create
                    ? 'Pick a school class from Classes & setup. Section A–D is for grouping only. Annual fee can be set when you edit the student.'
                    : 'Pick a school class from Classes & setup. Tuition fee is not filled automatically — enter it below. Section A–D is for grouping only.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700, height: 1.35),
              ),
              const SizedBox(height: 12),
              if (_classesLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_classes.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  key: ValueKey<String>('school-class-${_selectedClassCode ?? 'none'}'),
                  initialValue: _selectedClassCode,
                  decoration: const InputDecoration(labelText: 'School class *'),
                  items: [
                    for (final c in _classes)
                      DropdownMenuItem(
                        value: c.code,
                        child: Text(c.displayLabel),
                      ),
                  ],
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Select a class' : null,
                  onChanged: (v) async {
                    setState(() {
                      _selectedClassCode = v;
                      if (v != null && v.isNotEmpty) {
                        _syncFieldsFromClass(v);
                      }
                    });
                    if (widget.mode == StudentFormMode.edit &&
                        widget.studentId != null &&
                        v != null &&
                        v.isNotEmpty) {
                      final fee = double.tryParse(_annualFeeDue.text.trim()) ?? 0;
                      try {
                        await widget.repo.mergeStudentProfile(widget.studentId!, {
                          'schoolClassCode': v,
                          'className': _className.text.trim(),
                          'section': _section,
                          'annualFeeDue': fee,
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Class saved.')),
                          );
                        }
                      } catch (_) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not save class. Use Save at the bottom.')),
                          );
                        }
                      }
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _className,
                  readOnly: _selectedClassCode != null && _selectedClassCode!.isNotEmpty,
                  decoration: const InputDecoration(
                    labelText: 'Class name (from selection)',
                    hintText: 'Filled from class master',
                  ),
                ),
                const SizedBox(height: 12),
                _sectionDropdown(),
              ] else ...[
                TextFormField(
                  controller: _className,
                  decoration: const InputDecoration(labelText: 'Class name *', hintText: 'e.g. Class 5'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                _sectionDropdown(),
              ],
              const SizedBox(height: 12),
              if (widget.mode == StudentFormMode.create)
                DropdownButtonFormField<String>(
                  initialValue: _medium,
                  decoration: const InputDecoration(labelText: 'Medium *'),
                  items: const [
                    DropdownMenuItem(value: 'Hindi', child: Text('Hindi')),
                    DropdownMenuItem(value: 'English', child: Text('English')),
                  ],
                  onChanged: (v) => setState(() => _medium = v ?? 'English'),
                )
              else
                _TwoCol(
                  left: TextFormField(
                    controller: _annualFeeDue,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Total annual fee (₹) *',
                      hintText: 'Enter manually',
                    ),
                    onEditingComplete: () async {
                      if (widget.studentId == null) return;
                      final fee = double.tryParse(_annualFeeDue.text.trim());
                      if (fee == null || fee < 0) return;
                      try {
                        await widget.repo.mergeStudentProfile(widget.studentId!, {'annualFeeDue': fee});
                      } catch (_) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not save fee. Use Save at the bottom.')),
                          );
                        }
                      }
                    },
                    validator: (v) {
                      final n = double.tryParse((v ?? '').trim());
                      if (n == null || n < 0) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                  right: DropdownButtonFormField<String>(
                    initialValue: _medium,
                    decoration: const InputDecoration(labelText: 'Medium *'),
                    items: const [
                      DropdownMenuItem(value: 'Hindi', child: Text('Hindi')),
                      DropdownMenuItem(value: 'English', child: Text('English')),
                    ],
                    onChanged: (v) => setState(() => _medium = v ?? 'English'),
                  ),
                ),
              const SizedBox(height: 12),
              _TwoCol(
                left: TextFormField(
                  controller: _rollNo,
                  decoration: const InputDecoration(labelText: 'Roll number (optional)'),
                ),
                right: DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Enrollment status'),
                  items: const [
                    DropdownMenuItem(value: 'Active', child: Text('Active')),
                    DropdownMenuItem(value: 'On Leave', child: Text('On Leave')),
                    DropdownMenuItem(value: 'Probation', child: Text('Probation')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'Active'),
                ),
              ),
              const SizedBox(height: 12),
              _TwoCol(
                left: DropdownButtonFormField<String>(
                  initialValue: _admissionYear.text.trim().isEmpty ? '${DateTime.now().year}' : _admissionYear.text.trim(),
                  decoration: const InputDecoration(labelText: 'Admission year'),
                  items: List.generate(8, (i) => (DateTime.now().year - i).toString())
                      .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                      .toList(growable: false),
                  onChanged: (v) {
                    _admissionYear.text = v ?? '';
                    setState(() {});
                  },
                ),
                right: TextFormField(
                  controller: _lastGradeCompleted,
                  decoration: const InputDecoration(labelText: 'Last grade completed'),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _previousInstitution,
                decoration: const InputDecoration(labelText: 'Previous institution'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          key: _guardianKey,
          title: '03. Guardian Information',
          trailing: const _Pill(text: 'REQUIRED SECTION'),
          child: Column(
            children: [
              _TwoCol(
                left: TextFormField(
                  controller: _guardianName,
                  decoration: const InputDecoration(labelText: 'Primary guardian name *'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
                right: DropdownButtonFormField<String>(
                  initialValue: (_guardianRelation.text.trim().isEmpty) ? 'Mother' : _guardianRelation.text.trim(),
                  decoration: const InputDecoration(labelText: 'Relationship'),
                  items: const [
                    DropdownMenuItem(value: 'Mother', child: Text('Mother')),
                    DropdownMenuItem(value: 'Father', child: Text('Father')),
                    DropdownMenuItem(value: 'Guardian', child: Text('Guardian')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (v) {
                    _guardianRelation.text = v ?? '';
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(height: 12),
              _TwoCol(
                left: TextFormField(
                  controller: _guardianPhone,
                  decoration: const InputDecoration(
                    labelText: 'Guardian mobile *',
                    hintText: '10-digit number',
                  ),
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return 'Guardian mobile is required';
                    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(s)) {
                      return 'Valid 10-digit Indian mobile';
                    }
                    return null;
                  },
                ),
                right: TextFormField(
                  controller: _guardianEmail,
                  decoration: const InputDecoration(
                    labelText: 'Guardian email (optional)',
                    hintText: 'Leave blank if none',
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          key: _medicalKey,
          title: '04. Medical Registry',
          trailing: const _Pill(text: 'OPTIONAL'),
          child: TextFormField(
            controller: _medicalNotes,
            decoration: const InputDecoration(
              labelText: 'Known allergies or medical conditions',
              hintText: 'Add important health notes here...',
            ),
            minLines: 3,
            maxLines: 5,
          ),
        ),
      ],
    );
  }

  Widget _sectionDropdown() {
    return DropdownButtonFormField<String>(
      value: _section,
      decoration: const InputDecoration(
        labelText: 'Section *',
        hintText: 'A, B, C, or D',
      ),
      items: [
        for (final sec in _kStudentSectionOptions)
          DropdownMenuItem<String>(value: sec, child: Text('Section $sec')),
      ],
      onChanged: (v) async {
        if (v == null) return;
        setState(() => _section = v);
        if (widget.mode == StudentFormMode.edit && widget.studentId != null) {
          try {
            await widget.repo.mergeStudentProfile(widget.studentId!, {'section': v});
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not save section. Use Save at the bottom.')),
              );
            }
          }
        }
      },
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.saving,
    required this.primaryLabel,
    required this.onBack,
    required this.onSubmit,
  });

  final bool saving;
  final String primaryLabel;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  static const _submitGreen = Color(0xFF16A34A);

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
                      backgroundColor: _submitGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      elevation: saving ? 0 : 2,
                      shadowColor: _submitGreen.withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: saving ? null : onSubmit,
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 22),
                    label: Text(
                      saving ? 'Please wait…' : primaryLabel,
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
    final isNarrow = MediaQuery.of(context).size.width < 760;
    if (isNarrow) {
      return Column(
        children: [
          left,
          const SizedBox(height: 12),
          right,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
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

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w900, fontSize: 11),
      ),
    );
  }
}

class _PhotoUploadCard extends StatelessWidget {
  const _PhotoUploadCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: 1.1,
      child: Card(
        color: Colors.grey.shade50,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_a_photo_outlined, color: Colors.grey.shade600),
                const SizedBox(height: 8),
                Text('Upload photo', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text('JPG/PNG', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Guideline extends StatelessWidget {
  const _Guideline({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF0F8A5F)),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

/// Scroll progress with soft gradient fill.
class _AnimatedProgressRail extends StatelessWidget {
  const _AnimatedProgressRail({required this.progress});

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
                              colors: [
                                cs.primary,
                                const Color(0xFF0D9488),
                              ],
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


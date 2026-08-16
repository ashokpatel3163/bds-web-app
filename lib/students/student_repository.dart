import 'dart:async';

import '../api/bds_api_client.dart';

class StudentRepository {
  StudentRepository({BdsApiClient? client}) : _client = client ?? BdsApiClient();

  final BdsApiClient _client;
  final List<Student> _students = [];
  final _updates = StreamController<void>.broadcast();

  void _notify() {
    if (!_updates.isClosed) _updates.add(null);
  }

  String _tempPassword() {
    final t = DateTime.now().millisecondsSinceEpoch;
    return 'Bds$t!x9Ab'; // satisfies backend min length
  }

  Future<void> _refresh() async {
    final raw = await _client.getOnboardingUsersList(userType: 'STUDENT', limit: 500);
    _students
      ..clear()
      ..addAll(raw.map((e) => Student.fromJson(e as Map<String, dynamic>)));
  }

  List<Student> _sorted() {
    final copy = List<Student>.from(_students);
    copy.sort((a, b) {
      final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return copy;
  }

  Stream<List<Student>> watchStudents() async* {
    await _refresh();
    yield _sorted();
    await for (final _ in _updates.stream) {
      yield _sorted();
    }
  }

  Stream<Student?> watchStudent(String id) {
    return watchStudents().map((list) {
      try {
        return list.firstWhere((s) => s.id == id);
      } catch (_) {
        return null;
      }
    });
  }

  Future<void> addStudent(StudentDraft draft) async {
    await _client.postJson('/onboarding/create', {
      'personalDetails': {
        'fullName': draft.fullName.trim(),
        'phone': draft.phone.trim(),
        if (draft.email.trim().isNotEmpty) 'email': draft.email.trim(),
      },
      'password': _tempPassword(),
      'userType': 'STUDENT',
      'termsAccepted': true,
      'profile': _draftToProfile(draft),
    });
    await _refresh();
    _notify();
  }

  Future<void> deleteStudent(String id) async {
    await _client.delete('/onboarding/user/$id');
    await _refresh();
    _notify();
  }

  Future<void> setStudentActive(String id, bool active) async {
    await _client.patchJson('/onboarding/details', {
      'vendorCode': id,
      'isActive': active,
    });
    await _refresh();
    _notify();
  }

  Future<void> updateStudent(String id, StudentDraft draft) async {
    await _client.patchJson('/onboarding/details', {
      'vendorCode': id,
      'personalDetails': {
        'fullName': draft.fullName.trim(),
        'phone': draft.phone.trim(),
        if (draft.email.trim().isNotEmpty) 'email': draft.email.trim(),
      },
      'profile': _draftToProfile(draft),
    });
    await _refresh();
    _notify();
  }

  /// Merges keys into `profile` without replacing the whole object (e.g. class + fee after dropdown).
  Future<void> mergeStudentProfile(String id, Map<String, dynamic> profilePatch) async {
    await _client.patchJson('/onboarding/details', {
      'vendorCode': id,
      'profilePatch': profilePatch,
    });
    await _refresh();
    _notify();
  }

  Map<String, dynamic> _draftToProfile(StudentDraft d) {
    return {
      'admissionId': d.admissionId.trim(),
      'dateOfBirth': d.dateOfBirth.trim(),
      'gender': d.gender.trim(),
      'nationality': d.nationality.trim(),
      'languagesSpoken': d.languagesSpoken.trim(),
      'medium': d.medium.trim(),
      'schoolClassCode': d.schoolClassCode.trim(),
      'className': d.className.trim(),
      'section': d.section.trim(),
      'rollNo': d.rollNo.trim(),
      'enrollmentStatus': d.enrollmentStatus.trim(),
      'admissionYear': d.admissionYear.trim(),
      'previousInstitution': d.previousInstitution.trim(),
      'lastGradeCompleted': d.lastGradeCompleted.trim(),
      'guardianName': d.guardianName.trim(),
      'guardianRelation': d.guardianRelation.trim(),
      'guardianPhone': d.phone.trim(),
      'guardianEmail': d.guardianEmail.trim(),
      'address': d.address.trim(),
      'medicalNotes': d.medicalNotes.trim(),
      'annualFeeDue': d.annualFeeDue,
    };
  }
}

class Student {
  const Student({
    required this.id,
    required this.admissionId,
    required this.fullName,
    required this.email,
    required this.dateOfBirth,
    required this.gender,
    required this.nationality,
    required this.languagesSpoken,
    required this.medium,
    this.schoolClassCode = '',
    required this.className,
    required this.section,
    required this.rollNo,
    required this.isActive,
    required this.enrollmentStatus,
    required this.admissionYear,
    required this.previousInstitution,
    required this.lastGradeCompleted,
    required this.guardianName,
    required this.guardianRelation,
    required this.guardianEmail,
    required this.phone,
    required this.address,
    required this.medicalNotes,
    required this.annualFeeDue,
    required this.createdAt,
  });

  factory Student.fromJson(Map<String, dynamic> j) {
    if (j.containsKey('vendorCode')) {
      return Student._fromOnboarding(j);
    }
    return Student._fromFlat(j);
  }

  factory Student._fromOnboarding(Map<String, dynamic> u) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    final p = u['personalDetails'] as Map<String, dynamic>? ?? {};
    final prof = u['profile'] as Map<String, dynamic>? ?? {};
    return Student(
      id: u['vendorCode'] as String,
      admissionId: prof['admissionId']?.toString() ?? '',
      fullName: p['fullName']?.toString() ?? '',
      email: p['email']?.toString() ?? '',
      dateOfBirth: prof['dateOfBirth']?.toString() ?? '',
      gender: prof['gender']?.toString() ?? '',
      nationality: prof['nationality']?.toString() ?? '',
      languagesSpoken: prof['languagesSpoken']?.toString() ?? '',
      medium: prof['medium']?.toString() ?? '',
      schoolClassCode: prof['schoolClassCode']?.toString() ?? '',
      className: prof['className']?.toString() ?? '',
      section: prof['section']?.toString() ?? '',
      rollNo: prof['rollNo']?.toString() ?? '',
      isActive: u['isActive'] as bool? ?? true,
      enrollmentStatus: prof['enrollmentStatus']?.toString() ?? '',
      admissionYear: prof['admissionYear']?.toString() ?? '',
      previousInstitution: prof['previousInstitution']?.toString() ?? '',
      lastGradeCompleted: prof['lastGradeCompleted']?.toString() ?? '',
      guardianName: prof['guardianName']?.toString() ?? '',
      guardianRelation: prof['guardianRelation']?.toString() ?? '',
      guardianEmail: prof['guardianEmail']?.toString() ?? '',
      phone: () {
        final pp = p['phone']?.toString().trim() ?? '';
        if (pp.isNotEmpty) return pp;
        return prof['guardianPhone']?.toString().trim() ?? '';
      }(),
      address: prof['address']?.toString() ?? '',
      medicalNotes: prof['medicalNotes']?.toString() ?? '',
      annualFeeDue: (prof['annualFeeDue'] as num?)?.toDouble() ?? 0,
      createdAt: parseDate(u['createdAt']),
    );
  }

  factory Student._fromFlat(Map<String, dynamic> j) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    return Student(
      id: j['id'] as String,
      admissionId: j['admissionId']?.toString() ?? '',
      fullName: j['fullName']?.toString() ?? '',
      email: j['email']?.toString() ?? '',
      dateOfBirth: j['dateOfBirth']?.toString() ?? '',
      gender: j['gender']?.toString() ?? '',
      nationality: j['nationality']?.toString() ?? '',
      languagesSpoken: j['languagesSpoken']?.toString() ?? '',
      medium: j['medium']?.toString() ?? '',
      schoolClassCode: j['schoolClassCode']?.toString() ?? '',
      className: j['className']?.toString() ?? '',
      section: j['section']?.toString() ?? '',
      rollNo: j['rollNo']?.toString() ?? '',
      isActive: j['isActive'] as bool? ?? true,
      enrollmentStatus: j['enrollmentStatus']?.toString() ?? '',
      admissionYear: j['admissionYear']?.toString() ?? '',
      previousInstitution: j['previousInstitution']?.toString() ?? '',
      lastGradeCompleted: j['lastGradeCompleted']?.toString() ?? '',
      guardianName: j['guardianName']?.toString() ?? '',
      guardianRelation: j['guardianRelation']?.toString() ?? '',
      guardianEmail: j['guardianEmail']?.toString() ?? '',
      phone: j['phone']?.toString() ?? '',
      address: j['address']?.toString() ?? '',
      medicalNotes: j['medicalNotes']?.toString() ?? '',
      annualFeeDue: (j['annualFeeDue'] as num?)?.toDouble() ?? 0,
      createdAt: parseDate(j['createdAt']),
    );
  }

  final String id;
  final String admissionId;
  final String fullName;
  final String email;
  final String dateOfBirth;
  final String gender;
  final String nationality;
  final String languagesSpoken;
  final String medium;
  final String schoolClassCode;
  final String className;
  final String section;
  final String rollNo;
  final bool isActive;
  final String enrollmentStatus;
  final String admissionYear;
  final String previousInstitution;
  final String lastGradeCompleted;
  final String guardianName;
  final String guardianRelation;
  final String guardianEmail;
  final String phone;
  final String address;
  final String medicalNotes;
  final double annualFeeDue;
  final DateTime? createdAt;
}

class StudentDraft {
  const StudentDraft({
    required this.admissionId,
    required this.fullName,
    required this.email,
    required this.dateOfBirth,
    required this.gender,
    required this.nationality,
    required this.languagesSpoken,
    required this.medium,
    this.schoolClassCode = '',
    required this.className,
    required this.section,
    required this.rollNo,
    required this.enrollmentStatus,
    required this.admissionYear,
    required this.previousInstitution,
    required this.lastGradeCompleted,
    required this.guardianName,
    required this.guardianRelation,
    required this.guardianEmail,
    required this.phone,
    required this.address,
    required this.medicalNotes,
    this.annualFeeDue = 60000,
  });

  final String admissionId;
  final String fullName;
  final String email;
  final String dateOfBirth;
  final String gender;
  final String nationality;
  final String languagesSpoken;
  final String medium;
  final String schoolClassCode;
  final String className;
  final String section;
  final String rollNo;
  final String enrollmentStatus;
  final String admissionYear;
  final String previousInstitution;
  final String lastGradeCompleted;
  final String guardianName;
  final String guardianRelation;
  final String guardianEmail;
  final String phone;
  final String address;
  final String medicalNotes;
  final double annualFeeDue;
}

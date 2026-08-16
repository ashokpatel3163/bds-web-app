import 'dart:async';

import 'package:intl/intl.dart';

import '../api/bds_api_client.dart';

/// Default shift for new staff (editable before save).
const String kDefaultStaffShiftTiming = '7:30 AM — 1:00 PM';

num? _parseMonthlySalaryInput(String raw) {
  var t = raw.trim().replaceAll(',', '').replaceAll('₹', '').trim();
  final lower = t.toLowerCase();
  if (lower.startsWith('rs')) {
    t = t.substring(2).trim();
  }
  if (t.toLowerCase().endsWith('inr')) {
    t = t.substring(0, t.length - 3).trim();
  }
  if (t.isEmpty) return null;
  return num.tryParse(t);
}

String _formatSalaryFromProfile(dynamic v) {
  if (v == null) return '';
  if (v is num) {
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);
  }
  final s = v.toString().trim();
  return s;
}

class StaffRepository {
  StaffRepository({BdsApiClient? client}) : _client = client ?? BdsApiClient();

  final BdsApiClient _client;
  final List<StaffMember> _rows = [];
  final _updates = StreamController<void>.broadcast();

  void _notify() {
    if (!_updates.isClosed) _updates.add(null);
  }

  String _tempPassword() {
    final t = DateTime.now().millisecondsSinceEpoch;
    return 'Bds$t!x9Ab';
  }

  Future<void> _refresh() async {
    final teachers = await _client.getOnboardingUsersList(userType: 'TEACHER', limit: 500);
    final workers = await _client.getOnboardingUsersList(userType: 'WORKER', limit: 500);
    _rows
      ..clear()
      ..addAll([
        ...teachers.map((e) => StaffMember.fromJson(e as Map<String, dynamic>)),
        ...workers.map((e) => StaffMember.fromJson(e as Map<String, dynamic>)),
      ]);
  }

  List<StaffMember> _sorted() {
    final copy = List<StaffMember>.from(_rows);
    copy.sort((a, b) {
      final ta = a.joinedOn ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.joinedOn ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return copy;
  }

  Stream<List<StaffMember>> watchStaff() async* {
    await _refresh();
    yield _sorted();
    await for (final _ in _updates.stream) {
      yield _sorted();
    }
  }

  Stream<StaffMember?> watchStaffMember(String id) {
    return watchStaff().map((list) {
      try {
        return list.firstWhere((s) => s.id == id);
      } catch (_) {
        return null;
      }
    });
  }

  /// Attendance history from [BdsApiClient.getStaffAttendanceList]. Omit [from]/[to] for server default (~3 months).
  Future<List<StaffAttendanceRow>> fetchStaffAttendance(
    String vendorCode, {
    String? from,
    String? to,
  }) async {
    final list = await _client.getStaffAttendanceList(
      vendorCode: vendorCode,
      from: from,
      to: to,
    );
    return list
        .map((e) => StaffAttendanceRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> setStaffActive(String id, bool active) async {
    await _client.patchJson('/onboarding/details', {
      'vendorCode': id,
      'isActive': active,
    });
    await _refresh();
    _notify();
  }

  bool hasPortalPassword(String vendorCode) {
    try {
      return _rows.firstWhere((r) => r.id == vendorCode).portalPasswordSet;
    } catch (_) {
      return false;
    }
  }

  /// Returns `(null, employeeId)` on success, or `(errorMessage, null)` on failure.
  /// Employee id is assigned only by the server.
  Future<(String?, String?)> addStaff(StaffDraft draft, {String? portalPassword}) async {
    try {
      final userType = draft.role == StaffRole.teacher ? 'TEACHER' : 'WORKER';
      final pw = (portalPassword != null && portalPassword.trim().isNotEmpty)
          ? portalPassword.trim()
          : _tempPassword();
      final emergencyName = draft.emergencyContactName.trim();
      final emergencyPhone = draft.emergencyContactPhone.trim();
      final legacyEmergency = [emergencyName, emergencyPhone].where((s) => s.isNotEmpty).join(' · ');
      final data = await _client.postJson('/onboarding/create', {
        'personalDetails': {
          'fullName': draft.fullName.trim(),
          'phone': draft.phone.trim(),
          if (draft.email.trim().isNotEmpty) 'email': draft.email.trim(),
        },
        'password': pw,
        'userType': userType,
        'termsAccepted': true,
        'profile': {
          'department': draft.department.trim(),
          'designation': draft.designation.trim(),
          'staffRole': _roleToApi(draft.role),
          'address': draft.address.trim(),
          'guardianName': draft.guardianName.trim(),
          'guardianPhone': draft.guardianPhone.trim(),
          'emergencyContactName': emergencyName,
          'emergencyContactPhone': emergencyPhone,
          if (legacyEmergency.isNotEmpty) 'emergencyContact': legacyEmergency,
          'qualification': draft.qualification.trim(),
          'notes': draft.notes.trim(),
          'joinedOn': draft.joinedOn?.toIso8601String(),
          'portalPasswordSet': portalPassword != null && portalPassword.trim().isNotEmpty,
          'shiftTiming': draft.shiftTiming.trim().isNotEmpty
              ? draft.shiftTiming.trim()
              : kDefaultStaffShiftTiming,
          if (_parseMonthlySalaryInput(draft.monthlySalary) != null)
            'monthlySalary': _parseMonthlySalaryInput(draft.monthlySalary),
        },
      });
      await _refresh();
      _notify();
      final user = data['user'] as Map<String, dynamic>?;
      final emp = user?['employeeId']?.toString();
      return (null, emp);
    } catch (e) {
      final raw = e.toString();
      if (raw.startsWith('Exception: ')) {
        return (raw.substring('Exception: '.length), null);
      }
      return (raw, null);
    }
  }

  static String _roleToApi(StaffRole r) => switch (r) {
        StaffRole.teacher => 'teacher',
        StaffRole.adminStaff => 'adminStaff',
        StaffRole.support => 'support',
      };

  /// Updates staff via `PATCH /onboarding/details` (personalDetails + profilePatch). [current] preserves employee id / portal flags.
  Future<String?> updateStaff({
    required String vendorCode,
    required StaffDraft draft,
    required StaffMember current,
  }) async {
    try {
      final emergencyName = draft.emergencyContactName.trim();
      final emergencyPhone = draft.emergencyContactPhone.trim();
      final legacyEmergency = [emergencyName, emergencyPhone].where((s) => s.isNotEmpty).join(' · ');
      final profilePatch = <String, dynamic>{
        'department': draft.department.trim(),
        'designation': draft.designation.trim(),
        'staffRole': _roleToApi(draft.role),
        'address': draft.address.trim(),
        'guardianName': draft.guardianName.trim(),
        'guardianPhone': draft.guardianPhone.trim(),
        'emergencyContactName': emergencyName,
        'emergencyContactPhone': emergencyPhone,
        if (legacyEmergency.isNotEmpty) 'emergencyContact': legacyEmergency,
        'qualification': draft.qualification.trim(),
        'notes': draft.notes.trim(),
        'shiftTiming': draft.shiftTiming.trim().isNotEmpty
            ? draft.shiftTiming.trim()
            : kDefaultStaffShiftTiming,
        'portalPasswordSet': current.portalPasswordSet,
      };
      if (draft.joinedOn != null) {
        profilePatch['joinedOn'] = draft.joinedOn!.toIso8601String();
      }
      final sal = _parseMonthlySalaryInput(draft.monthlySalary);
      if (sal != null) {
        profilePatch['monthlySalary'] = sal;
      }
      await _client.patchJson('/onboarding/details', {
        'vendorCode': vendorCode,
        'personalDetails': {
          'fullName': draft.fullName.trim(),
          'phone': draft.phone.trim(),
          if (draft.email.trim().isNotEmpty) 'email': draft.email.trim(),
        },
        'profilePatch': profilePatch,
      });
      await _refresh();
      _notify();
      return null;
    } catch (e) {
      final raw = e.toString();
      if (raw.startsWith('Exception: ')) {
        return raw.substring('Exception: '.length);
      }
      return raw;
    }
  }

}

StaffRole _parseStaffRole(String? r) => switch (r) {
      'teacher' => StaffRole.teacher,
      'adminStaff' => StaffRole.adminStaff,
      'support' => StaffRole.support,
      _ => StaffRole.support,
    };

enum StaffRole { teacher, adminStaff, support }

extension StaffRoleLabel on StaffRole {
  String get label => switch (this) {
        StaffRole.teacher => 'Teacher',
        StaffRole.adminStaff => 'Admin',
        StaffRole.support => 'Support',
      };
}

class StaffDraft {
  const StaffDraft({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.department,
    required this.designation,
    required this.role,
    required this.isActive,
    required this.joinedOn,
    required this.address,
    required this.guardianName,
    required this.guardianPhone,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.qualification,
    required this.notes,
    this.shiftTiming = kDefaultStaffShiftTiming,
    this.monthlySalary = '',
  });

  final String fullName;
  final String email;
  final String phone;
  final String department;
  final String designation;
  final StaffRole role;
  final bool isActive;
  final DateTime? joinedOn;
  final String address;
  final String guardianName;
  final String guardianPhone;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String qualification;
  final String notes;
  final String shiftTiming;
  /// Plain input, e.g. `45000` — stored as a number on the server when valid.
  final String monthlySalary;
}

class StaffMember {
  const StaffMember({
    required this.id,
    this.employeeId = '',
    required this.fullName,
    required this.email,
    required this.phone,
    required this.department,
    required this.designation,
    required this.role,
    required this.isActive,
    required this.joinedOn,
    this.address = '',
    this.guardianName = '',
    this.guardianPhone = '',
    this.emergencyContactName = '',
    this.emergencyContactPhone = '',
    this.emergencyContact = '',
    this.qualification = '',
    this.notes = '',
    this.portalPasswordSet = false,
    this.shiftTiming = kDefaultStaffShiftTiming,
    this.monthlySalary = '',
  });

  factory StaffMember.fromJson(Map<String, dynamic> j) {
    if (j.containsKey('vendorCode')) {
      return StaffMember._fromOnboarding(j);
    }
    return StaffMember._fromFlat(j);
  }

  factory StaffMember._fromOnboarding(Map<String, dynamic> u) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    final p = u['personalDetails'] as Map<String, dynamic>? ?? {};
    final prof = u['profile'] as Map<String, dynamic>? ?? {};
    final gName = prof['guardianName']?.toString() ?? '';
    final gPhone = prof['guardianPhone']?.toString() ?? '';
    final eName = prof['emergencyContactName']?.toString() ?? '';
    final ePhone = prof['emergencyContactPhone']?.toString() ?? '';
    final legacyEmergency = prof['emergencyContact']?.toString() ?? '';
    final empId = prof['employeeId']?.toString() ?? '';
    return StaffMember(
      id: u['vendorCode'] as String,
      employeeId: empId,
      fullName: p['fullName']?.toString() ?? '',
      email: p['email']?.toString() ?? '',
      phone: p['phone']?.toString() ?? '',
      department: prof['department']?.toString() ?? '',
      designation: prof['designation']?.toString() ?? '',
      role: _parseStaffRole(prof['staffRole']?.toString()),
      isActive: u['isActive'] as bool? ?? true,
      joinedOn: parseDate(prof['joinedOn']),
      address: prof['address']?.toString() ?? '',
      guardianName: gName,
      guardianPhone: gPhone,
      emergencyContactName: eName,
      emergencyContactPhone: ePhone,
      emergencyContact: legacyEmergency.isNotEmpty
          ? legacyEmergency
          : [eName, ePhone].where((s) => s.isNotEmpty).join(' · '),
      qualification: prof['qualification']?.toString() ?? '',
      notes: prof['notes']?.toString() ?? '',
      portalPasswordSet: prof['portalPasswordSet'] as bool? ?? false,
      shiftTiming: prof['shiftTiming']?.toString().trim().isNotEmpty == true
          ? prof['shiftTiming']!.toString()
          : kDefaultStaffShiftTiming,
      monthlySalary: _formatSalaryFromProfile(prof['monthlySalary']),
    );
  }

  factory StaffMember._fromFlat(Map<String, dynamic> j) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    return StaffMember(
      id: j['id'] as String,
      employeeId: j['employeeId']?.toString() ?? '',
      fullName: j['fullName']?.toString() ?? '',
      email: j['email']?.toString() ?? '',
      phone: j['phone']?.toString() ?? '',
      department: j['department']?.toString() ?? '',
      designation: j['designation']?.toString() ?? '',
      role: _parseStaffRole(j['role']?.toString()),
      isActive: j['isActive'] as bool? ?? true,
      joinedOn: parseDate(j['joinedOn']),
      address: j['address']?.toString() ?? '',
      guardianName: j['guardianName']?.toString() ?? '',
      guardianPhone: j['guardianPhone']?.toString() ?? '',
      emergencyContactName: j['emergencyContactName']?.toString() ?? '',
      emergencyContactPhone: j['emergencyContactPhone']?.toString() ?? '',
      emergencyContact: j['emergencyContact']?.toString() ?? '',
      qualification: j['qualification']?.toString() ?? '',
      notes: j['notes']?.toString() ?? '',
      portalPasswordSet: j['portalPasswordSet'] as bool? ?? false,
      shiftTiming: j['shiftTiming']?.toString() ?? kDefaultStaffShiftTiming,
      monthlySalary: _formatSalaryFromProfile(j['monthlySalary']),
    );
  }

  final String id;
  /// Human-readable id from `profile.employeeId` (server-generated). [id] is vendorCode.
  final String employeeId;
  final String fullName;
  final String email;
  final String phone;
  final String department;
  final String designation;
  final StaffRole role;
  final bool isActive;
  final DateTime? joinedOn;
  final String address;
  final String guardianName;
  final String guardianPhone;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String emergencyContact;
  final String qualification;
  final String notes;
  final bool portalPasswordSet;
  final String shiftTiming;
  final String monthlySalary;
}

/// One day row from `/staff-attendance/me`.
class StaffAttendanceRow {
  const StaffAttendanceRow({
    required this.workDate,
    this.checkInAt,
    this.checkOutAt,
    this.checkInLocation = '',
    this.checkOutLocation = '',
  });

  factory StaffAttendanceRow.fromJson(Map<String, dynamic> j) {
    DateTime? parseIso(String? s) {
      if (s == null || s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    return StaffAttendanceRow(
      workDate: j['workDate']?.toString() ?? '',
      checkInAt: parseIso(j['checkInAt']?.toString()),
      checkOutAt: parseIso(j['checkOutAt']?.toString()),
      checkInLocation: j['checkInLocation']?.toString() ?? '',
      checkOutLocation: j['checkOutLocation']?.toString() ?? '',
    );
  }

  final String workDate;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final String checkInLocation;
  final String checkOutLocation;
}

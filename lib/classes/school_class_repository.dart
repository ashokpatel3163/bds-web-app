import 'dart:async';

import '../api/bds_api_client.dart';
import 'school_class.dart';

export 'school_class.dart';

/// Master list of school classes — each row has a server-generated code and total annual fee.
class SchoolClassRepository {
  SchoolClassRepository({BdsApiClient? client}) : _client = client ?? BdsApiClient();

  final BdsApiClient _client;
  final List<SchoolClass> _rows = [];
  final _updates = StreamController<void>.broadcast();

  void _notify() {
    if (!_updates.isClosed) _updates.add(null);
  }

  Future<void> _refresh({bool includeInactive = false}) async {
    final q = includeInactive ? '?includeInactive=1' : '';
    final raw = await _client.getDataList('/classes$q');
    _rows
      ..clear()
      ..addAll(raw.map((e) => SchoolClass.fromJson(e as Map<String, dynamic>)));
  }

  List<SchoolClass> _sorted() {
    final copy = List<SchoolClass>.from(_rows);
    copy.sort((a, b) {
      final o = a.sortOrder.compareTo(b.sortOrder);
      if (o != 0) return o;
      return a.displayLabel.toLowerCase().compareTo(b.displayLabel.toLowerCase());
    });
    return copy;
  }

  /// Active classes only (default).
  Future<List<SchoolClass>> fetchClasses({bool includeInactive = false}) async {
    await _refresh(includeInactive: includeInactive);
    return List<SchoolClass>.from(_sorted());
  }

  Stream<List<SchoolClass>> watchClasses({bool includeInactive = false}) async* {
    await _refresh(includeInactive: includeInactive);
    yield _sorted();
    await for (final _ in _updates.stream) {
      await _refresh(includeInactive: includeInactive);
      yield _sorted();
    }
  }

  Future<SchoolClass?> getByCode(String classCode) async {
    try {
      final data = await _client.getDataMap('/classes/${Uri.encodeComponent(classCode)}');
      return SchoolClass.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> createClass({
    required String name,
    String section = '',
    required double totalAnnualFee,
    int sortOrder = 0,
  }) async {
    await _client.postJson('/classes', {
      'name': name.trim(),
      'section': section.trim(),
      'totalAnnualFee': totalAnnualFee,
      'sortOrder': sortOrder,
    });
    await _refresh();
    _notify();
  }

  Future<void> updateClass(
    String classCode, {
    String? name,
    String? section,
    double? totalAnnualFee,
    int? sortOrder,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (section != null) body['section'] = section;
    if (totalAnnualFee != null) body['totalAnnualFee'] = totalAnnualFee;
    if (sortOrder != null) body['sortOrder'] = sortOrder;
    if (isActive != null) body['isActive'] = isActive;
    await _client.patchJson('/classes/${Uri.encodeComponent(classCode)}', body);
    await _refresh();
    _notify();
  }

  Future<void> deleteClass(String classCode) async {
    await _client.delete('/classes/${Uri.encodeComponent(classCode)}');
    await _refresh();
    _notify();
  }

  /// Annual fee for fee screens: **by class name only** (section is ignored).
  /// If [schoolClassCode] is set, the master row's [name] is used as the class key.
  /// Otherwise [className] is matched against master [SchoolClass.name].
  /// Falls back to [fallbackAnnualFeeDue] when no master row matches.
  Future<double> resolveAnnualFeeFromClassMaster({
    required String schoolClassCode,
    required String className,
    required double fallbackAnnualFeeDue,
  }) async {
    var anchorName = className.trim();
    final code = schoolClassCode.trim();
    if (code.isNotEmpty) {
      final row = await getByCode(code);
      if (row != null && row.name.trim().isNotEmpty) {
        anchorName = row.name.trim();
      }
    }
    if (anchorName.isEmpty) return fallbackAnnualFeeDue;

    final list = await fetchClasses();
    final target = _normClassKey(anchorName);
    for (final c in list) {
      if (_normClassKey(c.name) == target) {
        return c.totalAnnualFee;
      }
    }
    return fallbackAnnualFeeDue;
  }

  static String _normClassKey(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

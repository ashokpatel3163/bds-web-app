import 'dart:async';

import '../api/bds_api_client.dart';

class FeeRepository {
  FeeRepository({BdsApiClient? client}) : _client = client ?? BdsApiClient();

  final BdsApiClient _client;
  final List<FeeReceipt> _receipts = [];
  final _updates = StreamController<void>.broadcast();

  void _notify() {
    if (!_updates.isClosed) _updates.add(null);
  }

  Future<void> _refresh() async {
    final raw = await _client.getDataList('/fees');
    _receipts
      ..clear()
      ..addAll(raw.map((e) => FeeReceipt.fromJson(e as Map<String, dynamic>)));
  }

  List<FeeReceipt> _sorted() {
    final copy = List<FeeReceipt>.from(_receipts);
    copy.sort((a, b) {
      final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return copy;
  }

  Stream<List<FeeReceipt>> watchFees() async* {
    await _refresh();
    yield _sorted();
    await for (final _ in _updates.stream) {
      yield _sorted();
    }
  }

  List<FeeReceipt> receiptsForStudent(String studentId) {
    final list = _receipts.where((r) => r.studentId == studentId).toList();
    list.sort((a, b) {
      final ta = a.paidOn ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.paidOn ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return list;
  }

  double totalPaidForStudent(String studentId) {
    return _receipts.where((r) => r.studentId == studentId).fold<double>(0, (sum, r) => sum + r.amount);
  }

  Future<void> addReceipt(FeeDraft draft) async {
    await _client.postJson('/fees', {
      'receiptNo': draft.receiptNo.trim(),
      'studentId': draft.studentId.trim(),
      'studentName': draft.studentName.trim(),
      'fatherName': draft.fatherName.trim(),
      'admissionId': draft.admissionId.trim(),
      'className': draft.className.trim(),
      'section': draft.section.trim(),
      'rollNo': draft.rollNo.trim(),
      'feeHead': draft.feeHead.trim(),
      'feeItems': draft.feeItems.map((e) => {'feeHead': e.feeHead, 'amount': e.amount}).toList(),
      'amount': draft.amount,
      'notes': draft.notes.trim(),
      'paidOn': draft.paidOn.toIso8601String(),
    });
    await _refresh();
    _notify();
  }
}

class FeeReceipt {
  const FeeReceipt({
    required this.id,
    required this.receiptNo,
    required this.studentId,
    required this.studentName,
    required this.fatherName,
    required this.admissionId,
    required this.className,
    required this.section,
    required this.rollNo,
    required this.feeHead,
    required this.feeItems,
    required this.amount,
    required this.notes,
    required this.paidOn,
    required this.createdAt,
  });

  factory FeeReceipt.fromJson(Map<String, dynamic> j) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    final items = j['feeItems'];
    final feeItems = <FeeItem>[];
    if (items is List) {
      for (final x in items) {
        if (x is Map<String, dynamic>) {
          feeItems.add(FeeItem(
            feeHead: x['feeHead']?.toString() ?? '',
            amount: (x['amount'] as num?)?.toDouble() ?? 0,
          ));
        }
      }
    }

    return FeeReceipt(
      id: j['id']?.toString() ?? '',
      receiptNo: j['receiptNo']?.toString() ?? '',
      studentId: j['studentId']?.toString() ?? '',
      studentName: j['studentName']?.toString() ?? '',
      fatherName: j['fatherName']?.toString() ?? '',
      admissionId: j['admissionId']?.toString() ?? '',
      className: j['className']?.toString() ?? '',
      section: j['section']?.toString() ?? '',
      rollNo: j['rollNo']?.toString() ?? '',
      feeHead: j['feeHead']?.toString() ?? '',
      feeItems: feeItems,
      amount: (j['amount'] as num?)?.toDouble() ?? 0,
      notes: j['notes']?.toString() ?? '',
      paidOn: parseDate(j['paidOn']),
      createdAt: parseDate(j['createdAt']),
    );
  }

  final String id;
  final String receiptNo;
  final String studentId;
  final String studentName;
  final String fatherName;
  final String admissionId;
  final String className;
  final String section;
  final String rollNo;
  final String feeHead;
  final List<FeeItem> feeItems;
  final double amount;
  final String notes;
  final DateTime? paidOn;
  final DateTime? createdAt;

  String get feeHeadSummary {
    if (feeItems.isEmpty) return feeHead;
    if (feeItems.length <= 2) {
      return feeItems.map((e) => e.feeHead).join(', ');
    }
    return '${feeItems.first.feeHead}, +${feeItems.length - 1} more';
  }
}

class FeeDraft {
  const FeeDraft({
    required this.receiptNo,
    required this.studentId,
    required this.studentName,
    required this.fatherName,
    required this.admissionId,
    required this.className,
    required this.section,
    required this.rollNo,
    required this.feeHead,
    required this.feeItems,
    required this.amount,
    required this.notes,
    required this.paidOn,
  });

  final String receiptNo;
  final String studentId;
  final String studentName;
  final String fatherName;
  final String admissionId;
  final String className;
  final String section;
  final String rollNo;
  final String feeHead;
  final List<FeeItem> feeItems;
  final double amount;
  final String notes;
  final DateTime paidOn;
}

class FeeItem {
  const FeeItem({
    required this.feeHead,
    required this.amount,
  });

  final String feeHead;
  final double amount;
}

/// One row from `BDSschoolclasses` — API field `classCode` is stored as [code] (Dart `classCode` parses badly).
class SchoolClass {
  const SchoolClass({
    required this.code,
    required this.name,
    required this.section,
    required this.totalAnnualFee,
    required this.sortOrder,
    required this.isActive,
  });

  factory SchoolClass.fromJson(Map<String, dynamic> j) {
    return SchoolClass(
      code: j['classCode']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      section: j['section']?.toString() ?? '',
      totalAnnualFee: (j['totalAnnualFee'] as num?)?.toDouble() ?? 0,
      sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: j['isActive'] as bool? ?? true,
    );
  }

  final String code;
  final String name;
  final String section;
  final double totalAnnualFee;
  final int sortOrder;
  final bool isActive;

  String get displayLabel => section.isEmpty ? name : '$name — $section';
}

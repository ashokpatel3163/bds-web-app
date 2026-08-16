import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (label) {
      'Active' => (const Color(0xFFDDF8EF), const Color(0xFF0F8A5F)),
      'On Leave' => (const Color(0xFFF2F1FA), const Color(0xFF5A4FA3)),
      'On hold' => (const Color(0xFFFFF4E5), const Color(0xFFB45309)),
      'Probation' => (const Color(0xFFFFE6E6), const Color(0xFFB54747)),
      'Inactive' => (const Color(0xFFFFECE1), const Color(0xFFC2410C)),
      _ => (Colors.grey.shade200, Colors.grey.shade800),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

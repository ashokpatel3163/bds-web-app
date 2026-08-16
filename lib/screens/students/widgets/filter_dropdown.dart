import 'package:flutter/material.dart';

class FilterDropdown extends StatelessWidget {
  const FilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.toolbarDense = false,
    this.toolbarHeight,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  /// When true, height comes from [toolbarHeight] (same as Filters / Search for this row).
  final bool toolbarDense;

  /// Required when [toolbarDense] is true — use [rosterToolbarHeightFor] from the parent.
  final double? toolbarHeight;

  @override
  Widget build(BuildContext context) {
    final effective = options.contains(value) ? value : options.first;

    if (toolbarDense) {
      final height = toolbarHeight ?? 48;
      final padTop = (height * 0.30).clamp(12.0, 22.0);
      final padBottom = (height * 0.16).clamp(6.0, 12.0);
      final padH = (height * 0.16).clamp(8.0, 12.0);

      return SizedBox(
        height: height,
        child: Theme(
          data: Theme.of(context).copyWith(visualDensity: VisualDensity.compact),
          child: DropdownButtonFormField<String>(
            initialValue: effective,
            isExpanded: true,
            style: TextStyle(fontSize: 13, height: 1.1, color: Colors.grey.shade900),
            decoration: InputDecoration(
              labelText: label,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              floatingLabelStyle: TextStyle(
                fontSize: (height * 0.16).clamp(9.0, 11.0),
                height: 1,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
              isDense: true,
              contentPadding: EdgeInsets.fromLTRB(padH, padTop, padH - 2, padBottom),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade500),
              ),
            ),
            items: options
                .map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: effective,
      decoration: InputDecoration(labelText: label),
      items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

import 'package:flutter/material.dart';

enum ShellSection { dashboard, students, staff, fees, classes }

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onLogout,
  });

  final ShellSection selected;
  final ValueChanged<ShellSection> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      width: 268,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primary,
                  cs.primary.withValues(alpha: 0.85),
                  const Color(0xFF0D9488).withValues(alpha: 0.9),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BDS',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            'Admin',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
            child: Text(
              'MENU',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
                color: theme.hintColor,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _NavItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  selected: selected == ShellSection.dashboard,
                  onTap: () => onSelect(ShellSection.dashboard),
                ),
                _NavItem(
                  icon: Icons.school_outlined,
                  label: 'Students',
                  selected: selected == ShellSection.students,
                  onTap: () => onSelect(ShellSection.students),
                ),
                _NavItem(
                  icon: Icons.groups_2_outlined,
                  label: 'Faculty & staff',
                  selected: selected == ShellSection.staff,
                  onTap: () => onSelect(ShellSection.staff),
                ),
                _NavItem(
                  icon: Icons.receipt_long_outlined,
                  label: 'Fees',
                  selected: selected == ShellSection.fees,
                  onTap: () => onSelect(ShellSection.fees),
                ),
                _NavItem(
                  icon: Icons.class_outlined,
                  label: 'Classes & setup',
                  selected: selected == ShellSection.classes,
                  onTap: () => onSelect(ShellSection.classes),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: FilledButton.icon(
              onPressed: () => onSelect(ShellSection.students),
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
              label: const Text('New admission'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextButton.icon(
              onPressed: onLogout,
              icon: Icon(Icons.logout_outlined, size: 20, color: Colors.grey.shade700),
              label: Text('Log out', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(40)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: TextButton.icon(
              onPressed: () {},
              icon: Icon(Icons.settings_outlined, size: 20, color: Colors.grey.shade700),
              label: Text('Settings', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(40)),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bg = selected ? cs.primary.withValues(alpha: 0.1) : Colors.transparent;
    final fg = selected ? cs.primary : Colors.grey.shade800;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(
              children: [
                Icon(icon, color: fg, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(color: fg, fontWeight: FontWeight.w700),
                  ),
                ),
                if (selected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

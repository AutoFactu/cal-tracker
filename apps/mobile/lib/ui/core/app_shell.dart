import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations_context.dart';
import 'design_system.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.freshPalette;
    final items = _items(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final selectedIndex = _selectedIndex(context);
        final isWide = constraints.maxWidth >= 720;
        if (isWide) {
          return Scaffold(
            backgroundColor: palette.screen,
            body: Row(
              children: [
                _FreshSideNav(
                  items: items,
                  selectedIndex: selectedIndex,
                  onSelected: (index) => _go(context, index),
                ),
                Expanded(child: child),
              ],
            ),
          );
        }
        return Scaffold(
          backgroundColor: palette.screen,
          body: child,
          bottomNavigationBar: _FreshBottomNav(
            items: items,
            selectedIndex: selectedIndex,
            onSelected: (index) => _go(context, index),
          ),
        );
      },
    );
  }

  int _selectedIndex(BuildContext context) {
    final path = GoRouterState.of(context).matchedLocation;
    return switch (path) {
      '/dashboard' => 0,
      '/history' => 1,
      '/templates' => 3,
      '/settings' => 4,
      _ => 2,
    };
  }

  void _go(BuildContext context, int index) {
    final route = switch (index) {
      0 => '/dashboard',
      1 => '/history',
      3 => '/templates',
      4 => '/settings',
      _ => '/log',
    };
    context.go(route);
  }
}

class _FreshBottomNav extends StatelessWidget {
  const _FreshBottomNav({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.freshPalette;
    return SafeArea(
      top: false,
      child: Container(
        color: palette.screen,
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _NavButton(
              item: items[0],
              selected: selectedIndex == 0,
              onTap: () => onSelected(0),
            ),
            _NavButton(
              item: items[1],
              selected: selectedIndex == 1,
              onTap: () => onSelected(1),
            ),
            _CenterNavButton(
              selected: selectedIndex == 2,
              onTap: () => onSelected(2),
            ),
            _NavButton(
              item: items[3],
              selected: selectedIndex == 3,
              onTap: () => onSelected(3),
            ),
            _NavButton(
              item: items[4],
              selected: selectedIndex == 4,
              onTap: () => onSelected(4),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreshSideNav extends StatelessWidget {
  const _FreshSideNav({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.freshPalette;
    return SafeArea(
      child: Container(
        width: 112,
        padding: const EdgeInsets.all(16),
        color: palette.screen,
        child: FreshCard(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              const _BrandMark(compact: true),
              const SizedBox(height: FreshSpacing.xl),
              for (var index = 0; index < items.length; index++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _NavButton(
                    item: items[index],
                    selected: selectedIndex == index,
                    vertical: true,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
    this.vertical = false,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final palette = context.freshPalette;
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: selected ? palette.ink : palette.inkSoft,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
    final icon = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: selected ? palette.limeWash : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Icon(
        item.icon,
        color: selected ? palette.limeDeep : palette.ink,
        size: 22,
      ),
    );
    return InkWell(
      key: ValueKey('nav_${item.keyName}_button'),
      borderRadius: BorderRadius.circular(FreshRadii.lg),
      onTap: onTap,
      child: SizedBox(
        width: vertical ? 78 : 56,
        height: vertical ? 64 : 58,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(height: 4),
            Text(item.label,
                style: labelStyle, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _CenterNavButton extends StatelessWidget {
  const _CenterNavButton({
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.freshPalette;
    return InkWell(
      key: const ValueKey('nav_log_button'),
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: selected ? palette.lime : palette.limeSoft,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x369ad32a),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Icon(Icons.mic, color: palette.ink, size: 28),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.freshPalette;
    return Container(
      width: compact ? 46 : 52,
      height: compact ? 46 : 52,
      decoration: BoxDecoration(
        color: palette.limeWash,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.local_fire_department, color: palette.limeDeep),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.label, this.keyName);

  final IconData icon;
  final String label;
  final String keyName;
}

List<_NavItem> _items(BuildContext context) {
  final l10n = context.l10n;
  return [
    _NavItem(Icons.home_outlined, l10n.navHome, 'home'),
    _NavItem(Icons.bar_chart_rounded, l10n.navStats, 'stats'),
    _NavItem(Icons.mic_none_rounded, l10n.navLog, 'log'),
    _NavItem(Icons.star_border_rounded, l10n.navUsual, 'usual'),
    _NavItem(Icons.grid_view_rounded, l10n.navMenu, 'menu'),
  ];
}

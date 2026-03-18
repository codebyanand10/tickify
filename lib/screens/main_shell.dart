import 'package:flutter/material.dart';

import 'calendar_screen.dart';
import 'hosted_events_screen.dart';
import 'profile_screen.dart';
import 'tickets_screen.dart';
import 'home_screen.dart';

class MainShell extends StatefulWidget {
  final void Function(bool isDark) toggleTheme;

  const MainShell({super.key, required this.toggleTheme});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with RestorationMixin {
  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    5,
    (_) => GlobalKey<NavigatorState>(),
  );

  final RestorableInt _currentIndex = RestorableInt(0);

  @override
  String? get restorationId => 'main_shell';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_currentIndex, 'tab_index');
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  NavigatorState _currentNavigator() {
    final nav = _navigatorKeys[_currentIndex.value].currentState;
    if (nav == null) {
      // Fallback: root navigator (should be rare).
      return Navigator.of(context);
    }
    return nav;
  }

  void _onNavTap(int index) {
    if (index == _currentIndex.value) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
      return;
    }

    setState(() => _currentIndex.value = index);
  }

  Widget _tabNavigator({
    required int tabIndex,
    required Widget child,
  }) {
    return Offstage(
      offstage: _currentIndex.value != tabIndex,
      child: Navigator(
        key: _navigatorKeys[tabIndex],
        restorationScopeId: 'tab_$tabIndex',
        onGenerateRoute: (settings) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          _tabNavigator(tabIndex: 0, child: HomeScreen(toggleTheme: widget.toggleTheme)),
          _tabNavigator(tabIndex: 1, child: const HostedEventsScreen()),
          _tabNavigator(tabIndex: 2, child: const CalendarScreen()),
          _tabNavigator(tabIndex: 3, child: const TicketsScreen()),
          _tabNavigator(tabIndex: 4, child: const ProfileScreen()),
        ],
      ),
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: _currentIndex.value,
        onTap: _onNavTap,
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int index) onTap;

  const _FloatingNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        bottom: 12 + (bottomInset > 0 ? bottomInset : 6),
        left: 16,
        right: 16,
      ),
      child: Container(
        height: 76,
        decoration: BoxDecoration(
          color: isDark ? cs.surfaceContainerHighest.withOpacity(0.72) : cs.surface.withOpacity(0.92),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.22 : 0.10),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
          border: Border.all(
            color: cs.outlineVariant.withOpacity(isDark ? 0.35 : 0.55),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              label: 'Home',
              selected: currentIndex == 0,
              icon: currentIndex == 0 ? Icons.home : Icons.home_outlined,
              onTap: () => onTap(0),
            ),
            _NavItem(
              label: 'Events',
              selected: currentIndex == 1,
              icon: currentIndex == 1 ? Icons.event : Icons.event_outlined,
              onTap: () => onTap(1),
            ),
            _NavItem(
              label: 'Calendar',
              selected: currentIndex == 2,
              icon: currentIndex == 2 ? Icons.calendar_month : Icons.calendar_today,
              onTap: () => onTap(2),
            ),
            _NavItem(
              label: 'Tickets',
              selected: currentIndex == 3,
              icon: currentIndex == 3
                  ? Icons.confirmation_number
                  : Icons.confirmation_number_outlined,
              onTap: () => onTap(3),
            ),
            _NavItem(
              label: 'Profile',
              selected: currentIndex == 4,
              icon: currentIndex == 4 ? Icons.person : Icons.person_outline,
              onTap: () => onTap(4),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selectedColor = cs.primary;
    final unselectedColor = cs.onSurfaceVariant;

    return Expanded(
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        containedInkWell: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? selectedColor.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: selected ? selectedColor : unselectedColor,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  color: selected ? selectedColor : unselectedColor,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 11,
                ),
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

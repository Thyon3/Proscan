import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:thyscan/core/theme/constants/theme.dart';
import 'package:thyscan/features/home/presentation/screens/homescreen.dart';
import 'package:thyscan/features/home/presentation/screens/tools_screen.dart';
import 'package:thyscan/features/home/presentation/screens/library.dart';
import 'package:thyscan/features/home/presentation/screens/profile.dart';

class AppMainScreen extends ConsumerWidget {
  const AppMainScreen({super.key});

  // -----------------------------------------------------------------
  //  Bottom-navigation items (selected / unselected icons)
  // -----------------------------------------------------------------
  static final List<_NavItem> _navItems = [
    _NavItem(Icons.home_outlined, Icons.home, 'Home'),
    _NavItem(Icons.grid_view_rounded, Icons.grid_view, 'Tools'),
    _NavItem(null, null, ''), // FAB placeholder
    _NavItem(Icons.folder_outlined, Icons.folder, 'Library'),
    _NavItem(Icons.person_outline_rounded, Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final int currentIndex = ref.watch(screenIndexProvider);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Widget> screens = [
      const HomeScreen(),
      const ToolsScreen(),
      const Placeholder(),
      const LibraryScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: screens),

      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/scan'),
        backgroundColor: AppColors.primary,
        elevation: 12,
        child: const Icon(Icons.camera_alt, color: Colors.white, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 10,
        color: isDark ? const Color(0xFF0A0E0A) : Colors.white,
        elevation: 20,
        child: SizedBox(
          height: screenHeight * 0.06,
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: (int idx) {
              if (idx != 2) {
                ref.read(screenIndexProvider.notifier).state = idx;
                debugPrint('→ Navigated to index $idx');
              }
            },
            type: BottomNavigationBarType.fixed,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            selectedFontSize: 10,
            unselectedFontSize: 10,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: Theme.of(
              context,
            ).colorScheme.onSurface.withOpacity(0.6),

            items: _navItems.asMap().entries.map((e) {
              final int idx = e.key;
              final _NavItem item = e.value;

              if (idx == 2) {
                return const BottomNavigationBarItem(
                  icon: SizedBox(width: 48),
                  label: '',
                );
              }

              return BottomNavigationBarItem(
                icon: Icon(
                  currentIndex == idx ? item.selected : item.unselected,
                ),
                label: item.label,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData? unselected;
  final IconData? selected;
  final String label;
  const _NavItem(this.unselected, this.selected, this.label);
}

final screenIndexProvider = StateProvider<int>((ref) => 0);

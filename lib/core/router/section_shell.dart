// lib/core/router/section_shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

/// The persistent section bar: Today · Progress · Library · Settings, each a
/// glyph and a word, the current one marked. Navigation used to be one
/// hamburger on Home, so Library to Progress meant back, summon, choose
/// (audit top finding 5; batch-2 ruling, Library as a peer).
class SectionShell extends StatelessWidget {
  const SectionShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const destinations = [
    NavigationDestination(icon: Icon(LucideIcons.house), label: 'Today'),
    NavigationDestination(icon: Icon(LucideIcons.chartColumn), label: 'Progress'),
    NavigationDestination(icon: Icon(LucideIcons.libraryBig), label: 'Library'),
    NavigationDestination(icon: Icon(LucideIcons.settings), label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        // Tapping the current section returns it to its first screen.
        onDestinationSelected: (i) => navigationShell.goBranch(i,
            initialLocation: i == navigationShell.currentIndex),
        destinations: destinations,
      ),
    );
  }
}

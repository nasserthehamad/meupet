import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../common/chat_list_screen.dart';
import '../common/profile_screen.dart';
import 'agenda_screen.dart';
import 'home_screen.dart';
import 'my_pets_screen.dart';

class TutorShell extends StatefulWidget {
  const TutorShell({super.key});
  @override
  State<TutorShell> createState() => _TutorShellState();
}

class _TutorShellState extends State<TutorShell> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onGoToPets: () => setState(() => _i = 1)),
      const MyPetsScreen(),
      const AgendaScreen(),
      const ChatListScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _i, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.teal.withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded, color: AppColors.teal), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.pets_outlined), selectedIcon: Icon(Icons.pets_rounded, color: AppColors.teal), label: 'Meus Pets'),
          NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event_rounded, color: AppColors.teal), label: 'Agenda'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline_rounded), selectedIcon: Icon(Icons.chat_bubble_rounded, color: AppColors.teal), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded, color: AppColors.teal), label: 'Perfil'),
        ],
      ),
    );
  }
}

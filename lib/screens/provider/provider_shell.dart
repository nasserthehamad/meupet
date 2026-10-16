import 'package:flutter/material.dart';

import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../common/chat_list_screen.dart';
import '../common/profile_screen.dart';
import 'provider_screens.dart';

class ProviderShell extends StatefulWidget {
  const ProviderShell({super.key});
  @override
  State<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<ProviderShell> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Appointment>>(
      stream: Db.providerAppointments(Session.uid),
      builder: (context, snap) {
        final all = snap.data ?? [];
        final pending = all.where((a) => a.status == 'pendente').length;
        final pages = [
          AtendimentosScreen(appointments: all, loading: !snap.hasData),
          SolicitacoesScreen(appointments: all, loading: !snap.hasData),
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
            destinations: [
              const NavigationDestination(
                  icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note_rounded, color: AppColors.teal), label: 'Atendimentos'),
              NavigationDestination(
                icon: Badge(isLabelVisible: pending > 0, label: Text('$pending'), child: const Icon(Icons.inbox_outlined)),
                selectedIcon: Badge(isLabelVisible: pending > 0, label: Text('$pending'), child: const Icon(Icons.inbox_rounded, color: AppColors.teal)),
                label: 'Solicitações',
              ),
              const NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline_rounded), selectedIcon: Icon(Icons.chat_bubble_rounded, color: AppColors.teal), label: 'Chat'),
              const NavigationDestination(
                  icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront_rounded, color: AppColors.teal), label: 'Perfil'),
            ],
          ),
        );
      },
    );
  }
}

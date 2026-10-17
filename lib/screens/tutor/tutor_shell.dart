import 'package:flutter/material.dart';

import '../../widgets/app_drawer.dart';
import 'home_screen.dart';

/// Estrutura do tutor: Início com menu ☰ lateral (sem barra de abas),
/// como no protótipo.
class TutorShell extends StatelessWidget {
  const TutorShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      drawer: AppDrawer(),
      body: HomeScreen(),
    );
  }
}

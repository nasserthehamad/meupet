import 'package:flutter/material.dart';

import '../../widgets/app_drawer.dart';
import 'provider_screens.dart';

/// Estrutura do prestador: Início com menu ☰ lateral, como no protótipo.
class ProviderShell extends StatelessWidget {
  const ProviderShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      drawer: AppDrawer(),
      body: ProviderHome(),
    );
  }
}

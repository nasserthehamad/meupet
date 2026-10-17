import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/app_drawer.dart';
import '../common/emergency_screen.dart';
import 'provider_screens.dart';

/// Estrutura do prestador: Início com menu ☰ lateral, como no protótipo.
/// Clínicas 24h recebem um aviso na tela quando chega um SOS.
class ProviderShell extends StatefulWidget {
  const ProviderShell({super.key});

  /// Desligado nas prints automáticas.
  static bool alertBanner = true;
  @override
  State<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<ProviderShell> {
  StreamSubscription<List<Emergency>>? _sub;
  final Set<String> _seen = {};

  @override
  void initState() {
    super.initState();
    if (ProviderShell.alertBanner && hasEmergency24h(Session.current.value)) {
      _sub = Db.openEmergencies().listen(_onAlerts, onError: (_) {});
    }
  }

  void _onAlerts(List<Emergency> list) {
    final fresh = list.where((e) => !_seen.contains(e.id)).toList();
    _seen.addAll(list.map((e) => e.id));
    if (fresh.isEmpty || !mounted) return;
    HapticFeedback.vibrate();
    final e = fresh.first;
    final m = ScaffoldMessenger.of(context);
    m.clearMaterialBanners();
    m.showMaterialBanner(MaterialBanner(
      backgroundColor: AppColors.dark ? const Color(0xFF3A2124) : const Color(0xFFFFF1F1),
      leading: Image.asset('assets/ui/sos.gif', width: 40),
      content: Text(
        fresh.length > 1
            ? '${fresh.length} novos chamados de emergência!'
            : 'SOS: ${e.petName}${e.petSpecies.isEmpty ? '' : ' (${e.petSpecies})'} — ${e.tutorName}',
        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.red),
      ),
      actions: [
        TextButton(onPressed: m.hideCurrentMaterialBanner, child: const Text('Depois')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.red),
          onPressed: () {
            m.hideCurrentMaterialBanner();
            Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyAlertsScreen()));
          },
          child: const Text('Ver'),
        ),
      ],
    ));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      drawer: AppDrawer(),
      body: ProviderHome(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'chat_screen.dart';

/// SOS: clínicas que atendem emergência 24h, com ligação e chat.
/// (Fase 2: alerta automático para as clínicas, com "Aceitar".)
class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<AppUser>>(
        stream: Db.providersByCategory('Emergência 24h'),
        builder: (context, snap) {
          final list = snap.data ?? [];
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              PetHeader(
                showBack: true,
                title: 'Emergência',
                photo: Session.current.value?.photo,
                avatarOverride: Image.asset('assets/ui/sos.gif', width: 80),
              ),
              SnakeBand(
                index: 1,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.emergency_rounded, color: AppColors.red, size: 30),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Seu pet precisa de ajuda agora? Ligue para uma clínica 24h abaixo.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                  ),
                  const SectionTitle('Clínicas 24h'),
                  if (!snap.hasData)
                    const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
                  else if (list.isEmpty)
                    const EmptyState(
                      icon: Icons.local_hospital_rounded,
                      text: 'Ainda não há clínicas 24h cadastradas.\nEm emergência, procure o veterinário mais próximo.',
                    )
                  else
                    for (final p in list)
                      WhiteBlock(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          PhotoAvatar(photo: p.photo, size: 54, fallbackIcon: Icons.local_hospital_rounded),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(p.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                              if (p.address.isNotEmpty || p.city.isNotEmpty)
                                Text([p.address, p.city].where((e) => e.isNotEmpty).join(' · '),
                                    style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                            ]),
                          ),
                          IconButton(
                            tooltip: 'Conversar',
                            icon: const Icon(Icons.chat_rounded, color: AppColors.teal),
                            onPressed: () async {
                              final id = await Db.openChat(p.id, p.displayName);
                              if (!context.mounted) return;
                              Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: id, otherName: p.displayName, otherId: p.id)));
                            },
                          ),
                          IconButton.filled(
                            tooltip: 'Ligar',
                            style: IconButton.styleFrom(backgroundColor: AppColors.green),
                            icon: const Icon(Icons.call_rounded, color: Colors.white),
                            onPressed: p.phone.isEmpty ? null : () => launchUrl(Uri.parse('tel:${p.phone.replaceAll(RegExp(r'[^0-9+]'), '')}')),
                          ),
                        ]),
                      ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

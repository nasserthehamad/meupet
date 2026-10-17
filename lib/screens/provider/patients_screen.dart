import 'package:flutter/material.dart';

import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../tutor/pet_detail_screen.dart';

/// Pets já atendidos (ou agendados) pelo prestador.
class PatientsScreen extends StatelessWidget {
  const PatientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final u = Session.current.value;
    return Scaffold(
      body: StreamBuilder<List<Appointment>>(
        stream: Db.providerAppointments(Session.uid),
        builder: (context, snap) {
          final seen = <String>{};
          final pets = <Appointment>[];
          for (final a in (snap.data ?? []).reversed) {
            if (seen.add(a.petId)) pets.add(a);
          }
          pets.sort((a, b) => a.petName.compareTo(b.petName));
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              PetHeader(showBack: true, title: 'Meus Pacientes', photo: u?.photo, fallbackIcon: Icons.storefront_rounded),
              SnakeBand(
                index: 1,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 30),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (!snap.hasData)
                    const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
                  else if (pets.isEmpty)
                    const EmptyState(icon: Icons.pets_rounded, text: 'Os pets que você atender aparecem aqui.')
                  else
                    for (final a in pets)
                      WhiteBlock(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          leading: PhotoAvatar(photo: a.petPhoto, size: 48),
                          title: Text(a.petName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${a.species} · Tutor: ${a.tutorName}'),
                          trailing: const Icon(Icons.assignment_rounded, color: AppColors.brown),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HistoricoScreen(petId: a.petId))),
                        ),
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

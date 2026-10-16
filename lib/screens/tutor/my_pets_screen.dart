import 'package:flutter/material.dart';

import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'agenda_screen.dart';
import 'pet_detail_screen.dart';
import 'pet_form_screen.dart';

class MyPetsScreen extends StatelessWidget {
  const MyPetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final u = Session.current.value;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo pet'),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PetFormScreen())),
      ),
      body: StreamBuilder<List<Pet>>(
        stream: Db.myPets(Session.uid),
        builder: (context, snap) {
          final pets = snap.data ?? [];
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              PetHeader(title: u?.name, photo: u?.photo),
              SnakeBand(
                index: 1,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const SectionTitle('Meus Pets'),
                  if (!snap.hasData)
                    const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
                  else if (pets.isEmpty)
                    const EmptyState(icon: Icons.pets_rounded, text: 'Você ainda não cadastrou nenhum pet.\nToque em "Novo pet" para começar!')
                  else
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      childAspectRatio: 0.7,
                      children: [for (final p in pets) _PetCell(pet: p)],
                    ),
                ]),
              ),
              const SnakeBand(
                index: 2,
                roundBottom: false,
                padding: EdgeInsets.only(top: 6, bottom: 100),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SectionTitle('Agendamentos Próximos'),
                  UpcomingAppointments(limit: 3),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PetCell extends StatelessWidget {
  final Pet pet;
  const _PetCell({required this.pet});

  void _open(BuildContext context, int tab) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PetDetailScreen(petId: pet.id, initialTab: tab)),
      );

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      GestureDetector(
        onTap: () => _open(context, 0),
        child: Stack(alignment: Alignment.bottomCenter, children: [
          PhotoAvatar(photo: pet.photo, size: 96, border: AppColors.bg),
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(10)),
            child: Text(pet.name, style: scriptStyle(16, AppColors.teal)),
          ),
        ]),
      ),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _mini(Icons.assignment_rounded, AppColors.brown, () => _open(context, 1)),
        _mini(Icons.vaccines_rounded, AppColors.teal, () => _open(context, 2)),
        _mini(Icons.badge_rounded, AppColors.yellow, () => _open(context, 0)),
      ]),
    ]);
  }

  Widget _mini(IconData i, Color c, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          child: CircleAvatar(radius: 14, backgroundColor: c, child: Icon(i, size: 15, color: Colors.white)),
        ),
      );
}

import 'package:flutter/material.dart';

import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/rating.dart';

/// Botão "Info." do protótipo (bloquinho laranja).
class InfoAction extends StatelessWidget {
  const InfoAction({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Transform.rotate(
          angle: -0.12,
          child: Container(
            width: 34,
            height: 26,
            decoration: BoxDecoration(color: const Color(0xFFF07A2A), borderRadius: BorderRadius.circular(4)),
            child: const Icon(Icons.notes_rounded, color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(height: 3),
        const Text('Info.', style: TextStyle(fontSize: 9, color: AppColors.muted)),
      ]),
    );
  }
}

/// Balão "Info." do protótipo: observações do tutor, cuidados do pet e a
/// "Avaliação do PET" deixada pelos prestadores (comportamento).
Future<void> showPetInfoSheet(
  BuildContext context, {
  required String petId,
  required String petName,
  String? petPhoto,
  String obs = '',
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      maxChildSize: 0.92,
      builder: (c, scroll) => StreamBuilder<Pet>(
        stream: Db.petStream(petId),
        builder: (c, petSnap) => StreamBuilder<List<PetNote>>(
          stream: Db.petNotes(petId),
          builder: (c, notesSnap) {
            final pet = petSnap.data;
            final notes = notesSnap.data ?? const <PetNote>[];
            final avg = notes.isEmpty ? 0.0 : notes.fold<int>(0, (a, n) => a + n.stars) / notes.length;
            final bullets = <String>[
              if (obs.isNotEmpty) obs,
              if ((pet?.allergies ?? '').isNotEmpty) 'Alergias: ${pet!.allergies}',
              if ((pet?.treatments ?? '').isNotEmpty) 'Tratamentos: ${pet!.treatments}',
              if ((pet?.food ?? '').isNotEmpty) 'Alimentação: ${pet!.food}',
            ];
            return ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(20, 14, 20, 30), children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 12),
              Row(children: [
                PhotoAvatar(photo: petPhoto ?? pet?.photo, size: 58),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(petName, style: scriptStyle(26, AppColors.teal)),
                    if (pet != null)
                      Text([pet.species, pet.breed, ageLabel(pet.birthDate)].where((e) => e.isNotEmpty && e != '-').join(' · '),
                          style: const TextStyle(color: AppColors.muted)),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              if (bullets.isEmpty)
                const Text('O tutor não deixou observações.', style: TextStyle(color: AppColors.muted))
              else
                for (final b in bullets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('•  $b', style: const TextStyle(height: 1.3)),
                  ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  Stars(avg, size: 26),
                  const SizedBox(height: 2),
                  Text(
                    notes.isEmpty ? 'Avaliação do PET — ainda sem notas' : 'Avaliação do PET · ${notes.length} prestador(es)',
                    style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              for (final n in notes.take(10))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(n.providerName, style: const TextStyle(fontWeight: FontWeight.w600))),
                      Stars(n.stars.toDouble(), size: 14),
                    ]),
                    if (n.text.isNotEmpty) Text(n.text, style: TextStyle(color: AppColors.text2)),
                  ]),
                ),
              if (Session.current.value?.isProvider == true) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                  onPressed: () => _ratePet(c, petId, petName),
                  icon: const Icon(Icons.star_rounded, color: kStar),
                  label: Text('Avaliar o comportamento de $petName'),
                ),
              ],
            ]);
          },
        ),
      ),
    ),
  );
}

Future<void> _ratePet(BuildContext context, String petId, String petName) async {
  var stars = 0;
  final text = TextEditingController();
  await showDialog(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => AlertDialog(
        title: Text('Como foi com $petName?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                onPressed: () => setS(() => stars = i),
                icon: Icon(i <= stars ? Icons.star_rounded : Icons.star_outline_rounded, color: kStar, size: 32),
              ),
          ]),
          TextField(
            controller: text,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: inputDeco('Ex.: dócil, ansioso no banho, gosta de petiscos'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              if (stars == 0) return;
              await Db.addPetNote(petId, stars, text.text);
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    ),
  );
}

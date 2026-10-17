import 'package:flutter/material.dart';

import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../common/chat_screen.dart';
import 'agenda_screen.dart';
import 'pet_detail_screen.dart';
import 'pet_form_screen.dart';

class MyPetsScreen extends StatefulWidget {
  const MyPetsScreen({super.key});
  @override
  State<MyPetsScreen> createState() => _MyPetsScreenState();
}

class _MyPetsScreenState extends State<MyPetsScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final u = Session.current.value;
    return Scaffold(
      body: StreamBuilder<List<Pet>>(
        stream: Db.myPets(Session.uid),
        builder: (context, snap) {
          final all = snap.data ?? [];
          final pets = _q.isEmpty ? all : all.where((p) => p.name.toLowerCase().contains(_q.toLowerCase())).toList();
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              PetHeader(white: true, showBack: true, title: u?.name, photo: u?.photo),
              SnakeBand(
                index: 2,
                padding: const EdgeInsets.fromLTRB(10, 18, 10, 22),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: TextField(
                      onChanged: (v) => setState(() => _q = v.trim()),
                      decoration: InputDecoration(
                        hintText: 'Digite sua busca',
                        hintStyle: const TextStyle(color: AppColors.muted),
                        suffixIcon: const Icon(Icons.search_rounded, color: AppColors.teal),
                        filled: true,
                        fillColor: AppColors.surface,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 14, 0, 4),
                    child: Row(children: [
                      Expanded(child: Text('Meus Pets', style: sectionStyle().copyWith(fontSize: 20))),
                      TextButton.icon(
                        key: const Key('novo_pet'),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PetFormScreen())),
                        icon: const Icon(Icons.add_circle_rounded, color: AppColors.orange),
                        label: const Text('Novo pet', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                  if (!snap.hasData)
                    const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
                  else if (all.isEmpty)
                    const EmptyState(icon: Icons.pets_rounded, text: 'Você ainda não cadastrou nenhum pet.\nToque em "Novo pet" para começar!')
                  else
                    LayoutBuilder(builder: (context, c) {
                      final w = c.maxWidth / 3;
                      return Wrap(children: [for (final p in pets) SizedBox(width: w, child: _PetCell(pet: p))]);
                    }),
                ]),
              ),
              SnakeBand(
                index: 3,
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 40),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Text('Agendamentos Próximos', style: sectionStyle().copyWith(fontSize: 20))),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgendaScreen())),
                      child: const Text('Ver todos', style: TextStyle(color: AppColors.muted)),
                    ),
                  ]),
                  const _Upcoming(),
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

  void _open(BuildContext context, int which) {
    switch (which) {
      case 1:
        Navigator.push(context, MaterialPageRoute(builder: (_) => HistoricoScreen(petId: pet.id)));
        break;
      case 2:
        Navigator.push(context, MaterialPageRoute(builder: (_) => VacinasScreen(petId: pet.id)));
        break;
      default:
        Navigator.push(context, fadeRoute(CarteirinhaScreen(petId: pet.id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(children: [
        GestureDetector(
          onTap: () => _open(context, 0),
          child: Stack(alignment: Alignment.bottomCenter, children: [
            PhotoAvatar(photo: pet.photo, size: 104, border: AppColors.surface),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                pet.name,
                style: scriptStyle(19, AppColors.teal).copyWith(
                  shadows: [Shadow(color: AppColors.surface, blurRadius: 6), Shadow(color: AppColors.surface, blurRadius: 3)],
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _mini(Image.asset('assets/ui/clipboard.png'), Colors.transparent, 'Histórico clínico', () => _open(context, 1)),
          _mini(Padding(padding: const EdgeInsets.all(5), child: Image.asset('assets/ui/cal_clock.png')), AppColors.teal, 'Vacinas',
              () => _open(context, 2)),
          _mini(Image.asset('assets/ui/idcard.png'), Colors.transparent, 'Carteirinha', () => _open(context, 0)),
        ]),
      ]),
    );
  }

  Widget _mini(Widget child, Color bg, String tip, VoidCallback onTap) => Tooltip(
        message: tip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 33,
            height: 33,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
            child: child,
          ),
        ),
      );
}

/// Agendamentos próximos (compacto, com Notificar e Reagendar).
class _Upcoming extends StatelessWidget {
  const _Upcoming();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Appointment>>(
      stream: Db.tutorAppointments(Session.uid),
      builder: (context, snap) {
        final now = DateTime.now().subtract(const Duration(hours: 2));
        final l = (snap.data ?? [])
            .where((a) => (a.dateTime ?? now).isAfter(now) && a.status != 'cancelado' && a.status != 'recusado')
            .take(4)
            .toList();
        if (snap.hasData && l.isEmpty) {
          return const EmptyState(icon: Icons.event_note_rounded, text: 'Sem agendamentos próximos.\nEscolha um serviço na Início para agendar.');
        }
        return Column(children: [for (final a in l) _UpcomingTile(a: a)]);
      },
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  final Appointment a;
  const _UpcomingTile({required this.a});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        DateBadge(a.dateTime, big: true),
        const SizedBox(width: 8),
        PhotoAvatar(photo: a.petPhoto, size: 46, border: AppColors.surface),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.petName, style: TextStyle(fontSize: 14, color: AppColors.text2, fontWeight: FontWeight.w600)),
            Text('${a.service}${a.taxiPet ? ' + Taxipet' : ''}',
                style: TextStyle(fontSize: 13, color: AppColors.text2), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('${fmtTime(a.dateTime)} · ${a.providerName}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            const SizedBox(height: 2),
            StatusChip(a.status),
          ]),
        ),
        _ImgButton(
          asset: 'assets/ui/notificar.png',
          label: 'Notificar',
          onTap: () async {
            final id = await Db.openChat(a.providerId, a.providerName);
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  chatId: id,
                  otherName: a.providerName,
                  otherId: a.providerId,
                  initialText: 'Olá! Sobre o agendamento de ${a.petName} (${a.service}) em ${fmtDate(a.dateTime)} às ${fmtTime(a.dateTime)}: ',
                ),
              ),
            );
          },
        ),
        _ImgButton(
          asset: 'assets/ui/reagendar.png',
          label: 'Reagendar',
          onTap: () async {
            final d = await pickDateTime(context, initial: a.dateTime);
            if (d == null) return;
            await Db.reschedule(a.id, d, byProvider: false);
            if (context.mounted) showSnack(context, 'Pedido de reagendamento enviado para ${a.providerName}.');
          },
        ),
      ]),
    );
  }
}

class _ImgButton extends StatelessWidget {
  final String asset;
  final String label;
  final VoidCallback onTap;
  const _ImgButton({required this.asset, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset(asset, width: 32, height: 32),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
        ]),
      ),
    );
  }
}

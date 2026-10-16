import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../common/chat_screen.dart';

class AgendaScreen extends StatelessWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Appointment>>(
      stream: Db.tutorAppointments(Session.uid),
      builder: (context, snap) {
        final all = snap.data ?? [];
        final now = DateTime.now().subtract(const Duration(hours: 2));
        final upcoming = all.where((a) => (a.dateTime ?? now).isAfter(now) && a.status != 'cancelado' && a.status != 'recusado').toList();
        final past = all.where((a) => !upcoming.contains(a)).toList().reversed.toList();
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            PetHeader(title: 'Agendamentos', photo: Session.current.value?.photo),
            SnakeBand(
              index: 1,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle('Próximos'),
                if (!snap.hasData)
                  const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
                else if (upcoming.isEmpty)
                  const EmptyState(icon: Icons.event_available_rounded, text: 'Nenhum agendamento.\nEscolha um serviço na tela Início para agendar.')
                else
                  for (final a in upcoming) TutorAppointmentTile(a: a),
              ]),
            ),
            if (past.isNotEmpty)
              SnakeBand(
                index: 2,
                roundBottom: false,
                padding: const EdgeInsets.only(top: 6, bottom: 40),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const SectionTitle('Histórico'),
                  for (final a in past) TutorAppointmentTile(a: a, compact: true),
                ]),
              ),
          ],
        );
      },
    );
  }
}

/// Lista curta usada em "Meus Pets".
class UpcomingAppointments extends StatelessWidget {
  final int limit;
  const UpcomingAppointments({super.key, this.limit = 3});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Appointment>>(
      stream: Db.tutorAppointments(Session.uid),
      builder: (context, snap) {
        final now = DateTime.now().subtract(const Duration(hours: 2));
        final l = (snap.data ?? [])
            .where((a) => (a.dateTime ?? now).isAfter(now) && a.status != 'cancelado' && a.status != 'recusado')
            .take(limit)
            .toList();
        if (snap.hasData && l.isEmpty) {
          return const EmptyState(icon: Icons.event_note_rounded, text: 'Sem agendamentos próximos.');
        }
        return Column(children: [for (final a in l) TutorAppointmentTile(a: a)]);
      },
    );
  }
}

class TutorAppointmentTile extends StatelessWidget {
  final Appointment a;
  final bool compact;
  const TutorAppointmentTile({super.key, required this.a, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final active = a.status == 'pendente' || a.status == 'confirmado';
    return WhiteBlock(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        Row(children: [
          DateBadge(a.dateTime),
          const SizedBox(width: 10),
          PhotoAvatar(photo: a.petPhoto, size: 42),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${a.petName} · ${a.service}${a.taxiPet ? ' + TaxiPet' : ''}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text('${a.providerName} · ${fmtTime(a.dateTime)}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              const SizedBox(height: 3),
              StatusChip(a.status),
            ]),
          ),
          Icon(iconForService(a.service), color: AppColors.teal.withValues(alpha: 0.6)),
        ]),
        if (!compact && active) ...[
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            RoundAction(
              icon: Icons.chat_rounded,
              label: 'Conversar',
              color: AppColors.teal,
              onTap: () async {
                final id = await Db.openChat(a.providerId, a.providerName);
                if (!context.mounted) return;
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: id, otherName: a.providerName)));
              },
            ),
            RoundAction(
              icon: Icons.edit_calendar_rounded,
              label: 'Reagendar',
              color: AppColors.orange,
              onTap: () async {
                final d = await pickDateTime(context, initial: a.dateTime);
                if (d == null) return;
                await Db.reschedule(a.id, d, byProvider: false);
                if (context.mounted) showSnack(context, 'Pedido de reagendamento enviado.');
              },
            ),
            RoundAction(
              icon: Icons.close_rounded,
              label: 'Cancelar',
              color: AppColors.red,
              onTap: () async {
                final ok = await confirm(context, 'Cancelar agendamento?', '${a.service} de ${a.petName} em ${fmtDate(a.dateTime)}.', ok: 'Cancelar agendamento');
                if (ok) await Db.setAppointmentStatus(a.id, 'cancelado');
              },
            ),
          ]),
        ],
      ]),
    );
  }
}

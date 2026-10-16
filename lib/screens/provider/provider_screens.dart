import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../common/chat_screen.dart';
import '../tutor/pet_detail_screen.dart';

String _groupTitle() {
  final cats = Session.current.value?.categories ?? const <String>[];
  for (final g in serviceGroups) {
    if (g.items.any((i) => cats.contains(i.name))) return g.title.toUpperCase();
  }
  return '+CUIDADO';
}

/// Agenda de atendimentos confirmados.
class AtendimentosScreen extends StatefulWidget {
  final List<Appointment> appointments;
  final bool loading;
  const AtendimentosScreen({super.key, required this.appointments, required this.loading});
  @override
  State<AtendimentosScreen> createState() => _AtendimentosScreenState();
}

class _AtendimentosScreenState extends State<AtendimentosScreen> {
  String _filter = 'Próximos';

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final u = Session.current.value;
    final now = DateTime.now();
    final confirmed = widget.appointments.where((a) => a.status == 'confirmado').toList();
    List<Appointment> list;
    switch (_filter) {
      case 'Hoje':
        list = confirmed.where((a) => a.dateTime != null && _sameDay(a.dateTime!, now)).toList();
        break;
      case 'Concluídos':
        list = widget.appointments.where((a) => a.status == 'concluido').toList().reversed.toList();
        break;
      case 'Todos':
        list = confirmed;
        break;
      default:
        list = confirmed.where((a) => (a.dateTime ?? now).isAfter(now.subtract(const Duration(hours: 3)))).toList();
    }
    final todayCount = confirmed.where((a) => a.dateTime != null && _sameDay(a.dateTime!, now)).length;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        PetHeader(title: _groupTitle(), subtitle: u?.displayName, photo: u?.photo, fallbackIcon: Icons.storefront_rounded),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _stat('Hoje', '$todayCount', AppColors.teal),
            const SizedBox(width: 10),
            _stat('Pendentes', '${widget.appointments.where((a) => a.status == 'pendente').length}', AppColors.orange),
            const SizedBox(width: 10),
            _stat('Concluídos', '${widget.appointments.where((a) => a.status == 'concluido').length}', AppColors.green),
          ]),
        ),
        SectionTitle(
          'Atendimentos',
          trailing: PopupMenuButton<String>(
            initialValue: _filter,
            onSelected: (v) => setState(() => _filter = v),
            itemBuilder: (_) => [for (final f in const ['Hoje', 'Próximos', 'Todos', 'Concluídos']) PopupMenuItem(value: f, child: Text(f))],
            child: Chip(
              avatar: const Icon(Icons.filter_list_rounded, size: 16, color: AppColors.teal),
              label: Text(_filter),
              backgroundColor: Colors.white,
            ),
          ),
        ),
        if (widget.loading)
          const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
        else if (list.isEmpty)
          const EmptyState(icon: Icons.event_available_rounded, text: 'Nenhum atendimento aqui.\nNovos pedidos aparecem em "Solicitações".')
        else
          for (final a in list) ProviderAppointmentTile(a: a),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _stat(String label, String v, Color c) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Text(v, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c)),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ]),
        ),
      );
}

/// Pedidos aguardando aceite.
class SolicitacoesScreen extends StatelessWidget {
  final List<Appointment> appointments;
  final bool loading;
  const SolicitacoesScreen({super.key, required this.appointments, required this.loading});

  @override
  Widget build(BuildContext context) {
    final u = Session.current.value;
    final pending = appointments.where((a) => a.status == 'pendente').toList();
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        PetHeader(title: 'Aceitar Agendamentos', subtitle: u?.displayName, photo: u?.photo, fallbackIcon: Icons.storefront_rounded),
        if (loading)
          const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
        else if (pending.isEmpty)
          const EmptyState(icon: Icons.inbox_rounded, text: 'Nenhuma solicitação pendente. 🐾')
        else
          for (final a in pending) ProviderAppointmentTile(a: a, pending: true),
        const SizedBox(height: 30),
      ],
    );
  }
}

class ProviderAppointmentTile extends StatelessWidget {
  final Appointment a;
  final bool pending;
  const ProviderAppointmentTile({super.key, required this.a, this.pending = false});

  @override
  Widget build(BuildContext context) {
    return WhiteBlock(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          DateBadge(a.dateTime),
          const SizedBox(width: 10),
          PhotoAvatar(photo: a.petPhoto, size: 46),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(fmtTime(a.dateTime), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.teal)),
              Text('Nome: ${a.petName}', style: const TextStyle(fontSize: 13)),
              Text('Animal: ${a.species}', style: const TextStyle(fontSize: 13)),
              Text('Serviço: ${a.service}${a.taxiPet ? ' + TaxiPet' : ''}', style: const TextStyle(fontSize: 13)),
              if (a.taxiPet && a.address.isNotEmpty)
                Row(children: [
                  const Icon(Icons.place_rounded, size: 14, color: AppColors.orange),
                  Expanded(child: Text(a.address, style: const TextStyle(fontSize: 12, color: AppColors.orange))),
                ]),
              if (a.notes.isNotEmpty) Text('Obs.: ${a.notes}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              Text('Tutor: ${a.tutorName}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ),
          if (!pending) StatusChip(a.status),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          if (pending) ...[
            RoundAction(icon: Icons.check_rounded, label: 'Aceitar', color: AppColors.green, onTap: () => _setStatus(context, 'confirmado', 'Agendamento confirmado!')),
            RoundAction(icon: Icons.close_rounded, label: 'Recusar', color: AppColors.red, onTap: () async {
              final ok = await confirm(context, 'Recusar pedido?', 'O tutor será avisado no app.', ok: 'Recusar');
              if (ok && context.mounted) _setStatus(context, 'recusado', 'Pedido recusado.');
            }),
          ] else if (a.status == 'confirmado')
            RoundAction(icon: Icons.task_alt_rounded, label: 'Concluir', color: AppColors.green, onTap: () => _setStatus(context, 'concluido', 'Atendimento concluído!')),
          RoundAction(
            icon: Icons.edit_calendar_rounded,
            label: 'Reagendar',
            color: AppColors.orange,
            onTap: () async {
              final d = await pickDateTime(context, initial: a.dateTime);
              if (d == null) return;
              await Db.reschedule(a.id, d, byProvider: true);
              if (context.mounted) showSnack(context, 'Reagendado para ${fmtDate(d)} às ${fmtTime(d)}.');
            },
          ),
          RoundAction(
            icon: Icons.assignment_rounded,
            label: 'Prontuário',
            color: AppColors.brown,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PetDetailScreen(petId: a.petId, initialTab: 1))),
          ),
          RoundAction(
            icon: Icons.chat_rounded,
            label: 'Conversar',
            color: AppColors.teal,
            onTap: () async {
              final id = await Db.openChat(a.tutorId, a.tutorName);
              if (!context.mounted) return;
              Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: id, otherName: a.tutorName, otherId: a.tutorId)));
            },
          ),
        ]),
      ]),
    );
  }

  Future<void> _setStatus(BuildContext context, String s, String msg) async {
    await Db.setAppointmentStatus(a.id, s);
    if (context.mounted) showSnack(context, msg);
  }
}

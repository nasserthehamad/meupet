import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../common/chat_screen.dart';
import '../tutor/pet_detail_screen.dart';

String providerGroupWord() {
  final cats = Session.current.value?.categories ?? const <String>[];
  for (final c in cats) {
    final g = groupOfCategory(c);
    if (g != null) return g.heroTitle;
  }
  return '+CUIDADO';
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Início do prestador (vet, petshop, TaxiPet…), como no vídeo do protótipo.
class ProviderHome extends StatefulWidget {
  const ProviderHome({super.key});
  @override
  State<ProviderHome> createState() => _ProviderHomeState();
}

class _ProviderHomeState extends State<ProviderHome> {
  String _q = '';
  DateTime? _date;
  String _filter = 'confirmado';
  int _page = 0;

  bool _match(Appointment a) {
    if (_q.isEmpty) return true;
    final q = _q.toLowerCase();
    return a.petName.toLowerCase().contains(q) || a.tutorName.toLowerCase().contains(q) || a.service.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final u = Session.current.value;
    return StreamBuilder<List<Appointment>>(
      stream: Db.providerAppointments(Session.uid),
      builder: (context, snap) {
        final all = (snap.data ?? []).where(_match).toList();
        final now = DateTime.now();
        // Atendimentos (paginados por dia)
        final atend = all.where((a) => a.dateTime != null && (_filter == 'todos' ? a.status != 'pendente' : a.status == _filter)).toList();
        List<DateTime> days;
        if (_date != null) {
          days = [_day(_date!)];
        } else {
          final set = <DateTime>{for (final a in atend) _day(a.dateTime!)}.toList()..sort();
          final future = set.where((d) => !d.isBefore(_day(now))).toList();
          days = _filter == 'confirmado' && future.isNotEmpty ? future : set.reversed.toList();
        }
        final page = days.isEmpty ? 0 : _page.clamp(0, days.length - 1);
        final dayList = days.isEmpty ? <Appointment>[] : atend.where((a) => _sameDay(a.dateTime!, days[page])).toList();
        final pending = all.where((a) => a.status == 'pendente').toList();

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            _ProviderHeader(user: u, pending: pending.length),
            SnakeBand(
              index: 1,
              padding: const EdgeInsets.fromLTRB(14, 16, 12, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      onChanged: (v) => setState(() {
                        _q = v.trim();
                        _page = 0;
                      }),
                      decoration: _pill('Digite sua busca', Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        if (_date != null) {
                          setState(() => _date = null);
                          return;
                        }
                        final d = await pickDate(context, initial: now);
                        if (d != null) setState(() => _date = d);
                      },
                      child: InputDecorator(
                        isEmpty: true,
                        decoration: _pill(_date == null ? 'Digite a data' : fmtDate(_date), _date == null ? Icons.event_rounded : Icons.close_rounded),
                        child: const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Text('Atendimentos', style: sectionStyle().copyWith(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(providerGroupWord(), style: scriptStyle(26, const Color(0xFFCFD3D4))),
                  const Spacer(),
                  PopupMenuButton<String>(
                    tooltip: 'Filtrar',
                    initialValue: _filter,
                    onSelected: (v) => setState(() {
                      _filter = v;
                      _page = 0;
                    }),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'confirmado', child: Text('Confirmados')),
                      PopupMenuItem(value: 'concluido', child: Text('Concluídos')),
                      PopupMenuItem(value: 'todos', child: Text('Todos')),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Row(children: [
                        Icon(Icons.filter_list_rounded, size: 18, color: AppColors.muted),
                        Text(' Filtrar', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                      ]),
                    ),
                  ),
                ]),
                if (days.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 4),
                    child: Text(_dayLabel(days[page], now), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ),
                if (!snap.hasData)
                  const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
                else if (dayList.isEmpty)
                  const EmptyState(icon: Icons.event_available_rounded, text: 'Nenhum atendimento aqui.\nPedidos novos aparecem em "Agendamentos Próximos".')
                else
                  for (final a in dayList) _AtendimentoTile(a: a),
                if (days.length > 1)
                  _Pager(count: days.length, page: page, onPage: (p) => setState(() => _page = p)),
              ]),
            ),
            SnakeBand(
              index: 2,
              roundBottom: false,
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 40),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text('Agendamentos Próximos', style: sectionStyle().copyWith(fontSize: 20))),
                  if (pending.isNotEmpty) Image.asset('assets/images/alerta.gif', width: 30, height: 30),
                ]),
                const SizedBox(height: 6),
                if (snap.hasData && pending.isEmpty)
                  const EmptyState(icon: Icons.inbox_rounded, text: 'Nenhum pedido aguardando confirmação.')
                else
                  for (final a in pending) _PedidoTile(a: a),
              ]),
            ),
          ],
        );
      },
    );
  }

  String _dayLabel(DateTime d, DateTime now) {
    if (_sameDay(d, now)) return 'Hoje, ${fmtDate(d)}';
    if (_sameDay(d, now.add(const Duration(days: 1)))) return 'Amanhã, ${fmtDate(d)}';
    const w = ['segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];
    return '${w[d.weekday - 1][0].toUpperCase()}${w[d.weekday - 1].substring(1)}, ${fmtDate(d)}';
  }

  InputDecoration _pill(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
        suffixIcon: Icon(icon, color: AppColors.teal),
        filled: true,
        fillColor: const Color(0xFFF2F3F3),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );
}

class _ProviderHeader extends StatelessWidget {
  final AppUser? user;
  final int pending;
  const _ProviderHeader({required this.user, required this.pending});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return ColoredBox(
      color: Colors.white,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(kBandRadius)),
        ),
        padding: EdgeInsets.fromLTRB(14, top + 10, 14, 22),
        child: Stack(children: [
          const Positioned.fill(child: IgnorePointer(child: PawTrail())),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [MenuButton(), SizedBox(width: 6), LogoText(size: 26)]),
              const SizedBox(height: 8),
              BellButton(
                dot: pending > 0,
                onTap: () => showSnack(
                  context,
                  pending == 0 ? 'Nenhum aviso novo.' : '$pending pedido(s) aguardando confirmação — veja em Agendamentos Próximos.',
                ),
              ),
            ]),
            Expanded(
              child: Center(
                child: PhotoAvatar(photo: user?.photo, size: 104, fallbackIcon: Icons.storefront_rounded, border: Colors.white),
              ),
            ),
            const _EmergencyCard(count: 0),
          ]),
        ]),
      ),
    );
  }
}

/// Painel "EMERGÊNCIA" (fase 2: alertas SOS reais com "Aceitar").
class _EmergencyCard extends StatelessWidget {
  final int count;
  const _EmergencyCard({required this.count});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showSnack(context, 'Os alertas de SOS dos tutores aparecerão aqui (próxima etapa).'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 74,
        padding: const EdgeInsets.fromLTRB(4, 8, 6, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF2B8BC), width: 2),
        ),
        child: Row(children: [
          const RotatedBox(
            quarterTurns: 3,
            child: Text('EMERGÊNCIA', style: TextStyle(fontSize: 10, letterSpacing: 1, color: AppColors.muted)),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(children: [
              Image.asset('assets/ui/sos.gif', height: 28),
              const SizedBox(height: 4),
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.red, width: 2.5)),
                child: Text('$count', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.red, fontSize: 15)),
              ),
              const SizedBox(height: 2),
              const Text('Aceitar', style: TextStyle(fontSize: 10, color: AppColors.muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  final int count;
  final int page;
  final ValueChanged<int> onPage;
  const _Pager({required this.count, required this.page, required this.onPage});
  @override
  Widget build(BuildContext context) {
    final start = (page - 1).clamp(0, (count - 3).clamp(0, count));
    final end = (start + 3).clamp(0, count);
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      IconButton(
        onPressed: page > 0 ? () => onPage(page - 1) : null,
        icon: const Icon(Icons.chevron_left_rounded),
        color: AppColors.muted,
      ),
      for (var i = start; i < end; i++)
        GestureDetector(
          onTap: () => onPage(i),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: i == page ? AppColors.muted : Colors.white),
            child: Text('${i + 1}',
                style: TextStyle(fontWeight: FontWeight.w700, color: i == page ? Colors.white : AppColors.muted)),
          ),
        ),
      IconButton(
        onPressed: page < count - 1 ? () => onPage(page + 1) : null,
        icon: const Icon(Icons.chevron_right_rounded),
        color: AppColors.muted,
      ),
    ]);
  }
}

class _ImgAction extends StatelessWidget {
  final String asset;
  final String label;
  final VoidCallback onTap;
  final double size;
  const _ImgAction({required this.asset, required this.label, required this.onTap, this.size = 34});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset(asset, width: size, height: size),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
        ]),
      ),
    );
  }
}

class _ApptText extends StatelessWidget {
  final Appointment a;
  final bool showObs;
  const _ApptText({required this.a, this.showObs = true});
  @override
  Widget build(BuildContext context) {
    const st = TextStyle(fontSize: 13, color: Color(0xFF6B7477), height: 1.3);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(fmtTime(a.dateTime), style: st.copyWith(fontWeight: FontWeight.w600, color: AppColors.text)),
      Text('Nome: ${a.petName}', style: st),
      Text('Animal: ${a.species}', style: st),
      if (showObs) Text('Obs.: ${a.notes.isEmpty ? a.service : '${a.service} · ${a.notes}'}', style: st, maxLines: 2, overflow: TextOverflow.ellipsis),
      if (a.taxiPet)
        Row(children: [
          const Icon(Icons.local_taxi_rounded, size: 14, color: AppColors.orange),
          const SizedBox(width: 3),
          Expanded(child: Text(a.address.isEmpty ? 'TaxiPet' : a.address, style: st.copyWith(color: AppColors.orange, fontSize: 12))),
        ]),
    ]);
  }
}

Future<void> _reschedule(BuildContext context, Appointment a) async {
  final d = await pickDateTime(context, initial: a.dateTime);
  if (d == null) return;
  await Db.reschedule(a.id, d, byProvider: true);
  if (context.mounted) showSnack(context, 'Reagendado para ${fmtDate(d)} às ${fmtTime(d)}.');
}

void _prontuario(BuildContext context, Appointment a) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => HistoricoScreen(petId: a.petId)));

class _AtendimentoTile extends StatelessWidget {
  final Appointment a;
  const _AtendimentoTile({required this.a});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showAppointmentSheet(context, a),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          DateBadge(a.dateTime, big: true),
          const SizedBox(width: 8),
          PhotoAvatar(photo: a.petPhoto, size: 54, border: Colors.white),
          const SizedBox(width: 10),
          Expanded(child: _ApptText(a: a)),
          _ImgAction(asset: 'assets/ui/clipboard.png', label: 'Prontuário', onTap: () => _prontuario(context, a)),
          _ImgAction(asset: 'assets/ui/reagendar.png', label: 'Reagendar', onTap: () => _reschedule(context, a)),
        ]),
      ),
    );
  }
}

class _PedidoTile extends StatelessWidget {
  final Appointment a;
  const _PedidoTile({required this.a});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        DateBadge(a.dateTime, big: true),
        const SizedBox(width: 8),
        PhotoAvatar(photo: a.petPhoto, size: 50, border: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: _ApptText(a: a, showObs: false)),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            await Db.setAppointmentStatus(a.id, 'confirmado');
            if (context.mounted) showSnack(context, 'Agendamento de ${a.petName} confirmado!');
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 3, vertical: 4),
            child: Column(children: [
              CircleAvatar(radius: 17, backgroundColor: Color(0xFF5E7A1C), child: Icon(Icons.check_rounded, color: Colors.white)),
              SizedBox(height: 2),
              Text('Confirmar', style: TextStyle(fontSize: 10, color: AppColors.muted)),
            ]),
          ),
        ),
        _ImgAction(asset: 'assets/ui/reagendar.png', label: 'Reagendar', onTap: () => _reschedule(context, a)),
        IconButton(
          tooltip: 'Detalhes',
          visualDensity: VisualDensity.compact,
          onPressed: () => showAppointmentSheet(context, a),
          icon: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ),
      ]),
    );
  }
}

/// Detalhes do agendamento com todas as ações.
Future<void> showAppointmentSheet(BuildContext context, Appointment a) {
  Future<void> set(BuildContext c, String s, String msg) async {
    await Db.setAppointmentStatus(a.id, s);
    if (c.mounted) Navigator.pop(c);
    if (context.mounted) showSnack(context, msg);
  }

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            PhotoAvatar(photo: a.petPhoto, size: 60),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.petName, style: scriptStyle(26, AppColors.teal)),
                Text('${a.species} · Tutor: ${a.tutorName}', style: const TextStyle(color: AppColors.muted)),
              ]),
            ),
            StatusChip(a.status),
          ]),
          const Divider(height: 24),
          Text('${a.service}${a.taxiPet ? ' + TaxiPet' : ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text('${fmtDate(a.dateTime)} às ${fmtTime(a.dateTime)}'),
          if (a.taxiPet && a.address.isNotEmpty) Text('Buscar em: ${a.address}', style: const TextStyle(color: AppColors.orange)),
          if (a.notes.isNotEmpty) Text('Obs.: ${a.notes}', style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          Wrap(alignment: WrapAlignment.spaceAround, spacing: 6, runSpacing: 8, children: [
            if (a.status == 'pendente') ...[
              RoundAction(icon: Icons.check_rounded, label: 'Confirmar', color: AppColors.green, onTap: () => set(c, 'confirmado', 'Agendamento confirmado!')),
              RoundAction(
                icon: Icons.close_rounded,
                label: 'Recusar',
                color: AppColors.red,
                onTap: () async {
                  final ok = await confirm(c, 'Recusar pedido?', 'O tutor verá o pedido como recusado.', ok: 'Recusar');
                  if (ok && c.mounted) await set(c, 'recusado', 'Pedido recusado.');
                },
              ),
            ],
            if (a.status == 'confirmado')
              RoundAction(icon: Icons.task_alt_rounded, label: 'Concluir', color: AppColors.green, onTap: () => set(c, 'concluido', 'Atendimento concluído!')),
            RoundAction(
              icon: Icons.edit_calendar_rounded,
              label: 'Reagendar',
              color: AppColors.orange,
              onTap: () async {
                Navigator.pop(c);
                await _reschedule(context, a);
              },
            ),
            RoundAction(
              icon: Icons.assignment_rounded,
              label: 'Prontuário',
              color: AppColors.brown,
              onTap: () {
                Navigator.pop(c);
                _prontuario(context, a);
              },
            ),
            RoundAction(
              icon: Icons.chat_rounded,
              label: 'Conversar',
              color: AppColors.teal,
              onTap: () async {
                Navigator.pop(c);
                final id = await Db.openChat(a.tutorId, a.tutorName);
                if (!context.mounted) return;
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: id, otherName: a.tutorName, otherId: a.tutorId)));
              },
            ),
          ]),
        ]),
      ),
    ),
  );
}

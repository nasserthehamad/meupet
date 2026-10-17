import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../common/chat_screen.dart';
import '../common/emergency_screen.dart';
import '../common/pet_info_sheet.dart';
import '../common/prescription_screens.dart' show canPrescribe;
import '../common/ride_screens.dart';
import '../common/store_screens.dart';
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

  String? _mode;

  static const _modeLabel = {'servicos': 'Atendimentos', 'corridas': 'Corridas', 'pedidos': 'Pedidos'};
  static const _modeIcon = {
    'servicos': Icons.event_available_rounded,
    'corridas': Icons.local_taxi_rounded,
    'pedidos': Icons.shopping_bag_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final u = Session.current.value;
    final cats = u?.categories ?? const <String>[];
    final modes = <String>[
      if (hasServiceCats(cats) || (!isTaxiUser(cats) && !isStoreUser(cats))) 'servicos',
      if (isTaxiUser(cats)) 'corridas',
      if (isStoreUser(cats)) 'pedidos',
    ];
    // O primeiro serviço cadastrado define a tela inicial (ex.: Pet Taxi abre nas corridas).
    if (cats.isNotEmpty) {
      final first = cats.first == 'TaxiPet' ? 'corridas' : (storeCategoryNames.contains(cats.first) ? 'pedidos' : 'servicos');
      if (modes.remove(first)) modes.insert(0, first);
    }
    final mode = modes.contains(_mode) ? _mode! : modes.first;
    switch (mode) {
      case 'corridas':
        return _ridesView(u, modes, mode);
      case 'pedidos':
        return _ordersView(u, modes, mode);
      default:
        return _servicesView(u, modes, mode);
    }
  }

  Widget _modeChips(List<String> modes, String mode) {
    if (modes.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(spacing: 8, children: [
        for (final m in modes)
          ChoiceChip(
            key: Key('modo_$m'),
            avatar: Icon(_modeIcon[m], size: 18, color: m == mode ? Colors.white : AppColors.teal),
            label: Text(_modeLabel[m]!),
            selected: m == mode,
            selectedColor: AppColors.teal,
            showCheckmark: false,
            labelStyle: TextStyle(color: m == mode ? Colors.white : AppColors.text, fontWeight: FontWeight.w600),
            onSelected: (_) => setState(() {
              _mode = m;
              _page = 0;
            }),
          ),
      ]),
    );
  }

  Widget _searchRow(DateTime now) => Row(children: [
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
              decoration: _pill(_date == null ? 'Data' : fmtShort(_date), _date == null ? Icons.event_rounded : Icons.close_rounded),
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      ]);

  bool _onDate(DateTime? d) => _date == null || (d != null && _sameDay(d, _date!));

  // ------------------------------------------------------------ TaxiPet
  Widget _ridesView(AppUser? u, List<String> modes, String mode) {
    final now = DateTime.now();
    return StreamBuilder<List<Ride>>(
      stream: Db.driverRides(Session.uid),
      builder: (context, snap) {
        final q = _q.toLowerCase();
        final all = (snap.data ?? [])
            .where((r) => q.isEmpty || r.petName.toLowerCase().contains(q) || r.tutorName.toLowerCase().contains(q))
            .toList();
        final requests = all.where((r) => r.status == 'pedida').toList();
        final active = all.where((r) => r.isActive && r.status != 'pedida' && _onDate(r.when)).toList();
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            _ProviderHeader(user: u, pending: requests.length, onNewRides: null),
            SnakeBand(
              index: 1,
              padding: const EdgeInsets.fromLTRB(14, 16, 12, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _modeChips(modes, mode),
                _searchRow(now),
                const SizedBox(height: 14),
                Row(children: [
                  Text('Atendimentos', style: sectionStyle().copyWith(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text('+CUIDADO', style: scriptStyle(26, const Color(0xFFCFD3D4))),
                ]),
                if (!snap.hasData)
                  const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
                else if (active.isEmpty)
                  const EmptyState(icon: Icons.local_taxi_rounded, text: 'Nenhuma corrida confirmada.
Novos pedidos aparecem em "Aceitar Agendamentos".')
                else
                  for (final r in active) RideTile(r: r, driverView: true),
              ]),
            ),
            SnakeBand(
              index: 2,
              roundBottom: false,
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 40),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text('Aceitar Agendamentos', style: sectionStyle().copyWith(fontSize: 20))),
                  if (requests.isNotEmpty) Image.asset('assets/images/alerta.gif', width: 30, height: 30),
                ]),
                const SizedBox(height: 6),
                if (snap.hasData && requests.isEmpty)
                  const EmptyState(icon: Icons.inbox_rounded, text: 'Nenhum pedido de corrida agora.')
                else
                  for (final r in requests) _RideRequestTile(r: r),
              ]),
            ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------ Loja
  Widget _ordersView(AppUser? u, List<String> modes, String mode) {
    final now = DateTime.now();
    return StreamBuilder<List<StoreOrder>>(
      stream: Db.storeOrders(Session.uid),
      builder: (context, snap) {
        final q = _q.toLowerCase();
        final all = (snap.data ?? [])
            .where((o) => q.isEmpty || o.tutorName.toLowerCase().contains(q) || o.nfe.toLowerCase().contains(q) || o.pickupName.toLowerCase().contains(q))
            .toList();
        final novos = all.where((o) => o.status == 'novo').toList();
        final ativos = all.where((o) => (o.status == 'confirmado' || o.status == 'pronto') && _onDate(o.pickupDate ?? o.createdAt)).toList()
          ..sort((a, b) => (a.pickupDate ?? a.createdAt ?? DateTime(2100)).compareTo(b.pickupDate ?? b.createdAt ?? DateTime(2100)));
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            _ProviderHeader(user: u, pending: novos.length),
            SnakeBand(
              index: 1,
              padding: const EdgeInsets.fromLTRB(14, 16, 12, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _modeChips(modes, mode),
                _searchRow(now),
                const SizedBox(height: 14),
                Row(children: [
                  Text('Atendimentos', style: sectionStyle().copyWith(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text('+PRODUTO', style: scriptStyle(26, const Color(0xFFCFD3D4))),
                ]),
                if (!snap.hasData)
                  const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
                else if (ativos.isEmpty)
                  const EmptyState(icon: Icons.shopping_bag_rounded, text: 'Nenhum pedido para separar.
Novos pedidos aparecem em "Pedidos Recebidos".')
                else
                  for (final o in ativos)
                    OrderTile(o: o, storeView: true, actions: [
                      _ImgActionIcon(
                        icon: Icons.push_pin_rounded,
                        color: AppColors.red,
                        label: o.status == 'pronto' ? 'Pronto' : 'Local',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderScreen(orderId: o.id))),
                      ),
                      _ImgAction(asset: 'assets/ui/reagendar.png', label: 'Reagendar', onTap: () => rescheduleOrder(context, o)),
                    ]),
              ]),
            ),
            SnakeBand(
              index: 2,
              roundBottom: false,
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 40),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text('Pedidos Recebidos', style: sectionStyle().copyWith(fontSize: 20))),
                  if (novos.isNotEmpty) Image.asset('assets/images/alerta.gif', width: 30, height: 30),
                ]),
                const SizedBox(height: 6),
                if (snap.hasData && novos.isEmpty)
                  const EmptyState(icon: Icons.inbox_rounded, text: 'Nenhum pedido novo.')
                else
                  for (final o in novos)
                    OrderTile(o: o, storeView: true, actions: [
                      _ConfirmAction(onTap: () async {
                        await Db.updateOrder(o, {'status': 'confirmado'});
                        if (context.mounted) showSnack(context, 'Pedido de ${o.tutorName} confirmado!');
                      }),
                      _ImgAction(asset: 'assets/ui/reagendar.png', label: 'Reagendar', onTap: () => rescheduleOrder(context, o)),
                    ]),
              ]),
            ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------ Serviços
  Widget _servicesView(AppUser? u, List<String> modes, String mode) {
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
            _ProviderHeader(
              user: u,
              pending: pending.length,
              onNewRides: modes.contains('corridas') ? () => setState(() => _mode = 'corridas') : null,
            ),
            SnakeBand(
              index: 1,
              padding: const EdgeInsets.fromLTRB(14, 16, 12, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _modeChips(modes, mode),
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
                        decoration: _pill(_date == null ? 'Data' : fmtShort(_date), _date == null ? Icons.event_rounded : Icons.close_rounded),
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
  final VoidCallback? onNewRides;
  const _ProviderHeader({required this.user, required this.pending, this.onNewRides});

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
          const Positioned(left: 52, top: 64, bottom: 0, width: 40, child: IgnorePointer(child: PawTrail())),
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
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (isTaxiUser(user?.categories ?? const [])) ...[
                  _NewRideBadge(onTap: onNewRides),
                  const SizedBox(width: 6),
                ],
                PhotoAvatar(photo: user?.photo, size: 104, fallbackIcon: Icons.storefront_rounded, border: Colors.white),
              ]),
            ),
            if (hasEmergency24h(user))
              StreamBuilder<List<Emergency>>(
                stream: Db.openEmergencies(),
                builder: (context, snap) => _EmergencyCard(count: snap.data?.length ?? 0),
              ),
          ]),
        ]),
      ),
    );
  }
}

/// Painel "EMERGÊNCIA": chamados SOS abertos, com "Aceitar".
class _EmergencyCard extends StatelessWidget {
  final int count;
  const _EmergencyCard({required this.count});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('painel_emergencia'),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyAlertsScreen())),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 74,
        padding: const EdgeInsets.fromLTRB(4, 8, 6, 8),
        decoration: BoxDecoration(
          color: count > 0 ? const Color(0xFFFFF1F1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: count > 0 ? AppColors.red : const Color(0xFFF2B8BC), width: 2),
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

/// "Nova Corrida" do protótipo do Pet Taxi (carrinho com contador).
class _NewRideBadge extends StatelessWidget {
  final VoidCallback? onTap;
  const _NewRideBadge({this.onTap});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Ride>>(
      stream: Db.driverRides(Session.uid),
      builder: (context, snap) {
        final n = (snap.data ?? []).where((r) => r.status == 'pedida').length;
        return InkWell(
          key: const Key('nova_corrida'),
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Stack(clipBehavior: Clip.none, children: [
                const Icon(Icons.local_taxi_rounded, color: AppColors.teal, size: 40),
                if (n > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: const Color(0xFF3E4446),
                      child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ),
              ]),
              const Text('Nova Corrida', style: TextStyle(fontSize: 10, color: AppColors.muted)),
            ]),
          ),
        );
      },
    );
  }
}

class _ConfirmAction extends StatelessWidget {
  final VoidCallback onTap;
  const _ConfirmAction({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        child: Column(children: [
          CircleAvatar(radius: 15, backgroundColor: Color(0xFF5E7A1C), child: Icon(Icons.check_rounded, color: Colors.white, size: 20)),
          SizedBox(height: 2),
          Text('Confirmar', style: TextStyle(fontSize: 9, color: AppColors.muted)),
        ]),
      ),
    );
  }
}

class _ImgActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _ImgActionIcon({required this.icon, required this.color, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 9, color: AppColors.muted)),
        ]),
      ),
    );
  }
}

/// Pedido de corrida (Confirmar / Reagendar).
class _RideRequestTile extends StatelessWidget {
  final Ride r;
  const _RideRequestTile({required this.r});
  @override
  Widget build(BuildContext context) {
    const st = TextStyle(fontSize: 12, color: Color(0xFF6B7477), height: 1.25);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        DateBadge(r.when, big: true),
        const SizedBox(width: 6),
        PhotoAvatar(photo: r.petPhoto, size: 44, border: Colors.white),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(fmtTime(r.when), style: st.copyWith(fontWeight: FontWeight.w600, color: AppColors.text)),
            Text('Nome: ${r.petName}', style: st, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('Animal: ${r.petSpecies}', style: st, maxLines: 1, overflow: TextOverflow.ellipsis),
            Row(children: [
              const Icon(Icons.local_taxi_rounded, size: 14, color: AppColors.orange),
              const SizedBox(width: 3),
              Expanded(
                child: Text(r.pickup, maxLines: 1, overflow: TextOverflow.ellipsis, style: st.copyWith(color: AppColors.orange, fontSize: 11)),
              ),
            ]),
          ]),
        ),
        _ConfirmAction(onTap: () async {
          await Db.setRideStatus(r, 'aceita');
          if (context.mounted) showSnack(context, 'Corrida de ${r.petName} confirmada!');
        }),
        _ImgAction(asset: 'assets/ui/reagendar.png', label: 'Reagendar', onTap: () => rescheduleRide(context, r)),
        InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RideScreen(rideId: r.id))),
          borderRadius: BorderRadius.circular(16),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 22),
          ),
        ),
      ]),
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
  const _ImgAction({required this.asset, required this.label, required this.onTap});
  static const double size = 30;
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
          Text(label, style: const TextStyle(fontSize: 9, color: AppColors.muted)),
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
    const st = TextStyle(fontSize: 12, color: Color(0xFF6B7477), height: 1.25);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(fmtTime(a.dateTime), style: st.copyWith(fontWeight: FontWeight.w600, color: AppColors.text)),
      Text('Nome: ${a.petName}', style: st, maxLines: 1, overflow: TextOverflow.ellipsis),
      Text('Animal: ${a.species}', style: st, maxLines: 1, overflow: TextOverflow.ellipsis),
      if (showObs) Text('Obs.: ${a.notes.isEmpty ? a.service : '${a.service} · ${a.notes}'}', style: st, maxLines: 2, overflow: TextOverflow.ellipsis),
      if (a.taxiPet)
        Row(children: [
          const Icon(Icons.local_taxi_rounded, size: 14, color: AppColors.orange),
          const SizedBox(width: 3),
          Expanded(
            child: Text(a.address.isEmpty ? 'TaxiPet' : a.address,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: st.copyWith(color: AppColors.orange, fontSize: 11)),
          ),
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
          const SizedBox(width: 6),
          PhotoAvatar(photo: a.petPhoto, size: 46, border: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: _ApptText(a: a)),
          if (canPrescribe(Session.current.value))
            _ImgAction(asset: 'assets/ui/clipboard.png', label: 'Prontuário', onTap: () => _prontuario(context, a))
          else
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => showPetInfoSheet(context, petId: a.petId, petName: a.petName, petPhoto: a.petPhoto, obs: a.notes),
              child: const InfoAction(),
            ),
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
        const SizedBox(width: 6),
        PhotoAvatar(photo: a.petPhoto, size: 44, border: Colors.white),
        const SizedBox(width: 8),
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
              CircleAvatar(radius: 15, backgroundColor: Color(0xFF5E7A1C), child: Icon(Icons.check_rounded, color: Colors.white, size: 20)),
              SizedBox(height: 2),
              Text('Confirmar', style: TextStyle(fontSize: 9, color: AppColors.muted)),
            ]),
          ),
        ),
        _ImgAction(asset: 'assets/ui/reagendar.png', label: 'Reagendar', onTap: () => _reschedule(context, a)),
        InkWell(
          onTap: () => showAppointmentSheet(context, a),
          borderRadius: BorderRadius.circular(16),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 22),
          ),
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

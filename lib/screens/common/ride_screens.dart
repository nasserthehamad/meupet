import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'chat_screen.dart';
import 'pet_info_sheet.dart';

const kTaxiYellow = Color(0xFFF5C518);

Future<void> openMap(String address) => launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}'),
      mode: LaunchMode.externalApplication,
    );

Future<void> callPhone(BuildContext context, String phone, String who) async {
  final p = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (p.isEmpty) {
    showSnack(context, '$who não cadastrou telefone. Use o chat.', error: true);
    return;
  }
  await launchUrl(Uri.parse('tel:$p'));
}

Future<void> openChatWith(BuildContext context, String otherId, String otherName) async {
  final id = await Db.openChat(otherId, otherName);
  if (!context.mounted) return;
  Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: id, otherName: otherName, otherId: otherId)));
}

// ============================================================ pedir corrida

class RideRequestScreen extends StatefulWidget {
  final AppUser driver;
  const RideRequestScreen({super.key, required this.driver});
  @override
  State<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends State<RideRequestScreen> {
  Pet? _pet;
  late final _pickup = TextEditingController(
    text: [Session.current.value?.address ?? '', Session.current.value?.city ?? ''].where((e) => e.isNotEmpty).join(', '),
  );
  final _dest = TextEditingController();
  final _notes = TextEditingController();
  bool _now = true;
  DateTime? _when;
  bool _saving = false;

  Future<void> _send() async {
    if (_pet == null || _pickup.text.trim().isEmpty || _dest.text.trim().isEmpty) {
      showSnack(context, 'Escolha o pet e informe onde buscar e para onde levar.', error: true);
      return;
    }
    if (!_now && _when == null) {
      showSnack(context, 'Escolha o dia e a hora da corrida.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final id = await Db.requestRide(
        pet: _pet!,
        driver: widget.driver,
        pickup: _pickup.text,
        destination: _dest.text,
        when: _now ? DateTime.now() : _when!,
        notes: _notes.text,
      );
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RideScreen(rideId: id)));
    } catch (e) {
      if (mounted) showSnack(context, 'Não foi possível pedir a corrida: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.driver;
    final price = d.prices['TaxiPet'];
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          PetHeader(showBack: true, title: 'Chamar TaxiPet', subtitle: d.displayName, photo: d.photo, fallbackIcon: Icons.local_taxi_rounded),
          SnakeBand(
            index: 1,
            roundBottom: false,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 50),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Qual pet vai passear?', style: sectionStyle().copyWith(fontSize: 17)),
              const SizedBox(height: 6),
              StreamBuilder<List<Pet>>(
                stream: Db.myPets(Session.uid),
                builder: (context, snap) {
                  final pets = snap.data ?? [];
                  if (snap.hasData && pets.isEmpty) {
                    return const Text('Cadastre um pet em "Meus Pets" primeiro.', style: TextStyle(color: AppColors.muted));
                  }
                  return SizedBox(
                    height: 92,
                    child: ListView(scrollDirection: Axis.horizontal, children: [
                      for (final p in pets)
                        GestureDetector(
                          onTap: () => setState(() => _pet = p),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Column(children: [
                              PhotoAvatar(photo: p.photo, size: 62, border: _pet?.id == p.id ? AppColors.orange : AppColors.surface),
                              const SizedBox(height: 3),
                              Text(p.name, style: TextStyle(fontWeight: _pet?.id == p.id ? FontWeight.w700 : FontWeight.w400)),
                            ]),
                          ),
                        ),
                    ]),
                  );
                },
              ),
              const SizedBox(height: 10),
              _RouteFields(pickup: _pickup, dest: _dest),
              const SizedBox(height: 14),
              Text('Quando?', style: sectionStyle().copyWith(fontSize: 17)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                ChoiceChip(label: const Text('O quanto antes'), selected: _now, onSelected: (_) => setState(() => _now = true)),
                ChoiceChip(
                  label: Text(_when == null || _now ? 'Agendar horário' : '${fmtShort(_when)} às ${fmtTime(_when)}'),
                  selected: !_now,
                  onSelected: (_) async {
                    final w = await pickDateTime(context, initial: _when);
                    if (w != null) {
                      setState(() {
                        _now = false;
                        _when = w;
                      });
                    }
                  },
                ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: inputDeco('Observações (porte, caixa de transporte, ida e volta…)'),
              ),
              if (price != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text('Corrida a partir de ${fmtMoney(price)} — o valor final você combina com ${d.displayName}.',
                      style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              const SizedBox(height: 18),
              OrangeButton(label: 'Pedir corrida', icon: Icons.local_taxi_rounded, loading: _saving, onPressed: _send),
            ]),
          ),
        ],
      ),
    );
  }
}

/// Campos "Buscar em" → "Levar para" ligados por uma linha pontilhada.
class _RouteFields extends StatelessWidget {
  final TextEditingController pickup;
  final TextEditingController dest;
  const _RouteFields({required this.pickup, required this.dest});
  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 18, right: 8),
        child: Column(children: [
          const Icon(Icons.trip_origin_rounded, color: AppColors.teal, size: 20),
          for (var i = 0; i < 5; i++)
            Container(width: 2, height: 6, margin: const EdgeInsets.symmetric(vertical: 2), color: const Color(0xFFB9C0C2)),
          const Icon(Icons.place_rounded, color: AppColors.red, size: 22),
        ]),
      ),
      Expanded(
        child: Column(children: [
          TextField(controller: pickup, decoration: inputDeco('Buscar em', hint: 'Rua, número e bairro')),
          const SizedBox(height: 10),
          TextField(controller: dest, decoration: inputDeco('Levar para', hint: 'Ex.: Vet Amicão — Av. do Estado, 1200')),
        ]),
      ),
    ]);
  }
}

// ============================================================ acompanhar corrida

class RideScreen extends StatelessWidget {
  final String rideId;
  const RideScreen({super.key, required this.rideId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<Ride>(
        stream: Db.rideStream(rideId),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final r = snap.data!;
          final driver = Session.uid == r.driverId;
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              PetHeader(
                showBack: true,
                title: 'TaxiPet',
                subtitle: rideStatusLabel[r.status] ?? r.status,
                photo: r.petPhoto,
                avatarLabel: r.petName,
              ),
              SnakeBand(
                index: 1,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (r.status == 'recusada' || r.status == 'cancelada')
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(rideStatusLabel[r.status]!, style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
                    )
                  else
                    RideTimeline(ride: r),
                ]),
              ),
              SnakeBand(
                index: 2,
                roundBottom: false,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 50),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _line(Icons.event_rounded, 'Quando', '${fmtDate(r.when)} às ${fmtTime(r.when)}'),
                  _line(Icons.trip_origin_rounded, 'Buscar em', r.pickup, onMap: () => openMap(r.pickup)),
                  _line(Icons.place_rounded, 'Levar para', r.destination, onMap: () => openMap(r.destination)),
                  if (r.notes.isNotEmpty) _line(Icons.notes_rounded, 'Obs.', r.notes),
                  _line(driver ? Icons.person_rounded : Icons.local_taxi_rounded, driver ? 'Tutor' : 'Motorista',
                      driver ? r.tutorName : r.driverName),
                  const SizedBox(height: 12),
                  Wrap(alignment: WrapAlignment.spaceEvenly, spacing: 10, runSpacing: 8, children: [
                    RoundAction(
                      icon: Icons.chat_rounded,
                      label: 'Conversar',
                      color: AppColors.teal,
                      onTap: () => openChatWith(context, driver ? r.tutorId : r.driverId, driver ? r.tutorName : r.driverName),
                    ),
                    RoundAction(
                      icon: Icons.call_rounded,
                      label: 'Ligar',
                      color: AppColors.green,
                      onTap: () => callPhone(context, driver ? r.tutorPhone : r.driverPhone, driver ? r.tutorName : r.driverName),
                    ),
                    if (driver)
                      RoundAction(
                        icon: Icons.sticky_note_2_rounded,
                        label: 'Info. do pet',
                        color: AppColors.orange,
                        onTap: () => showPetInfoSheet(context, petId: r.petId, petName: r.petName, petPhoto: r.petPhoto, obs: r.notes),
                      ),
                    if (r.isActive && r.step <= 1)
                      RoundAction(
                        icon: Icons.edit_calendar_rounded,
                        label: 'Reagendar',
                        color: AppColors.orange,
                        onTap: () => rescheduleRide(context, r),
                      ),
                  ]),
                  const SizedBox(height: 18),
                  ..._mainActions(context, r, driver),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _mainActions(BuildContext context, Ride r, bool driver) {
    if (!r.isActive) return const [];
    if (driver) {
      if (r.status == 'pedida') {
        return [
          OrangeButton(label: 'Aceitar corrida', icon: Icons.check_rounded, onPressed: () => Db.setRideStatus(r, 'aceita')),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () async {
              if (await confirm(context, 'Recusar corrida?', 'O tutor verá que você não pode atender.', ok: 'Recusar')) {
                await Db.setRideStatus(r, 'recusada');
              }
            },
            child: const Text('Recusar', style: TextStyle(color: AppColors.red)),
          ),
        ];
      }
      final next = r.nextStatus;
      if (next == null) return const [];
      return [
        OrangeButton(
          key: const Key('avancar_corrida'),
          label: rideActionLabel[next] ?? 'Avançar',
          icon: next == 'concluida' ? Icons.task_alt_rounded : Icons.arrow_forward_rounded,
          onPressed: () => Db.setRideStatus(r, next),
        ),
      ];
    }
    if (r.step <= 1) {
      return [
        TextButton(
          onPressed: () async {
            if (await confirm(context, 'Cancelar corrida?', 'O motorista será avisado.', ok: 'Cancelar corrida')) {
              await Db.setRideStatus(r, 'cancelada');
            }
          },
          child: const Text('Cancelar corrida', style: TextStyle(color: AppColors.muted)),
        ),
      ];
    }
    return const [];
  }

  Widget _line(IconData icon, String label, String value, {VoidCallback? onMap}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: AppColors.teal),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
          ),
          if (onMap != null) TextButton.icon(onPressed: onMap, icon: const Icon(Icons.map_rounded, size: 18), label: const Text('Mapa')),
        ]),
      );
}

Future<void> rescheduleRide(BuildContext context, Ride r) async {
  final w = await pickDateTime(context, initial: r.when);
  if (w == null) return;
  await Db.setRideStatus(r, r.status, when: w);
  if (context.mounted) showSnack(context, 'Corrida reagendada para ${fmtDate(w)} às ${fmtTime(w)}.');
}

/// Linha do tempo da corrida: pedida → … → concluída.
class RideTimeline extends StatelessWidget {
  final Ride ride;
  const RideTimeline({super.key, required this.ride});

  static const _labels = {
    'pedida': 'Pedido enviado',
    'aceita': 'Corrida confirmada',
    'a_caminho': 'Motorista a caminho',
    'pet_a_bordo': 'Pet a bordo',
    'chegou': 'Chegou ao destino',
    'concluida': 'Concluída',
  };

  @override
  Widget build(BuildContext context) {
    final cur = ride.step;
    return Column(children: [
      for (var i = 0; i < Ride.flow.length; i++)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < cur
                    ? AppColors.teal
                    : i == cur
                        ? kTaxiYellow
                        : AppColors.surface,
                border: Border.all(color: i <= cur ? Colors.transparent : AppColors.line, width: 2),
              ),
              child: i < cur
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                  : i == cur
                      ? const Icon(Icons.local_taxi_rounded, color: Color(0xFF3E4446), size: 17)
                      : null,
            ),
            if (i < Ride.flow.length - 1)
              Container(width: 3, height: 22, color: i < cur ? AppColors.teal : AppColors.line),
          ]),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _labels[Ride.flow[i]]!,
              style: TextStyle(
                fontWeight: i == cur ? FontWeight.w800 : FontWeight.w500,
                color: i <= cur ? AppColors.textStrong : AppColors.muted,
                fontSize: i == cur ? 16 : 14,
              ),
            ),
          ),
        ]),
    ]);
  }
}

/// Item de corrida em listas (tutor e motorista).
class RideTile extends StatelessWidget {
  final Ride r;
  final bool driverView;
  const RideTile({super.key, required this.r, this.driverView = false});
  @override
  Widget build(BuildContext context) {
    final st = TextStyle(fontSize: 12, color: AppColors.text2, height: 1.25);
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RideScreen(rideId: r.id))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          DateBadge(r.when, big: true),
          const SizedBox(width: 6),
          PhotoAvatar(photo: r.petPhoto, size: 46, border: AppColors.surface),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(fmtTime(r.when), style: st.copyWith(fontWeight: FontWeight.w600, color: AppColors.text)),
              Text('Nome: ${r.petName}', style: st, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(driverView ? 'Animal: ${r.petSpecies}' : 'Motorista: ${r.driverName}', style: st, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(r.status == 'pedida' || !driverView ? (rideStatusLabel[r.status] ?? '') : r.pickup,
                  style: st.copyWith(color: AppColors.orange, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          if (driverView)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => showPetInfoSheet(context, petId: r.petId, petName: r.petName, petPhoto: r.petPhoto, obs: r.notes),
              child: const InfoAction(),
            ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ]),
      ),
    );
  }
}

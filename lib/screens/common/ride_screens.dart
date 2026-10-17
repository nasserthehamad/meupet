import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/catalog.dart';
import '../../core/db.dart';
import '../../core/geo.dart';
import '../../core/location.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/taxi_map.dart';
import 'chat_screen.dart';
import 'pet_info_sheet.dart';

export '../../widgets/taxi_map.dart' show kTaxiYellow;

Future<void> openMap(String address) => launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}'),
      mode: LaunchMode.externalApplication,
    );

/// Abre a navegação (Google Maps / Waze) até o ponto.
Future<void> openNavigation(GeoPos p) => launchUrl(
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${p.lat},${p.lng}&travelmode=driving'),
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

/// Executa depois do quadro atual (o mapa avisa mudanças durante o desenho).
void _later(VoidCallback fn) => WidgetsBinding.instance.addPostFrameCallback((_) => fn());

/// Botão redondo de voltar sobre o mapa.
class _MapBack extends StatelessWidget {
  const _MapBack();
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.maybePop(context),
        child: Padding(padding: const EdgeInsets.all(10), child: Icon(Icons.arrow_back_rounded, color: AppColors.text)),
      ),
    );
  }
}

class _MapRound extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  const _MapRound({required this.icon, required this.onTap, this.tooltip});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(10), child: Icon(icon, color: AppColors.teal, semanticLabel: tooltip)),
      ),
    );
  }
}

/// Partida → destino com a linha pontilhada (toque para alterar ou navegar).
class RouteCard extends StatelessWidget {
  final String pickup;
  final String dest;
  final VoidCallback? onPickup;
  final VoidCallback? onDest;
  final String actionLabel;
  const RouteCard({super.key, required this.pickup, required this.dest, this.onPickup, this.onDest, this.actionLabel = 'Alterar'});

  Widget _row(String label, String value, VoidCallback? onTap, Key key) => InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.2)),
              ]),
            ),
            if (onTap != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(actionLabel, style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Column(children: [
          const PickupDot(size: 16),
          for (var i = 0; i < 4; i++)
            Container(width: 2, height: 5, margin: const EdgeInsets.symmetric(vertical: 2), color: AppColors.muted.withValues(alpha: 0.6)),
          const Icon(Icons.place_rounded, color: AppColors.red, size: 20),
        ]),
        const SizedBox(width: 10),
        Expanded(
          child: Column(children: [
            _row('Buscar em', pickup, onPickup, const Key('rota_partida')),
            Divider(height: 10, color: AppColors.line),
            _row('Levar para', dest, onDest, const Key('rota_destino')),
          ]),
        ),
      ]),
    );
  }
}

// ============================================================ pedir corrida

enum _Stage { pickup, destOnMap, summary }

/// Pedir TaxiPet como no Uber: a partida é a sua localização (arraste o mapa
/// para ajustar), escolha o destino pela busca ou no mapa, veja a rota, o
/// tempo e o valor estimado. Sem motorista escolhido, o pedido vai para os
/// motoristas perto e o primeiro que aceitar leva.
class RideRequestScreen extends StatefulWidget {
  final AppUser? driver;
  const RideRequestScreen({super.key, this.driver});
  @override
  State<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends State<RideRequestScreen> {
  static const _fallback = GeoPos(-23.5505, -46.6333); // centro de São Paulo
  final _map = MapController();
  bool _ready = false;
  GeoPos? _start;
  GeoPos _center = _fallback;
  String? _centerAddr;
  int _lookup = 0;
  Timer? _debounce;
  _Stage _stage = _Stage.pickup;
  Place? _pickup;
  Place? _dest;
  RouteInfo? _route;
  Pet? _pet;
  bool _now = true;
  DateTime? _when;
  final _notes = TextEditingController();
  bool _saving = false;
  AppUser? _driver;
  List<AppUser> _nearby = const [];

  @override
  void initState() {
    super.initState();
    _driver = widget.driver;
    _locate();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    final p = await LocationService.current();
    if (!mounted) return;
    final me = Session.current.value;
    final start = p ?? (me != null && me.hasLocation ? GeoPos(me.lat!, me.lng!) : _fallback);
    setState(() {
      _start = start;
      _center = start;
    });
    if (p == null && LocationService.lastError != null) {
      showSnack(context, '${LocationService.lastError} Arraste o mapa até onde buscar o pet.', error: true);
    }
    if (_ready) _map.move(ll(start), 16);
  }

  void _onReady() {
    _ready = true;
    _later(() {
      if (mounted) _reverse();
    });
  }

  void _onMoved(GeoPos c, bool byUser) {
    if (_stage == _Stage.summary) return;
    _center = c;
    _debounce?.cancel();
    if (_centerAddr != null) {
      _later(() {
        if (mounted) setState(() => _centerAddr = null);
      });
    }
    _debounce = Timer(const Duration(milliseconds: 650), _reverse);
  }

  Future<void> _reverse() async {
    final id = ++_lookup;
    final c = _center;
    final a = await GeoService.reverse(c.lat, c.lng);
    if (!mounted || id != _lookup) return;
    setState(() => _centerAddr = a ?? 'Ponto no mapa');
  }

  Place _centerPlace() {
    final a = _centerAddr ?? 'Ponto no mapa';
    final i = a.indexOf(', ');
    return i < 0 ? Place(a, '', _center.lat, _center.lng) : Place(a.substring(0, i), a.substring(i + 2), _center.lat, _center.lng);
  }

  Future<void> _ensureAddress() async {
    if (_centerAddr == null) await _reverse();
  }

  /// "Para onde vamos?"
  Future<void> _chooseDest() async {
    if (_stage == _Stage.pickup) {
      await _ensureAddress();
      _pickup = _centerPlace();
    }
    if (!mounted) return;
    final res = await Navigator.push<Object>(
      context,
      MaterialPageRoute(builder: (_) => PlaceSearchScreen(title: 'Para onde vamos?', near: _pickup?.pos ?? _center)),
    );
    if (!mounted || res == null) return;
    if (res == PlaceSearchScreen.pickOnMap) {
      setState(() {
        _stage = _Stage.destOnMap;
        _centerAddr = null;
        _route = null;
      });
      if (_dest != null && _ready) _map.move(ll(_dest!.pos), 16);
      _later(_reverse);
      return;
    }
    _setDest(res as Place);
  }

  /// Alterar a partida: pela busca ou ajustando no mapa.
  Future<void> _editPickup() async {
    final res = await Navigator.push<Object>(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceSearchScreen(title: 'Onde buscar o pet?', near: _pickup?.pos ?? _center, mapLabel: 'Ajustar no mapa'),
      ),
    );
    if (!mounted || res == null) return;
    if (res == PlaceSearchScreen.pickOnMap) {
      setState(() {
        _stage = _Stage.pickup;
        _route = null;
      });
      if (_pickup != null && _ready) _map.move(ll(_pickup!.pos), 16);
      _later(_reverse);
      return;
    }
    _pickup = res as Place;
    if (_dest != null) {
      _setDest(_dest!);
    } else {
      setState(() => _stage = _Stage.pickup);
      if (_ready) _map.move(ll(_pickup!.pos), 16);
    }
  }

  Future<void> _confirmPickup() async {
    await _ensureAddress();
    _pickup = _centerPlace();
    if (_dest != null) _setDest(_dest!);
  }

  Future<void> _setDest(Place d) async {
    setState(() {
      _dest = d;
      _stage = _Stage.summary;
      _route = null;
    });
    _fit();
    _loadNearby();
    final r = await GeoService.route(_pickup!.pos, d.pos);
    if (!mounted || _dest != d) return;
    setState(() => _route = r);
    _later(_fit);
  }

  void _fit() {
    if (!mounted || !_ready || _pickup == null || _dest == null) return;
    final pts = (_route?.points.length ?? 0) > 1 ? _route!.points : [_pickup!.pos, _dest!.pos];
    final top = MediaQuery.paddingOf(context).top;
    _map.fitCamera(CameraFit.coordinates(
      coordinates: pts.map(ll).toList(),
      padding: EdgeInsets.fromLTRB(48, top + 80, 48, 48),
      maxZoom: 17,
    ));
  }

  Future<void> _loadNearby() async {
    if (_pickup == null) return;
    try {
      final l = await Db.nearbyDrivers(_pickup!.pos, city: Session.current.value?.city ?? '');
      if (mounted) setState(() => _nearby = l);
    } catch (_) {}
  }

  Future<void> _chooseDriver() async {
    final km = _route?.km ?? 0;
    final list = [
      if (widget.driver != null && !_nearby.any((d) => d.id == widget.driver!.id)) widget.driver!,
      ..._nearby,
    ];
    final picked = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.7),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 16, 16, 16), children: [
            Text('Quem vai levar?', style: sectionStyle().copyWith(fontSize: 18)),
            const SizedBox(height: 6),
            ListTile(
              key: const Key('motorista_qualquer'),
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(radius: 22, backgroundColor: kTaxiYellow, child: Icon(Icons.bolt_rounded, color: Color(0xFF3E4446))),
              title: const Text('Qualquer motorista perto', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Mais rápido: o primeiro que aceitar leva.'),
              trailing: _driver == null ? const Icon(Icons.check_circle_rounded, color: AppColors.teal) : null,
              onTap: () => Navigator.pop(c, 'qualquer'),
            ),
            for (final d in list)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: PhotoAvatar(photo: d.photo, size: 44, fallbackIcon: Icons.local_taxi_rounded, border: AppColors.surface),
                title: Text(d.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text([
                  if (d.hasLocation && _pickup != null) 'a ${fmtKm(distanceKm(_pickup!.lat, _pickup!.lng, d.lat!, d.lng!))}',
                  if (taxiFare(d, km) != null) fmtMoney(taxiFare(d, km)!) else 'valor a combinar',
                ].join(' · ')),
                trailing: _driver?.id == d.id ? const Icon(Icons.check_circle_rounded, color: AppColors.teal) : null,
                onTap: () => Navigator.pop(c, d),
              ),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('Ainda não há motoristas TaxiPet cadastrados perto daqui.', style: TextStyle(color: AppColors.muted)),
              ),
          ]),
        ),
      ),
    );
    if (!mounted) return;
    if (picked == 'qualquer') setState(() => _driver = null);
    if (picked is AppUser) setState(() => _driver = picked);
  }

  Future<void> _send() async {
    if (_pet == null) {
      showSnack(context, 'Escolha qual pet vai na corrida.', error: true);
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
        driver: _driver,
        pickup: _pickup!,
        destination: _dest!,
        route: _route ?? GeoService.straight(_pickup!.pos, _dest!.pos),
        when: _now ? DateTime.now() : _when!,
        notes: _notes.text,
        nearby: _nearby,
      );
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RideScreen(rideId: id)));
    } catch (e) {
      if (mounted) showSnack(context, 'Não foi possível pedir a corrida: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ------------------------------------------------------------ tela

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: Column(children: [
        Expanded(
          child: _start == null
              ? const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Buscando sua localização…', style: TextStyle(color: AppColors.muted)),
                  ]),
                )
              : Stack(children: [
                  Positioned.fill(
                    child: TaxiMap(
                      controller: _map,
                      center: _start!,
                      zoom: 16,
                      pickup: _stage == _Stage.pickup ? null : _pickup?.pos,
                      dest: _stage == _Stage.summary ? _dest?.pos : null,
                      route: _stage == _Stage.summary ? (_route?.points ?? const []) : const [],
                      onMoved: _onMoved,
                      onReady: _onReady,
                    ),
                  ),
                  if (_stage != _Stage.summary) CenterPin(destination: _stage == _Stage.destOnMap),
                  Positioned(top: top + 10, left: 12, right: 12, child: _topBar()),
                  if (_stage != _Stage.summary)
                    Positioned(
                      right: 14,
                      bottom: 18,
                      child: _MapRound(
                        icon: Icons.my_location_rounded,
                        tooltip: 'Minha localização',
                        onTap: () async {
                          final p = await LocationService.current();
                          if (p != null && _ready) _map.move(ll(p), 16);
                        },
                      ),
                    )
                  else
                    Positioned(right: 14, bottom: 18, child: _MapRound(icon: Icons.zoom_out_map_rounded, onTap: _fit)),
                ]),
        ),
        _panel(),
      ]),
    );
  }

  Widget _topBar() {
    final d = _driver;
    return Row(children: [
      const _MapBack(),
      const SizedBox(width: 10),
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Row(children: [
            const Icon(Icons.local_taxi_rounded, color: kTaxiYellow, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('TaxiPet', style: scriptStyle(18, AppColors.textStrong)),
                Text(d == null ? 'Motoristas perto de você' : d.displayName,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _panel() {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final Widget child = switch (_stage) {
      _Stage.pickup => _pickupPanel(),
      _Stage.destOnMap => _destMapPanel(),
      _Stage.summary => _summaryPanel(),
    };
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, -2))],
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(18, 10, 18, 14 + bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 10),
          child,
        ]),
      ),
    );
  }

  Widget _addressUnderPin(String label, {bool destination = false}) => Row(children: [
        destination ? const Icon(Icons.place_rounded, color: AppColors.red, size: 22) : const PickupDot(size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
            Text(_centerAddr ?? 'Procurando o endereço…',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600, color: _centerAddr == null ? AppColors.muted : AppColors.text)),
          ]),
        ),
      ]);

  Widget _pickupPanel() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _addressUnderPin('Buscar o pet em'),
        const SizedBox(height: 14),
        if (_dest == null)
          Material(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              key: const Key('para_onde'),
              borderRadius: BorderRadius.circular(16),
              onTap: _chooseDest,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                child: Row(children: [
                  Icon(Icons.search_rounded, color: AppColors.teal, size: 26),
                  SizedBox(width: 10),
                  Text('Para onde vamos?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          )
        else
          OrangeButton(label: 'Confirmar partida', icon: Icons.check_rounded, onPressed: _confirmPickup),
        const SizedBox(height: 8),
        const Text('Arraste o mapa para ajustar o ponto de partida.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.muted)),
      ]);

  Widget _destMapPanel() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _addressUnderPin('Levar para', destination: true),
        const SizedBox(height: 14),
        OrangeButton(
          key: const Key('confirmar_destino'),
          label: 'Confirmar destino',
          icon: Icons.check_rounded,
          onPressed: () async {
            await _ensureAddress();
            _setDest(_centerPlace());
          },
        ),
        TextButton.icon(onPressed: _chooseDest, icon: const Icon(Icons.search_rounded), label: const Text('Buscar pelo endereço')),
      ]);

  Widget _summaryPanel() {
    final r = _route;
    final d = _driver;
    String price;
    if (r == null) {
      price = '…';
    } else if (d != null) {
      final f = taxiFare(d, r.km);
      price = f == null ? 'A combinar' : fmtMoney(f);
    } else {
      final fares = [for (final n in _nearby) taxiFare(n, r.km)].whereType<double>().toList()..sort();
      price = fares.isEmpty
          ? 'A combinar'
          : fares.first == fares.last
              ? fmtMoney(fares.first)
              : '${fmtMoney(fares.first)} – ${fmtMoney(fares.last)}';
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RouteCard(pickup: _pickup!.label, dest: _dest!.label, onPickup: _editPickup, onDest: _chooseDest),
      const SizedBox(height: 8),
      Row(children: [
        const Icon(Icons.route_rounded, size: 20, color: AppColors.teal),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            r == null ? 'Calculando a rota…' : '${fmtKm(r.km)} · ${r.minutes} min de carro${r.estimated ? ' (aprox.)' : ''}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      Text('Qual pet vai?', style: sectionStyle()),
      const SizedBox(height: 6),
      StreamBuilder<List<Pet>>(
        stream: Db.myPets(Session.uid),
        builder: (context, snap) {
          final pets = snap.data ?? [];
          if (snap.hasData && pets.isEmpty) {
            return const Text('Cadastre um pet em "Meus Pets" primeiro.', style: TextStyle(color: AppColors.muted));
          }
          if (_pet == null && pets.length == 1) {
            _later(() {
              if (mounted && _pet == null) setState(() => _pet = pets.first);
            });
          }
          return SizedBox(
            height: 86,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final p in pets)
                GestureDetector(
                  key: Key('pet_${p.id}'),
                  onTap: () => setState(() => _pet = p),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(children: [
                      PhotoAvatar(photo: p.photo, size: 58, border: _pet?.id == p.id ? AppColors.orange : AppColors.line),
                      const SizedBox(height: 3),
                      Text(p.name, style: TextStyle(fontSize: 13, fontWeight: _pet?.id == p.id ? FontWeight.w700 : FontWeight.w400)),
                    ]),
                  ),
                ),
            ]),
          );
        },
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 4, children: [
        ChoiceChip(label: const Text('Agora'), selected: _now, onSelected: (_) => setState(() => _now = true)),
        ChoiceChip(
          avatar: const Icon(Icons.event_rounded, size: 18),
          label: Text(_when == null || _now ? 'Agendar' : '${fmtShort(_when)} às ${fmtTime(_when)}'),
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
      const SizedBox(height: 8),
      TextField(
        controller: _notes,
        maxLines: 2,
        minLines: 1,
        textCapitalization: TextCapitalization.sentences,
        decoration: inputDeco('Observações (porte, caixa de transporte, ida e volta…)'),
      ),
      const SizedBox(height: 10),
      Material(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: const Key('escolher_motorista'),
          borderRadius: BorderRadius.circular(16),
          onTap: _chooseDriver,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(children: [
              d == null
                  ? const CircleAvatar(radius: 20, backgroundColor: kTaxiYellow, child: Icon(Icons.bolt_rounded, color: Color(0xFF3E4446)))
                  : PhotoAvatar(photo: d.photo, size: 40, fallbackIcon: Icons.local_taxi_rounded, border: AppColors.surface),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d == null ? 'Qualquer motorista perto' : d.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    d == null
                        ? (_nearby.isEmpty ? 'O primeiro que aceitar leva' : '${_nearby.length} motorista(s) perto · o primeiro que aceitar leva')
                        : 'Pedido direto para este motorista',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ]),
              ),
              const Text('Trocar', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Row(children: [
        const Expanded(child: Text('Valor estimado', style: TextStyle(color: AppColors.muted))),
        Text(price, key: const Key('preco_estimado'), style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.w800, fontSize: 18)),
      ]),
      const Text('Calculado pelo preço que o motorista informou (saída + km). O valor final você confirma com ele.',
          style: TextStyle(fontSize: 11, color: AppColors.muted)),
      const SizedBox(height: 12),
      OrangeButton(
        key: const Key('pedir_corrida'),
        label: 'Chamar TaxiPet',
        icon: Icons.local_taxi_rounded,
        loading: _saving,
        onPressed: r == null ? null : _send,
      ),
    ]);
  }
}

/// Busca de endereço com sugestões enquanto digita.
class PlaceSearchScreen extends StatefulWidget {
  static const pickOnMap = 'mapa';
  final String title;
  final GeoPos? near;
  final String mapLabel;
  final String? initialQuery;
  const PlaceSearchScreen({super.key, required this.title, this.near, this.mapLabel = 'Escolher no mapa', this.initialQuery});
  @override
  State<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends State<PlaceSearchScreen> {
  late final _q = TextEditingController(text: widget.initialQuery);
  Timer? _deb;
  List<Place> _results = const [];
  bool _loading = false;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    if ((widget.initialQuery ?? '').isNotEmpty) _run();
  }

  @override
  void dispose() {
    _deb?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _changed(String _) {
    _deb?.cancel();
    _deb = Timer(const Duration(milliseconds: 450), _run);
  }

  Future<void> _run() async {
    final id = ++_seq;
    final q = _q.text;
    if (q.trim().length < 3) {
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    final r = await GeoService.search(q, near: widget.near);
    if (!mounted || id != _seq) return;
    setState(() {
      _results = r;
      _loading = false;
    });
  }

  Future<void> _home(String address) async {
    final r = await GeoService.search(address, near: widget.near);
    if (!mounted) return;
    if (r.isEmpty) {
      _q.text = address;
      _run();
      return;
    }
    Navigator.pop(context, r.first);
  }

  @override
  Widget build(BuildContext context) {
    final me = Session.current.value;
    final home = [me?.address ?? '', me?.city ?? ''].where((e) => e.trim().isNotEmpty).join(', ');
    final n = widget.near;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w600))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: TextField(
            key: const Key('busca_endereco'),
            controller: _q,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _changed,
            onSubmitted: (_) => _run(),
            decoration: inputDeco('Endereço, lugar ou clínica', icon: Icons.search_rounded),
          ),
        ),
        ListTile(
          key: const Key('escolher_no_mapa'),
          leading: CircleAvatar(backgroundColor: AppColors.teal.withValues(alpha: 0.12), child: const Icon(Icons.map_rounded, color: AppColors.teal)),
          title: Text(widget.mapLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Arraste o mapa até o ponto certo'),
          onTap: () => Navigator.pop(context, PlaceSearchScreen.pickOnMap),
        ),
        if (home.isNotEmpty)
          ListTile(
            leading: CircleAvatar(backgroundColor: AppColors.orange.withValues(alpha: 0.12), child: const Icon(Icons.home_rounded, color: AppColors.orange)),
            title: const Text('Endereço do perfil', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(home, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => _home(home),
          ),
        Divider(height: 1, color: AppColors.line),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _results.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _q.text.trim().length < 3
                        ? 'Digite pelo menos 3 letras. Ex.: "Av. Paulista 1000" ou o nome da clínica.'
                        : _loading
                            ? ''
                            : 'Nada encontrado. Tente com o número e a cidade, ou escolha no mapa.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                )
              : ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => Divider(height: 1, indent: 72, color: AppColors.line),
                  itemBuilder: (context, i) {
                    final p = _results[i];
                    return ListTile(
                      key: Key('lugar_$i'),
                      leading: const CircleAvatar(backgroundColor: Colors.transparent, child: Icon(Icons.place_outlined, color: AppColors.muted)),
                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: p.detail.isEmpty ? null : Text(p.detail, maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: n == null ? null : Text(fmtKm(distanceKm(n.lat, n.lng, p.lat, p.lng)), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      onTap: () => Navigator.pop(context, p),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ============================================================ ofertas ao motorista

/// Corridas que o motorista pode aceitar: abertas perto dele e pedidas direto.
class RideOffers {
  static final ignored = ValueNotifier<Set<String>>(<String>{});
  static GeoPos? myPos;
  static Future<GeoPos?>? _locating;
  static const radiusKm = 40.0;

  static Future<GeoPos?> locate() => _locating ??= LocationService.current().then((p) {
        myPos = p;
        return p;
      });

  static void ignore(String id) => ignored.value = {...ignored.value, id};

  /// Pedido aberto que vale mostrar para este motorista.
  static bool show(Ride r) {
    if (!r.isOpen || ignored.value.contains(r.id) || r.tutorId == Session.uid) return false;
    final w = r.when;
    if (w != null && w.isBefore(DateTime.now().subtract(const Duration(hours: 2)))) return false;
    final me = Session.current.value;
    final p = myPos ?? (me != null && me.hasLocation ? GeoPos(me.lat!, me.lng!) : null);
    if (p == null || r.pickupPos == null) return true;
    return distanceKm(p.lat, p.lng, r.pickupLat!, r.pickupLng!) <= radiusKm;
  }

  /// Junta os pedidos diretos (status "pedida") com os abertos perto.
  static Widget builder(Widget Function(BuildContext context, List<Ride> offers, bool loading) build) {
    return FutureBuilder<GeoPos?>(
      future: locate(),
      builder: (context, _) => StreamBuilder<List<Ride>>(
        stream: Db.driverRides(Session.uid),
        builder: (context, mine) => StreamBuilder<List<Ride>>(
          stream: Db.openRides(),
          builder: (context, open) => ValueListenableBuilder<Set<String>>(
            valueListenable: ignored,
            builder: (context, _, __) {
              final offers = [
                ...(mine.data ?? const <Ride>[]).where((r) => r.status == 'pedida'),
                ...(open.data ?? const <Ride>[]).where(show),
              ];
              return build(context, offers, !mine.hasData);
            },
          ),
        ),
      ),
    );
  }
}

/// Cartão de pedido para o motorista: rota, distância até a partida e o valor.
class RideOfferTile extends StatefulWidget {
  final Ride r;
  const RideOfferTile({super.key, required this.r});
  @override
  State<RideOfferTile> createState() => _RideOfferTileState();
}

class _RideOfferTileState extends State<RideOfferTile> {
  bool _busy = false;

  Future<void> _accept() async {
    final r = widget.r;
    setState(() => _busy = true);
    final ok = await Db.acceptRide(r);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      showSnack(context, 'Corrida aceita! Vá buscar ${r.petName}.');
      Navigator.push(context, MaterialPageRoute(builder: (_) => RideScreen(rideId: r.id)));
    } else {
      showSnack(context, 'Outro motorista já aceitou esta corrida.', error: true);
    }
  }

  Future<void> _decline() async {
    final r = widget.r;
    if (r.isOpen) {
      RideOffers.ignore(r.id);
      return;
    }
    if (await confirm(context, 'Recusar corrida?', 'O tutor verá que você não pode atender.', ok: 'Recusar')) {
      await Db.setRideStatus(r, 'recusada');
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final me = Session.current.value;
    final p = RideOffers.myPos;
    final away = p != null && r.pickupPos != null ? distanceKm(p.lat, p.lng, r.pickupLat!, r.pickupLng!) : null;
    final fare = r.price ?? (me == null || r.km == null ? null : taxiFare(me, r.km!));
    final soon = r.when == null || r.when!.difference(DateTime.now()).inMinutes.abs() <= 15;
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RideScreen(rideId: r.id))),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: r.isOpen ? kTaxiYellow : AppColors.line, width: r.isOpen ? 2 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            PhotoAvatar(photo: r.petPhoto, size: 46, border: AppColors.surface),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${r.petName}${r.petSpecies.isEmpty ? '' : ' · ${r.petSpecies}'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(r.isOpen ? 'Pedido aberto · ${r.tutorName}' : 'Pediu para você · ${r.tutorName}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ]),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => showPetInfoSheet(context, petId: r.petId, petName: r.petName, petPhoto: r.petPhoto, obs: r.notes),
              child: const InfoAction(),
            ),
            if (fare != null)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(fmtMoney(fare), style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.w800, fontSize: 16)),
              ),
          ]),
          const SizedBox(height: 8),
          _miniRoute(r.pickup, r.destination),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _chip(Icons.schedule_rounded, soon ? 'Agora' : '${fmtShort(r.when)} às ${fmtTime(r.when)}', strong: soon),
            if (away != null) _chip(Icons.near_me_rounded, 'a ${fmtKm(away)} de você'),
            if (r.km != null) _chip(Icons.route_rounded, '${fmtKm(r.km!)}${r.minutes == null ? '' : ' · ${r.minutes} min'}'),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _busy ? null : _decline,
                child: Text(r.isOpen ? 'Ignorar' : 'Recusar', style: const TextStyle(color: AppColors.muted)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                key: Key('aceitar_${r.id}'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _busy ? null : _accept,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Aceitar', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String text, {bool strong = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: strong ? kTaxiYellow.withValues(alpha: 0.25) : AppColors.surface2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: AppColors.teal),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, fontWeight: strong ? FontWeight.w700 : FontWeight.w500, color: AppColors.text)),
        ]),
      );
}

Widget _miniRoute(String pickup, String dest) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Column(children: [
          const PickupDot(size: 12),
          Container(width: 2, height: 14, margin: const EdgeInsets.symmetric(vertical: 2), color: AppColors.line),
          const Icon(Icons.place_rounded, color: AppColors.red, size: 15),
        ]),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(pickup, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          Text(dest, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    ]);

// ============================================================ acompanhar corrida

const _tracking = ['aceita', 'a_caminho', 'pet_a_bordo', 'chegou'];

class RideScreen extends StatefulWidget {
  final String rideId;
  const RideScreen({super.key, required this.rideId});
  @override
  State<RideScreen> createState() => _RideScreenState();
}

class _RideScreenState extends State<RideScreen> {
  final _map = MapController();
  bool _ready = false;
  bool _fitted = false;
  RouteInfo? _route;
  String _routeKey = '';
  Ride? _last;

  void _ensureRoute(Ride r) {
    if (!r.hasMap) return;
    final key = '${r.pickupLat},${r.pickupLng},${r.destLat},${r.destLng}';
    if (key == _routeKey) return;
    _routeKey = key;
    GeoService.route(r.pickupPos!, r.destPos!).then((v) {
      if (!mounted) return;
      setState(() => _route = v);
      _later(() => _fit(r));
    });
  }

  void _fit(Ride r) {
    if (!_ready || !r.hasMap || !mounted) return;
    final pts = [
      ...((_route?.points.length ?? 0) > 1 ? _route!.points : [r.pickupPos!, r.destPos!]),
      if (r.driverPos != null && _tracking.contains(r.status)) r.driverPos!,
    ];
    final top = MediaQuery.paddingOf(context).top;
    _map.fitCamera(CameraFit.coordinates(coordinates: pts.map(ll).toList(), padding: EdgeInsets.fromLTRB(44, top + 70, 44, 54), maxZoom: 17));
    _fitted = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<Ride>(
        stream: Db.rideStream(widget.rideId),
        builder: (context, snap) {
          if (snap.hasError) return _gone(context);
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final r = snap.data!;
          _last = r;
          final me = Session.current.value;
          final isDriver = Session.uid == r.driverId || (r.isOpen && r.tutorId != Session.uid && isTaxiUser(me?.categories ?? const []));
          _ensureRoute(r);
          final tracker = Session.uid == r.driverId && _tracking.contains(r.status) ? _DriverTracker(rideId: r.id) : null;
          if (!r.hasMap) return _legacy(context, r, isDriver, tracker);
          return LayoutBuilder(builder: (context, c) {
            final mapH = c.maxHeight * 0.42;
            final top = MediaQuery.paddingOf(context).top;
            final bottom = MediaQuery.paddingOf(context).bottom;
            return Stack(children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: mapH + 26,
                child: Stack(children: [
                  Positioned.fill(
                    child: TaxiMap(
                      controller: _map,
                      center: r.pickupPos!,
                      zoom: 14,
                      pickup: r.pickupPos,
                      dest: r.destPos,
                      driver: _tracking.contains(r.status) ? r.driverPos : null,
                      route: _route?.points ?? [r.pickupPos!, r.destPos!],
                      onReady: () {
                        _ready = true;
                        if (!_fitted) _later(() => _fit(_last ?? r));
                      },
                    ),
                  ),
                  Positioned(top: top + 10, left: 12, child: const _MapBack()),
                  Positioned(top: top + 6, right: 12, child: _PetBadge(ride: r)),
                  Positioned(right: 12, bottom: 38, child: _MapRound(icon: Icons.zoom_out_map_rounded, onTap: () => _fit(r))),
                ]),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: mapH,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2))],
                  ),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(18, 16, 18, 24 + bottom),
                    children: [
                      if (tracker != null) tracker,
                      ..._panel(context, r, isDriver),
                    ],
                  ),
                ),
              ),
            ]);
          });
        },
      ),
    );
  }

  Widget _gone(BuildContext context) => SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.all(12), child: _MapBack()),
          const Expanded(
            child: EmptyState(
              icon: Icons.local_taxi_rounded,
              text: 'Esta corrida não está mais disponível.\nOutro motorista aceitou ou o tutor cancelou.',
            ),
          ),
        ]),
      );

  /// Corridas antigas (sem mapa).
  Widget _legacy(BuildContext context, Ride r, bool isDriver, Widget? tracker) {
    return ListView(padding: EdgeInsets.zero, children: [
      PetHeader(
        showBack: true,
        title: 'TaxiPet',
        subtitle: rideStatusText(r),
        avatarOverride: _PetBadge(ride: r, size: 92),
      ),
      if (tracker != null) tracker,
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _panel(context, r, isDriver)),
      ),
    ]);
  }

  String? _subtitle(Ride r, bool isDriver) {
    if (r.isOpen) {
      return isDriver
          ? 'Pedido aberto: o primeiro motorista que aceitar leva.'
          : 'Avisamos os motoristas TaxiPet perto. O primeiro que aceitar leva ${r.petName}.';
    }
    final d = r.driverPos;
    if (!isDriver && d != null && (r.status == 'aceita' || r.status == 'a_caminho') && r.pickupPos != null) {
      final km = distanceKm(d.lat, d.lng, r.pickupLat!, r.pickupLng!) * 1.3;
      final min = (km / 30 * 60).ceil().clamp(1, 600);
      return 'Motorista a ${fmtKm(km)} · chega em cerca de $min min';
    }
    if (!isDriver && d != null && r.status == 'pet_a_bordo' && r.destPos != null) {
      final km = distanceKm(d.lat, d.lng, r.destLat!, r.destLng!) * 1.3;
      return 'Faltam ${fmtKm(km)} até o destino';
    }
    return '${fmtDate(r.when)} às ${fmtTime(r.when)}';
  }

  List<Widget> _panel(BuildContext context, Ride r, bool isDriver) {
    final sub = _subtitle(r, isDriver);
    final other = isDriver ? r.tutorName : r.driverName;
    final cancelled = r.status == 'recusada' || r.status == 'cancelada';
    return [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(rideStatusText(r), style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: cancelled ? AppColors.red : AppColors.textStrong)),
            if (sub != null) Text(sub, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          ]),
        ),
        if (r.priceLabel.isNotEmpty)
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(r.priceLabel, style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.w800, fontSize: 17)),
            Text(r.price != null ? 'valor da corrida' : 'estimativa', style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
          ]),
      ]),
      if (r.isOpen)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(minHeight: 5, color: kTaxiYellow, backgroundColor: AppColors.line, value: TaxiMap.testMode ? 0.4 : null),
          ),
        ),
      const SizedBox(height: 14),
      if (!r.isOpen && other.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: isDriver ? AppColors.teal : kTaxiYellow,
              child: Icon(isDriver ? Icons.person_rounded : Icons.local_taxi_rounded, color: isDriver ? Colors.white : const Color(0xFF3E4446)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isDriver ? 'Tutor' : 'Motorista', style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                Text(other, style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ),
            if (!cancelled) ...[
              RoundAction(
                icon: Icons.chat_rounded,
                label: 'Conversar',
                color: AppColors.teal,
                onTap: () => openChatWith(context, isDriver ? r.tutorId : r.driverId, other),
              ),
              RoundAction(
                icon: Icons.call_rounded,
                label: 'Ligar',
                color: AppColors.green,
                onTap: () => callPhone(context, isDriver ? r.tutorPhone : r.driverPhone, other),
              ),
            ],
          ]),
        ),
      RouteCard(
        pickup: r.pickup,
        dest: r.destination,
        actionLabel: isDriver ? 'Navegar' : 'Mapa',
        onPickup: r.pickupPos != null ? (isDriver ? () => openNavigation(r.pickupPos!) : null) : () => openMap(r.pickup),
        onDest: r.destPos != null ? (isDriver ? () => openNavigation(r.destPos!) : null) : () => openMap(r.destination),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 14, runSpacing: 4, children: [
        _info(Icons.event_rounded, '${fmtDate(r.when)} às ${fmtTime(r.when)}'),
        if (r.km != null) _info(Icons.route_rounded, '${fmtKm(r.km!)}${r.minutes == null ? '' : ' · ${r.minutes} min'}'),
      ]),
      if (r.notes.isNotEmpty) ...[
        const SizedBox(height: 6),
        _info(Icons.notes_rounded, r.notes),
      ],
      const SizedBox(height: 10),
      Wrap(alignment: WrapAlignment.spaceEvenly, spacing: 10, runSpacing: 8, children: [
        if (isDriver)
          RoundAction(
            icon: Icons.sticky_note_2_rounded,
            label: 'Info. do pet',
            color: AppColors.orange,
            onTap: () => showPetInfoSheet(context, petId: r.petId, petName: r.petName, petPhoto: r.petPhoto, obs: r.notes),
          ),
        if (r.isActive && r.step <= 1 && !(isDriver && r.isOpen))
          RoundAction(
            icon: Icons.edit_calendar_rounded,
            label: 'Reagendar',
            color: AppColors.orange,
            onTap: () => rescheduleRide(context, r),
          ),
      ]),
      const SizedBox(height: 14),
      ..._mainActions(context, r, isDriver),
      if (!r.isOpen && !cancelled) ...[
        const SizedBox(height: 18),
        Text('Etapas', style: sectionStyle()),
        const SizedBox(height: 8),
        RideTimeline(ride: r),
      ],
    ];
  }

  Widget _info(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 17, color: AppColors.teal),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: TextStyle(fontSize: 13, color: AppColors.text2))),
      ]);

  List<Widget> _mainActions(BuildContext context, Ride r, bool driver) {
    if (!r.isActive) return const [];
    if (driver) {
      if (r.status == 'pedida') {
        return [
          OrangeButton(
            key: const Key('aceitar_corrida'),
            label: 'Aceitar corrida',
            icon: Icons.check_rounded,
            onPressed: () async {
              final ok = await Db.acceptRide(r);
              if (!context.mounted) return;
              showSnack(context, ok ? 'Corrida aceita! Vá buscar ${r.petName}.' : 'Outro motorista já aceitou esta corrida.', error: !ok);
            },
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () async {
              if (r.isOpen) {
                RideOffers.ignore(r.id);
                Navigator.maybePop(context);
              } else if (await confirm(context, 'Recusar corrida?', 'O tutor verá que você não pode atender.', ok: 'Recusar')) {
                await Db.setRideStatus(r, 'recusada');
              }
            },
            child: Text(r.isOpen ? 'Ignorar' : 'Recusar', style: const TextStyle(color: AppColors.red)),
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
            if (await confirm(context, 'Cancelar corrida?', r.isOpen ? 'O pedido sai da lista dos motoristas.' : 'O motorista será avisado.',
                ok: 'Cancelar corrida')) {
              await Db.setRideStatus(r, 'cancelada');
            }
          },
          child: const Text('Cancelar corrida', style: TextStyle(color: AppColors.muted)),
        ),
      ];
    }
    return const [];
  }
}

/// Foto do pet (atualizada pelo cadastro do pet) com o nome embaixo.
class _PetBadge extends StatelessWidget {
  final Ride ride;
  final double size;
  const _PetBadge({required this.ride, this.size = 64});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Pet>(
      stream: ride.petId.isEmpty ? null : Db.petStream(ride.petId),
      builder: (context, snap) {
        final photo = (snap.data?.photo ?? '').isNotEmpty ? snap.data!.photo : ride.petPhoto;
        return Stack(alignment: Alignment.bottomCenter, clipBehavior: Clip.none, children: [
          PhotoAvatar(photo: photo, size: size, border: AppColors.surface, fallbackIcon: Icons.pets_rounded),
          Positioned(
            bottom: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
              child: Text(ride.petName, style: scriptStyle(size > 80 ? 17 : 13, AppColors.teal)),
            ),
          ),
        ]);
      },
    );
  }
}

/// Envia a posição do motorista enquanto esta tela estiver aberta.
class _DriverTracker extends StatefulWidget {
  final String rideId;
  const _DriverTracker({required this.rideId});
  @override
  State<_DriverTracker> createState() => _DriverTrackerState();
}

class _DriverTrackerState extends State<_DriverTracker> {
  StreamSubscription<Position>? _sub;
  DateTime _lastSent = DateTime(2000);
  String? _problem;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (LocationService.testOverride != null) return;
    final first = await LocationService.current(); // pede a permissão
    if (!mounted) return;
    if (first == null) {
      setState(() => _problem = LocationService.lastError ?? 'Não foi possível obter sua localização.');
      return;
    }
    _send(first);
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 25),
    ).listen((p) => _send(GeoPos(p.latitude, p.longitude)), onError: (_) {});
  }

  void _send(GeoPos p) {
    final now = DateTime.now();
    if (now.difference(_lastSent).inSeconds < 8) return;
    _lastSent = now;
    Db.updateDriverLocation(widget.rideId, p).catchError((_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_problem == null) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(Icons.gps_fixed_rounded, size: 15, color: AppColors.green),
          SizedBox(width: 6),
          Expanded(
            child: Text('O tutor acompanha você no mapa enquanto esta tela estiver aberta.',
                style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
          ),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text('$_problem O tutor não verá você no mapa.', style: const TextStyle(fontSize: 12, color: AppColors.red)),
    );
  }
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
              width: 26,
              height: 26,
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
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                  : i == cur
                      ? const Icon(Icons.local_taxi_rounded, color: Color(0xFF3E4446), size: 15)
                      : null,
            ),
            if (i < Ride.flow.length - 1) Container(width: 3, height: 16, color: i < cur ? AppColors.teal : AppColors.line),
          ]),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              _labels[Ride.flow[i]]!,
              style: TextStyle(
                fontWeight: i == cur ? FontWeight.w800 : FontWeight.w500,
                color: i <= cur ? AppColors.textStrong : AppColors.muted,
                fontSize: i == cur ? 15 : 13.5,
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
              Text(driverView ? 'Animal: ${r.petSpecies}' : 'Motorista: ${r.driverName.isEmpty ? 'procurando…' : r.driverName}',
                  style: st, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(r.status == 'pedida' || !driverView ? rideStatusText(r) : r.pickup,
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

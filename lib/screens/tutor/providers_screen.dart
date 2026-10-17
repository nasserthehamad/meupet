import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/catalog.dart';
import '../../core/db.dart';
import '../../core/location.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/category_grid.dart';
import '../../widgets/common.dart';
import '../../widgets/rating.dart';
import '../common/chat_screen.dart';

/// Tela de um grupo (+SAÚDE / +CUIDADO / +PRODUTO) com a grade de categorias.
class ServiceGroupScreen extends StatelessWidget {
  final ServiceGroup group;
  const ServiceGroupScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          PetHeader(showBack: true, title: group.heroTitle, subtitle: group.subtitle, photo: Session.current.value?.photo),
          SnakeBand(
            index: 1,
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 30),
            child: CategoryGrid(
              group: group,
              onTap: (c) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => c.isProviderCategory
                      ? ProvidersListScreen(title: c.name, categories: [c.name])
                      : ProvidersListScreen(title: c.name, categories: group.providerCategories.map((e) => e.name).toList()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lista de prestadores de uma ou mais categorias.
/// [nearMe]: ordena pela distância (GPS) e, sem localização, pela cidade.
/// [sortByRating]: melhores avaliados primeiro.
/// [bookOnTap]: tocar no prestador já abre o agendamento.
class ProvidersListScreen extends StatefulWidget {
  final String title;
  final List<String> categories;
  final bool nearMe;
  final bool bookOnTap;
  final bool sortByRating;
  final String? species; // só quem atende esse animal
  const ProvidersListScreen({
    super.key,
    required this.title,
    required this.categories,
    this.nearMe = false,
    this.bookOnTap = false,
    this.sortByRating = false,
    this.species,
  });

  @override
  State<ProvidersListScreen> createState() => _ProvidersListScreenState();
}

class _ProvidersListScreenState extends State<ProvidersListScreen> {
  GeoPos? _pos;
  bool _locating = false;
  String? _locError;

  @override
  void initState() {
    super.initState();
    if (widget.nearMe) _locate();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final p = await LocationService.current();
    if (!mounted) return;
    setState(() {
      _pos = p;
      _locError = p == null ? (LocationService.lastError ?? 'Não foi possível obter a localização.') : null;
      _locating = false;
    });
  }

  String _norm(String s) => s.trim().toLowerCase();

  double? _dist(AppUser p) => _pos == null || !p.hasLocation ? null : distanceKm(_pos!.lat, _pos!.lng, p.lat!, p.lng!);

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final myCity = _norm(Session.current.value?.city ?? '');
    final single = w.categories.length == 1 ? w.categories.first : null;
    return Scaffold(
      body: WithRatings(
        builder: (context, ratings) => StreamBuilder<List<AppUser>>(
          stream: Db.providersByAny(w.categories),
          builder: (context, snap) {
            var list = snap.data ?? [];
            if (w.species != null) list = list.where((p) => servesSpecies(p.animals, w.species!)).toList();
            if (w.sortByRating) {
              list = [...list]..sort((a, b) {
                  final ra = ratings[a.id], rb = ratings[b.id];
                  final c = (rb?.avg ?? 0).compareTo(ra?.avg ?? 0);
                  return c != 0 ? c : (rb?.count ?? 0).compareTo(ra?.count ?? 0);
                });
            }
            // perto de mim: com GPS (ordenados), mesma cidade, outras
            List<AppUser> near = [], sameCity = [], others = [];
            if (w.nearMe) {
              near = list.where((p) => _dist(p) != null).toList()..sort((a, b) => _dist(a)!.compareTo(_dist(b)!));
              final rest = list.where((p) => _dist(p) == null).toList();
              sameCity = myCity.isEmpty ? rest : rest.where((p) => _norm(p.city) == myCity).toList();
              others = myCity.isEmpty ? [] : rest.where((p) => _norm(p.city) != myCity).toList();
            }
            Widget tile(AppUser p) => ProviderTile(
                  provider: p,
                  category: single,
                  bookOnTap: w.bookOnTap,
                  rating: ratings[p.id],
                  distance: _dist(p),
                );
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                PetHeader(showBack: true, title: w.title, photo: Session.current.value?.photo),
                SnakeBand(
                  index: 1,
                  roundBottom: false,
                  padding: const EdgeInsets.only(top: 12, bottom: 50),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (w.bookOnTap)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: Text('Escolha com quem você quer agendar:', style: TextStyle(color: AppColors.muted)),
                      ),
                    if (w.sortByRating)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: Text('Os mais bem avaliados pelos tutores primeiro.', style: TextStyle(color: AppColors.muted)),
                      ),
                    if (w.nearMe) _locationCard(),
                    if (!snap.hasData)
                      const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                    else if (list.isEmpty)
                      const EmptyState(icon: Icons.storefront_rounded, text: 'Ainda não há prestadores cadastrados aqui.')
                    else if (!w.nearMe)
                      ...[for (final p in list) tile(p)]
                    else ...[
                      if (near.isNotEmpty) ...[const SectionTitle('Perto de você'), for (final p in near) tile(p)],
                      if (sameCity.isNotEmpty) ...[
                        SectionTitle(myCity.isEmpty ? 'Sem localização no mapa' : 'Na sua cidade'),
                        for (final p in sameCity) tile(p),
                      ],
                      if (others.isNotEmpty) ...[const SectionTitle('Outras cidades'), for (final p in others) tile(p)],
                    ],
                  ]),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _locationCard() {
    final city = Session.current.value?.city ?? '';
    final String text;
    if (_locating) {
      text = 'Buscando sua localização…';
    } else if (_pos != null) {
      text = 'Ordenado pela distância até você.';
    } else {
      text = '${_locError ?? 'Sem localização.'} ${city.isEmpty ? 'Informe sua cidade em Editar Perfil.' : 'Mostrando por cidade ($city).'}';
    }
    return WhiteBlock(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(children: [
        Icon(_pos != null ? Icons.my_location_rounded : Icons.location_searching_rounded, color: AppColors.teal),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        if (_locating)
          const Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
        else if (_pos == null)
          TextButton(onPressed: _locate, child: const Text('Tentar')),
      ]),
    );
  }
}

class ProviderTile extends StatelessWidget {
  final AppUser provider;
  final String? category;
  final bool bookOnTap;
  final RatingInfo? rating;
  final double? distance;
  const ProviderTile({super.key, required this.provider, this.category, this.bookOnTap = false, this.rating, this.distance});
  @override
  Widget build(BuildContext context) {
    final price = category == null ? null : provider.prices[category];
    return WhiteBlock(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => bookOnTap
                ? BookingScreen(provider: provider, initialService: category)
                : ProviderDetailScreen(provider: provider, category: category),
          ),
        ),
        child: Row(children: [
          PhotoAvatar(photo: provider.photo, size: 56, fallbackIcon: Icons.storefront_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(provider.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (provider.address.isNotEmpty || provider.city.isNotEmpty)
                Text([provider.address, provider.city].where((e) => e.isNotEmpty).join(' · '),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              if (rating != null) Padding(padding: const EdgeInsets.only(top: 1), child: RatingLine(rating, size: 13)),
              if (price != null)
                Text('$category a partir de ${fmtMoney(price)}',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.orange))
              else
                Text(provider.categories.join(', '),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.teal)),
            ]),
          ),
          if (distance != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppColors.teal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(fmtKm(distance!), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.teal)),
            )
          else
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ]),
      ),
    );
  }
}

class ProviderDetailScreen extends StatelessWidget {
  final AppUser provider;
  final String? category;
  const ProviderDetailScreen({super.key, required this.provider, this.category});

  Future<void> _directions() async {
    final p = provider;
    final q = p.hasLocation ? '${p.lat},${p.lng}' : [p.address, p.city].where((e) => e.isNotEmpty).join(', ');
    await launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}'),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final isTutor = Session.current.value?.isProvider != true;
    return Scaffold(
      body: StreamBuilder<List<Review>>(
        stream: Db.reviewsFor(p.id),
        builder: (context, rs) {
          final reviews = rs.data ?? const <Review>[];
          final info = reviews.isEmpty
              ? null
              : RatingInfo(reviews.fold<int>(0, (a, r) => a + r.stars) / reviews.length, reviews.length);
          Review? mine;
          for (final r in reviews) {
            if (r.tutorId == Session.current.value?.id) mine = r;
          }
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              PetHeader(showBack: true, title: p.displayName, photo: p.photo, fallbackIcon: Icons.storefront_rounded),
              SnakeBand(
                index: 1,
                padding: const EdgeInsets.only(top: 12, bottom: 26),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Center(child: RatingLine(info, size: 18)),
                  const SizedBox(height: 6),
                  WhiteBlock(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (p.description.isNotEmpty) ...[Text(p.description), const SizedBox(height: 10)],
                      _info(Icons.person_rounded, 'Responsável', p.name),
                      if (p.address.isNotEmpty) _info(Icons.place_rounded, 'Endereço', p.address),
                      if (p.city.isNotEmpty) _info(Icons.location_city_rounded, 'Cidade', p.city),
                      if (p.phone.isNotEmpty) _info(Icons.phone_rounded, 'Telefone', p.phone),
                      if (p.animals.isNotEmpty) _info(Icons.pets_rounded, 'Atende', p.animals.join(', ')),
                    ]),
                  ),
                  const SectionTitle('Serviços'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(spacing: 8, runSpacing: 6, children: [
                      for (final c in p.categories)
                        Chip(
                          avatar: Icon(iconForService(c), size: 16, color: AppColors.teal),
                          label: Text(p.prices[c] == null ? c : '$c · ${fmtMoney(p.prices[c]!)}'),
                          backgroundColor: Colors.white,
                        ),
                    ]),
                  ),
                  if (p.prices.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
                      child: Text('Preços "a partir de", informados pelo prestador.', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                    ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (isTutor) ...[
                        OrangeButton(
                          label: 'Agendar',
                          icon: Icons.event_available_rounded,
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => BookingScreen(provider: p, initialService: category)),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                            icon: const Icon(Icons.chat_rounded),
                            label: const Text('Conversar'),
                            onPressed: () async {
                              final id = await Db.openChat(p.id, p.displayName);
                              if (!context.mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => ChatScreen(chatId: id, otherName: p.displayName, otherPhoto: p.photo, otherId: p.id)),
                              );
                            },
                          ),
                        ),
                        if (p.hasLocation || p.address.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                              icon: const Icon(Icons.map_rounded),
                              label: const Text('Como chegar'),
                              onPressed: _directions,
                            ),
                          ),
                        ],
                      ]),
                    ]),
                  ),
                ]),
              ),
              SnakeBand(
                index: 2,
                roundBottom: false,
                padding: const EdgeInsets.only(top: 8, bottom: 50),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SectionTitle(
                    'Avaliações',
                    trailing: isTutor
                        ? TextButton.icon(
                            key: const Key('avaliar'),
                            onPressed: () => showReviewSheet(context, p, mine: mine),
                            icon: const Icon(Icons.star_rounded, color: kStar),
                            label: Text(mine == null ? 'Avaliar' : 'Editar minha nota'),
                          )
                        : null,
                  ),
                  if (reviews.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: Text('Ninguém avaliou ainda.', style: TextStyle(color: AppColors.muted)),
                    )
                  else
                    for (final r in reviews.take(20))
                      WhiteBlock(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(r.tutorName, style: const TextStyle(fontWeight: FontWeight.w600))),
                            Stars(r.stars.toDouble(), size: 15),
                          ]),
                          if (r.text.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(r.text)),
                          if (r.date != null)
                            Text(fmtDate(r.date), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                        ]),
                      ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _info(IconData i, String label, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, size: 18, color: AppColors.teal),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(v)),
        ]),
      );
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _q = '';

  String _norm(String s) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const to = 'aaaaaeeeeiiiiooooouuuuc';
    var r = s.toLowerCase();
    for (var i = 0; i < from.length; i++) {
      r = r.replaceAll(from[i], to[i]);
    }
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final q = _norm(_q.trim());
    final cats = q.isEmpty ? <ServiceCat>[] : allServiceCats.where((c) => _norm(c.name).contains(q)).toList();
    return Scaffold(
      body: StreamBuilder<List<AppUser>>(
        stream: Db.allProviders(),
        builder: (context, snap) {
          final all = snap.data ?? [];
          final provs = q.isEmpty
              ? all
              : all.where((p) => _norm('${p.displayName} ${p.city} ${p.categories.join(' ')}').contains(q)).toList();
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              PetHeader(
                showBack: true,
                title: 'Buscar',
                photo: Session.current.value?.photo,
                bottom: TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => _q = v),
                  decoration: inputDeco('Serviço, nome ou cidade', icon: Icons.search_rounded),
                ),
              ),
              SnakeBand(
                index: 1, padding: const EdgeInsets.only(top: 8, bottom: 30),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (cats.isNotEmpty) ...[
                const SectionTitle('Categorias'),
                for (final c in cats)
                  ListTile(
                    leading: CategoryCircle(cat: c, color: groupOfCategory(c.name)?.color ?? AppColors.teal, size: 42),
                    title: Text(c.name),
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => ProvidersListScreen(title: c.name, categories: [c.name]))),
                  ),
              ],
              const SectionTitle('Prestadores'),
              if (!snap.hasData)
                const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
              else if (provs.isEmpty)
                const EmptyState(icon: Icons.search_off_rounded, text: 'Nada encontrado.')
              else
                for (final p in provs) ProviderTile(provider: p),
              const SizedBox(height: 24),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

class BookingScreen extends StatefulWidget {
  final AppUser provider;
  final String? initialService;
  const BookingScreen({super.key, required this.provider, this.initialService});
  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  Pet? _pet;
  String? _service;
  DateTime? _when;
  bool _taxi = false;
  final _address = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final cats = widget.provider.categories;
    _service = cats.contains(widget.initialService) ? widget.initialService : (cats.isNotEmpty ? cats.first : null);
  }

  Future<void> _save() async {
    if (_pet == null || _service == null || _when == null) {
      showSnack(context, 'Escolha o pet, o serviço e a data/hora.', error: true);
      return;
    }
    if (_taxi && _address.text.trim().isEmpty) {
      showSnack(context, 'Informe o endereço para o TaxiPet.', error: true);
      return;
    }
    setState(() => _saving = true);
    final me = Session.user;
    try {
      await Db.appointments.add({
        'tutorId': me.id,
        'tutorName': me.name,
        'tutorPhone': me.phone,
        'petId': _pet!.id,
        'petName': _pet!.name,
        'species': _pet!.species,
        'petPhoto': _pet!.photo,
        'providerId': widget.provider.id,
        'providerName': widget.provider.displayName,
        'service': _service,
        'dateTime': Timestamp.fromDate(_when!),
        'status': 'pendente',
        'notes': _notes.text.trim(),
        'taxiPet': _taxi,
        'address': _address.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      showSnack(context, 'Pedido enviado! Aguarde a confirmação de ${widget.provider.displayName}.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, 'Erro ao agendar: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Pet>>(
        stream: Db.myPets(Session.uid),
        builder: (context, snap) {
          final pets = snap.data ?? [];
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              PetHeader(showBack: true, title: 'Agendar', subtitle: widget.provider.displayName, photo: widget.provider.photo, fallbackIcon: Icons.storefront_rounded),
              SnakeBand(
                index: 1, padding: const EdgeInsets.only(top: 8, bottom: 30),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle('Qual pet?'),
              if (snap.hasData && pets.isEmpty)
                const EmptyState(icon: Icons.pets_rounded, text: 'Cadastre um pet em "Meus Pets" primeiro.')
              else
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    children: [
                      for (final p in pets)
                        GestureDetector(
                          onTap: () => setState(() => _pet = p),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Column(children: [
                              PhotoAvatar(
                                photo: p.photo,
                                size: 64,
                                border: _pet?.id == p.id ? AppColors.orange : Colors.white,
                              ),
                              const SizedBox(height: 4),
                              Text(p.name, style: TextStyle(fontWeight: _pet?.id == p.id ? FontWeight.w700 : FontWeight.w400)),
                            ]),
                          ),
                        ),
                    ],
                  ),
                ),
              const SectionTitle('Serviço'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ChipSelector(
                  options: widget.provider.categories,
                  value: _service,
                  onChanged: (v) => setState(() => _service = v),
                ),
              ),
              if (_service != null && widget.provider.prices[_service] != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                  child: Text('$_service a partir de ${fmtMoney(widget.provider.prices[_service]!)} (valor informado pelo prestador)',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.orange, fontWeight: FontWeight.w600)),
                ),
              const SectionTitle('Quando?'),
              WhiteBlock(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.calendar_month_rounded, color: AppColors.teal),
                  title: Text(_when == null ? 'Escolher data e hora' : '${fmtDate(_when)} às ${fmtTime(_when)}'),
                  trailing: const Icon(Icons.edit_calendar_rounded),
                  onTap: () async {
                    final d = await pickDateTime(context, initial: _when);
                    if (d != null) setState(() => _when = d);
                  },
                ),
              ),
              WhiteBlock(
                padding: EdgeInsets.zero,
                child: SwitchListTile(
                  value: _taxi,
                  activeThumbColor: AppColors.orange,
                  secondary: const Icon(Icons.local_taxi_rounded, color: AppColors.orange),
                  title: const Text('Incluir TaxiPet'),
                  subtitle: const Text('Buscar e levar o pet'),
                  onChanged: (v) => setState(() => _taxi = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(children: [
                  if (_taxi) ...[
                    TextField(controller: _address, decoration: inputDeco('Endereço para buscar', icon: Icons.place_rounded)),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _notes,
                    maxLines: 3,
                    decoration: inputDeco('Observações (ex.: banho e tosa, alergias…)', icon: Icons.notes_rounded),
                  ),
                  const SizedBox(height: 20),
                  OrangeButton(label: 'Solicitar agendamento', loading: _saving, onPressed: _save, icon: Icons.send_rounded),
                  const SizedBox(height: 30),
                ]),
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

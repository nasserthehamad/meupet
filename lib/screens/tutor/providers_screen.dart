import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../common/chat_screen.dart';

/// Tela "+CUIDADO" / "+SAÚDE" / "+PRODUTOS" com a grade de categorias.
class ServiceGroupScreen extends StatelessWidget {
  final ServiceGroup group;
  const ServiceGroupScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          PetHeader(showBack: true, title: group.title.toUpperCase(), subtitle: group.subtitle, photo: Session.current.value?.photo),
          SnakeBand(
            index: 1, padding: const EdgeInsets.only(top: 14, bottom: 30),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: 150,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              image: DecorationImage(image: AssetImage(group.image), fit: BoxFit.cover),
            ),
          ),
          const SectionTitle('Categorias'),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            childAspectRatio: 0.8,
            children: [
              for (final c in group.items)
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProvidersListScreen(category: c.name))),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    CircleAvatar(radius: 28, backgroundColor: AppColors.green, child: Icon(c.icon, color: Colors.white, size: 28)),
                    const SizedBox(height: 6),
                    Text(c.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 24),
            ]),
          ),
        ],
      ),
    );
  }
}

class ProvidersListScreen extends StatelessWidget {
  final String category;
  const ProvidersListScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<AppUser>>(
        stream: Db.providersByCategory(category),
        builder: (context, snap) {
          final list = snap.data ?? [];
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              PetHeader(showBack: true, title: category, photo: Session.current.value?.photo),
              SnakeBand(
                index: 1, padding: const EdgeInsets.only(top: 12, bottom: 30),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (!snap.hasData)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
              else if (list.isEmpty)
                const EmptyState(icon: Icons.storefront_rounded, text: 'Ainda não há prestadores cadastrados nesta categoria.')
              else
                for (final p in list) ProviderTile(provider: p, category: category),
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

class ProviderTile extends StatelessWidget {
  final AppUser provider;
  final String? category;
  const ProviderTile({super.key, required this.provider, this.category});
  @override
  Widget build(BuildContext context) {
    return WhiteBlock(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProviderDetailScreen(provider: provider, category: category)),
        ),
        child: Row(children: [
          PhotoAvatar(photo: provider.photo, size: 56, fallbackIcon: Icons.storefront_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(provider.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (provider.address.isNotEmpty || provider.city.isNotEmpty)
                Text([provider.address, provider.city].where((e) => e.isNotEmpty).join(' · '),
                    style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              Text(provider.categories.join(', '),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.teal)),
            ]),
          ),
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

  @override
  Widget build(BuildContext context) {
    final p = provider;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          PetHeader(showBack: true, title: p.displayName, photo: p.photo, fallbackIcon: Icons.storefront_rounded),
          SnakeBand(
            index: 1, padding: const EdgeInsets.only(top: 12, bottom: 30),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          WhiteBlock(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (p.description.isNotEmpty) ...[Text(p.description), const SizedBox(height: 10)],
              _info(Icons.person_rounded, 'Responsável', p.name),
              if (p.address.isNotEmpty) _info(Icons.place_rounded, 'Endereço', p.address),
              if (p.city.isNotEmpty) _info(Icons.location_city_rounded, 'Cidade', p.city),
              if (p.phone.isNotEmpty) _info(Icons.phone_rounded, 'Telefone', p.phone),
            ]),
          ),
          const SectionTitle('Serviços'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 8, runSpacing: 6, children: [
              for (final c in p.categories)
                Chip(
                  avatar: Icon(iconForService(c), size: 16, color: AppColors.teal),
                  label: Text(c),
                  backgroundColor: Colors.white,
                ),
            ]),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              OrangeButton(
                label: 'Agendar',
                icon: Icons.event_available_rounded,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => BookingScreen(provider: p, initialService: category)),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                icon: const Icon(Icons.chat_rounded),
                label: const Text('Conversar'),
                onPressed: () async {
                  final id = await Db.openChat(p.id, p.displayName);
                  if (!context.mounted) return;
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: id, otherName: p.displayName, otherPhoto: p.photo)));
                },
              ),
            ]),
          ),
          const SizedBox(height: 30),
            ]),
          ),
        ],
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
                    leading: CircleAvatar(backgroundColor: AppColors.green, child: Icon(c.icon, color: Colors.white)),
                    title: Text(c.name),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProvidersListScreen(category: c.name))),
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../common/chat_screen.dart';

class AdoptionScreen extends StatefulWidget {
  final String? initialSpecies;
  const AdoptionScreen({super.key, this.initialSpecies});
  @override
  State<AdoptionScreen> createState() => _AdoptionScreenState();
}

class _AdoptionScreenState extends State<AdoptionScreen> {
  late String? _species = widget.initialSpecies;
  String _q = '';
  bool _onlyFav = false;

  Future<void> _toggleFav(String id, bool fav) => Db.users.doc(Session.uid).update({
        'favorites': fav ? FieldValue.arrayRemove([id]) : FieldValue.arrayUnion([id]),
      });

  Future<void> _filterSheet() async {
    await showModalBottomSheet(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Filtrar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.purple)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 6, children: [
                for (final s in [null, ...speciesList])
                  ChoiceChip(
                    label: Text(s ?? 'Todos'),
                    selected: _species == s,
                    selectedColor: AppColors.purple,
                    labelStyle: TextStyle(color: _species == s ? Colors.white : AppColors.text),
                    onSelected: (_) {
                      setState(() => _species = s);
                      setS(() {});
                    },
                  ),
              ]),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _onlyFav,
                activeThumbColor: AppColors.purple,
                title: const Text('Só os meus favoritos ❤️'),
                onChanged: (v) {
                  setState(() => _onlyFav = v);
                  setS(() {});
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.homeBg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.volunteer_activism_rounded),
        label: const Text('Doar um pet'),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdoptionFormScreen())),
      ),
      body: StreamBuilder<AppUser>(
        stream: Db.userStream(Session.uid),
        builder: (context, us) {
          final favs = us.data?.favorites ?? const <String>[];
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: Db.adoptions.where('status', isEqualTo: 'disponivel').snapshots(),
            builder: (context, snap) {
              var list = (snap.data?.docs ?? []).map(Adoption.fromDoc).toList();
              if (_species != null) list = list.where((a) => a.species == _species).toList();
              if (_onlyFav) list = list.where((a) => favs.contains(a.id)).toList();
              if (_q.isNotEmpty) {
                final q = _q.toLowerCase();
                list = list.where((a) => '${a.name} ${a.species} ${a.city}'.toLowerCase().contains(q)).toList();
              }
              return Column(children: [
                const TopBar(color: AppColors.purple, showBack: true),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 100),
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text('O seu novo amiguinho está aqui!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.purple, fontWeight: FontWeight.w700, fontSize: 20)),
                      ),
                      Container(
                        color: AppColors.purple,
                        padding: const EdgeInsets.only(top: 10),
                        child: Image.asset('assets/images/adocao_banner.png', fit: BoxFit.fitWidth),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 18, right: 4),
                            child: Text('A', style: scriptStyle(20, AppColors.purple)),
                          ),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text.rich(TextSpan(children: [
                              TextSpan(text: 'Meu', style: logoStyle(50, AppColors.teal)),
                              TextSpan(text: 'PET', style: logoStyle(50, AppColors.orange)),
                            ])),
                            Transform.translate(
                              offset: const Offset(24, -10),
                              child: Text('+VIDA',
                                  style: scriptStyle(26, Colors.white).copyWith(
                                    shadows: const [Shadow(color: Color(0x55000000), blurRadius: 3)],
                                  )),
                            ),
                          ]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: Text('está com você nessa jornada', style: scriptStyle(16, AppColors.purple)),
                            ),
                          ),
                        ]),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 10, 8),
                        child: Row(children: [
                          Expanded(
                            child: TextField(
                              onChanged: (v) => setState(() => _q = v.trim()),
                              decoration: InputDecoration(
                                hintText: 'Digite a sua busca',
                                hintStyle: const TextStyle(color: Color(0xFF8A9599), fontSize: 16),
                                suffixIcon: const Icon(Icons.search_rounded, color: AppColors.purple, size: 28),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.35),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.purple, width: 2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.purple, width: 2.5),
                                ),
                              ),
                            ),
                          ),
                          InkWell(
                            key: const Key('filtrar'),
                            borderRadius: BorderRadius.circular(12),
                            onTap: _filterSheet,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Column(children: [
                                Text(
                                  _species ?? (_onlyFav ? 'Favoritos' : 'Filtrar'),
                                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                ),
                                const Icon(Icons.filter_alt_rounded, color: AppColors.purple, size: 34),
                              ]),
                            ),
                          ),
                        ]),
                      ),
                      if (!snap.hasData)
                        const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
                      else if (list.isEmpty)
                        const EmptyState(icon: Icons.favorite_border_rounded, text: 'Nenhum pet para adoção com esse filtro ainda.')
                      else
                        LayoutBuilder(builder: (context, c) {
                          final w = (c.maxWidth - 16) / 3;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Wrap(children: [
                              for (final a in list)
                                SizedBox(
                                  width: w,
                                  child: _AdoptCell(
                                    a: a,
                                    size: w - 12,
                                    fav: favs.contains(a.id),
                                    onFav: () => _toggleFav(a.id, favs.contains(a.id)),
                                    onTap: () => _details(context, a),
                                  ),
                                ),
                            ]),
                          );
                        }),
                    ],
                  ),
                ),
              ]);
            },
          );
        },
      ),
    );
  }

  void _details(BuildContext context, Adoption a) {
    final mine = a.postedBy == Session.uid;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          PhotoAvatar(photo: a.photo, size: 150, border: AppColors.purple),
          const SizedBox(height: 10),
          Text(a.name, style: scriptStyle(30, AppColors.purple)),
          Text('${a.species} · ${a.sex == 'F' ? 'Fêmea' : 'Macho'} · ${a.age}${a.city.isNotEmpty ? ' · ${a.city}' : ''}',
              style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 10),
          Text(a.description.isEmpty ? 'Sem descrição.' : a.description, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('Publicado por ${a.postedByName}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 18),
          if (mine)
            OrangeButton(
              label: 'Marcar como adotado',
              icon: Icons.favorite_rounded,
              onPressed: () async {
                await Db.adoptions.doc(a.id).update({'status': 'adotado'});
                if (c.mounted) Navigator.pop(c);
              },
            )
          else
            OrangeButton(
              label: 'Quero adotar!',
              icon: Icons.chat_rounded,
              onPressed: () async {
                final id = await Db.openChat(a.postedBy, a.postedByName);
                if (!c.mounted) return;
                Navigator.pop(c);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: id, otherName: a.postedByName, initialText: 'Olá! Tenho interesse em adotar ${a.name} 🐾')));
              },
            ),
        ]),
      ),
    );
  }
}

class _AdoptCell extends StatelessWidget {
  final Adoption a;
  final double size;
  final bool fav;
  final VoidCallback onFav;
  final VoidCallback onTap;
  const _AdoptCell({required this.a, required this.size, required this.fav, required this.onFav, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final female = a.sex == 'F';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(children: [
        GestureDetector(
          onTap: onTap,
          child: Stack(children: [
            PhotoAvatar(photo: a.photo, size: size, border: AppColors.surface),
            Positioned(
              right: size * 0.06,
              top: size * 0.32,
              child: Icon(female ? Icons.female_rounded : Icons.male_rounded,
                  size: size * 0.24, color: female ? const Color(0xFFF0508C) : const Color(0xFF2F8FE0)),
            ),
            Positioned(
              right: size * 0.04,
              bottom: size * 0.02,
              child: GestureDetector(
                onTap: onFav,
                child: CircleAvatar(
                  radius: size * 0.13,
                  backgroundColor: fav ? AppColors.purple : Colors.white.withValues(alpha: 0.85),
                  child: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      size: size * 0.15, color: fav ? Colors.white : AppColors.purple),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 4),
        Text('${a.name}, ${a.age}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
      ]),
    );
  }
}

class AdoptionFormScreen extends StatefulWidget {
  const AdoptionFormScreen({super.key});
  @override
  State<AdoptionFormScreen> createState() => _AdoptionFormScreenState();
}

class _AdoptionFormScreenState extends State<AdoptionFormScreen> {
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _desc = TextEditingController();
  late final _city = TextEditingController(text: Session.current.value?.city);
  String _species = 'Cachorro';
  String _sex = 'M';
  String? _photo;
  bool _saving = false;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _photo == null) {
      showSnack(context, 'Adicione uma foto e o nome do pet.', error: true);
      return;
    }
    setState(() => _saving = true);
    final me = Session.user;
    try {
      await Db.adoptions.add({
        'name': _name.text.trim(),
        'species': _species,
        'age': _age.text.trim(),
        'sex': _sex,
        'photo': _photo,
        'description': _desc.text.trim(),
        'city': _city.text.trim(),
        'postedBy': me.id,
        'postedByName': me.displayName,
        'status': 'disponivel',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, 'Erro: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          PetHeader(showBack: true, title: 'Doar um pet', photo: Session.current.value?.photo),
          SnakeBand(
            index: 1, padding: const EdgeInsets.only(top: 10, bottom: 30),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: PhotoPickerAvatar(photo: _photo, onPicked: (b) => setState(() => _photo = b))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: inputDeco('Nome', icon: Icons.pets_rounded)),
              const SizedBox(height: 12),
              ChipSelector(options: speciesList, value: _species, onChanged: (v) => setState(() => _species = v)),
              const SizedBox(height: 12),
              ChipSelector(options: const ['Macho', 'Fêmea'], value: _sex == 'F' ? 'Fêmea' : 'Macho', onChanged: (v) => setState(() => _sex = v == 'Fêmea' ? 'F' : 'M')),
              const SizedBox(height: 12),
              TextField(controller: _age, decoration: inputDeco('Idade (ex.: 2 meses)', icon: Icons.cake_rounded)),
              const SizedBox(height: 12),
              TextField(controller: _city, decoration: inputDeco('Cidade', icon: Icons.location_city_rounded)),
              const SizedBox(height: 12),
              TextField(controller: _desc, maxLines: 4, decoration: inputDeco('Conte sobre ele (temperamento, vacinas, castração…)')),
              const SizedBox(height: 20),
              OrangeButton(label: 'Publicar', loading: _saving, onPressed: _save, icon: Icons.favorite_rounded),
              const SizedBox(height: 30),
            ]),
          ),
            ]),
          ),
        ],
      ),
    );
  }
}

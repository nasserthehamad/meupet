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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.volunteer_activism_rounded),
        label: const Text('Doar um pet'),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdoptionFormScreen())),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: Db.adoptions.where('status', isEqualTo: 'disponivel').snapshots(),
        builder: (context, snap) {
          final all = (snap.data?.docs ?? []).map(Adoption.fromDoc).toList();
          final list = _species == null ? all : all.where((a) => a.species == _species).toList();
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              PetHeader(showBack: true, title: 'Adoção', photo: Session.current.value?.photo),
              Container(
                color: AppColors.purple,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: const Text('O seu novo amiguinho está aqui!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              Image.asset('assets/images/adocao_banner.png', fit: BoxFit.fitWidth),
              SnakeBand(
                index: 1,
                roundTop: false,
                padding: const EdgeInsets.only(top: 12, bottom: 100),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _filter(null, 'Todos'),
                    for (final s in speciesList) _filter(s, s),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (!snap.hasData)
                const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
              else if (list.isEmpty)
                const EmptyState(icon: Icons.favorite_border_rounded, text: 'Nenhum pet para adoção nesta categoria ainda.')
              else
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  childAspectRatio: 0.72,
                  children: [
                    for (final a in list)
                      GestureDetector(
                        onTap: () => _details(context, a),
                        child: Column(children: [
                          Stack(children: [
                            PhotoAvatar(photo: a.photo, size: 96, border: AppColors.purple),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.white,
                                child: Icon(a.sex == 'F' ? Icons.female_rounded : Icons.male_rounded,
                                    size: 18, color: a.sex == 'F' ? Colors.pink : Colors.blue),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Text('${a.name}, ${a.age}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                        ]),
                      ),
                  ],
                ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filter(String? s, String label) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChoiceChip(
          label: Text(label),
          selected: _species == s,
          selectedColor: AppColors.purple,
          labelStyle: TextStyle(color: _species == s ? Colors.white : AppColors.text),
          onSelected: (_) => setState(() => _species = s),
        ),
      );

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

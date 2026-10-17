import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/animal_avatar.dart';
import '../../widgets/category_grid.dart';
import '../../widgets/common.dart';
import 'adoption_screen.dart';
import 'agenda_screen.dart';
import 'providers_screen.dart';

/// "Ver tudo" da Categoria Animal: todas as espécies.
class AnimalsScreen extends StatelessWidget {
  const AnimalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDCDCDC),
      body: Column(children: [
        TopBar(
          showBack: true,
          onBell: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgendaScreen())),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('Categoria Animal',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: AppColors.teal)),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 2, 4, 16),
                child: Text('Escolha o animal para ver quem cuida dele, produtos e adoção.',
                    style: TextStyle(color: AppColors.muted)),
              ),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.92,
                children: [
                  for (final a in animalCategories)
                    AnimalCard(
                      animal: a,
                      avatar: 74,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AnimalScreen(animal: a))),
                    ),
                ],
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

/// Página de um animal: quem atende (+Saúde, +Cuidado, +Produtos) e adoção.
class AnimalScreen extends StatelessWidget {
  final AnimalCat animal;
  const AnimalScreen({super.key, required this.animal});

  String get _species => animal.$2;
  String get _label => animal.$1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<AppUser>>(
        stream: Db.allProviders(),
        builder: (context, snap) {
          final provs = (snap.data ?? []).where((p) => servesSpecies(p.animals, _species)).toList()
            ..sort((a, b) => a.displayName.compareTo(b.displayName));
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              PetHeader(
                showBack: true,
                title: _label,
                subtitle: 'Quem cuida, o que comprar e quem adotar',
                avatarOverride: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  child: AnimalAvatar(animal: animal, size: 84),
                ),
              ),
              for (var i = 0; i < serviceGroups.length; i++)
                SnakeBand(
                  index: i + 1,
                  padding: const EdgeInsets.only(top: 12, bottom: 28),
                  child: _GroupSection(
                    group: serviceGroups[i],
                    providers: provs,
                    loading: !snap.hasData,
                    species: _species,
                    label: _label,
                  ),
                ),
              SnakeBand(
                index: serviceGroups.length + 1,
                padding: const EdgeInsets.only(top: 12, bottom: 40),
                child: _AdoptionSection(animal: animal),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHead extends StatelessWidget {
  final String title;
  final Color color;
  final VoidCallback? onSeeAll;
  const _SectionHead(this.title, this.color, {this.onSeeAll});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 10, 4),
      child: Row(children: [
        Expanded(child: Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: color))),
        if (onSeeAll != null) SeeAll(onTap: onSeeAll!),
      ]),
    );
  }
}

class _GroupSection extends StatelessWidget {
  final ServiceGroup group;
  final List<AppUser> providers;
  final bool loading;
  final String species;
  final String label;
  const _GroupSection({
    required this.group,
    required this.providers,
    required this.loading,
    required this.species,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cats = group.providerCategories.map((c) => c.name).toSet();
    final list = providers.where((p) => p.categories.any(cats.contains)).toList();
    final color = group.key == 'produtos' ? group.color : AppColors.orange;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _SectionHead(
        group.title,
        color,
        onSeeAll: list.length > 3
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProvidersListScreen(
                      title: '${group.title} · $label',
                      categories: cats.toList(),
                      species: species,
                    ),
                  ),
                )
            : null,
      ),
      if (loading)
        const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
      else if (list.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Text('Ainda não há ninguém de ${group.title} para ${label.toLowerCase()} por aqui.',
              style: const TextStyle(color: AppColors.muted)),
        )
      else
        for (final p in list.take(3)) ProviderTile(provider: p),
    ]);
  }
}

class _AdoptionSection extends StatelessWidget {
  final AnimalCat animal;
  const _AdoptionSection({required this.animal});

  void _openAll(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => AdoptionScreen(initialSpecies: animal.$2)));

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: Db.adoptions.where('status', isEqualTo: 'disponivel').where('species', isEqualTo: animal.$2).snapshots(),
      builder: (context, snap) {
        final list = (snap.data?.docs ?? []).map(Adoption.fromDoc).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _SectionHead('Para adoção', AppColors.purple, onSeeAll: list.isEmpty ? null : () => _openAll(context)),
          if (!snap.hasData)
            const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
          else if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text('Nenhum ${animal.$1.toLowerCase()} esperando um lar agora.',
                  style: const TextStyle(color: AppColors.muted)),
            )
          else
            SizedBox(
              height: 136,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final a = list[i];
                  return GestureDetector(
                    onTap: () => _openAll(context),
                    child: SizedBox(
                      width: 96,
                      child: Column(children: [
                        PhotoAvatar(photo: a.photo, size: 92, fallbackIcon: Icons.pets, border: AppColors.purple),
                        const SizedBox(height: 4),
                        Text(a.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: scriptStyle(18, AppColors.purple)),
                      ]),
                    ),
                  );
                },
              ),
            ),
        ]);
      },
    );
  }
}

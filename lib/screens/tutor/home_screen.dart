import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'adoption_screen.dart';
import 'providers_screen.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onGoToPets;
  const HomeScreen({super.key, required this.onGoToPets});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppUser?>(
      valueListenable: Session.current,
      builder: (context, u, _) {
        final first = (u?.name ?? '').split(' ').first;
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            PetHeader(
              subtitle: first.isEmpty ? null : 'Olá, $first!',
              photo: u?.photo,
              bottom: _SearchBox(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()))),
            ),
            SnakeBand(
              index: 1,
              padding: const EdgeInsets.only(top: 14, bottom: 22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _Hero(onTap: onGoToPets),
                const SectionTitle('Categoria Animal'),
                SizedBox(
                  height: 96,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    children: [
                      for (final s in const ['Cachorro', 'Gato', 'Coelho', 'Aves', 'Roedor'])
                        _AnimalChip(
                          label: s,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdoptionScreen(initialSpecies: s))),
                        ),
                    ],
                  ),
                ),
              ]),
            ),
            SnakeBand(
              index: 2,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle('Categorias de Serviços'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [
                    for (final g in serviceGroups)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceGroupScreen(group: g))),
                          child: Column(children: [
                            Text(g.title, style: logoStyle(22, AppColors.orange)),
                            const SizedBox(height: 6),
                            Container(
                              width: 92,
                              height: 92,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                image: DecorationImage(image: AssetImage(g.image), fit: BoxFit.cover),
                              ),
                            ),
                          ]),
                        ),
                      ),
                  ]),
                ),
              ]),
            ),
            SnakeBand(
              index: 3,
              padding: const EdgeInsets.only(top: 18, bottom: 26),
              child: _AdoptionBanner(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdoptionScreen())),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SearchBox extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchBox({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.teal.withValues(alpha: 0.6)),
        ),
        child: const Row(children: [
          Expanded(child: Text('Digite a sua busca', style: TextStyle(color: AppColors.muted))),
          Icon(Icons.search_rounded, color: AppColors.teal),
        ]),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final VoidCallback onTap;
  const _Hero({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: 'Meu', style: logoStyle(40, AppColors.teal)),
                TextSpan(text: 'PET', style: logoStyle(40, AppColors.orange)),
              ])),
              Text('+VIDA', style: scriptStyle(24, AppColors.teal)),
              const SizedBox(height: 6),
              const Text('Tudo sobre a saúde e o cuidado do seu pet num só lugar.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ),
          Container(
            width: 130,
            height: 130,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.yellow,
            ),
            padding: const EdgeInsets.all(6),
            child: const CircleAvatar(backgroundImage: AssetImage('assets/images/hero.jpg')),
          ),
        ]),
      ),
    );
  }
}

class _AnimalChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AnimalChip({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 78,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(color: const Color(0xFFF1F4F4), borderRadius: BorderRadius.circular(18)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.teal.withValues(alpha: 0.12),
            child: Icon(iconForSpecies(label), color: AppColors.teal),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }
}

class _AdoptionBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _AdoptionBanner({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 8),
            child: Row(children: [
              const Expanded(
                child: Text('Adoção PET\nfacilitada',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, height: 1.1)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: const Text('Adote agora!', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          Image.asset('assets/images/adocao_banner.png', fit: BoxFit.fitWidth, width: double.infinity),
        ]),
      ),
    );
  }
}

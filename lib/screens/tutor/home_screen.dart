import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../core/theme.dart';
import '../../widgets/animal_avatar.dart';
import '../../widgets/category_grid.dart';
import '../../widgets/common.dart';
import 'adoption_screen.dart';
import 'agenda_screen.dart';
import 'animal_screen.dart';
import 'average_cost_screen.dart';
import 'providers_screen.dart';


/// Início do tutor: "+VIDA" e o carrossel +SAÚDE / +CUIDADO / +PRODUTO,
/// que se arrasta para o lado (como nos vídeos do protótipo).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _pages = PageController();
  int _page = 0;

  void _goTo(int i) => _pages.animateToPage(i, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = serviceGroups.length + 1;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Column(children: [
      TopBar(onBell: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgendaScreen()))),
      Expanded(
        child: ColoredBox(
          color: AppColors.homeBg,
          child: Column(children: [
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _VidaPage(onOpenGroup: (i) => _goTo(i + 1)),
                  for (final g in serviceGroups) _GroupPage(group: g),
                ],
              ),
            ),
            // "Adoção PET facilitada" fica sempre fixa no rodapé, em todas as telas do carrossel.
            const _AdoptionBanner(),
            Padding(
              padding: EdgeInsets.fromLTRB(0, 10, 0, 10 + bottom),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < count; i++)
                  GestureDetector(
                    onTap: () => _goTo(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 12 : 9,
                      height: i == _page ? 12 : 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page ? AppColors.teal : Colors.white,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }
}

double _heroCircle(double w) => (w * 0.47).clamp(150.0, 240.0);

/// Página rolável do carrossel: os enfeites amarelos rolam junto com o conteúdo.
class _ScrollPage extends StatelessWidget {
  final List<Widget> children;
  const _ScrollPage({required this.children});
  @override
  Widget build(BuildContext context) {
    final circle = _heroCircle(MediaQuery.sizeOf(context).width);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 8),
      child: Stack(children: [
        Positioned.fill(child: _Blobs(circle: circle)),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ]),
    );
  }
}

// ---------------------------------------------------------------- elementos

class _SearchBox extends StatelessWidget {
  const _SearchBox();
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.teal, width: 2),
          color: Colors.white.withValues(alpha: 0.35),
        ),
        child: const Row(children: [
          Expanded(child: Text('Digite a sua busca', style: TextStyle(color: Color(0xFF7E8789), fontSize: 16))),
          Icon(Icons.search_rounded, color: AppColors.teal, size: 28),
        ]),
      ),
    );
  }
}

/// Enfeites amarelos do protótipo (atrás dos cartões, nunca sobre textos).
class _Blobs extends StatelessWidget {
  final double circle;
  const _Blobs({required this.circle});
  @override
  Widget build(BuildContext context) {
    // 78 = busca; depois vem o herói (circle + 10) e o título (~42).
    final firstRow = 78 + circle + 10 + 42;
    return IgnorePointer(
      child: Stack(clipBehavior: Clip.hardEdge, children: [
        Positioned(left: -18, top: 70, child: Image.asset('assets/ui/blob_yellow.png', width: 64)),
        Positioned(left: 0, top: 86, child: Opacity(opacity: 0.6, child: Image.asset('assets/ui/blob_line.png', width: 52))),
        Positioned(right: -24, top: firstRow + 30, child: Image.asset('assets/ui/blob_yellow.png', width: 50)),
        Positioned(
          left: -26,
          top: firstRow + 170,
          child: Opacity(opacity: 0.8, child: Image.asset('assets/ui/blob_yellow.png', width: 46)),
        ),
      ]),
    );
  }
}

/// "MeuPET +VIDA" e a foto redonda grande.
class _Hero extends StatelessWidget {
  final String word;
  final String image;
  const _Hero({required this.word, required this.image});
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final circle = _heroCircle(w);
    return SizedBox(
      height: circle + 10,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          right: -16,
          top: 0,
          child: Container(
            width: circle,
            height: circle,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.yellow,
              image: DecorationImage(image: AssetImage(image), fit: BoxFit.cover),
            ),
          ),
        ),
        Positioned(
          right: circle - 30,
          top: circle * 0.36,
          child: Transform.rotate(angle: -0.4, child: const Icon(Icons.pets, color: Color(0xFFF5B342), size: 26)),
        ),
        Positioned(
          left: 18,
          top: circle * 0.30,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: 'Meu', style: logoStyle(58, AppColors.teal)),
              TextSpan(text: 'PET', style: logoStyle(58, AppColors.orange)),
            ])),
            Transform.translate(
              offset: const Offset(18, -10),
              child: Text(
                word,
                style: scriptStyle(32, Colors.white).copyWith(
                  shadows: const [Shadow(color: Color(0x55000000), blurRadius: 3, offset: Offset(0, 1))],
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback? onSeeAll;
  const _Title(this.text, {this.color = AppColors.teal, this.onSeeAll});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 10, 6),
      child: Row(children: [
        Expanded(child: Text(text, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w500, color: color))),
        if (onSeeAll != null) SeeAll(onTap: onSeeAll!),
      ]),
    );
  }
}

class _AdoptionBanner extends StatelessWidget {
  const _AdoptionBanner();
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('adocao'),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdoptionScreen())),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 14, 6),
            child: Row(children: [
              const Expanded(
                child: Text('Adoção PET\nfacilitada',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600, height: 1.15)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: const Text('Adote agora!', style: TextStyle(color: Color(0xFF6B7477), fontSize: 15)),
              ),
            ]),
          ),
          Image.asset('assets/images/adocao_banner.png', fit: BoxFit.fitWidth, width: double.infinity),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ páginas

class _VidaPage extends StatelessWidget {
  final ValueChanged<int> onOpenGroup;
  const _VidaPage({required this.onOpenGroup});

  @override
  Widget build(BuildContext context) {
    return _ScrollPage(
        children: [
          const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 12), child: _SearchBox()),
          const _Hero(word: '+VIDA', image: 'assets/images/hero.jpg'),
          _Title('Categoria Animal',
              onSeeAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnimalsScreen()))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              for (final a in animalCategories.take(4))
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: AnimalCard(
                      animal: a,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AnimalScreen(animal: a))),
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          const _Title('Categorias de Serviços'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final i in const [0, 2, 1]) // ordem do protótipo: +Saúde, +Produtos, +Cuidado
                Expanded(
                  child: GestureDetector(
                    key: Key('grupo_${serviceGroups[i].key}'),
                    onTap: () => onOpenGroup(i),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      padding: const EdgeInsets.fromLTRB(6, 10, 6, 12),
                      decoration: BoxDecoration(color: AppColors.homeCard, borderRadius: BorderRadius.circular(16)),
                      child: Column(children: [
                        Text(serviceGroups[i].title,
                            style: const TextStyle(color: AppColors.orange, fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, c) => CircleAvatar(
                            radius: (c.maxWidth / 2 - 4).clamp(30.0, 56.0),
                            backgroundImage: AssetImage(serviceGroups[i].image),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ],
    );
  }
}

class _GroupPage extends StatelessWidget {
  final ServiceGroup group;
  const _GroupPage({required this.group});

  void _open(BuildContext context, ServiceCat cat) {
    final cats = group.providerCategories.map((c) => c.name).toList();
    Widget page;
    switch (cat.kind) {
      case CatKind.provider:
        page = ProvidersListScreen(title: cat.name, categories: [cat.name]);
        break;
      case CatKind.nearby:
        page = ProvidersListScreen(title: 'Perto de mim', categories: cats, nearMe: true);
        break;
      case CatKind.reviews:
        page = ProvidersListScreen(title: 'Avaliações', categories: cats, sortByRating: true);
        break;
      case CatKind.schedule:
        page = ProvidersListScreen(title: 'Agendar', categories: cats, bookOnTap: true);
        break;
      case CatKind.averageCost:
        page = AverageCostScreen(group: group);
        break;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = group.key == 'produtos' ? group.color : AppColors.teal;
    return _ScrollPage(
        children: [
          const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 12), child: _SearchBox()),
          _Hero(word: group.heroTitle, image: group.hero),
          _Title('Categorias', color: titleColor),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: CategoryGrid(group: group, onTap: (c) => _open(context, c)),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: SeeAll(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProvidersListScreen(
                      title: group.title,
                      categories: group.providerCategories.map((c) => c.name).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
    );
  }
}

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
import '../common/ride_screens.dart';


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

/// Tamanhos da página do carrossel. Em telas mais baixas os cartões ficam
/// um pouco menores para tudo caber sem rolar e sem nada ficar escondido
/// atrás do banner de adoção.
class _Fit {
  final bool compact;
  const _Fit(this.compact);
  double get searchTop => compact ? 10 : 16;
  double get searchBottom => compact ? 6 : 12;
  double get search => searchTop + 50 + searchBottom;
  double get titlePad => compact ? 0 : 6;
  double get animal => compact ? 50 : 60;
  double get serviceMax => compact ? 38 : 56;
  double get gridCircle => compact ? 56 : 66;
  double get gap => compact ? 6 : 12;
}

const _heroMin = 128.0;

/// Página do carrossel com tamanho fixo: ocupa exatamente a altura da tela.
/// A foto redonda usa o espaço que sobra; só rola em telas muito baixas.
class _FitPage extends StatelessWidget {
  /// Altura de tudo menos a foto (para a medida [_Fit] e a largura dada).
  final double Function(_Fit f, double width) rest;
  final List<Widget> Function(_Fit f) children;
  const _FitPage({required this.rest, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      var f = const _Fit(false);
      if (c.maxHeight - rest(f, w) < _heroCircle(w) * 0.82 + 10) f = const _Fit(true);
      final need = rest(f, w) + _heroMin;
      final h = c.maxHeight >= need ? c.maxHeight : need;
      final page = SizedBox(
        height: h,
        child: Stack(children: [
          Positioned.fill(child: _Blobs(height: h)),
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children(f)),
        ]),
      );
      return c.maxHeight >= need ? page : SingleChildScrollView(child: page);
    });
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
  final double height;
  const _Blobs({required this.height});
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(clipBehavior: Clip.hardEdge, children: [
        Positioned(left: -18, top: 70, child: Image.asset('assets/ui/blob_yellow.png', width: 64)),
        Positioned(left: 0, top: 86, child: Opacity(opacity: 0.6, child: Image.asset('assets/ui/blob_line.png', width: 52))),
        Positioned(right: -24, top: height * 0.55, child: Image.asset('assets/ui/blob_yellow.png', width: 50)),
        Positioned(
          left: -26,
          top: height * 0.80,
          child: Opacity(opacity: 0.8, child: Image.asset('assets/ui/blob_yellow.png', width: 46)),
        ),
      ]),
    );
  }
}

/// "MeuPET +VIDA" e a foto redonda grande (do tamanho do espaço que sobra).
class _Hero extends StatelessWidget {
  final String word;
  final String image;
  const _Hero({required this.word, required this.image});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final full = _heroCircle(w);
      final circle = (c.maxHeight - 10).clamp(_heroMin - 10, full).toDouble();
      final k = (circle / full).clamp(0.72, 1.0);
      return Align(
        alignment: Alignment.center,
        child: SizedBox(
          height: circle + 10,
          width: w,
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
              child: Transform.rotate(angle: -0.4, child: Icon(Icons.pets, color: const Color(0xFFF5B342), size: 26 * k)),
            ),
            Positioned(
              left: 18,
              top: circle * 0.30,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: 'Meu', style: logoStyle(58 * k, AppColors.teal)),
                  TextSpan(text: 'PET', style: logoStyle(58 * k, AppColors.orange)),
                ])),
                Transform.translate(
                  offset: Offset(18 * k, -10 * k),
                  child: Text(
                    word,
                    style: scriptStyle(32 * k, Colors.white).copyWith(
                      shadows: const [Shadow(color: Color(0x55000000), blurRadius: 3, offset: Offset(0, 1))],
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      );
    });
  }
}

class _Title extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback? onSeeAll;
  final double pad;
  const _Title(this.text, {this.color = AppColors.teal, this.onSeeAll, this.pad = 6});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, pad, 10, pad),
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

  static double _serviceRadius(_Fit f, double w) => (((w - 24) / 3 - 10 - 12) / 2 - 4).clamp(30.0, f.serviceMax);

  /// Tudo menos a foto: busca, 2 títulos, fileira de animais e de serviços.
  static double _rest(_Fit f, double w) =>
      f.search +
      (f.titlePad * 2 + 48) +
      (f.animal + 24 + 8 + 24) +
      f.gap +
      (f.titlePad * 2 + 34) +
      (10 + 24 + 8 + _serviceRadius(f, w) * 2 + 12) +
      8;

  @override
  Widget build(BuildContext context) {
    return _FitPage(
      rest: _rest,
      children: (f) => [
        Padding(padding: EdgeInsets.fromLTRB(16, f.searchTop, 16, f.searchBottom), child: const _SearchBox()),
        const Expanded(child: _Hero(word: '+VIDA', image: 'assets/images/hero.jpg')),
        _Title('Categoria Animal',
            pad: f.titlePad, onSeeAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnimalsScreen()))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            for (final a in animalCategories.take(4))
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimalCard(
                    animal: a,
                    avatar: f.animal,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AnimalScreen(animal: a))),
                  ),
                ),
              ),
          ]),
        ),
        SizedBox(height: f.gap),
        _Title('Categorias de Serviços', pad: f.titlePad),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
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
                          maxLines: 1,
                          style: const TextStyle(color: AppColors.orange, fontSize: 16, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, c) => CircleAvatar(
                          radius: (c.maxWidth / 2 - 4).clamp(30.0, f.serviceMax),
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
        // TaxiPet funciona como Uber: abre o mapa direto.
        page = cat.name == 'TaxiPet'
            ? const RideRequestScreen()
            : ProvidersListScreen(title: cat.name, categories: [cat.name]);
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
    final rows = (group.items.length / 4).ceil();
    return _FitPage(
      rest: (f, w) => f.search + (f.titlePad * 2 + 34) + rows * (f.gridCircle + 54) + 48 + 4,
      children: (f) => [
        Padding(padding: EdgeInsets.fromLTRB(16, f.searchTop, 16, f.searchBottom), child: const _SearchBox()),
        Expanded(child: _Hero(word: group.heroTitle, image: group.hero)),
        _Title('Categorias', color: titleColor, pad: f.titlePad),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: CategoryGrid(group: group, circle: f.gridCircle, onTap: (c) => _open(context, c)),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 10, bottom: 4),
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

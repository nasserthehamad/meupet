import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/category_grid.dart';
import '../../widgets/common.dart';
import 'providers_screen.dart';

/// Custo médio de cada serviço do grupo, a partir dos preços "a partir de"
/// que os prestadores informam no perfil.
class AverageCostScreen extends StatefulWidget {
  final ServiceGroup group;
  const AverageCostScreen({super.key, required this.group});
  @override
  State<AverageCostScreen> createState() => _AverageCostScreenState();
}

class _AverageCostScreenState extends State<AverageCostScreen> {
  late bool _myCity = (Session.current.value?.city ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final city = (Session.current.value?.city ?? '').trim();
    final cats = g.providerCategories;
    return Scaffold(
      body: StreamBuilder<List<AppUser>>(
        stream: Db.providersByAny(cats.map((c) => c.name).toList()),
        builder: (context, snap) {
          var provs = snap.data ?? [];
          if (_myCity && city.isNotEmpty) {
            provs = provs.where((p) => p.city.trim().toLowerCase() == city.toLowerCase()).toList();
          }
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              PetHeader(showBack: true, title: 'Custo médio', subtitle: g.title, photo: Session.current.value?.photo),
              SnakeBand(
                index: 1,
                roundBottom: false,
                padding: const EdgeInsets.only(top: 12, bottom: 50),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (city.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                      child: Wrap(spacing: 8, children: [
                        ChoiceChip(
                          label: Text('Em $city'),
                          selected: _myCity,
                          onSelected: (_) => setState(() => _myCity = true),
                        ),
                        ChoiceChip(
                          label: const Text('Todas as cidades'),
                          selected: !_myCity,
                          onSelected: (_) => setState(() => _myCity = false),
                        ),
                      ]),
                    ),
                  if (!snap.hasData)
                    const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                  else
                    for (final c in cats) _CostRow(cat: c, color: g.color, providers: provs),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(22, 12, 22, 0),
                    child: Text(
                      'Valores "a partir de" informados pelos próprios prestadores. O preço final pode variar com o porte do pet e o serviço.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                    ),
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

class _CostRow extends StatelessWidget {
  final ServiceCat cat;
  final Color color;
  final List<AppUser> providers;
  const _CostRow({required this.cat, required this.color, required this.providers});

  @override
  Widget build(BuildContext context) {
    final prices = [
      for (final p in providers)
        if (p.categories.contains(cat.name) && p.prices[cat.name] != null) p.prices[cat.name]!,
    ];
    final avg = prices.isEmpty ? null : prices.reduce((a, b) => a + b) / prices.length;
    prices.sort();
    return WhiteBlock(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProvidersListScreen(title: cat.name, categories: [cat.name])),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(children: [
            CategoryCircle(cat: cat, color: color, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (avg == null)
                  const Text('Sem preços informados ainda', style: TextStyle(fontSize: 12, color: AppColors.muted))
                else
                  Text(
                    prices.length == 1
                        ? '1 local'
                        : 'de ${fmtMoney(prices.first)} a ${fmtMoney(prices.last)} · ${prices.length} locais',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
              ]),
            ),
            if (avg != null)
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(fmtMoney(avg.roundToDouble()), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
                const Text('em média', style: TextStyle(fontSize: 10.5, color: AppColors.muted)),
              ]),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ]),
        ),
      ),
    );
  }
}

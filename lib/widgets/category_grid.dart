import 'package:flutter/material.dart';

import '../core/catalog.dart';
import '../core/theme.dart';

/// Círculo colorido com o ícone desenhado do protótipo.
class CategoryCircle extends StatelessWidget {
  final ServiceCat cat;
  final Color color;
  final double size;
  const CategoryCircle({super.key, required this.cat, required this.color, this.size = 66});

  @override
  Widget build(BuildContext context) {
    final asset = cat.asset;
    // Alguns ícones (higiene, brinquedos, suplementos) já vêm com cor própria.
    final colored = asset != null && (asset.contains('higiene') || asset.contains('brinquedos') || asset.contains('suplementos'));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 3))],
      ),
      padding: EdgeInsets.all(colored ? size * 0.06 : size * 0.17),
      child: asset != null
          ? Image.asset(asset, fit: BoxFit.contain)
          : Icon(cat.icon, color: Colors.white, size: size * 0.55),
    );
  }
}

/// Grade 4 colunas do protótipo (+SAÚDE / +CUIDADO / +PRODUTO).
class CategoryGrid extends StatelessWidget {
  final ServiceGroup group;
  final void Function(ServiceCat cat) onTap;
  final double circle;
  const CategoryGrid({super.key, required this.group, required this.onTap, this.circle = 66});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth / 4;
      return Wrap(
        children: [
          for (final cat in group.items)
            SizedBox(
              width: w,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onTap(cat),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(children: [
                    CategoryCircle(cat: cat, color: group.color, size: circle),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 32,
                      child: Text(
                        cat.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7477), height: 1.15),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
        ],
      );
    });
  }
}

/// "Ver tudo" pequeno, alinhado à direita (com os pontinhos do protótipo).
class SeeAll extends StatelessWidget {
  final VoidCallback onTap;
  const SeeAll({super.key, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(foregroundColor: AppColors.muted, padding: const EdgeInsets.symmetric(horizontal: 8)),
      child: const Text('Ver tudo', style: TextStyle(fontSize: 13)),
    );
  }
}

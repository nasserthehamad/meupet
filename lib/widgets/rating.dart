import 'package:flutter/material.dart';

import '../core/db.dart';
import '../core/models.dart';
import '../core/theme.dart';
import 'common.dart';

const kStar = Color(0xFFF5B342);

/// Cinco estrelas (aceita meia estrela).
class Stars extends StatelessWidget {
  final double value;
  final double size;
  const Stars(this.value, {super.key, this.size = 16});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 1; i <= 5; i++)
        Icon(
          value >= i
              ? Icons.star_rounded
              : value >= i - 0.5
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded,
          color: kStar,
          size: size,
        ),
    ]);
  }
}

/// "★★★★☆ 4,5 (12)" ou "Sem avaliações".
class RatingLine extends StatelessWidget {
  final RatingInfo? r;
  final double size;
  const RatingLine(this.r, {super.key, this.size = 14});
  @override
  Widget build(BuildContext context) {
    if (r == null || r!.count == 0) {
      return Text('Sem avaliações ainda', style: TextStyle(fontSize: size - 2.5, color: AppColors.muted));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Stars(r!.avg, size: size),
      const SizedBox(width: 4),
      Text('${r!.label} (${r!.count})',
          style: TextStyle(fontSize: size - 2, fontWeight: FontWeight.w600, color: const Color(0xFF5B6366))),
    ]);
  }
}

/// Fornece o mapa de notas (prestadorId → média) para listas.
class WithRatings extends StatelessWidget {
  final Widget Function(BuildContext context, Map<String, RatingInfo> ratings) builder;
  const WithRatings({super.key, required this.builder});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, RatingInfo>>(
      stream: Db.ratings(),
      builder: (context, snap) => builder(context, snap.data ?? const {}),
    );
  }
}

/// Avaliar um prestador (só quem já agendou com ele).
Future<void> showReviewSheet(BuildContext context, AppUser provider, {Review? mine}) async {
  if (!await Db.canReview(provider.id)) {
    if (context.mounted) {
      showSnack(context, 'Você poderá avaliar ${provider.displayName} depois de agendar um atendimento.', error: true);
    }
    return;
  }
  if (!context.mounted) return;
  var stars = mine?.stars ?? 0;
  final text = TextEditingController(text: mine?.text);
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Avaliar ${provider.displayName}', style: sectionStyle()),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                key: Key('estrela_$i'),
                iconSize: 40,
                onPressed: () => setS(() => stars = i),
                icon: Icon(i <= stars ? Icons.star_rounded : Icons.star_outline_rounded, color: kStar),
              ),
          ]),
          Center(
            child: Text(
              const ['Toque nas estrelas', 'Ruim', 'Regular', 'Bom', 'Muito bom', 'Excelente!'][stars],
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: text,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: inputDeco('Conte como foi (opcional)'),
          ),
          const SizedBox(height: 16),
          OrangeButton(
            label: mine == null ? 'Enviar avaliação' : 'Atualizar avaliação',
            icon: Icons.send_rounded,
            onPressed: () async {
              if (stars == 0) return;
              await Db.saveReview(provider.id, stars, text.text);
              if (c.mounted) Navigator.pop(c);
              if (context.mounted) showSnack(context, 'Obrigado pela avaliação!');
            },
          ),
        ]),
      ),
    ),
  );
}

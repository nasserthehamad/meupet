import 'package:flutter/material.dart';

import '../core/catalog.dart';
import '../core/theme.dart';

/// Foto redonda do animal (ou desenho, quando não há foto).
class AnimalAvatar extends StatelessWidget {
  final AnimalCat animal;
  final double size;
  const AnimalAvatar({super.key, required this.animal, this.size = 60});

  @override
  Widget build(BuildContext context) {
    final img = animal.$3;
    if (img != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(image: AssetImage(img), fit: BoxFit.cover),
        ),
      );
    }
    if (animal.$2 == 'Peixe') {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _FishPainter()),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFBE3C8)),
      child: Icon(Icons.pets, color: AppColors.orange, size: size * 0.5),
    );
  }
}

class _FishPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final r = s.width / 2;
    final c = Offset(r, r);
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFBFE6EA));
    // bolhas
    final bubble = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * 0.025;
    canvas.drawCircle(Offset(s.width * 0.72, s.height * 0.26), s.width * 0.045, bubble);
    canvas.drawCircle(Offset(s.width * 0.80, s.height * 0.16), s.width * 0.03, bubble);
    final body = Paint()..color = AppColors.orange;
    // rabo
    final tail = Path()
      ..moveTo(s.width * 0.36, s.height * 0.55)
      ..lineTo(s.width * 0.16, s.height * 0.40)
      ..lineTo(s.width * 0.18, s.height * 0.70)
      ..close();
    canvas.drawPath(tail, body);
    // corpo
    canvas.drawOval(
      Rect.fromCenter(center: Offset(s.width * 0.54, s.height * 0.55), width: s.width * 0.48, height: s.height * 0.32),
      body,
    );
    // barbatana
    final fin = Path()
      ..moveTo(s.width * 0.46, s.height * 0.41)
      ..quadraticBezierTo(s.width * 0.55, s.height * 0.28, s.width * 0.64, s.height * 0.41)
      ..close();
    canvas.drawPath(fin, Paint()..color = const Color(0xFFD9741C));
    // olho
    canvas.drawCircle(Offset(s.width * 0.67, s.height * 0.52), s.width * 0.045, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(s.width * 0.68, s.height * 0.52), s.width * 0.022, Paint()..color = const Color(0xFF333333));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Cartão cinza com a foto e o nome (Categoria Animal).
class AnimalCard extends StatelessWidget {
  final AnimalCat animal;
  final VoidCallback onTap;
  final double avatar;
  const AnimalCard({super.key, required this.animal, required this.onTap, this.avatar = 60});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFEEEEEE),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('animal_${animal.$2}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimalAvatar(animal: animal, size: avatar),
            const SizedBox(height: 8),
            Text(animal.$1,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, color: Color(0xFF6B7477))),
          ]),
        ),
      ),
    );
  }
}

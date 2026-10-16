import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/db.dart';
import '../core/models.dart';
import '../core/theme.dart';

/// Logo "MEU PET+" em texto (laranja/azul como no protótipo).
class LogoText extends StatelessWidget {
  final double size;
  const LogoText({super.key, this.size = 22});
  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: 'MEU ', style: logoStyle(size, AppColors.teal)),
        TextSpan(text: 'PET+', style: logoStyle(size, AppColors.orange)),
      ]),
    );
  }
}

const double kBandRadius = 46;

/// Cabeçalho cinza do protótipo: trilha de patinhas, logo, título manuscrito
/// e avatar. O canto inferior esquerdo é arredondado e "encaixa" na primeira
/// faixa branca (efeito em S).
class PetHeader extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final String? photo;
  final String? avatarLabel;
  final IconData fallbackIcon;
  final bool showBack;
  final List<Widget> actions;
  final Widget? bottom;

  const PetHeader({
    super.key,
    this.title,
    this.subtitle,
    this.photo,
    this.avatarLabel,
    this.fallbackIcon = Icons.person_rounded,
    this.showBack = false,
    this.actions = const [],
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return ColoredBox(
      color: Colors.white,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(kBandRadius)),
        ),
        padding: EdgeInsets.fromLTRB(14, top + 10, 14, bottom == null ? 26 : 18),
        child: Stack(
          children: [
            const Positioned.fill(child: IgnorePointer(child: PawTrail())),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (showBack)
                      Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).maybePop(),
                          child: const Padding(
                            padding: EdgeInsets.all(9),
                            child: Icon(Icons.arrow_back_rounded, color: AppColors.muted),
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const LogoText(size: 28),
                          if (title != null)
                            Text(
                              title!,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: scriptStyle(23, const Color(0xFF3E4446)),
                            ),
                          if (subtitle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(subtitle!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                    ...actions,
                    Stack(alignment: Alignment.bottomCenter, children: [
                      PhotoAvatar(photo: photo, size: 82, fallbackIcon: fallbackIcon, border: Colors.white),
                      if (avatarLabel != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(avatarLabel!,
                              style: scriptStyle(17, AppColors.teal).copyWith(
                                shadows: const [Shadow(color: Colors.white, blurRadius: 6)],
                              )),
                        ),
                    ]),
                  ],
                ),
                if (bottom != null) ...[const SizedBox(height: 12), bottom!],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Trilha de patinhas brancas descendo na diagonal (como no protótipo).
class PawTrail extends StatelessWidget {
  final Color color;
  const PawTrail({super.key, this.color = Colors.white});
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _PawTrailPainter(color));
}

class _PawTrailPainter extends CustomPainter {
  final Color color;
  _PawTrailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const icon = Icons.pets;
    final start = Offset(size.width * 0.24, 4);
    final end = Offset(size.width * 0.42, size.height - 4);
    const steps = 8;
    final dir = end - start;
    final len = dir.distance;
    final n = Offset(-dir.dy / len, dir.dx / len); // perpendicular
    final angle = dir.direction - 1.5708; // patinhas "andando" ao longo da trilha
    for (var i = 0; i < steps; i++) {
      final t = (i + 0.5) / steps;
      final side = i.isEven ? 1.0 : -1.0;
      final p = start + dir * t + n * (7 * side);
      final tp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: 15,
            color: color.withValues(alpha: 0.95),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(angle + 3.1416 + (side * 0.25));
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PawTrailPainter old) => old.color != color;
}

/// Cor da faixa atual (para os cartões se adaptarem).
class BandScope extends InheritedWidget {
  final Color color;
  const BandScope({super.key, required this.color, required super.child});
  static Color? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<BandScope>()?.color;
  @override
  bool updateShouldNotify(BandScope old) => old.color != color;
}

/// Faixa do efeito em S do protótipo. Índices ímpares = branca, arredondada
/// à direita; pares = cinza, arredondada à esquerda. O cabeçalho é o índice 0.
class SnakeBand extends StatelessWidget {
  final int index;
  final Widget child;
  final EdgeInsets padding;
  final bool roundTop;
  final bool roundBottom;
  const SnakeBand({
    super.key,
    required this.index,
    required this.child,
    this.padding = const EdgeInsets.only(top: 6, bottom: 22),
    this.roundTop = true,
    this.roundBottom = true,
  });

  bool get isWhite => index.isOdd;

  @override
  Widget build(BuildContext context) {
    const r = Radius.circular(kBandRadius);
    final color = isWhite ? Colors.white : AppColors.bg;
    final radius = isWhite
        ? BorderRadius.only(topRight: roundTop ? r : Radius.zero, bottomRight: roundBottom ? r : Radius.zero)
        : BorderRadius.only(topLeft: roundTop ? r : Radius.zero, bottomLeft: roundBottom ? r : Radius.zero);
    return ColoredBox(
      color: isWhite ? AppColors.bg : Colors.white,
      child: Container(
        decoration: BoxDecoration(color: color, borderRadius: radius),
        padding: padding,
        child: BandScope(color: color, child: child),
      ),
    );
  }
}

class PhotoAvatar extends StatelessWidget {
  final String? photo;
  final double size;
  final IconData fallbackIcon;
  final Color border;
  const PhotoAvatar({
    super.key,
    this.photo,
    this.size = 48,
    this.fallbackIcon = Icons.pets_rounded,
    this.border = AppColors.teal,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = decodePhoto(photo);
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(shape: BoxShape.circle, color: border),
      child: ClipOval(
        child: ColoredBox(
          color: const Color(0xFFE3F2F4),
          child: SizedBox.expand(
            child: bytes != null
                ? Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
                : Icon(fallbackIcon, color: AppColors.teal, size: size * 0.5),
          ),
        ),
      ),
    );
  }
}

/// Avatar clicável para escolher foto (galeria ou câmera).
class PhotoPickerAvatar extends StatelessWidget {
  final String? photo;
  final double size;
  final ValueChanged<String> onPicked;
  final IconData fallbackIcon;
  const PhotoPickerAvatar({
    super.key,
    required this.photo,
    required this.onPicked,
    this.size = 110,
    this.fallbackIcon = Icons.pets_rounded,
  });

  Future<void> _choose(BuildContext context) async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: AppColors.teal),
            title: const Text('Escolher da galeria'),
            onTap: () => Navigator.pop(c, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded, color: AppColors.teal),
            title: const Text('Tirar foto'),
            onTap: () => Navigator.pop(c, ImageSource.camera),
          ),
        ]),
      ),
    );
    if (src == null) return;
    final b64 = await pickPhotoBase64(source: src);
    if (b64 != null) onPicked(b64);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _choose(context),
      child: Stack(
        children: [
          PhotoAvatar(photo: photo, size: size, fallbackIcon: fallbackIcon),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 8),
      child: Row(children: [
        Expanded(child: Text(text, style: sectionStyle())),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// Cartão arredondado. Fica branco sobre faixa cinza e cinza-claro sobre faixa branca.
class WhiteBlock extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  const WhiteBlock({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  });
  @override
  Widget build(BuildContext context) {
    final onWhite = BandScope.of(context) == Colors.white;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: onWhite
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Material(
        color: onWhite ? const Color(0xFFF1F4F4) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class OrangeButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData icon;
  const OrangeButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon = Icons.arrow_forward_rounded,
  });
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.orange,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(width: 10),
                Icon(icon),
              ]),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.text, this.action});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      child: Column(children: [
        Icon(icon, size: 48, color: AppColors.muted.withValues(alpha: 0.5)),
        const SizedBox(height: 10),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
        if (action != null) ...[const SizedBox(height: 12), action!],
      ]),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    Color c;
    switch (status) {
      case 'confirmado':
        c = AppColors.green;
        break;
      case 'recusado':
      case 'cancelado':
        c = AppColors.red;
        break;
      case 'concluido':
        c = AppColors.teal;
        break;
      default:
        c = AppColors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(appointmentStatusLabel[status] ?? status,
          style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

/// Selo de data no estilo "calendário vermelho" do protótipo.
class DateBadge extends StatelessWidget {
  final DateTime? date;
  const DateBadge(this.date, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(height: 9, color: AppColors.red),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(fmtShort(date), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

class RoundAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const RoundAction({super.key, required this.icon, required this.label, required this.color, this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(radius: 17, backgroundColor: color, child: Icon(icon, color: Colors.white, size: 18)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
        ]),
      ),
    );
  }
}

void showSnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? AppColors.red : AppColors.tealDark,
    behavior: SnackBarBehavior.floating,
  ));
}

Future<bool> confirm(BuildContext context, String title, String msg, {String ok = 'Confirmar'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Voltar')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
      ],
    ),
  );
  return r ?? false;
}

Future<DateTime?> pickDate(BuildContext context, {DateTime? initial, DateTime? first, DateTime? last}) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initial ?? now,
    firstDate: first ?? DateTime(now.year - 30),
    lastDate: last ?? DateTime(now.year + 5),
  );
}

Future<DateTime?> pickDateTime(BuildContext context, {DateTime? initial}) async {
  final now = DateTime.now();
  final d = await pickDate(context, initial: initial ?? now, first: DateTime(now.year, now.month, now.day));
  if (d == null || !context.mounted) return null;
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial ?? DateTime(now.year, now.month, now.day, 9)),
  );
  if (t == null) return null;
  return DateTime(d.year, d.month, d.day, t.hour, t.minute);
}

/// Seletor simples por chips (substitui dropdowns).
class ChipSelector extends StatelessWidget {
  final List<String> options;
  final String? value;
  final ValueChanged<String> onChanged;
  const ChipSelector({super.key, required this.options, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(o),
            selected: o == value,
            selectedColor: AppColors.teal,
            labelStyle: TextStyle(color: o == value ? Colors.white : AppColors.text),
            onSelected: (_) => onChanged(o),
          ),
      ],
    );
  }
}

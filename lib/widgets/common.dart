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
    // Nunca quebra em duas linhas: se faltar espaço, diminui.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: 'MEU ', style: logoStyle(size, AppColors.teal)),
          TextSpan(text: 'PET+', style: logoStyle(size, AppColors.orange)),
        ]),
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}


/// Botão ☰ (círculo com contorno) que abre o menu lateral.
class MenuButton extends StatelessWidget {
  final Color color;
  const MenuButton({super.key, this.color = AppColors.teal});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('menu'),
      customBorder: const CircleBorder(),
      onTap: () => Scaffold.maybeOf(context)?.openDrawer(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2.2)),
        child: Icon(Icons.menu_rounded, color: color, size: 26),
      ),
    );
  }
}

/// Sino de avisos (círculo preenchido com bolinha laranja).
/// Sino do topo. A bolinha laranja só aparece quando há novidade: mensagem
/// não lida, atendimento nas próximas 24h (tutor) ou pedido esperando
/// resposta (prestador).
class BellButton extends StatelessWidget {
  final Color color;
  final VoidCallback? onTap;
  final bool? dot; // null = automático
  const BellButton({super.key, this.color = AppColors.teal, this.onTap, this.dot});

  @override
  Widget build(BuildContext context) {
    if (dot != null) return _bell(dot!);
    final uid = Session.current.value?.id ?? '';
    if (uid.isEmpty) return _bell(false);
    final prov = Session.current.value?.isProvider == true;
    return StreamBuilder<bool>(
      stream: Db.hasUnreadChats(uid),
      builder: (context, chats) => StreamBuilder<List<Appointment>>(
        stream: prov ? Db.providerAppointments(uid) : Db.tutorAppointments(uid),
        builder: (context, ap) {
          final now = DateTime.now();
          final soon = (ap.data ?? const <Appointment>[]).any((a) {
            if (prov) return a.status == 'pendente';
            final d = a.dateTime;
            return (a.status == 'confirmado' || a.status == 'pendente') &&
                d != null &&
                d.isAfter(now) &&
                d.isBefore(now.add(const Duration(hours: 24)));
          });
          return _bell(chats.data == true || soon);
        },
      ),
    );
  }

  Widget _bell(bool dot) {
    return InkWell(
      key: const Key('bell'),
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: Stack(alignment: Alignment.center, children: [
          const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 26),
          if (dot)
            const Positioned(
              top: 10,
              right: 12,
              child: CircleAvatar(radius: 4, backgroundColor: AppColors.orange),
            ),
        ]),
      ),
    );
  }
}

class _BackCircle extends StatelessWidget {
  final Color background;
  const _BackCircle({required this.background});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        key: const Key('back'),
        customBorder: const CircleBorder(),
        onTap: () => Navigator.of(context).maybePop(),
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(Icons.arrow_back_rounded, color: AppColors.muted),
        ),
      ),
    );
  }
}

/// Barra branca do topo da Início/Adoção: ☰, patinhas, logo e sino.
class TopBar extends StatelessWidget {
  final Color color;
  final VoidCallback? onBell;
  final bool showBack;
  const TopBar({super.key, this.color = AppColors.teal, this.onBell, this.showBack = false});
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(14, top + 8, 14, 10),
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          left: 56,
          top: 0,
          bottom: 0,
          width: 32,
          child: IgnorePointer(child: PawTrail(color: AppColors.muted.withValues(alpha: 0.6), small: true)),
        ),
        Row(children: [
          if (showBack) _BackCircle(background: AppColors.surface2) else MenuButton(color: color),
          const Expanded(child: Center(child: LogoText(size: 30))),
          BellButton(color: color, onTap: onBell),
        ]),
      ]),
    );
  }
}

const double kBandRadius = 46;

/// Cabeçalho do protótipo com trilha de patinhas, logo, título manuscrito e
/// avatar. Cinza (padrão) com canto inferior esquerdo arredondado, ou branco
/// ([white]) com o canto inferior direito arredondado — sempre "encaixando" na
/// faixa seguinte (efeito em S).
class PetHeader extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final String? photo;
  final String? avatarLabel;
  final IconData fallbackIcon;
  final bool showBack;
  final bool showMenu;
  final bool white;
  final List<Widget> actions;
  final Widget? bottom;
  final Widget? avatarOverride;

  const PetHeader({
    super.key,
    this.title,
    this.subtitle,
    this.photo,
    this.avatarLabel,
    this.fallbackIcon = Icons.person_rounded,
    this.showBack = false,
    this.showMenu = false,
    this.white = false,
    this.actions = const [],
    this.bottom,
    this.avatarOverride,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final color = white ? AppColors.surface : AppColors.bg;
    final outer = white ? AppColors.bg : AppColors.surface;
    const r = Radius.circular(kBandRadius);
    return ColoredBox(
      color: outer,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: white ? const BorderRadius.only(bottomRight: r) : const BorderRadius.only(bottomLeft: r),
        ),
        padding: EdgeInsets.fromLTRB(14, top + 10, 14, bottom == null ? 24 : 18),
        child: Stack(
          children: [
            Positioned(
              left: 48,
              top: 0,
              bottom: 0,
              width: 40,
              child: IgnorePointer(
                child: PawTrail(color: white ? AppColors.muted.withValues(alpha: 0.45) : AppColors.surface),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      if (showMenu) const MenuButton(),
                      if (showMenu && showBack) const SizedBox(height: 8),
                      if (showBack) _BackCircle(background: white ? AppColors.surface2 : AppColors.surface),
                      if (!showMenu && !showBack) const SizedBox(width: 6),
                    ]),
                    const SizedBox(width: 38),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const LogoText(size: 30),
                          if (title != null)
                            Text(
                              title!,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: scriptStyle(24, AppColors.textStrong),
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
                    avatarOverride ??
                        Stack(alignment: Alignment.bottomCenter, children: [
                          PhotoAvatar(
                            photo: photo,
                            size: 92,
                            fallbackIcon: fallbackIcon,
                            border: white ? AppColors.bg : AppColors.surface,
                          ),
                          if (avatarLabel != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(avatarLabel!,
                                  style: scriptStyle(18, AppColors.teal).copyWith(
                                    shadows: [Shadow(color: AppColors.surface, blurRadius: 6)],
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
  final bool small;
  const PawTrail({super.key, this.color = Colors.white, this.small = false});
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _PawTrailPainter(color, small));
}

/// Desenha a trilha dentro da própria caixa (estreita, ao lado do logo):
/// patinhas pequenas, do mesmo tamanho, num "S" suave de cima para baixo.
class _PawTrailPainter extends CustomPainter {
  final Color color;
  final bool small;
  _PawTrailPainter(this.color, this.small);

  @override
  void paint(Canvas canvas, Size size) {
    const icon = Icons.pets;
    final paw = small ? 11.0 : 13.0;
    final steps = small ? 4 : 7;
    // S suave: começa à direita no topo, vai para a esquerda e volta para a direita.
    final p0 = Offset(size.width * 0.80, paw * 0.6);
    final p1 = Offset(size.width * 0.05, size.height * 0.45);
    final p2 = Offset(size.width * 0.85, size.height - paw * 0.6);
    Offset at(double t) => p0 * ((1 - t) * (1 - t)) + p1 * (2 * (1 - t) * t) + p2 * (t * t);
    Offset tangent(double t) => (p1 - p0) * (2 * (1 - t)) + (p2 - p1) * (2 * t);
    final shadow = color.computeLuminance() > 0.6;
    for (var i = 0; i < steps; i++) {
      final t = i / (steps - 1);
      final side = i.isEven ? 1.0 : -1.0;
      final tg = tangent(t);
      final len = tg.distance == 0 ? 1.0 : tg.distance;
      final n = Offset(-tg.dy / len, tg.dx / len);
      final p = at(t) + n * (paw * 0.32 * side);
      TextPainter painter(Color c) => TextPainter(
            text: TextSpan(
              text: String.fromCharCode(icon.codePoint),
              style: TextStyle(fontFamily: icon.fontFamily, package: icon.fontPackage, fontSize: paw, color: c),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(tg.direction + 1.5708);
      if (shadow) {
        final sp = painter(const Color(0x22000000));
        sp.paint(canvas, Offset(-sp.width / 2 + 0.6, -sp.height / 2 + 0.8));
      }
      final tp = painter(color);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PawTrailPainter old) => old.color != color || old.small != small;
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
    final color = isWhite ? AppColors.surface : AppColors.bg;
    final radius = isWhite
        ? BorderRadius.only(topRight: roundTop ? r : Radius.zero, bottomRight: roundBottom ? r : Radius.zero)
        : BorderRadius.only(topLeft: roundTop ? r : Radius.zero, bottomLeft: roundBottom ? r : Radius.zero);
    return ColoredBox(
      color: isWhite ? AppColors.bg : AppColors.surface,
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
          color: AppColors.dark ? const Color(0xFF1F3A3E) : const Color(0xFFE3F2F4),
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
    final onWhite = BandScope.of(context) == AppColors.surface;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: onWhite
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Material(
        color: onWhite ? AppColors.surface2 : AppColors.surface,
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
  final bool big;
  const DateBadge(this.date, {super.key, this.big = false});
  @override
  Widget build(BuildContext context) {
    final w = big ? 56.0 : 46.0;
    return Container(
      width: w,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE6E6E6)),
        boxShadow: big ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))] : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          height: big ? 12 : 9,
          color: AppColors.red,
          child: big
              ? Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  for (var i = 0; i < 3; i++) Container(width: 4, height: 6, color: Colors.white.withValues(alpha: 0.85)),
                ])
              : null,
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: big ? 7 : 4),
          child: Text(fmtShort(date),
              style: TextStyle(fontSize: big ? 15 : 12, fontWeight: FontWeight.w600, color: AppColors.text2)),
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

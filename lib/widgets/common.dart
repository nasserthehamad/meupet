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

/// Cabeçalho branco curvo com o logo, título manuscrito e avatar.
class PetHeader extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final String? photo;
  final IconData fallbackIcon;
  final bool showBack;
  final List<Widget> actions;
  final Widget? bottom;

  const PetHeader({
    super.key,
    this.title,
    this.subtitle,
    this.photo,
    this.fallbackIcon = Icons.person_rounded,
    this.showBack = false,
    this.actions = const [],
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return ClipPath(
      clipper: _CurveClipper(),
      child: Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(12, top + 8, 16, 34),
        child: Stack(
          children: [
            const Positioned(left: 40, top: 30, child: _Paws()),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (showBack)
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.teal),
                      )
                    else
                      const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const LogoText(size: 24),
                          if (title != null)
                            Text(
                              title!,
                              textAlign: TextAlign.center,
                              style: logoStyle(22, AppColors.text).copyWith(fontWeight: FontWeight.w600),
                            ),
                          if (subtitle != null)
                            Text(subtitle!,
                                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    ...actions,
                    PhotoAvatar(photo: photo, size: 56, fallbackIcon: fallbackIcon),
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

class _Paws extends StatelessWidget {
  const _Paws();
  @override
  Widget build(BuildContext context) {
    final c = AppColors.muted.withValues(alpha: 0.25);
    return Column(
      children: [
        Icon(Icons.pets, size: 12, color: c),
        Padding(padding: const EdgeInsets.only(left: 18), child: Icon(Icons.pets, size: 12, color: c)),
        Icon(Icons.pets, size: 12, color: c),
      ],
    );
  }
}

class _CurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    final p = Path()..lineTo(0, s.height - 10);
    p.quadraticBezierTo(s.width * 0.15, s.height - 34, s.width * 0.5, s.height - 22);
    p.quadraticBezierTo(s.width * 0.85, s.height - 10, s.width, s.height - 30);
    p.lineTo(s.width, 0);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
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

/// Bloco branco arredondado (as "ondas" cinza/brancas do protótipo).
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
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Material(
        color: Colors.white,
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

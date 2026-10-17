import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/catalog.dart';
import '../core/db.dart';
import '../core/theme.dart';
import '../core/theme_controller.dart';
import '../screens/common/chat_list_screen.dart';
import '../screens/common/emergency_screen.dart';
import '../screens/common/profile_screen.dart';
import '../screens/provider/patients_screen.dart';
import '../screens/common/store_screens.dart';
import '../screens/tutor/activity_screen.dart';
import '../screens/tutor/agenda_screen.dart';
import '../screens/tutor/my_pets_screen.dart';
import '../screens/tutor/pet_form_screen.dart';
import 'common.dart';

const double _strip = 30;

/// Menu lateral do protótipo (tutor e prestador).
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  /// Fecha o menu e devolve um contexto que continua válido (o do Navigator).
  BuildContext _close(BuildContext context) {
    final nav = Navigator.of(context);
    nav.pop();
    return nav.context;
  }

  void _go(BuildContext context, Widget page) {
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _password(BuildContext context) async {
    final email = Session.user.email;
    context = _close(context);
    final ok = await confirm(context, 'Trocar senha', 'Vamos enviar um link para $email criar uma nova senha.', ok: 'Enviar link');
    if (!ok) return;
    try {
      await Db.resetPassword(email);
      if (context.mounted) showSnack(context, 'Link enviado para $email.');
    } catch (e) {
      if (context.mounted) showSnack(context, authErrorPt(e), error: true);
    }
  }

  Future<void> _language(BuildContext context) async {
    context = _close(context);
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Idioma'),
        content: const Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(Icons.radio_button_checked_rounded, color: AppColors.teal),
            title: Text('Português (Brasil)'),
          ),
          Text('Outros idiomas chegam em breve.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _theme(BuildContext context) async {
    context = _close(context);
    final picked = await showDialog<ThemeMode>(
      context: context,
      builder: (c) {
        final cur = ThemeController.mode.value;
        Widget opt(ThemeMode m, IconData icon, String sub) => ListTile(
              key: Key('tema_${m.name}'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(icon, color: AppColors.teal),
              title: Text(ThemeController.label(m)),
              subtitle: Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              trailing: Icon(
                m == cur ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: m == cur ? AppColors.teal : AppColors.muted,
              ),
              onTap: () => Navigator.pop(c, m),
            );
        return AlertDialog(
          title: const Text('Tema | Modo'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            opt(ThemeMode.light, Icons.light_mode_rounded, 'Fundo claro'),
            opt(ThemeMode.dark, Icons.dark_mode_rounded, 'Fundo escuro, descansa a vista'),
            opt(ThemeMode.system, Icons.brightness_auto_rounded, 'Segue o modo do seu celular'),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar'))],
        );
      },
    );
    if (picked != null) await ThemeController.set(picked);
  }

  Future<void> _rate(BuildContext context) async {
    context = _close(context);
    int stars = 5;
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('Avaliar o app'),
          content: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                onPressed: () => setS(() => stars = i),
                icon: Icon(i <= stars ? Icons.star_rounded : Icons.star_border_rounded, color: AppColors.yellow, size: 34),
              ),
          ]),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(c);
                showSnack(context, 'Obrigado pela avaliação! 🐾');
              },
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    _close(context);
    const text = 'Conheça o Meu Pet+: carteirinha, vacinas, agendamentos e adoção num só app! 🐾';
    await launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication);
  }

  Future<void> _switchAccount(BuildContext context, {required bool exit}) async {
    context = _close(context);
    final ok = await confirm(
      context,
      exit ? 'Sair da conta?' : 'Mudar de conta',
      exit ? 'Você poderá entrar novamente quando quiser.' : 'Você vai sair desta conta para entrar com outra.',
      ok: exit ? 'Sair' : 'Trocar',
    );
    if (ok) await Db.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final u = Session.current.value;
    final prov = u?.isProvider ?? false;
    final top = MediaQuery.of(context).padding.top;
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.82,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(),
      child: Stack(children: [
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: _strip,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.teal,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
            ),
          ),
        ),
        ListView(
          padding: EdgeInsets.fromLTRB(0, top + 8, 0, 20),
          children: [
            // Cabeçalho
            Padding(
              padding: const EdgeInsets.only(left: 16, right: _strip + 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Material(
                    color: const Color(0xFFB9763C),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.pop(context),
                      child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.arrow_back_rounded, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const LogoText(size: 28),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  PhotoAvatar(photo: u?.photo, size: 64, fallbackIcon: prov ? Icons.storefront_rounded : Icons.person_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(u?.displayName ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      Text(u?.email ?? '', style: const TextStyle(fontSize: 12, color: AppColors.muted), overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _QuickButton(
                    key: const Key('sos'),
                    image: Image.asset('assets/ui/sos.gif', height: 40),
                    label: 'SOS',
                    onTap: () => _go(context, const EmergencyScreen()),
                  ),
                  const SizedBox(width: 22),
                  _QuickButton(
                    key: const Key('chat'),
                    image: Image.asset('assets/ui/chat_bubbles.png', height: 40),
                    label: 'CHAT',
                    onTap: () => _go(context, const ChatListScreen()),
                  ),
                ]),
              ]),
            ),
            const _Divider(),
            const _Section('Informações'),
            _Item(
              color: const Color(0xFF2FB34A),
              icon: Icons.edit_rounded,
              label: 'Editar Perfil',
              onTap: () => _go(context, const ProfileScreen()),
            ),
            if (prov)
              _Item(
                color: AppColors.red,
                icon: Icons.pets_rounded,
                label: 'Meus Pacientes',
                onTap: () => _go(context, const PatientsScreen()),
              )
            else
              _Item(
                color: AppColors.red,
                icon: Icons.pets_rounded,
                label: 'Meus Pets',
                onTap: () => _go(context, const MyPetsScreen()),
              ),
            if (!prov)
              _Item(
                color: AppColors.orange,
                icon: Icons.local_taxi_rounded,
                label: 'Corridas e Pedidos',
                onTap: () => _go(context, const ActivityScreen()),
              ),
            if (prov && isStoreUser(Session.current.value?.categories ?? const []))
              _Item(
                color: kProdutoColor,
                icon: Icons.inventory_2_rounded,
                label: 'Meus Produtos',
                onTap: () => _go(context, const ManageProductsScreen()),
              ),
            _Item(color: const Color(0xFFD9A441), icon: Icons.lock_rounded, label: 'Senha', onTap: () => _password(context)),
            const _Divider(),
            const _Section('Preferências'),
            _Item(
              color: AppColors.teal,
              icon: Icons.notifications_rounded,
              label: prov ? 'Notificações' : 'Notificações e agenda',
              onTap: prov ? () => Navigator.pop(context) : () => _go(context, const AgendaScreen()),
            ),
            _Item(color: AppColors.yellow, icon: Icons.language_rounded, label: 'Idioma', onTap: () => _language(context)),
            _Item(
              key: const Key('tema'),
              color: AppColors.dark ? const Color(0xFF5B6366) : const Color(0xFF2F3A3D),
              icon: Icons.contrast_rounded,
              label: 'Tema | Modo',
              sub: ThemeController.label(ThemeController.mode.value),
              onTap: () => _theme(context),
            ),
            const _Divider(),
            const _Section('Conta'),
            _Item(
              color: AppColors.surface,
              outlined: true,
              icon: Icons.add_rounded,
              label: prov ? 'Adicionar Serviços' : 'Adicionar Pet',
              onTap: () => _go(context, prov ? const ProfileScreen() : const PetFormScreen()),
            ),
            _Item(
              color: const Color(0xFFEF5350),
              icon: Icons.swap_horiz_rounded,
              label: 'Mudar de Conta',
              onTap: () => _switchAccount(context, exit: false),
            ),
            _Item(color: const Color(0xFF7E8587), icon: Icons.logout_rounded, label: 'Sair', onTap: () => _switchAccount(context, exit: true)),
            const _Divider(),
            _Item(color: AppColors.yellow, icon: Icons.star_rounded, label: 'Avaliar o App', onTap: () => _rate(context)),
            _Item(color: kOlive, icon: Icons.share_rounded, label: 'Compartilhar o App', onTap: () => _share(context)),
          ],
        ),
      ]),
    );
  }
}

const kOlive = Color(0xFF5E7A1C);

class _QuickButton extends StatelessWidget {
  final Widget image;
  final String label;
  final VoidCallback onTap;
  const _QuickButton({super.key, required this.image, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(children: [
          image,
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted, letterSpacing: 0.5)),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, _strip + 8, 6),
      child: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.teal)),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Padding(padding: EdgeInsets.fromLTRB(20, 8, _strip + 16, 4), child: Divider(height: 1, color: AppColors.line));
}

class _Item extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final String? sub;
  final bool outlined;
  final VoidCallback onTap;
  const _Item({super.key, required this.color, required this.icon, required this.label, required this.onTap, this.sub, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Row(children: [
          const SizedBox(width: 20),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: outlined ? Border.all(color: kOlive, width: 1.5) : null,
            ),
            child: Icon(icon, size: 18, color: outlined ? kOlive : Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 16)),
              if (sub != null) Text(sub!, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ]),
          ),
          const SizedBox(width: _strip, child: Icon(Icons.chevron_right_rounded, color: Colors.white)),
        ]),
      ),
    );
  }
}

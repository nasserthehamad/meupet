import 'package:flutter/material.dart';

import '../../core/db.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/login_hero.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  Future<void> _login() async {
    if (_email.text.trim().isEmpty || _pass.text.isEmpty) {
      showSnack(context, 'Preencha e-mail e senha.', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await Db.signIn(_email.text, _pass.text);
    } catch (e) {
      if (mounted) showSnack(context, authErrorPt(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgot() async {
    final c = TextEditingController(text: _email.text);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recuperar senha'),
        content: TextField(controller: c, keyboardType: TextInputType.emailAddress, decoration: inputDeco('E-mail')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enviar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Db.resetPassword(c.text);
      if (mounted) showSnack(context, 'Enviamos um link de recuperação para ${c.text.trim()}.');
    } catch (e) {
      if (mounted) showSnack(context, authErrorPt(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    // A entrada é sempre clara, como no protótipo (vídeo e campos azuis).
    return Theme(
      data: buildTheme(),
      child: Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: h * 0.42),
                child: const Center(child: LoginHero()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: 8),
                const Text('Login', textAlign: TextAlign.center, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700)),
                const Text('Insira seus dados para continuar.',
                    textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 22),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: inputDeco('E-MAIL', icon: Icons.mail_rounded, filledTeal: true),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _pass,
                  obscureText: _obscure,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  onSubmitted: (_) => _login(),
                  decoration: inputDeco('SENHA', icon: Icons.lock_rounded, filledTeal: true).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: Colors.white),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Center(
                  child: SizedBox(
                    width: 200,
                    child: OrangeButton(label: 'Entrar', loading: _loading, onPressed: _login),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen())),
                      child: const Text('Não tem cadastro?\nCadastre-se AQUI!',
                          textAlign: TextAlign.center, style: TextStyle(color: AppColors.teal, fontSize: 13)),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: _forgot,
                      child: const Text('Esqueceu sua senha?\nClique AQUI!',
                          textAlign: TextAlign.center, style: TextStyle(color: AppColors.orange, fontSize: 13)),
                    ),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 8),
            Image.asset('assets/images/animais_rodape.jpg', fit: BoxFit.fitWidth),
          ],
        ),
      ),
    ));
  }
}

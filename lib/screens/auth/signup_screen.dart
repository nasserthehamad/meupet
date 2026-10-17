import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../core/db.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  String _role = 'tutor';
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _business = TextEditingController();
  final _address = TextEditingController();
  final Set<String> _cats = {};
  final Set<String> _animals = {};
  bool _loading = false;

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty || _pass.text.length < 6) {
      showSnack(context, 'Preencha nome, e-mail e uma senha com 6+ caracteres.', error: true);
      return;
    }
    if (_role == 'prestador' && (_business.text.trim().isEmpty || _cats.isEmpty)) {
      showSnack(context, 'Informe o nome do estabelecimento e pelo menos um serviço.', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await Db.signUp(
        name: _name.text,
        email: _email.text,
        pass: _pass.text,
        role: _role,
        businessName: _business.text,
        phone: _phone.text,
        city: _city.text,
        address: _address.text,
        categories: _cats.toList(),
        animals: _role == 'prestador' ? _animals.toList() : const [],
      );
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) showSnack(context, authErrorPt(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _roleCard(String role, String title, String sub, IconData icon) {
    final sel = _role == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _role = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: sel ? AppColors.teal : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: sel ? AppColors.teal : const Color(0xFFDADFE1)),
          ),
          child: Column(children: [
            Icon(icon, size: 34, color: sel ? Colors.white : AppColors.teal),
            const SizedBox(height: 6),
            Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: sel ? Colors.white : AppColors.text)),
            Text(sub, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: sel ? Colors.white70 : AppColors.muted)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isProv = _role == 'prestador';
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const PetHeader(title: 'Cadastro', showBack: true, fallbackIcon: Icons.person_add_alt_1_rounded),
          SnakeBand(
            index: 1, padding: const EdgeInsets.only(top: 14, bottom: 30),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Como você vai usar o Meu Pet+?', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Row(children: [
                _roleCard('tutor', 'Tutor', 'Cuido dos meus pets', Icons.favorite_rounded),
                const SizedBox(width: 12),
                _roleCard('prestador', 'Prestador', 'Vet, petshop, TaxiPet…', Icons.storefront_rounded),
              ]),
              const SizedBox(height: 18),
              TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: inputDeco(isProv ? 'Seu nome (responsável)' : 'Seu nome', icon: Icons.person_rounded)),
              const SizedBox(height: 12),
              TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: inputDeco('E-mail', icon: Icons.mail_rounded)),
              const SizedBox(height: 12),
              TextField(controller: _pass, obscureText: true, decoration: inputDeco('Senha (mín. 6 caracteres)', icon: Icons.lock_rounded)),
              const SizedBox(height: 12),
              TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: inputDeco('Telefone / WhatsApp', icon: Icons.phone_rounded)),
              const SizedBox(height: 12),
              TextField(controller: _city, textCapitalization: TextCapitalization.words, decoration: inputDeco('Cidade', icon: Icons.location_city_rounded)),
              if (isProv) ...[
                const SizedBox(height: 20),
                Text('Dados do estabelecimento', style: sectionStyle()),
                const SizedBox(height: 10),
                TextField(controller: _business, textCapitalization: TextCapitalization.words, decoration: inputDeco('Nome do estabelecimento', icon: Icons.store_rounded)),
                const SizedBox(height: 12),
                TextField(controller: _address, decoration: inputDeco('Endereço', icon: Icons.place_rounded)),
                const SizedBox(height: 16),
                const Text('Quais serviços você oferece?', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                for (final g in serviceGroups) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(g.title, style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.w700)),
                  ),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    for (final c in g.providerCategories)
                      FilterChip(
                        avatar: Icon(c.icon, size: 16, color: _cats.contains(c.name) ? Colors.white : AppColors.teal),
                        label: Text(c.name),
                        selected: _cats.contains(c.name),
                        selectedColor: AppColors.teal,
                        showCheckmark: false,
                        labelStyle: TextStyle(color: _cats.contains(c.name) ? Colors.white : AppColors.text),
                        onSelected: (v) => setState(() => v ? _cats.add(c.name) : _cats.remove(c.name)),
                      ),
                  ]),
                ],
                const SizedBox(height: 16),
                const Text('Quais animais você atende?', style: TextStyle(fontWeight: FontWeight.w600)),
                const Text('Deixe em branco se atende todos.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  for (final a in animalCategories)
                    FilterChip(
                      key: Key('animal_chip_${a.$2}'),
                      label: Text(a.$1),
                      selected: _animals.contains(a.$2),
                      selectedColor: AppColors.orange,
                      showCheckmark: false,
                      labelStyle: TextStyle(color: _animals.contains(a.$2) ? Colors.white : AppColors.text),
                      onSelected: (v) => setState(() => v ? _animals.add(a.$2) : _animals.remove(a.$2)),
                    ),
                ]),
              ],
              const SizedBox(height: 26),
              OrangeButton(label: 'Criar conta', loading: _loading, onPressed: _submit),
              const SizedBox(height: 30),
            ]),
          ),
            ]),
          ),
        ],
      ),
    );
  }
}

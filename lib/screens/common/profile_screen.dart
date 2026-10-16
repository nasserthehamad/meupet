import 'package:flutter/material.dart';

import '../../core/catalog.dart';
import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late AppUser _u = Session.user;
  late final _name = TextEditingController(text: _u.name);
  late final _phone = TextEditingController(text: _u.phone);
  late final _city = TextEditingController(text: _u.city);
  late final _business = TextEditingController(text: _u.businessName);
  late final _address = TextEditingController(text: _u.address);
  late final _desc = TextEditingController(text: _u.description);
  late final Set<String> _cats = {..._u.categories};
  late String? _photo = _u.photo;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Db.users.doc(_u.id).update({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'city': _city.text.trim(),
        'photo': _photo,
        if (_u.isProvider) ...{
          'businessName': _business.text.trim(),
          'address': _address.text.trim(),
          'description': _desc.text.trim(),
          'categories': _cats.toList(),
        },
      });
      if (mounted) showSnack(context, 'Perfil atualizado!');
    } catch (e) {
      if (mounted) showSnack(context, 'Erro: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _u = Session.current.value ?? _u;
    final prov = _u.isProvider;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        PetHeader(title: 'Meu perfil', subtitle: prov ? 'Prestador de serviço' : 'Tutor', photo: _photo),
        Center(
          child: PhotoPickerAvatar(
            photo: _photo,
            fallbackIcon: prov ? Icons.storefront_rounded : Icons.person_rounded,
            onPicked: (b) => setState(() => _photo = b),
          ),
        ),
        const SizedBox(height: 6),
        Center(child: Text(_u.email, style: const TextStyle(color: AppColors.muted))),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: inputDeco('Nome', icon: Icons.person_rounded)),
            const SizedBox(height: 12),
            TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: inputDeco('Telefone / WhatsApp', icon: Icons.phone_rounded)),
            const SizedBox(height: 12),
            TextField(controller: _city, decoration: inputDeco('Cidade', icon: Icons.location_city_rounded)),
            if (prov) ...[
              const SizedBox(height: 20),
              Text('Estabelecimento', style: sectionStyle()),
              const SizedBox(height: 10),
              TextField(controller: _business, decoration: inputDeco('Nome do estabelecimento', icon: Icons.store_rounded)),
              const SizedBox(height: 12),
              TextField(controller: _address, decoration: inputDeco('Endereço', icon: Icons.place_rounded)),
              const SizedBox(height: 12),
              TextField(controller: _desc, maxLines: 3, decoration: inputDeco('Descrição (aparece para os tutores)', icon: Icons.info_outline_rounded)),
              const SizedBox(height: 12),
              const Text('Serviços oferecidos', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (final c in allServiceCats)
                  FilterChip(
                    label: Text(c.name),
                    avatar: Icon(c.icon, size: 16, color: _cats.contains(c.name) ? Colors.white : AppColors.teal),
                    selected: _cats.contains(c.name),
                    showCheckmark: false,
                    selectedColor: AppColors.teal,
                    labelStyle: TextStyle(color: _cats.contains(c.name) ? Colors.white : AppColors.text),
                    onSelected: (v) => setState(() => v ? _cats.add(c.name) : _cats.remove(c.name)),
                  ),
              ]),
            ],
            const SizedBox(height: 24),
            OrangeButton(label: 'Salvar', loading: _saving, onPressed: _save, icon: Icons.check_rounded),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sair'),
              onPressed: () async {
                final ok = await confirm(context, 'Sair da conta?', 'Você poderá entrar novamente quando quiser.', ok: 'Sair');
                if (ok) await Db.signOut();
              },
            ),
            const SizedBox(height: 20),
            const Center(child: Text('Meu Pet+ · v1.0', style: TextStyle(color: AppColors.muted, fontSize: 12))),
            const SizedBox(height: 20),
          ]),
        ),
      ],
    );
  }
}

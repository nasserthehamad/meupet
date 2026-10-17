import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

/// Cadastro e edição de pet.
class PetFormScreen extends StatefulWidget {
  final Pet? pet;
  const PetFormScreen({super.key, this.pet});
  @override
  State<PetFormScreen> createState() => _PetFormScreenState();
}

class _PetFormScreenState extends State<PetFormScreen> {
  late final _name = TextEditingController(text: widget.pet?.name);
  late final _breed = TextEditingController(text: widget.pet?.breed);
  late final _weight = TextEditingController(text: widget.pet?.weight);
  late final _height = TextEditingController(text: widget.pet?.height);
  late final _allergies = TextEditingController(text: widget.pet?.allergies);
  late final _treatments = TextEditingController(text: widget.pet?.treatments);
  late final _food = TextEditingController(text: widget.pet?.food);
  late final _plan = TextEditingController(text: widget.pet?.plan);
  late String _species = widget.pet?.species ?? 'Cachorro';
  late String _sex = widget.pet?.sex ?? 'M';
  late DateTime? _birth = widget.pet?.birthDate;
  late String? _photo = widget.pet?.photo;
  bool _saving = false;

  bool get _editing => widget.pet != null;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showSnack(context, 'Dê um nome ao seu pet 🐾', error: true);
      return;
    }
    setState(() => _saving = true);
    final me = Session.user;
    final data = <String, dynamic>{
      'ownerId': me.id,
      'ownerName': me.name,
      'name': _name.text.trim(),
      'species': _species,
      'breed': _breed.text.trim(),
      'sex': _sex,
      'birthDate': _birth == null ? null : Timestamp.fromDate(_birth!),
      'weight': _weight.text.trim(),
      'height': _height.text.trim(),
      'photo': _photo,
      'allergies': _allergies.text.trim(),
      'treatments': _treatments.text.trim(),
      'food': _food.text.trim(),
      'plan': _plan.text.trim(),
    };
    try {
      if (_editing) {
        await Db.pets.doc(widget.pet!.id).update(data);
      } else {
        data['code'] = Db.newPetCode();
        data['createdAt'] = FieldValue.serverTimestamp();
        await Db.pets.add(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, 'Erro ao salvar: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirm(context, 'Excluir ${widget.pet!.name}?', 'Essa ação não pode ser desfeita.', ok: 'Excluir');
    if (!ok) return;
    await Db.pets.doc(widget.pet!.id).delete();
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          PetHeader(showBack: true, title: _editing ? 'Editar pet' : 'Novo pet', photo: Session.current.value?.photo),
          SnakeBand(
            index: 1, padding: const EdgeInsets.only(top: 10, bottom: 30),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: PhotoPickerAvatar(photo: _photo, onPicked: (b) => setState(() => _photo = b))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: inputDeco('Nome do pet', icon: Icons.pets_rounded)),
              const SizedBox(height: 14),
              const Text('Espécie', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ChipSelector(options: speciesList, value: _species, onChanged: (v) => setState(() => _species = v)),
              const SizedBox(height: 14),
              const Text('Sexo', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: _sexBtn('M', 'Macho', Icons.male_rounded, Colors.blue)),
                const SizedBox(width: 10),
                Expanded(child: _sexBtn('F', 'Fêmea', Icons.female_rounded, Colors.pink)),
              ]),
              const SizedBox(height: 14),
              TextField(controller: _breed, textCapitalization: TextCapitalization.words, decoration: inputDeco('Raça', icon: Icons.category_rounded)),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final d = await pickDate(context, initial: _birth ?? DateTime.now(), last: DateTime.now());
                  if (d != null) setState(() => _birth = d);
                },
                child: InputDecorator(
                  decoration: inputDeco('Data de nascimento', icon: Icons.cake_rounded),
                  child: Text(_birth == null ? 'Toque para escolher' : '${fmtDate(_birth)}  (${ageLabel(_birth)})'),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: _weight, keyboardType: TextInputType.number, decoration: inputDeco('Peso (kg)', icon: Icons.monitor_weight_rounded))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _height, keyboardType: TextInputType.number, decoration: inputDeco('Altura (cm)', icon: Icons.height_rounded))),
              ]),
              const SizedBox(height: 20),
              Text('Saúde', style: sectionStyle()),
              const SizedBox(height: 10),
              TextField(controller: _allergies, maxLines: 2, decoration: inputDeco('Alergias identificadas', icon: Icons.warning_amber_rounded)),
              const SizedBox(height: 12),
              TextField(controller: _treatments, maxLines: 2, decoration: inputDeco('Tratamentos de uso contínuo', icon: Icons.medication_rounded)),
              const SizedBox(height: 12),
              TextField(controller: _food, maxLines: 2, decoration: inputDeco('Alimentação (ração, extras…)', icon: Icons.rice_bowl_rounded)),
              const SizedBox(height: 12),
              TextField(controller: _plan, decoration: inputDeco('Plano de saúde pet', icon: Icons.health_and_safety_rounded)),
              const SizedBox(height: 24),
              OrangeButton(label: _editing ? 'Salvar alterações' : 'Cadastrar pet', loading: _saving, onPressed: _save, icon: Icons.check_rounded),
              if (_editing) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
                  label: const Text('Excluir pet', style: TextStyle(color: AppColors.red)),
                ),
              ],
              const SizedBox(height: 30),
            ]),
          ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _sexBtn(String v, String label, IconData i, Color c) {
    final sel = _sex == v;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        backgroundColor: sel ? c.withValues(alpha: 0.12) : AppColors.surface,
        side: BorderSide(color: sel ? c : AppColors.line),
        minimumSize: const Size.fromHeight(46),
      ),
      onPressed: () => setState(() => _sex = v),
      icon: Icon(i, color: c),
      label: Text(label, style: TextStyle(color: sel ? c : AppColors.text)),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'pet_form_screen.dart';

/// Área do pet: Carteirinha, Histórico Clínico e Vacinação.
/// Usada pelo tutor (dono) e pelo prestador (via agendamento).
class PetDetailScreen extends StatelessWidget {
  final String petId;
  final int initialTab;
  const PetDetailScreen({super.key, required this.petId, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Pet>(
      stream: Db.petStream(petId),
      builder: (context, snap) {
        if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final pet = snap.data!;
        if (pet.ownerId.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(icon: Icons.pets_rounded, text: 'Este pet não está mais disponível.'),
          );
        }
        final isOwner = pet.ownerId == Session.uid;
        return DefaultTabController(
          length: 3,
          initialIndex: initialTab,
          child: Scaffold(
            body: NestedScrollView(
              headerSliverBuilder: (context, _) => [
                SliverToBoxAdapter(
                  child: Builder(builder: (context) {
                    final tc = DefaultTabController.of(context);
                    return AnimatedBuilder(
                      animation: tc,
                      builder: (context, _) => PetHeader(
                        showBack: true,
                        title: const ['Carteirinha', 'Histórico Clínico', 'Vacinação'][tc.index],
                        subtitle: '${pet.species}${pet.breed.isNotEmpty ? ' · ${pet.breed}' : ''} · ${ageLabel(pet.birthDate)}',
                        photo: pet.photo,
                        avatarLabel: pet.name,
                        fallbackIcon: Icons.pets_rounded,
                        actions: [
                          if (isOwner)
                            IconButton(
                              tooltip: 'Editar pet',
                              style: IconButton.styleFrom(backgroundColor: AppColors.red.withValues(alpha: 0.85)),
                              icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PetFormScreen(pet: pet))),
                            ),
                        ],
                      ),
                    );
                  }),
                ),
                const SliverToBoxAdapter(
                  child: SnakeBand(
                    index: 1,
                    roundBottom: false,
                    padding: EdgeInsets.only(top: 4, right: 30),
                    child: TabBar(
                      labelColor: AppColors.teal,
                      unselectedLabelColor: AppColors.muted,
                      indicatorColor: AppColors.orange,
                      dividerColor: Colors.transparent,
                      tabs: [
                        Tab(icon: Icon(Icons.badge_rounded), text: 'Carteirinha'),
                        Tab(icon: Icon(Icons.assignment_rounded), text: 'Histórico'),
                        Tab(icon: Icon(Icons.vaccines_rounded), text: 'Vacinas'),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(children: [
                CarteirinhaTab(pet: pet),
                HistoricoTab(pet: pet),
                VacinasTab(pet: pet),
              ]),
            ),
          ),
        );
      },
    );
  }
}

// ======================= CARTEIRINHA =======================

class CarteirinhaTab extends StatelessWidget {
  final Pet pet;
  const CarteirinhaTab({super.key, required this.pet});

  String get _qrData => 'MEUPET+|${pet.id}|${pet.name}|${pet.species}|Tutor: ${pet.ownerName}|${pet.code}';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SnakeBand(
          index: 1,
          roundTop: false,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Carteirinha de identificação PET', style: sectionStyle()),
        const SizedBox(height: 10),
        // Frente
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.teal, width: 2),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Row(children: [
              const Icon(Icons.house_rounded, color: AppColors.teal),
              const SizedBox(width: 6),
              const LogoText(size: 16),
              const Spacer(),
              Text(pet.code.isEmpty ? '' : pet.code, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ]),
            const Divider(),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                PhotoAvatar(photo: pet.photo, size: 86),
                const SizedBox(height: 4),
                Text(pet.name, style: scriptStyle(22, AppColors.teal)),
              ]),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _field('IDENTIFICAÇÃO ANIMAL', pet.code.isEmpty ? '-' : pet.code),
                  Row(children: [
                    Expanded(child: _field('IDADE', ageLabel(pet.birthDate))),
                    const SizedBox(width: 6),
                    Expanded(child: _field('SEXO', pet.sex == 'F' ? 'Fêmea' : 'Macho')),
                  ]),
                  _field('TUTOR', pet.ownerName),
                  _field('PLANO', pet.plan.isEmpty ? 'Meu Pet+ | Padrão' : pet.plan),
                ]),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        // Verso
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.teal, width: 2),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: 'Meu', style: logoStyle(30, AppColors.teal)),
                  TextSpan(text: 'PET', style: logoStyle(30, AppColors.orange)),
                ])),
                Text('+VIDA', style: scriptStyle(18, AppColors.teal)),
                const SizedBox(height: 8),
                Text('${pet.species}${pet.breed.isNotEmpty ? ' · ${pet.breed}' : ''}', style: const TextStyle(fontSize: 12)),
                if (pet.allergies.isNotEmpty)
                  Row(children: [
                    const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.red),
                    const SizedBox(width: 3),
                    Expanded(child: Text('Alergias: ${pet.allergies}', style: const TextStyle(fontSize: 11, color: AppColors.red))),
                  ]),
                const SizedBox(height: 6),
                const Text('Cuidado que vale uma VIDA!', style: TextStyle(fontSize: 10, color: AppColors.orange, fontStyle: FontStyle.italic)),
              ]),
            ),
            GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) => Dialog(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(pet.name, style: scriptStyle(30, AppColors.teal)),
                      const SizedBox(height: 10),
                      QrImageView(data: _qrData, size: 240),
                      const SizedBox(height: 8),
                      const Text('Mostre ao veterinário ou petshop', style: TextStyle(color: AppColors.muted)),
                    ]),
                  ),
                ),
              ),
              child: QrImageView(data: _qrData, size: 110),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.zoom_in_rounded, size: 16, color: AppColors.muted),
          SizedBox(width: 4),
          Text('Toque no QR Code para ampliar', style: TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
          ]),
        ),
      ],
    );
  }

  Widget _field(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(8)),
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ]),
      );
}

// ======================= HISTÓRICO CLÍNICO =======================

class HistoricoTab extends StatelessWidget {
  final Pet pet;
  const HistoricoTab({super.key, required this.pet});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: Db.petSub(pet.id, 'records').snapshots(),
      builder: (context, snap) {
        final docs = (snap.data?.docs ?? []).toList()
          ..sort((a, b) => (tsToDate(b.data()['date']) ?? DateTime(1900)).compareTo(tsToDate(a.data()['date']) ?? DateTime(1900)));
        List<QueryDocumentSnapshot<Map<String, dynamic>>> byType(String t) => docs.where((d) => d.data()['type'] == t).toList();
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            SnakeBand(
              index: 1,
              roundTop: false,
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Prontuário Pet', style: sectionStyle()),
                const SizedBox(height: 6),
                Text('Pet: ${pet.name}${pet.breed.isNotEmpty ? ' (${pet.breed})' : ''}'),
                Text('Idade: ${ageLabel(pet.birthDate)}'),
                if (pet.weight.isNotEmpty) Text('Peso: ${pet.weight} kg'),
                if (pet.height.isNotEmpty) Text('Altura: ${pet.height} cm'),
                const Divider(height: 18),
                Text('Alergias identificadas: ${pet.allergies.isEmpty ? 'nenhuma' : pet.allergies}'),
                Text('Tratamentos de uso contínuo: ${pet.treatments.isEmpty ? 'nenhum' : pet.treatments}'),
                if (pet.food.isNotEmpty) ...[const Divider(height: 18), Text('Alimentação: ${pet.food}')],
              ]),
            ),
            _RecordSection(band: 2, pet: pet, type: 'consulta', title: 'Consultas', icon: Icons.medical_services_rounded, docs: byType('consulta')),
            _RecordSection(band: 3, pet: pet, type: 'receita', title: 'Receitas Médicas', icon: Icons.receipt_long_rounded, docs: byType('receita')),
            _RecordSection(band: 4, pet: pet, type: 'exame', title: 'Exames Pet', icon: Icons.biotech_rounded, docs: byType('exame')),
          ],
        );
      },
    );
  }
}

class _RecordSection extends StatelessWidget {
  final int band;
  final Pet pet;
  final String type;
  final String title;
  final IconData icon;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  const _RecordSection({required this.band, required this.pet, required this.type, required this.title, required this.icon, required this.docs});

  @override
  Widget build(BuildContext context) {
    final last = band == 4;
    return SnakeBand(
      index: band,
      roundBottom: !last,
      padding: EdgeInsets.fromLTRB(22, 10, 18, last ? 100 : 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: sectionStyle())),
          IconButton(
            tooltip: 'Adicionar',
            icon: const Icon(Icons.add_circle_rounded, color: AppColors.orange, size: 30),
            onPressed: () => showRecordForm(context, pet.id, type, title),
          ),
        ]),
        if (docs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('Nenhum registro ainda.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
          ),
        for (final d in docs)
          InkWell(
            onTap: () => _showRecord(context, d),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                DateBadge(tsToDate(d.data()['date'])),
                const SizedBox(width: 10),
                CircleAvatar(radius: 16, backgroundColor: AppColors.teal.withValues(alpha: 0.12), child: Icon(icon, size: 17, color: AppColors.teal)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d.data()['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(
                      [d.data()['professional'] ?? '', if ((d.data()['crm'] ?? '').toString().isNotEmpty) 'CRMV ${d.data()['crm']}']
                          .where((e) => e.toString().isNotEmpty)
                          .join(' · '),
                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              ]),
            ),
          ),
      ]),
    );
  }

  void _showRecord(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d.data()['title'] ?? '', style: sectionStyle().copyWith(fontSize: 18)),
          const SizedBox(height: 4),
          Text('${fmtDate(tsToDate(d.data()['date']))} · ${d.data()['professional'] ?? ''}', style: const TextStyle(color: AppColors.muted)),
          if ((d.data()['crm'] ?? '').toString().isNotEmpty) Text('CRMV: ${d.data()['crm']}', style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 12),
          Text((d.data()['notes'] ?? '').toString().isEmpty ? 'Sem observações.' : d.data()['notes']),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
              label: const Text('Excluir', style: TextStyle(color: AppColors.red)),
              onPressed: () async {
                final ok = await confirm(c, 'Excluir registro?', 'Essa ação não pode ser desfeita.', ok: 'Excluir');
                if (!ok) return;
                await d.reference.delete();
                if (c.mounted) Navigator.pop(c);
              },
            ),
          ),
        ]),
      ),
    );
  }
}

Future<void> showRecordForm(BuildContext context, String petId, String type, String title) async {
  final t = TextEditingController();
  final prof = TextEditingController(text: Session.current.value?.isProvider == true ? Session.user.displayName : '');
  final crm = TextEditingController();
  final notes = TextEditingController();
  DateTime date = DateTime.now();
  final hint = {
    'consulta': 'Ex.: Consulta de rotina',
    'receita': 'Ex.: Antibiótico Cefalexina 500mg',
    'exame': 'Ex.: Hemograma completo',
  }[type];
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Novo registro · $title', style: sectionStyle()),
            const SizedBox(height: 12),
            TextField(controller: t, decoration: inputDeco('Título', hint: hint)),
            const SizedBox(height: 10),
            TextField(controller: prof, decoration: inputDeco(type == 'exame' ? 'Laboratório / clínica' : 'Profissional')),
            const SizedBox(height: 10),
            if (type != 'exame') ...[
              TextField(controller: crm, decoration: inputDeco('CRMV (opcional)')),
              const SizedBox(height: 10),
            ],
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_rounded, color: AppColors.teal),
              title: Text('Data: ${fmtDate(date)}'),
              onTap: () async {
                final d = await pickDate(c, initial: date);
                if (d != null) setS(() => date = d);
              },
            ),
            TextField(controller: notes, maxLines: 4, decoration: inputDeco(type == 'exame' ? 'Resultado / observações' : 'Prescrição / observações')),
            const SizedBox(height: 16),
            OrangeButton(
              label: 'Salvar',
              icon: Icons.check_rounded,
              onPressed: () async {
                if (t.text.trim().isEmpty) return;
                await Db.petSub(petId, 'records').add({
                  'type': type,
                  'title': t.text.trim(),
                  'professional': prof.text.trim(),
                  'crm': crm.text.trim(),
                  'notes': notes.text.trim(),
                  'date': Timestamp.fromDate(date),
                  'createdBy': Session.uid,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (c.mounted) Navigator.pop(c);
              },
            ),
          ]),
        ),
      ),
    ),
  );
}

// ======================= VACINAS E PARASITAS =======================

class VacinasTab extends StatelessWidget {
  final Pet pet;
  const VacinasTab({super.key, required this.pet});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: Db.petSub(pet.id, 'vaccines').snapshots(),
      builder: (context, vs) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: Db.petSub(pet.id, 'parasites').snapshots(),
          builder: (context, ps) {
            final vac = (vs.data?.docs ?? []).toList()
              ..sort((a, b) => (tsToDate(b.data()['date']) ?? DateTime(1900)).compareTo(tsToDate(a.data()['date']) ?? DateTime(1900)));
            final par = (ps.data?.docs ?? []).toList()
              ..sort((a, b) => (tsToDate(b.data()['date']) ?? DateTime(1900)).compareTo(tsToDate(a.data()['date']) ?? DateTime(1900)));
            final now = DateTime.now();
            final upcoming = <(String, DateTime)>[
              for (final v in vac)
                if (tsToDate(v.data()['nextDate']) != null && tsToDate(v.data()['nextDate'])!.isAfter(now)) (v.data()['name'] as String? ?? '', tsToDate(v.data()['nextDate'])!),
              for (final p in par)
                if (tsToDate(p.data()['nextDate']) != null && tsToDate(p.data()['nextDate'])!.isAfter(now)) (p.data()['product'] as String? ?? '', tsToDate(p.data()['nextDate'])!),
            ]..sort((a, b) => a.$2.compareTo(b.$2));

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                SnakeBand(
                  index: 1,
                  roundTop: false,
                  padding: const EdgeInsets.fromLTRB(22, 10, 18, 22),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('Controle de Vacinação', style: sectionStyle())),
                      IconButton(
                        icon: const Icon(Icons.add_circle_rounded, color: AppColors.orange, size: 30),
                        onPressed: () => _vaccineForm(context),
                      ),
                    ]),
                    if (vac.isEmpty) const Text('Nenhuma vacina registrada.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                    for (final v in vac)
                      _ControlRow(
                        color: AppColors.teal,
                        title: v.data()['name'] ?? '',
                        date: tsToDate(v.data()['date']),
                        extra: v.data()['vet'] ?? '',
                        next: tsToDate(v.data()['nextDate']),
                        onDelete: () => v.reference.delete(),
                      ),
                  ]),
                ),
                SnakeBand(
                  index: 2,
                  padding: const EdgeInsets.fromLTRB(22, 10, 18, 22),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('Controle de Parasitas', style: sectionStyle())),
                      IconButton(
                        icon: const Icon(Icons.add_circle_rounded, color: AppColors.orange, size: 30),
                        onPressed: () => _parasiteForm(context),
                      ),
                    ]),
                    if (par.isEmpty) const Text('Nenhum vermífugo/antipulgas registrado.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                    for (final p in par)
                      _ControlRow(
                        color: AppColors.orange,
                        title: p.data()['product'] ?? '',
                        date: tsToDate(p.data()['date']),
                        extra: (p.data()['weight'] ?? '').toString().isEmpty ? '' : '${p.data()['weight']} kg',
                        next: tsToDate(p.data()['nextDate']),
                        onDelete: () => p.reference.delete(),
                      ),
                  ]),
                ),
                SnakeBand(
                  index: 3,
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 40),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Próximas Vacinas', style: sectionStyle()),
                    const SizedBox(height: 6),
                    if (upcoming.isEmpty)
                      const Text('Nada agendado. 🎉', style: TextStyle(color: AppColors.muted, fontSize: 13))
                    else
                      for (final u in upcoming)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            const Icon(Icons.notifications_active_rounded, color: AppColors.orange, size: 18),
                            const SizedBox(width: 8),
                            Text(fmtDate(u.$2), style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            Expanded(child: Text('[${u.$1}]')),
                            Text('em ${u.$2.difference(now).inDays} dias', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                          ]),
                        ),
                  ]),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _vaccineForm(BuildContext context) async {
    final name = TextEditingController();
    final vet = TextEditingController(text: Session.current.value?.isProvider == true ? Session.user.displayName : '');
    DateTime date = DateTime.now();
    DateTime? next = DateTime(date.year + 1, date.month, date.day);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(c).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Nova vacina', style: sectionStyle()),
            const SizedBox(height: 12),
            Wrap(spacing: 6, children: [
              for (final s in const ['V10', 'V8', 'Antirrábica', 'Gripe', 'Giárdia', 'V4 felina', 'V5 felina'])
                ActionChip(label: Text(s), onPressed: () => name.text = s),
            ]),
            const SizedBox(height: 8),
            TextField(controller: name, decoration: inputDeco('Vacina')),
            const SizedBox(height: 10),
            TextField(controller: vet, decoration: inputDeco('Veterinário / clínica')),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_rounded, color: AppColors.teal),
              title: Text('Aplicada em: ${fmtDate(date)}'),
              onTap: () async {
                final d = await pickDate(c, initial: date);
                if (d != null) setS(() => date = d);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_repeat_rounded, color: AppColors.orange),
              title: Text('Reforço: ${next == null ? 'sem reforço' : fmtDate(next)}'),
              trailing: next == null ? null : IconButton(icon: const Icon(Icons.clear), onPressed: () => setS(() => next = null)),
              onTap: () async {
                final d = await pickDate(c, initial: next ?? date);
                if (d != null) setS(() => next = d);
              },
            ),
            const SizedBox(height: 10),
            OrangeButton(
              label: 'Salvar',
              icon: Icons.check_rounded,
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                await Db.petSub(pet.id, 'vaccines').add({
                  'name': name.text.trim(),
                  'vet': vet.text.trim(),
                  'date': Timestamp.fromDate(date),
                  'nextDate': next == null ? null : Timestamp.fromDate(next!),
                  'createdBy': Session.uid,
                });
                if (c.mounted) Navigator.pop(c);
              },
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _parasiteForm(BuildContext context) async {
    final product = TextEditingController();
    final weight = TextEditingController(text: pet.weight);
    DateTime date = DateTime.now();
    DateTime? next = date.add(const Duration(days: 90));
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(c).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Vermífugo / antiparasitário', style: sectionStyle()),
            const SizedBox(height: 12),
            TextField(controller: product, decoration: inputDeco('Produto', hint: 'Ex.: Drontal Plus')),
            const SizedBox(height: 10),
            TextField(controller: weight, keyboardType: TextInputType.number, decoration: inputDeco('Peso na aplicação (kg)')),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_rounded, color: AppColors.teal),
              title: Text('Aplicado em: ${fmtDate(date)}'),
              onTap: () async {
                final d = await pickDate(c, initial: date);
                if (d != null) setS(() => date = d);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_repeat_rounded, color: AppColors.orange),
              title: Text('Reforço: ${next == null ? 'sem reforço' : fmtDate(next)}'),
              onTap: () async {
                final d = await pickDate(c, initial: next ?? date);
                if (d != null) setS(() => next = d);
              },
            ),
            const SizedBox(height: 10),
            OrangeButton(
              label: 'Salvar',
              icon: Icons.check_rounded,
              onPressed: () async {
                if (product.text.trim().isEmpty) return;
                await Db.petSub(pet.id, 'parasites').add({
                  'product': product.text.trim(),
                  'weight': weight.text.trim(),
                  'date': Timestamp.fromDate(date),
                  'nextDate': next == null ? null : Timestamp.fromDate(next!),
                  'createdBy': Session.uid,
                });
                if (c.mounted) Navigator.pop(c);
              },
            ),
          ]),
        ),
      ),
    );
  }
}

class _ControlRow extends StatelessWidget {
  final Color color;
  final String title;
  final DateTime? date;
  final String extra;
  final DateTime? next;
  final VoidCallback onDelete;
  const _ControlRow({
    required this.color,
    required this.title,
    required this.date,
    required this.extra,
    required this.next,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Container(
          width: 92,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
          child: Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
        ),
        const SizedBox(width: 8),
        DateBadge(date),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (extra.isNotEmpty) Text(extra, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            Text(next == null ? 'Sem reforço' : 'Reforço ${fmtDate(next)}', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: AppColors.muted, size: 20),
          onSelected: (_) => onDelete(),
          itemBuilder: (_) => const [PopupMenuItem(value: 'del', child: Text('Excluir'))],
        ),
      ]),
    );
  }
}

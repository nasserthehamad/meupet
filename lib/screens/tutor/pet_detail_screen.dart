import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/uploads.dart';
import '../../widgets/common.dart';
import '../common/prescription_screens.dart';
import 'pet_form_screen.dart';
import 'providers_screen.dart';

/// Atalho de compatibilidade: 0 = carteirinha, 1 = histórico, 2 = vacinas.
class PetDetailScreen extends StatelessWidget {
  final String petId;
  final int initialTab;
  const PetDetailScreen({super.key, required this.petId, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    switch (initialTab) {
      case 1:
        return HistoricoScreen(petId: petId);
      case 2:
        return VacinasScreen(petId: petId);
      default:
        return CarteirinhaScreen(petId: petId);
    }
  }
}

/// Transição de esmaecer (a carteirinha "aparece" por cima, como no vídeo).
Route<void> fadeRoute(Widget page) => PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    );

/// Esqueleto comum das telas do pet: cabeçalho com foto e nome + conteúdo.
class _PetScaffold extends StatelessWidget {
  final String petId;
  final String title;
  final bool whiteHeader;
  final List<Widget> Function(BuildContext context, Pet pet, bool isOwner) actions;
  final Widget Function(Pet pet, bool isOwner) body;
  const _PetScaffold({
    required this.petId,
    required this.title,
    required this.actions,
    required this.body,
    this.whiteHeader = false,
  });

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
        return Scaffold(
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              PetHeader(
                showBack: true,
                white: whiteHeader,
                title: title,
                photo: pet.photo,
                avatarLabel: pet.name,
                fallbackIcon: Icons.pets_rounded,
                actions: actions(context, pet, isOwner),
              ),
              body(pet, isOwner),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final String? asset;
  final IconData? icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;
  const _HeaderIcon({this.asset, this.icon, required this.color, required this.tooltip, this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            padding: const EdgeInsets.all(7),
            child: asset != null ? Image.asset(asset!) : Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

List<Widget> _editAction(BuildContext context, Pet pet, bool isOwner) => [
      if (isOwner)
        _HeaderIcon(
          icon: Icons.edit_rounded,
          color: AppColors.orange,
          tooltip: 'Editar pet',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PetFormScreen(pet: pet))),
        ),
    ];

class HistoricoScreen extends StatelessWidget {
  final String petId;
  const HistoricoScreen({super.key, required this.petId});
  @override
  Widget build(BuildContext context) => _PetScaffold(
        petId: petId,
        title: 'Histórico Clínico',
        actions: (c, pet, own) => [
          ..._editAction(c, pet, own),
          const _HeaderIcon(asset: 'assets/ui/clipboard.png', color: Colors.transparent, tooltip: 'Histórico clínico'),
        ],
        body: (pet, own) => HistoricoTab(pet: pet),
      );
}

class VacinasScreen extends StatelessWidget {
  final String petId;
  const VacinasScreen({super.key, required this.petId});
  @override
  Widget build(BuildContext context) => _PetScaffold(
        petId: petId,
        title: 'Vacinação',
        actions: (c, pet, own) => [
          ..._editAction(c, pet, own),
          _HeaderIcon(
            asset: 'assets/ui/clipboard.png',
            color: Colors.transparent,
            tooltip: 'Ver histórico clínico',
            onTap: () => Navigator.pushReplacement(c, MaterialPageRoute(builder: (_) => HistoricoScreen(petId: pet.id))),
          ),
        ],
        body: (pet, own) => VacinasTab(pet: pet),
      );
}

class CarteirinhaScreen extends StatelessWidget {
  final String petId;
  const CarteirinhaScreen({super.key, required this.petId});
  @override
  Widget build(BuildContext context) => _PetScaffold(
        petId: petId,
        title: 'Carteirinha',
        whiteHeader: true,
        actions: (c, pet, own) => _editAction(c, pet, own),
        body: (pet, own) => CarteirinhaTab(pet: pet),
      );
}

// ======================= CARTEIRINHA =======================

class CarteirinhaTab extends StatelessWidget {
  final Pet pet;
  const CarteirinhaTab({super.key, required this.pet});

  String get _qrData => 'MEUPET+|${pet.id}|${pet.name}|${pet.species}|Tutor: ${pet.ownerName}|${pet.code}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SnakeBand(
          index: 2,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 26),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Text('Carteirinha de identificação PET', style: sectionStyle().copyWith(fontSize: 18))),
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
            Image.asset('assets/ui/barcode.png', height: 34, width: double.infinity, fit: BoxFit.fill),
            const SizedBox(height: 8),
            Row(children: [
              Image.asset('assets/images/logo_mark.png', height: 30),
              const SizedBox(width: 6),
              const LogoText(size: 18),
              const Spacer(),
              Text(pet.code.isEmpty ? '' : pet.code, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ]),
            const SizedBox(height: 6),
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
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text.rich(TextSpan(children: [
                    TextSpan(text: 'Meu', style: logoStyle(34, AppColors.teal)),
                    TextSpan(text: 'PET', style: logoStyle(34, AppColors.orange)),
                  ])),
                  const SizedBox(width: 6),
                  Image.asset('assets/images/logo_mark.png', height: 28),
                ]),
                Transform.translate(
                  offset: const Offset(16, -6),
                  child: Text('+VIDA', style: scriptStyle(18, const Color(0xFFB8C2C4))),
                ),
                Row(children: [
                  Stack(alignment: Alignment.bottomCenter, children: [
                    PhotoAvatar(photo: pet.photo, size: 78, border: Colors.white),
                    Text(pet.name, style: scriptStyle(15, AppColors.teal).copyWith(shadows: const [Shadow(color: Colors.white, blurRadius: 5)])),
                  ]),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        backgroundColor: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(pet.name, style: scriptStyle(30, AppColors.teal)),
                            const SizedBox(height: 10),
                            QrImageView(data: _qrData, size: 240, eyeStyle: const QrEyeStyle(color: AppColors.teal, eyeShape: QrEyeShape.square), dataModuleStyle: const QrDataModuleStyle(color: AppColors.teal, dataModuleShape: QrDataModuleShape.square)),
                            const SizedBox(height: 8),
                            const Text('Mostre ao veterinário ou petshop', style: TextStyle(color: AppColors.muted)),
                          ]),
                        ),
                      ),
                    ),
                    child: QrImageView(
                      data: _qrData,
                      size: 96,
                      padding: EdgeInsets.zero,
                      eyeStyle: const QrEyeStyle(color: AppColors.teal, eyeShape: QrEyeShape.square),
                      dataModuleStyle: const QrDataModuleStyle(color: AppColors.teal, dataModuleShape: QrDataModuleShape.square),
                    ),
                  ),
                ]),
                if (pet.allergies.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.red),
                      const SizedBox(width: 3),
                      Expanded(child: Text('Alergias: ${pet.allergies}', style: const TextStyle(fontSize: 11, color: AppColors.red))),
                    ]),
                  ),
              ]),
            ),
            Container(width: 1.5, height: 150, color: const Color(0xFFE2E5E6)),
            const SizedBox(width: 4),
            RotatedBox(
              quarterTurns: 3,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Cuidado que vale uma VIDA!', style: scriptStyle(15, AppColors.purple)),
                const Text('WWW.MEUPET+.COM', style: TextStyle(fontSize: 8, letterSpacing: 1.5, color: AppColors.muted)),
              ]),
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
        SnakeBand(
          index: 3,
          padding: const EdgeInsets.fromLTRB(40, 14, 40, 30),
          child: Center(child: Text(pet.name, style: scriptStyle(46, AppColors.teal))),
        ),
      ],
    );
  }

  Widget _field(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: Color(0xFF2F3A3D))),
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
    return StreamBuilder<List<Prescription>>(
      stream: Db.petPrescriptions(pet.id),
      builder: (context, rxSnap) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: Db.petSub(pet.id, 'records').snapshots(),
      builder: (context, snap) {
        final rx = rxSnap.data ?? const <Prescription>[];
        final vet = canPrescribe(Session.current.value);
        final docs = (snap.data?.docs ?? []).toList()
          ..sort((a, b) => (tsToDate(b.data()['date']) ?? DateTime(1900)).compareTo(tsToDate(a.data()['date']) ?? DateTime(1900)));
        List<QueryDocumentSnapshot<Map<String, dynamic>>> byType(String t) => docs.where((d) => d.data()['type'] == t).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SnakeBand(
              index: 1,
              padding: const EdgeInsets.fromLTRB(22, 14, 18, 26),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('Prontuário Pet', style: sectionStyle().copyWith(fontSize: 19))),
                  InkWell(
                    key: const Key('ver_vacinas'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => VacinasScreen(petId: pet.id))),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Column(children: [
                        CircleAvatar(radius: 19, backgroundColor: Color(0xFFF26B5B), child: Icon(Icons.vaccines_rounded, color: Colors.white, size: 22)),
                        SizedBox(height: 2),
                        Text('Ver Vacinas', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                      ]),
                    ),
                  ),
                ]),
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
            _RecordSection(
              band: 2,
              pet: pet,
              type: 'receita',
              title: vet ? 'Medicações Prescritas' : 'Receitas Médicas',
              icon: Icons.receipt_long_rounded,
              docs: byType('receita'),
              rx: rx.where((e) => !e.isExam).toList(),
              header: vet
                  ? [
                      VetRxButton(
                        key: const Key('nova_receita'),
                        icon: Icons.post_add_rounded,
                        label: 'Nova Receita',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PrescriptionEditor(pet: pet))),
                      ),
                      const SizedBox(width: 8),
                      VetRxButton(
                        icon: Icons.assignment_rounded,
                        label: 'Minhas Receitas',
                        filled: false,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyPrescriptionsScreen())),
                      ),
                    ]
                  : null,
            ),
            _RecordSection(
              band: 3,
              pet: pet,
              type: 'exame',
              title: 'Exames Pet',
              icon: Icons.biotech_rounded,
              docs: byType('exame'),
              rx: rx.where((e) => e.isExam).toList(),
              header: vet
                  ? [
                      VetRxButton(
                        key: const Key('pedir_exame'),
                        icon: Icons.biotech_rounded,
                        label: 'Pedir exame',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PrescriptionEditor(pet: pet, kind: 'exame')),
                        ),
                      ),
                    ]
                  : null,
            ),
            _RecordSection(band: 4, pet: pet, type: 'consulta', title: 'Consultas', icon: Icons.medical_services_rounded, docs: byType('consulta')),
          ],
        );
      },
    ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MiniAction({required this.icon, required this.label, required this.onTap, this.color = AppColors.orange});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(radius: 15, backgroundColor: color, child: Icon(icon, color: Colors.white, size: 18)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
        ]),
      ),
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
  final List<Prescription> rx;
  final List<Widget>? header;
  const _RecordSection({
    required this.band,
    required this.pet,
    required this.type,
    required this.title,
    required this.icon,
    required this.docs,
    this.rx = const [],
    this.header,
  });

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
          if (header != null)
            ...header!
          else
            IconButton(
              tooltip: 'Adicionar',
              icon: const Icon(Icons.add_circle_rounded, color: AppColors.orange, size: 30),
              onPressed: () => showRecordForm(context, pet.id, type, title),
            ),
        ]),
        for (final p in rx) PrescriptionRow(p: p),
        if (docs.isEmpty && rx.isEmpty)
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
                _MiniAction(
                  icon: (d.data()['fileUrl'] ?? '').toString().isNotEmpty ? Icons.attach_file_rounded : Icons.download_rounded,
                  label: 'Abrir',
                  onTap: () => (d.data()['fileUrl'] ?? '').toString().isNotEmpty
                      ? launchUrl(Uri.parse(d.data()['fileUrl']), mode: LaunchMode.externalApplication)
                      : _showRecord(context, d),
                ),
                if (type == 'receita')
                  _MiniAction(
                    icon: Icons.shopping_cart_rounded,
                    label: 'Comprar',
                    color: AppColors.teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProvidersListScreen(title: 'Farmácia', categories: ['Farmácia'])),
                    ),
                  ),
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
          if ((d.data()['fileUrl'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse(d.data()['fileUrl']), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.attach_file_rounded),
                label: Text('Abrir ${d.data()['fileName'] ?? 'arquivo'}'),
              ),
            ),
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
  Attachment? file;
  var uploading = false;
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
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: uploading
                  ? null
                  : () async {
                      if (!Uploads.enabled) {
                        showSnack(c, 'O envio de arquivos ainda está sendo configurado.', error: true);
                        return;
                      }
                      final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']);
                      if (f == null) return;
                      setS(() => uploading = true);
                      try {
                        final a = await Uploads.upload(await f.readAsBytes(), f.name, folder: 'meupet/prontuario');
                        setS(() => file = a);
                      } catch (e) {
                        if (c.mounted) showSnack(c, '$e', error: true);
                      } finally {
                        setS(() => uploading = false);
                      }
                    },
              icon: uploading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(file == null ? Icons.attach_file_rounded : Icons.check_circle_rounded, color: file == null ? null : AppColors.green),
              label: Text(file == null ? 'Anexar arquivo (PDF ou foto)' : file!.name, overflow: TextOverflow.ellipsis),
            ),
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
                  if (file != null) ...{'fileUrl': file!.url, 'fileName': file!.name, 'fileType': file!.type},
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

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SnakeBand(
                  index: 1,
                  padding: const EdgeInsets.fromLTRB(22, 10, 18, 22),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('Controle de Vacinação', style: sectionStyle())),
                      IconButton(
                        icon: const Icon(Icons.add_circle_rounded, color: AppColors.orange, size: 30),
                        onPressed: () => _vaccineForm(context),
                      ),
                    ]),
                    if (vac.isEmpty)
                      const Text('Nenhuma vacina registrada.', style: TextStyle(color: AppColors.muted, fontSize: 13))
                    else
                      _PillTable(color: AppColors.teal, rows: vac.length, cols: [
                        _TableCol('VACINA', pill: true, flex: 3, cells: [
                          for (final v in vac)
                            Column(mainAxisSize: MainAxisSize.min, children: [
                              Text(v.data()['name'] ?? '', textAlign: TextAlign.center, maxLines: 2,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13, height: 1.1)),
                              const Icon(Icons.vaccines_rounded, color: Colors.white70, size: 14),
                            ]),
                        ]),
                        _TableCol('DATA', flex: 3, cells: [for (final v in vac) _DateYear(tsToDate(v.data()['date']))]),
                        _TableCol('REFORÇO', pill: true, flex: 3, cells: [
                          for (final v in vac) _IntervalCell(tsToDate(v.data()['date']), tsToDate(v.data()['nextDate'])),
                        ]),
                        _TableCol('', flex: 2, cells: [
                          for (final v in vac) _RescheduleCell(color: AppColors.teal, doc: v),
                        ]),
                      ]),
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
                    if (par.isEmpty)
                      const Text('Nenhum vermífugo/antipulgas registrado.', style: TextStyle(color: AppColors.muted, fontSize: 13))
                    else
                      _PillTable(color: AppColors.orange, rows: par.length, cols: [
                        _TableCol('DATA', flex: 3, cells: [for (final p in par) _DateYear(tsToDate(p.data()['date']))]),
                        _TableCol('VERMÍFUGO', pill: true, flex: 3, cells: [
                          for (final p in par)
                            Text(p.data()['product'] ?? '', textAlign: TextAlign.center, maxLines: 2,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13, height: 1.1)),
                        ]),
                        _TableCol('PESO', flex: 2, cells: [
                          for (final p in par)
                            Text((p.data()['weight'] ?? '').toString().isEmpty ? '-' : '${p.data()['weight']}kg',
                                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                        ]),
                        _TableCol('REFORÇO', pill: true, flex: 3, cells: [
                          for (final p in par) _IntervalCell(tsToDate(p.data()['date']), tsToDate(p.data()['nextDate']), clock: true),
                        ]),
                        _TableCol('', flex: 2, cells: [
                          for (final p in par) _RescheduleCell(color: AppColors.orange, doc: p),
                        ]),
                      ]),
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
                    const SizedBox(height: 14),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      _BigRoundButton(
                        icon: Icons.pest_control_rounded,
                        label: 'Novo\nvermífugo',
                        color: AppColors.orange,
                        outlined: true,
                        onTap: () => _parasiteForm(context),
                      ),
                      const SizedBox(width: 18),
                      _BigRoundButton(
                        icon: Icons.vaccines_rounded,
                        label: 'Nova\nvacinação',
                        color: const Color(0xFFF26B5B),
                        onTap: () => _vaccineForm(context),
                      ),
                    ]),
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

/// Tabela em "pílulas" do protótipo (colunas coloridas arredondadas).
class _TableCol {
  final String header;
  final bool pill;
  final int flex;
  final List<Widget> cells;
  const _TableCol(this.header, {this.pill = false, this.flex = 1, required this.cells});
}

class _PillTable extends StatelessWidget {
  final Color color;
  final int rows;
  final List<_TableCol> cols;
  const _PillTable({required this.color, required this.rows, required this.cols});

  static const _rowH = 68.0;
  static const _headH = 30.0;
  static const _padV = 8.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, right: 4),
      child: Stack(children: [
        for (var i = 0; i < rows - 1; i++)
          Positioned(
            left: 0,
            right: 0,
            top: _padV + _headH + _rowH * (i + 1),
            child: Container(height: 1.5, color: color.withValues(alpha: 0.5)),
          ),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final c in cols)
            Expanded(
              flex: c.flex,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: _padV),
                decoration: c.pill ? BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)) : null,
                child: Column(children: [
                  SizedBox(
                    height: _headH,
                    child: Center(
                      child: Text(c.header,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: c.pill ? const Color(0xFF1F2A2C) : AppColors.muted,
                          )),
                    ),
                  ),
                  for (final cell in c.cells) SizedBox(height: _rowH, child: Center(child: cell)),
                ]),
              ),
            ),
        ]),
      ]),
    );
  }
}

class _DateYear extends StatelessWidget {
  final DateTime? date;
  const _DateYear(this.date);
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      DateBadge(date),
      if (date != null)
        RotatedBox(
          quarterTurns: 3,
          child: Text('${date!.year}', style: const TextStyle(fontSize: 10, color: AppColors.muted)),
        ),
    ]);
  }
}

String intervalLabel(DateTime? from, DateTime? to) {
  if (from == null || to == null) return 'Sem\nreforço';
  final d = to.difference(from).inDays;
  if (d >= 350) {
    final y = (d / 365).round();
    return y == 1 ? '+1 ano' : '+$y anos';
  }
  if (d >= 28) {
    final m = (d / 30).round();
    return m == 1 ? '+1 mês' : '+$m meses';
  }
  return '+${d}dias';
}

class _IntervalCell extends StatelessWidget {
  final DateTime? from;
  final DateTime? to;
  final bool clock;
  const _IntervalCell(this.from, this.to, {this.clock = false});
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(intervalLabel(from, to),
          textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13, height: 1.1)),
      if (to != null)
        clock
            ? const Padding(
                padding: EdgeInsets.only(top: 3),
                child: CircleAvatar(radius: 10, backgroundColor: Colors.white, child: Icon(Icons.schedule_rounded, size: 16, color: Color(0xFF2F3A3D))),
              )
            : Text(fmtShort(to), style: const TextStyle(color: Colors.white70, fontSize: 10)),
    ]);
  }
}

class _RescheduleCell extends StatelessWidget {
  final Color color;
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _RescheduleCell({required this.color, required this.doc});

  Future<void> _menu(BuildContext context) async {
    final next = tsToDate(doc.data()['nextDate']);
    final r = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(Icons.edit_calendar_rounded, color: color),
            title: const Text('Reagendar reforço'),
            subtitle: Text(next == null ? 'Sem reforço' : 'Atual: ${fmtDate(next)}'),
            onTap: () => Navigator.pop(c, 'r'),
          ),
          if (next != null)
            ListTile(
              leading: const Icon(Icons.event_busy_rounded, color: AppColors.muted),
              title: const Text('Remover reforço'),
              onTap: () => Navigator.pop(c, 'n'),
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
            title: const Text('Excluir registro'),
            onTap: () => Navigator.pop(c, 'd'),
          ),
        ]),
      ),
    );
    if (!context.mounted || r == null) return;
    if (r == 'r') {
      final d = await pickDate(context, initial: next ?? DateTime.now());
      if (d != null) await doc.reference.update({'nextDate': Timestamp.fromDate(d)});
    } else if (r == 'n') {
      await doc.reference.update({'nextDate': null});
    } else if (r == 'd') {
      final ok = await confirm(context, 'Excluir registro?', 'Essa ação não pode ser desfeita.', ok: 'Excluir');
      if (ok) await doc.reference.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _menu(context),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            Icon(Icons.calendar_month_rounded, color: AppColors.red.withValues(alpha: 0.85), size: 26),
            Positioned(
              left: -6,
              bottom: -4,
              child: CircleAvatar(radius: 8, backgroundColor: color, child: const Icon(Icons.schedule_rounded, size: 12, color: Colors.white)),
            ),
          ]),
          const SizedBox(height: 4),
          const FittedBox(fit: BoxFit.scaleDown, child: Text('Reagendar', maxLines: 1, softWrap: false, style: TextStyle(fontSize: 10, color: AppColors.muted))),
        ]),
      ),
    );
  }
}

class _BigRoundButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool outlined;
  final VoidCallback onTap;
  const _BigRoundButton({required this.icon, required this.label, required this.color, this.outlined = false, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: outlined ? AppColors.surface : color,
            border: Border.all(color: color, width: 3),
          ),
          child: Icon(icon, color: outlined ? color : Colors.white, size: 30),
        ),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.muted, height: 1.15)),
      ]),
    );
  }
}

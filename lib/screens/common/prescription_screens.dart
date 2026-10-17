import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../tutor/providers_screen.dart';
import 'chat_screen.dart';

const _blueNew = Color(0xFF3D7BE0);

const commonExams = [
  'Hemograma completo',
  'Bioquímico (rins e fígado)',
  'Urina (urinálise)',
  'Fezes (parasitológico)',
  'Raio-X',
  'Ultrassom abdominal',
  'Eletrocardiograma',
  'Teste de leishmaniose',
  'FIV / FeLV',
];

final Map<String, Future<AppUser?>> _userCache = {};
Future<AppUser?> cachedUser(String id) => _userCache.putIfAbsent(id, () => Db.getUser(id));
void clearUserCache() => _userCache.clear();

/// Prestador da área da saúde (pode emitir receita e pedido de exame).
bool canPrescribe(AppUser? u) {
  if (u == null || !u.isProvider) return false;
  const health = {'Veterinário', 'Odontologia', 'Exames', 'Nutrição', 'Vacinação', 'Emergência 24h'};
  return u.categories.any(health.contains);
}

// ============================================================ papel

/// O "papel" do receituário do protótipo: fitas laranja, durex azul,
/// marca-d'água do MeuPET+, logo da clínica e assinatura.
class PrescriptionPaper extends StatelessWidget {
  final Prescription p;
  final String? logo;
  final List<Widget> actions;
  const PrescriptionPaper({super.key, required this.p, this.logo, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    const line = TextStyle(fontSize: 12.5, color: Color(0xFF5B6366), height: 1.35);
    final routes = <String>[];
    for (final i in p.items) {
      if (!routes.contains(i.route)) routes.add(i.route);
    }
    var n = 0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.13), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned.fill(
          child: Center(child: Opacity(opacity: 0.07, child: Image.asset('assets/images/logo.png', width: 230))),
        ),
        Positioned(
          left: -40,
          top: 6,
          child: Transform.rotate(angle: 0.07, child: Container(width: 210, height: 13, color: AppColors.orange)),
        ),
        Positioned(
          right: 96,
          top: -10,
          child: Transform.rotate(
            angle: 0.13,
            child: Container(width: 30, height: 64, color: AppColors.teal.withValues(alpha: 0.72)),
          ),
        ),
        Positioned(
          left: 0,
          top: 44,
          bottom: 44,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(12, (_) => Container(width: 6, height: 10, color: AppColors.orange)),
          ),
        ),
        Positioned(
          right: -30,
          bottom: 4,
          child: Transform.rotate(angle: 0.06, child: Container(width: 230, height: 13, color: AppColors.orange)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 16, 30),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(p.isExam ? 'Pedido de Exames' : 'Receituário Pet',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.teal)),
                ),
              ),
              PhotoAvatar(photo: logo, size: 52, fallbackIcon: Icons.local_hospital_rounded, border: const Color(0xFFE6E8E9)),
            ]),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Pet: ${p.petName}${p.petBreed.isEmpty ? '' : ' (${p.petBreed})'}', style: line),
                  if (p.petAge.isNotEmpty) Text('Idade: ${p.petAge}', style: line),
                  if (p.petWeight.isNotEmpty) Text('Peso: ${p.petWeight} kg', style: line),
                  if (p.petHeight.isNotEmpty) Text('Altura: ${p.petHeight} cm', style: line),
                  if (p.ownerName.isNotEmpty) Text('Tutor: ${p.ownerName}', style: line),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (p.consultaDate != null) Text('•  Consulta: ${fmtDate(p.consultaDate)}', style: line),
                if (p.returnDate != null) Text('•  Retorno: ${fmtDate(p.returnDate)}', style: line),
              ]),
            ]),
            const SizedBox(height: 14),
            if (p.isExam) ...[
              const Text('PEDIDO', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: Color(0xFF5B6366))),
              const SizedBox(height: 4),
              if (p.exams.isEmpty) const Text('Nenhum exame escolhido ainda.', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
              for (var i = 0; i < p.exams.length; i++) Text('${i + 1}. ${p.exams[i]}', style: line),
            ] else ...[
              if (p.items.isEmpty) const Text('Nenhum medicamento ainda.', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
              for (final r in routes) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 2),
                  child: Text('USO ${r.toUpperCase()}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: Color(0xFF5B6366))),
                ),
                for (final i in p.items.where((e) => e.route == r))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${++n}. ${i.name}', style: line.copyWith(color: const Color(0xFF3E4446))),
                      if (i.use.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: Text('•  ${i.use}', style: line),
                        ),
                    ]),
                  ),
              ],
            ],
            if (p.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(p.isExam ? 'Indicação: ${p.notes}' : 'Obs.: ${p.notes}', style: line),
            ],
            const SizedBox(height: 26),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: _Signature(p: p)),
              ...actions,
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Signature extends StatelessWidget {
  final Prescription p;
  const _Signature({required this.p});
  @override
  Widget build(BuildContext context) {
    final signed = p.signedAt != null;
    final name = p.professional.isEmpty ? p.providerName : p.professional;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 30,
        child: signed
            ? Text(name, maxLines: 1, overflow: TextOverflow.clip, style: scriptStyle(22, const Color(0xFF2B4C7E)))
            : null,
      ),
      Container(width: 150, height: 1, color: const Color(0xFF9AA2A5)),
      const SizedBox(height: 3),
      Text(name, style: const TextStyle(fontSize: 12, color: Color(0xFF5B6366))),
      Text(p.crmv.isEmpty ? 'CRMV —' : 'CRMV ${p.crmv}', style: const TextStyle(fontSize: 12, color: Color(0xFF5B6366))),
      if (signed)
        Text('Assinado eletronicamente em ${fmtDate(p.signedAt)} ${fmtTime(p.signedAt)}\nCódigo ${p.code}',
            style: const TextStyle(fontSize: 9.5, color: AppColors.muted))
      else
        const Text('Ainda não assinado', style: TextStyle(fontSize: 9.5, color: AppColors.red)),
    ]);
  }
}

class _PaperAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final Key? actionKey;
  const _PaperAction({required this.icon, required this.label, this.onTap, this.filled = false, this.actionKey});
  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final c = enabled ? AppColors.teal : const Color(0xFFB9C0C2);
    return InkWell(
      key: actionKey,
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled && enabled ? c : Colors.white,
              border: Border.all(color: c, width: 2),
            ),
            child: Icon(icon, color: filled && enabled ? Colors.white : c, size: 22),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10.5, color: enabled ? AppColors.muted : const Color(0xFFB9C0C2))),
        ]),
      ),
    );
  }
}

// ============================================================ editor (vet)

/// Nova receita / pedido de exame para um paciente.
class PrescriptionEditor extends StatefulWidget {
  final Pet pet;
  final String kind; // receita | exame
  final Prescription? initial;
  const PrescriptionEditor({super.key, required this.pet, this.kind = 'receita', this.initial});
  @override
  State<PrescriptionEditor> createState() => _PrescriptionEditorState();
}

class _PrescriptionEditorState extends State<PrescriptionEditor> {
  late final List<RxItem> _items = [...?widget.initial?.items];
  late final List<String> _exams = [...?widget.initial?.exams];
  late final _notes = TextEditingController(text: widget.initial?.notes ?? '');
  late final _crmv = TextEditingController(text: Session.current.value?.crmv ?? '');
  final _customExam = TextEditingController();
  late DateTime _consulta = widget.initial?.consultaDate ?? DateTime.now();
  late DateTime? _retorno = widget.initial?.returnDate;
  DateTime? _signedAt;
  String _code = '';
  bool _sending = false;

  bool get _isExam => widget.kind == 'exame';
  bool get _empty => _isExam ? _exams.isEmpty : _items.isEmpty;

  Prescription _build() {
    final me = Session.user;
    final pet = widget.pet;
    return Prescription(
      kind: widget.kind,
      petId: pet.id,
      petName: pet.name,
      petSpecies: pet.species,
      petBreed: pet.breed,
      petAge: pet.birthDate == null ? '' : ageLabel(pet.birthDate),
      petWeight: pet.weight,
      petHeight: pet.height,
      ownerId: pet.ownerId,
      ownerName: pet.ownerName,
      providerId: me.id,
      providerName: me.displayName,
      professional: me.name,
      crmv: _crmv.text.trim(),
      items: List.of(_items),
      exams: List.of(_exams),
      notes: _notes.text.trim(),
      consultaDate: _consulta,
      returnDate: _retorno,
      signedAt: _signedAt,
      code: _code,
    );
  }

  /// Qualquer mudança depois de assinar desfaz a assinatura.
  void _touch(VoidCallback f) => setState(() {
        f();
        _signedAt = null;
        _code = '';
      });

  void _sign() {
    if (_empty) {
      showSnack(context, _isExam ? 'Escolha pelo menos um exame.' : 'Adicione pelo menos um medicamento.', error: true);
      return;
    }
    if (_crmv.text.trim().isEmpty) {
      showSnack(context, 'Informe seu CRMV para assinar.', error: true);
      return;
    }
    setState(() {
      _signedAt = DateTime.now();
      _code = Db.newCode();
    });
    showSnack(context, _isExam ? 'Pedido assinado. Agora é só enviar.' : 'Receita assinada. Agora é só enviar.');
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      final p = _build();
      await Db.sendPrescription(p);
      final me = Session.user;
      if (me.crmv != p.crmv) await Db.users.doc(me.id).update({'crmv': p.crmv});
      if (!mounted) return;
      showSnack(context, '${_isExam ? 'Pedido de exame' : 'Receita'} enviado para ${p.ownerName.isEmpty ? 'o tutor' : p.ownerName}!');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, 'Não foi possível enviar: $e', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _addItem([int? index]) async {
    final old = index == null ? null : _items[index];
    final name = TextEditingController(text: old?.name);
    final use = TextEditingController(text: old?.use);
    var route = old?.route ?? 'Oral';
    final r = await showModalBottomSheet<RxItem>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(c).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(old == null ? 'Adicionar medicamento' : 'Editar medicamento', style: sectionStyle()),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: inputDeco('Medicamento e dose', hint: 'Ex.: Predinisona 20mg'),
            ),
            const SizedBox(height: 10),
            const Text('Via de uso', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ChipSelector(options: rxRoutes, value: route, onChanged: (v) => setS(() => route = v)),
            const SizedBox(height: 10),
            TextField(
              controller: use,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: inputDeco('Como usar', hint: 'Ex.: 1 comprimido ao dia durante 10 dias'),
            ),
            const SizedBox(height: 16),
            OrangeButton(
              label: 'Salvar',
              icon: Icons.check_rounded,
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                Navigator.pop(c, RxItem(name: name.text.trim(), route: route, use: use.text.trim()));
              },
            ),
          ]),
        ),
      ),
    );
    if (r == null) return;
    _touch(() => index == null ? _items.add(r) : _items[index] = r);
  }

  Widget _dateTile(String label, DateTime? d, VoidCallback onTap, {VoidCallback? onClear}) => Expanded(
        child: WhiteBlock(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          padding: EdgeInsets.zero,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                    Text(d == null ? 'Sem data' : fmtDate(d), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                ),
                if (onClear != null && d != null)
                  IconButton(onPressed: onClear, icon: const Icon(Icons.close_rounded, size: 18), visualDensity: VisualDensity.compact)
                else
                  const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.event_rounded, color: AppColors.teal, size: 20)),
              ]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = _build();
    final me = Session.current.value;
    final signed = _signedAt != null;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          PetHeader(
            showBack: true,
            title: _isExam ? 'Pedido de Exame' : 'Nova Receita',
            photo: widget.pet.photo,
            avatarLabel: widget.pet.name,
            fallbackIcon: Icons.pets_rounded,
          ),
          SnakeBand(
            index: 1,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(_isExam ? 'Exames' : 'Medicamentos', style: sectionStyle()),
              ),
              const SizedBox(height: 6),
              if (_isExam) ...[
                Wrap(spacing: 8, runSpacing: 4, children: [
                  for (final e in {...commonExams, ..._exams})
                    FilterChip(
                      label: Text(e),
                      selected: _exams.contains(e),
                      showCheckmark: false,
                      selectedColor: AppColors.teal,
                      labelStyle: TextStyle(color: _exams.contains(e) ? Colors.white : AppColors.text, fontSize: 13),
                      onSelected: (v) => _touch(() => v ? _exams.add(e) : _exams.remove(e)),
                    ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _customExam,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: inputDeco('Outro exame'),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      final t = _customExam.text.trim();
                      if (t.isEmpty || _exams.contains(t)) return;
                      _customExam.clear();
                      _touch(() => _exams.add(t));
                    },
                    icon: const Icon(Icons.add_circle_rounded, color: AppColors.orange, size: 32),
                  ),
                ]),
              ] else ...[
                for (var i = 0; i < _items.length; i++)
                  WhiteBlock(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.orange,
                        child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => _addItem(i),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_items[i].name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('Uso ${_items[i].route.toLowerCase()}${_items[i].use.isEmpty ? '' : ' · ${_items[i].use}'}',
                                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                          ]),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remover',
                        onPressed: () => _touch(() => _items.removeAt(i)),
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
                      ),
                    ]),
                  ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  key: const Key('add_med'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                  onPressed: () => _addItem(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Adicionar medicamento'),
                ),
              ],
              const SizedBox(height: 10),
              Row(children: [
                _dateTile('Consulta', _consulta, () async {
                  final d = await pickDate(context, initial: _consulta);
                  if (d != null) _touch(() => _consulta = d);
                }),
                if (!_isExam)
                  _dateTile('Retorno', _retorno, () async {
                    final d = await pickDate(context, initial: _retorno ?? _consulta.add(const Duration(days: 30)));
                    if (d != null) _touch(() => _retorno = d);
                  }, onClear: () => _touch(() => _retorno = null)),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: _notes,
                maxLines: 2,
                onChanged: (_) => _touch(() {}),
                textCapitalization: TextCapitalization.sentences,
                decoration: inputDeco(_isExam ? 'Indicação clínica' : 'Observações (opcional)'),
              ),
              if ((me?.crmv ?? '').isEmpty) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _crmv,
                  onChanged: (_) => _touch(() {}),
                  decoration: inputDeco('Seu CRMV (vai na assinatura)', hint: 'Ex.: 123456-SP', icon: Icons.badge_rounded),
                ),
              ],
            ]),
          ),
          SnakeBand(
            index: 2,
            roundBottom: false,
            padding: const EdgeInsets.fromLTRB(0, 18, 0, 50),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              PrescriptionPaper(
                p: p,
                logo: me?.photo,
                actions: [
                  _PaperAction(
                    actionKey: const Key('assinar'),
                    icon: signed ? Icons.verified_rounded : Icons.draw_rounded,
                    label: signed ? 'Assinado' : 'Assinar',
                    onTap: signed ? null : _sign,
                  ),
                  _PaperAction(
                    actionKey: const Key('enviar_receita'),
                    icon: Icons.send_rounded,
                    label: 'Enviar',
                    filled: true,
                    onTap: signed && !_sending ? _send : null,
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(28, 12, 28, 0),
                child: Text(
                  'Ao enviar, o tutor recebe no Histórico Clínico do pet e uma mensagem no chat.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ============================================================ visualizar

class PrescriptionView extends StatefulWidget {
  final Prescription p;
  const PrescriptionView({super.key, required this.p});
  @override
  State<PrescriptionView> createState() => _PrescriptionViewState();
}

class _PrescriptionViewState extends State<PrescriptionView> {
  @override
  void initState() {
    super.initState();
    final p = widget.p;
    if (!p.seen && p.ownerId == Session.current.value?.id && p.id.isNotEmpty) {
      Db.markPrescriptionSeen(p.id).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return Scaffold(
      body: FutureBuilder<AppUser?>(
        future: cachedUser(p.providerId),
        builder: (context, snap) {
          final prov = snap.data;
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              PetHeader(
                showBack: true,
                title: p.isExam ? 'Pedido de Exame' : 'Receita',
                subtitle: p.providerName,
                photo: prov?.photo,
                fallbackIcon: Icons.local_hospital_rounded,
              ),
              SnakeBand(
                index: 1,
                roundBottom: false,
                padding: const EdgeInsets.fromLTRB(0, 18, 0, 50),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  PrescriptionPaper(p: p, logo: prov?.photo),
                  const SizedBox(height: 18),
                  Wrap(alignment: WrapAlignment.center, spacing: 18, runSpacing: 10, children: [
                    RoundAction(
                      icon: Icons.share_rounded,
                      label: 'Compartilhar',
                      color: AppColors.green,
                      onTap: () => launchUrl(
                        Uri.parse('https://wa.me/?text=${Uri.encodeComponent(p.shareText())}'),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                    if (!p.isExam)
                      RoundAction(
                        icon: Icons.shopping_cart_rounded,
                        label: 'Comprar',
                        color: AppColors.teal,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProvidersListScreen(title: 'Farmácia', categories: ['Farmácia'])),
                        ),
                      )
                    else
                      RoundAction(
                        icon: Icons.event_available_rounded,
                        label: 'Agendar exame',
                        color: AppColors.teal,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProvidersListScreen(title: 'Exames', categories: ['Exames'], bookOnTap: true),
                          ),
                        ),
                      ),
                    if (prov != null && prov.id != Session.current.value?.id)
                      RoundAction(
                        icon: Icons.chat_rounded,
                        label: 'Conversar',
                        color: AppColors.orange,
                        onTap: () async {
                          final id = await Db.openChat(prov.id, prov.displayName);
                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(chatId: id, otherName: prov.displayName, otherPhoto: prov.photo, otherId: prov.id),
                            ),
                          );
                        },
                      ),
                  ]),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================ linhas do histórico

class PrescriptionRow extends StatelessWidget {
  final Prescription p;
  final bool showPet;
  const PrescriptionRow({super.key, required this.p, this.showPet = false});

  void _open(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => PrescriptionView(p: p)));

  @override
  Widget build(BuildContext context) {
    final isOwner = p.ownerId == Session.current.value?.id;
    final name = p.professional.isEmpty ? p.providerName : p.professional;
    return InkWell(
      onTap: () => _open(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          DateBadge(p.signedAt),
          const SizedBox(width: 8),
          FutureBuilder<AppUser?>(
            future: cachedUser(p.providerId),
            builder: (_, s) => PhotoAvatar(photo: s.data?.photo, size: 38, fallbackIcon: Icons.local_hospital_rounded, border: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(showPet ? p.petName : name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(showPet ? (p.isExam ? 'Pedido de exame' : 'Receita') : (p.crmv.isEmpty ? p.providerName : 'CRMV ${p.crmv}'),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.teal)),
            ]),
          ),
          if (isOwner && !p.seen)
            InkWell(
              onTap: () => _open(context),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.priority_high_rounded, color: _blueNew, size: 28),
                  Text('Novo', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                ]),
              ),
            ),
          _Mini(icon: Icons.download_rounded, label: 'Abrir', color: AppColors.orange, onTap: () => _open(context)),
          if (isOwner)
            p.isExam
                ? _Mini(
                    icon: Icons.event_available_rounded,
                    label: 'Agendar',
                    color: AppColors.teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProvidersListScreen(title: 'Exames', categories: ['Exames'], bookOnTap: true),
                      ),
                    ),
                  )
                : _Mini(
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
    );
  }
}

class _Mini extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Mini({required this.icon, required this.label, required this.color, required this.onTap});
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

/// Botões do protótipo na faixa "Medicações Prescritas" (vet).
class VetRxButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const VetRxButton({super.key, required this.icon, required this.label, required this.onTap, this.filled = true});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? AppColors.orange : Colors.white,
              border: filled ? null : Border.all(color: AppColors.teal, width: 2),
            ),
            child: Icon(icon, color: filled ? Colors.white : AppColors.teal, size: 22),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: filled ? AppColors.orange : AppColors.teal)),
        ]),
      ),
    );
  }
}

// ============================================================ minhas receitas (vet)

class MyPrescriptionsScreen extends StatelessWidget {
  const MyPrescriptionsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Prescription>>(
        stream: Db.providerPrescriptions(Session.uid),
        builder: (context, snap) {
          final list = snap.data ?? [];
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              PetHeader(showBack: true, title: 'Minhas Receitas', photo: Session.current.value?.photo, fallbackIcon: Icons.local_hospital_rounded),
              SnakeBand(
                index: 1,
                roundBottom: false,
                padding: const EdgeInsets.fromLTRB(18, 12, 12, 60),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (!snap.hasData)
                    const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
                  else if (list.isEmpty)
                    const EmptyState(icon: Icons.receipt_long_rounded, text: 'Você ainda não emitiu receitas.\nAbra o prontuário de um paciente e toque em "Nova Receita".')
                  else
                    for (final p in list) PrescriptionRow(p: p, showPet: true),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

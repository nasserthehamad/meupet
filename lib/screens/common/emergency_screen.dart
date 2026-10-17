import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'chat_screen.dart';

const _quick = ['Atropelamento', 'Envenenamento', 'Falta de ar', 'Convulsão', 'Sangramento', 'Engasgo', 'Vômito / diarreia'];

bool hasEmergency24h(AppUser? u) => u?.categories.contains('Emergência 24h') ?? false;

Future<void> _call(BuildContext context, String phone, String who) async {
  final p = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (p.isEmpty) {
    showSnack(context, '$who não cadastrou telefone. Use o chat.', error: true);
    return;
  }
  await launchUrl(Uri.parse('tel:$p'));
}

Future<void> _chat(BuildContext context, String otherId, String otherName, {String? text}) async {
  final id = text == null ? await Db.openChat(otherId, otherName) : await Db.notifyByChat(otherId, otherName, text);
  if (!context.mounted) return;
  Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: id, otherName: otherName, otherId: otherId)));
}

// ================================================================ tutor

/// SOS do tutor: envia um alerta para as clínicas 24h; a primeira que
/// aceitar fala com ele (chat e ligação).
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});
  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  Pet? _pet;
  final _desc = TextEditingController();
  bool _sending = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // atualiza o "há X min"
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_pet == null) {
      showSnack(context, 'Escolha qual pet precisa de ajuda.', error: true);
      return;
    }
    setState(() => _sending = true);
    try {
      await Db.createEmergency(_pet!, _desc.text.isEmpty ? 'Emergência' : _desc.text);
      _desc.clear();
    } catch (e) {
      if (mounted) showSnack(context, 'Não foi possível enviar o alerta: $e', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Session.current.value?.isProvider == true) return const EmergencyAlertsScreen();
    return Scaffold(
      body: StreamBuilder<List<Emergency>>(
        stream: Db.myEmergencies(),
        builder: (context, emSnap) {
          final now = DateTime.now();
          final active = (emSnap.data ?? [])
              .where((e) => e.isActive && (e.createdAt == null || now.difference(e.createdAt!).inHours < 12))
              .toList();
          final em = active.isEmpty ? null : active.first;
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              PetHeader(
                showBack: true,
                title: 'Emergência',
                avatarOverride: Image.asset('assets/ui/sos.gif', width: 84),
              ),
              SnakeBand(
                index: 1,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: em == null ? _form() : _status(em),
              ),
              SnakeBand(
                index: 2,
                roundBottom: false,
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 50),
                child: const _Clinics24h(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _form() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
        ),
        child: const Row(children: [
          Icon(Icons.emergency_rounded, color: AppColors.red, size: 30),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Seu pet precisa de ajuda agora? Envie o alerta: as clínicas 24h recebem e a primeira que aceitar fala com você.',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      Text('Qual pet?', style: sectionStyle().copyWith(fontSize: 17)),
      const SizedBox(height: 6),
      StreamBuilder<List<Pet>>(
        stream: Db.myPets(Session.uid),
        builder: (context, snap) {
          final pets = snap.data ?? [];
          if (snap.hasData && pets.isEmpty) {
            return const Text('Cadastre um pet em "Meus Pets" para pedir socorro por aqui.', style: TextStyle(color: AppColors.muted));
          }
          return SizedBox(
            height: 92,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final p in pets)
                  GestureDetector(
                    key: Key('sos_pet_${p.id}'),
                    onTap: () => setState(() => _pet = p),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Column(children: [
                        PhotoAvatar(photo: p.photo, size: 62, border: _pet?.id == p.id ? AppColors.red : AppColors.surface),
                        const SizedBox(height: 3),
                        Text(p.name,
                            style: TextStyle(
                              fontWeight: _pet?.id == p.id ? FontWeight.w700 : FontWeight.w400,
                              color: _pet?.id == p.id ? AppColors.red : AppColors.text,
                            )),
                      ]),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      const SizedBox(height: 6),
      Text('O que está acontecendo?', style: sectionStyle().copyWith(fontSize: 17)),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 2, children: [
        for (final q in _quick)
          ActionChip(
            label: Text(q, style: const TextStyle(fontSize: 12.5)),
            onPressed: () => setState(() {
              final t = _desc.text.trim();
              _desc.text = t.isEmpty ? q : '$t, ${q.toLowerCase()}';
            }),
          ),
      ]),
      const SizedBox(height: 8),
      TextField(
        controller: _desc,
        maxLines: 2,
        textCapitalization: TextCapitalization.sentences,
        decoration: inputDeco('Descreva rapidinho (opcional)'),
      ),
      const SizedBox(height: 14),
      SizedBox(
        height: 56,
        child: FilledButton.icon(
          key: const Key('enviar_sos'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.red,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          onPressed: _sending ? null : _send,
          icon: _sending
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : const Icon(Icons.campaign_rounded, size: 26),
          label: const Text('ENVIAR ALERTA SOS', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Se for muito grave, ligue já para uma clínica abaixo enquanto espera.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: AppColors.muted),
      ),
    ]);
  }

  Widget _status(Emergency em) {
    final accepted = em.status == 'aceito';
    final color = accepted ? AppColors.green : AppColors.red;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            accepted
                ? const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 50)
                : Image.asset('assets/ui/sos.gif', width: 54),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(accepted ? '${em.acceptedByName} aceitou!' : 'Alerta enviado!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
                Text('${em.petName} · ${timeAgo(accepted ? em.acceptedAt ?? em.createdAt : em.createdAt)}',
                    style: const TextStyle(color: AppColors.muted)),
                Text(
                  accepted ? 'Fale agora com a clínica:' : 'Aguardando uma clínica 24h aceitar…',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ]),
            ),
          ]),
          if (!accepted) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(color: AppColors.red, backgroundColor: Color(0x22E5484D), minHeight: 5),
          ],
          if (em.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('“${em.description}”', style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.text2)),
          ],
          if (accepted) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.teal, minimumSize: const Size.fromHeight(48)),
                  onPressed: () => _chat(context, em.acceptedBy, em.acceptedByName),
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text('Conversar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.green, minimumSize: const Size.fromHeight(48)),
                  onPressed: () => _call(context, em.acceptedByPhone, em.acceptedByName),
                  icon: const Icon(Icons.call_rounded),
                  label: const Text('Ligar'),
                ),
              ),
            ]),
          ],
        ]),
      ),
      const SizedBox(height: 6),
      TextButton(
        onPressed: () async {
          final ok = await confirm(
            context,
            accepted ? 'Encerrar chamado?' : 'Cancelar alerta?',
            accepted ? 'Use quando o atendimento já estiver resolvido.' : 'As clínicas deixam de ver o seu pedido de socorro.',
            ok: accepted ? 'Encerrar' : 'Cancelar alerta',
          );
          if (ok) await Db.setEmergencyStatus(em.id, accepted ? 'encerrado' : 'cancelado');
        },
        child: Text(accepted ? 'Encerrar chamado' : 'Cancelar alerta', style: const TextStyle(color: AppColors.muted)),
      ),
    ]);
  }
}

class _Clinics24h extends StatelessWidget {
  const _Clinics24h();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: Db.providersByCategory('Emergência 24h'),
      builder: (context, snap) {
        final list = snap.data ?? [];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionTitle('Clínicas 24h'),
          if (!snap.hasData)
            const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
          else if (list.isEmpty)
            const EmptyState(
              icon: Icons.local_hospital_rounded,
              text: 'Ainda não há clínicas 24h cadastradas.\nEm emergência, procure o veterinário mais próximo.',
            )
          else
            for (final p in list)
              WhiteBlock(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  PhotoAvatar(photo: p.photo, size: 54, fallbackIcon: Icons.local_hospital_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (p.address.isNotEmpty || p.city.isNotEmpty)
                        Text([p.address, p.city].where((e) => e.isNotEmpty).join(' · '),
                            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ]),
                  ),
                  IconButton(
                    tooltip: 'Conversar',
                    icon: const Icon(Icons.chat_rounded, color: AppColors.teal),
                    onPressed: () => _chat(context, p.id, p.displayName),
                  ),
                  IconButton.filled(
                    tooltip: 'Ligar',
                    style: IconButton.styleFrom(backgroundColor: AppColors.green),
                    icon: const Icon(Icons.call_rounded, color: Colors.white),
                    onPressed: () => _call(context, p.phone, p.displayName),
                  ),
                ]),
              ),
        ]);
      },
    );
  }
}

// ================================================================ prestador

/// Painel de emergências da clínica: chamados abertos (Aceitar) e aceitos.
class EmergencyAlertsScreen extends StatelessWidget {
  const EmergencyAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = Session.current.value;
    final can = hasEmergency24h(me);
    return Scaffold(
      body: StreamBuilder<List<Emergency>>(
        stream: Db.openEmergencies(),
        builder: (context, openSnap) => StreamBuilder<List<Emergency>>(
          stream: Db.emergenciesAcceptedByMe(),
          builder: (context, mineSnap) {
            final open = openSnap.data ?? [];
            final mine = (mineSnap.data ?? []).where((e) => e.status == 'aceito').toList();
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                PetHeader(
                  showBack: true,
                  title: 'Emergências',
                  subtitle: can ? 'Chamados SOS dos tutores' : 'Ative "Emergência 24h" nos seus serviços',
                  avatarOverride: Image.asset('assets/ui/sos.gif', width: 84),
                ),
                SnakeBand(
                  index: 1,
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 26),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SectionTitle('Chamados abertos (${open.length})'),
                    if (!openSnap.hasData)
                      const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
                    else if (open.isEmpty)
                      const EmptyState(icon: Icons.verified_user_rounded, text: 'Nenhum chamado aberto agora.')
                    else
                      for (final e in open) _AlertCard(e: e, canAccept: can),
                  ]),
                ),
                SnakeBand(
                  index: 2,
                  roundBottom: false,
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 50),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const SectionTitle('Aceitos por mim'),
                    if (mine.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        child: Text('Quando você aceitar um chamado, ele fica aqui.', style: TextStyle(color: AppColors.muted)),
                      )
                    else
                      for (final e in mine) _AcceptedCard(e: e),
                  ]),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AlertHead extends StatelessWidget {
  final Emergency e;
  final Color color;
  const _AlertHead({required this.e, required this.color});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      PhotoAvatar(photo: e.petPhoto, size: 58, border: color),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e.petName, style: scriptStyle(24, color)),
          Text('${e.petSpecies.isEmpty ? '' : '${e.petSpecies} · '}Tutor: ${e.tutorName}',
              style: TextStyle(fontSize: 12.5, color: AppColors.text2)),
          Text([if (e.city.isNotEmpty) e.city, timeAgo(e.createdAt)].join(' · '),
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
      ),
    ]);
  }
}

class _AlertCard extends StatefulWidget {
  final Emergency e;
  final bool canAccept;
  const _AlertCard({required this.e, required this.canAccept});
  @override
  State<_AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<_AlertCard> {
  bool _busy = false;

  Future<void> _accept() async {
    final e = widget.e;
    setState(() => _busy = true);
    try {
      final ok = await Db.acceptEmergency(e.id);
      if (!mounted) return;
      if (!ok) {
        showSnack(context, 'Outra clínica já aceitou este chamado.', error: true);
        return;
      }
      await _chat(context, e.tutorId, e.tutorName,
          text: 'Aceitei seu chamado de emergência para ${e.petName}. Estamos à disposição — pode vir agora ou me ligar.');
    } catch (err) {
      if (mounted) showSnack(context, 'Não foi possível aceitar: $err', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.e;
    return WhiteBlock(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _AlertHead(e: e, color: AppColors.red),
        if (e.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('“${e.description}”', style: const TextStyle(fontStyle: FontStyle.italic)),
          ),
        const SizedBox(height: 10),
        FilledButton.icon(
          key: Key('aceitar_${e.id}'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.red, minimumSize: const Size.fromHeight(46)),
          onPressed: !widget.canAccept || _busy ? null : _accept,
          icon: const Icon(Icons.check_rounded),
          label: Text(widget.canAccept ? 'Aceitar chamado' : 'Só clínicas 24h podem aceitar'),
        ),
      ]),
    );
  }
}

class _AcceptedCard extends StatelessWidget {
  final Emergency e;
  const _AcceptedCard({required this.e});
  @override
  Widget build(BuildContext context) {
    return WhiteBlock(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _AlertHead(e: e, color: AppColors.green),
        const SizedBox(height: 10),
        Wrap(alignment: WrapAlignment.spaceAround, spacing: 6, children: [
          RoundAction(icon: Icons.chat_rounded, label: 'Conversar', color: AppColors.teal, onTap: () => _chat(context, e.tutorId, e.tutorName)),
          RoundAction(icon: Icons.call_rounded, label: 'Ligar', color: AppColors.green, onTap: () => _call(context, e.tutorPhone, e.tutorName)),
          RoundAction(
            icon: Icons.task_alt_rounded,
            label: 'Encerrar',
            color: AppColors.muted,
            onTap: () async {
              final ok = await confirm(context, 'Encerrar chamado?', 'Use quando o atendimento estiver resolvido.', ok: 'Encerrar');
              if (ok) await Db.setEmergencyStatus(e.id, 'encerrado');
            },
          ),
        ]),
      ]),
    );
  }
}

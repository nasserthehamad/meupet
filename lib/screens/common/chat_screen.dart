import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

const _bubbleOther = Color(0xFFF2A46B);
const _bubbleMine = Color(0xFF5BB8C9);

/// Conversa (PETCHAT), com o fundo de patinhas e o botão de ligar do protótipo.
class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherName;
  final String? otherPhoto;
  final String? otherId;
  final String? initialText;
  const ChatScreen({super.key, required this.chatId, required this.otherName, this.otherPhoto, this.otherId, this.initialText});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final _ctrl = TextEditingController(text: widget.initialText);
  final _focus = FocusNode();
  AppUser? _other;

  String get _otherId {
    if (widget.otherId != null && widget.otherId!.isNotEmpty) return widget.otherId!;
    return widget.chatId.split('_').firstWhere((p) => p != Session.uid, orElse: () => '');
  }

  @override
  void initState() {
    super.initState();
    _markRead();
    _load();
  }

  Future<void> _load() async {
    if (_otherId.isEmpty) return;
    final u = await Db.getUser(_otherId);
    if (mounted) setState(() => _other = u);
  }

  void _markRead() {
    Db.chats.doc(widget.chatId).update({'readBy.${Session.uid}': true}).catchError((_) {});
  }

  Future<void> _send() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    _ctrl.clear();
    await Db.sendMessage(widget.chatId, t);
    await Db.chats.doc(widget.chatId).update({'readBy': {Session.uid: true}});
  }

  Future<void> _call() async {
    final phone = (_other?.phone ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
    if (phone.isEmpty) {
      showSnack(context, '${widget.otherName} ainda não cadastrou telefone.');
      return;
    }
    await launchUrl(Uri.parse('tel:$phone'));
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) return 'Hoje';
    final y = now.subtract(const Duration(days: 1));
    if (d.year == y.year && d.month == y.month && d.day == y.day) return 'Ontem';
    return fmtDate(d);
  }

  bool _sameDay(DateTime? a, DateTime? b) =>
      a != null && b != null && a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final me = Session.uid;
    final myPhoto = Session.current.value?.photo;
    final otherPhoto = widget.otherPhoto ?? _other?.photo;
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(children: [
        // Cabeçalho
        Container(
          color: AppColors.bg,
          padding: EdgeInsets.fromLTRB(12, top + 8, 12, 10),
          child: Row(children: [
            Material(
              color: Colors.white,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.maybePop(context),
                child: const Padding(padding: EdgeInsets.all(9), child: Icon(Icons.arrow_back_rounded, color: AppColors.muted)),
              ),
            ),
            const SizedBox(width: 10),
            PhotoAvatar(photo: otherPhoto, size: 40, fallbackIcon: Icons.person_rounded, border: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.otherName,
                  overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            InkWell(
              key: const Key('ligar'),
              customBorder: const CircleBorder(),
              onTap: _call,
              child: Image.asset('assets/ui/phone.png', width: 40, height: 40),
            ),
          ]),
        ),
        // Mensagens
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(34),
              image: const DecorationImage(
                image: AssetImage('assets/ui/paw_pattern.png'),
                repeat: ImageRepeat.repeat,
                opacity: 0.35,
                scale: 1.6,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: Db.chats.doc(widget.chatId).collection('messages').orderBy('createdAt', descending: true).limit(200).snapshots(),
              builder: (context, snap) {
                final docs = snap.data?.docs ?? [];
                if (snap.hasData && docs.isNotEmpty && docs.first.data()['senderId'] != me) _markRead();
                if (snap.hasData && docs.isEmpty) {
                  return EmptyState(icon: Icons.waving_hand_rounded, text: 'Diga olá para ${widget.otherName}!');
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final m = docs[i].data();
                    final mine = m['senderId'] == me;
                    final at = tsToDate(m['createdAt']);
                    final older = i + 1 < docs.length ? docs[i + 1].data() : null;
                    final firstOfGroup = older == null || older['senderId'] != m['senderId'];
                    final newDay = older == null || !_sameDay(at, tsToDate(older['createdAt']));
                    final bubble = _Bubble(
                      text: m['text'] ?? '',
                      time: at == null ? '' : '${two(at.hour)}:${two(at.minute)}',
                      mine: mine,
                      tail: firstOfGroup,
                      avatar: firstOfGroup ? (mine ? myPhoto : otherPhoto) : null,
                      showAvatar: firstOfGroup,
                    );
                    if (!newDay || at == null) return bubble;
                    return Column(children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFF5F6466), borderRadius: BorderRadius.circular(12)),
                        child: Text(_dayLabel(at), style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                      bubble,
                    ]);
                  },
                );
              },
            ),
          ),
        ),
        // Barra de digitação
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Row(children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(color: const Color(0xFF6E7376), borderRadius: BorderRadius.circular(28)),
                  child: Row(children: [
                    IconButton(
                      onPressed: () => _focus.requestFocus(),
                      icon: const Icon(Icons.sentiment_satisfied_alt_rounded, color: AppColors.yellow, size: 28),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        focusNode: _focus,
                        minLines: 1,
                        maxLines: 4,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: Colors.white,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Sua mensagem',
                          hintStyle: TextStyle(color: Colors.white70),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: AppColors.orange,
                shape: const CircleBorder(),
                child: InkWell(
                  key: const Key('enviar'),
                  customBorder: const CircleBorder(),
                  onTap: _send,
                  child: const Padding(padding: EdgeInsets.all(13), child: Icon(Icons.send_rounded, color: Colors.white)),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final String time;
  final bool mine;
  final bool tail;
  final String? avatar;
  final bool showAvatar;
  const _Bubble({required this.text, required this.time, required this.mine, required this.tail, this.avatar, required this.showAvatar});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final color = mine ? _bubbleMine : _bubbleOther;
    final av = SizedBox(
      width: 36,
      child: showAvatar ? PhotoAvatar(photo: avatar, size: 36, border: Colors.white, fallbackIcon: Icons.person_rounded) : null,
    );
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: w * 0.68),
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(!mine && tail ? 4 : 24),
          topRight: Radius.circular(mine && tail ? 4 : 24),
          bottomLeft: const Radius.circular(24),
          bottomRight: const Radius.circular(24),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 15.5, height: 1.3)),
        const SizedBox(height: 2),
        Text(time, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ]),
    );
    return Row(
      mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: mine ? [bubble, av] : [av, bubble],
    );
  }
}

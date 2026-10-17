import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'chat_screen.dart';

const _petchatOrange = Color(0xFFF2A46B);

/// PETCHAT: lista de conversas com filtro Todas / Lidas / Não lidas.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});
  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  int _filter = 0; // 0 todas, 1 lidas, 2 não lidas

  bool _unread(Map<String, dynamic> m, String me) =>
      m['lastSender'] != me && m['lastSender'] != null && (m['readBy'] is Map ? (m['readBy'][me] != true) : true);

  @override
  Widget build(BuildContext context) {
    final me = Session.uid;
    final u = Session.current.value;
    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: Db.chats.where('participants', arrayContains: me).snapshots(),
        builder: (context, snap) {
          var docs = (snap.data?.docs ?? []).where((d) => d.data()['lastMessage'] != null).toList()
            ..sort((a, b) =>
                (tsToDate(b.data()['updatedAt']) ?? DateTime(2100)).compareTo(tsToDate(a.data()['updatedAt']) ?? DateTime(2100)));
          if (_filter == 1) docs = docs.where((d) => !_unread(d.data(), me)).toList();
          if (_filter == 2) docs = docs.where((d) => _unread(d.data(), me)).toList();
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              PetHeader(photo: u?.photo, fallbackIcon: u?.isProvider == true ? Icons.storefront_rounded : Icons.person_rounded),
              SnakeBand(
                index: 1,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(color: _petchatOrange, borderRadius: BorderRadius.circular(28)),
                    child: Row(children: [
                      Material(
                        color: AppColors.surface,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.maybePop(context),
                          child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.arrow_back_rounded, color: AppColors.muted)),
                        ),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text('PETCHAT',
                              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1)),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    _tab(0, 'Todas as\nmensagens', AppColors.text),
                    _tab(1, 'Lidas', AppColors.teal),
                    _tab(2, 'Não lidas', AppColors.orange),
                  ]),
                  const Divider(height: 1),
                  if (!snap.hasData)
                    const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
                  else if (docs.isEmpty)
                    EmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      text: _filter == 0
                          ? 'Nenhuma conversa ainda.\nVocê pode conversar pelos agendamentos ou perfis dos prestadores.'
                          : 'Nada por aqui.',
                    )
                  else
                    for (final d in docs) _tile(context, d, me),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tab(int i, String label, Color color) {
    final sel = _filter == i;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _filter = i),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: sel ? color : Colors.transparent, width: 3))),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 15, fontWeight: sel ? FontWeight.w600 : FontWeight.w400, height: 1.2)),
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> d, String me) {
    final m = d.data();
    final parts = List<String>.from(m['participants'] ?? const []);
    final other = parts.firstWhere((p) => p != me, orElse: () => '');
    final names = Map<String, dynamic>.from(m['names'] ?? const {});
    final name = (names[other] ?? 'Contato').toString();
    final when = tsToDate(m['updatedAt']);
    final unread = _unread(m, me);
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: d.id, otherName: name, otherId: other))),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
        child: Row(children: [
          FutureBuilder<AppUser?>(
            future: Db.getUser(other),
            builder: (context, s) => PhotoAvatar(photo: s.data?.photo, size: 58, fallbackIcon: Icons.person_rounded, border: AppColors.surface),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 17, fontWeight: unread ? FontWeight.w700 : FontWeight.w500)),
                ),
                Text(when == null ? '' : _rel(when), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                Expanded(
                  child: Text(m['lastMessage'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: unread ? AppColors.text : AppColors.muted, fontSize: 14)),
                ),
                if (unread) const CircleAvatar(radius: 6, backgroundColor: AppColors.orange),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  String _rel(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) return '${two(d.hour)}:${two(d.minute)}';
    return fmtShort(d);
  }
}

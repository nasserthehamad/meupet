import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = Session.uid;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: Db.chats.where('participants', arrayContains: me).snapshots(),
      builder: (context, snap) {
        final docs = (snap.data?.docs ?? []).where((d) => d.data()['lastMessage'] != null).toList()
          ..sort((a, b) => (tsToDate(b.data()['updatedAt']) ?? DateTime(2100)).compareTo(tsToDate(a.data()['updatedAt']) ?? DateTime(2100)));
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            PetHeader(title: 'Conversas', photo: Session.current.value?.photo),
            if (!snap.hasData)
              const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
            else if (docs.isEmpty)
              const EmptyState(icon: Icons.chat_bubble_outline_rounded, text: 'Nenhuma conversa ainda.\nVocê pode conversar com prestadores pelos agendamentos.')
            else
              for (final d in docs) _tile(context, d, me),
            const SizedBox(height: 30),
          ],
        );
      },
    );
  }

  Widget _tile(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> d, String me) {
    final m = d.data();
    final parts = List<String>.from(m['participants'] ?? const []);
    final other = parts.firstWhere((p) => p != me, orElse: () => '');
    final names = Map<String, dynamic>.from(m['names'] ?? const {});
    final name = (names[other] ?? 'Contato').toString();
    final when = tsToDate(m['updatedAt']);
    final unread = m['lastSender'] != me && m['lastSender'] != null && (m['readBy'] is Map ? (m['readBy'][me] != true) : true);
    return WhiteBlock(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: FutureBuilder<AppUser?>(
          future: Db.getUser(other),
          builder: (context, s) => PhotoAvatar(photo: s.data?.photo, size: 46, fallbackIcon: Icons.person_rounded),
        ),
        title: Text(name, style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w500)),
        subtitle: Text(m['lastMessage'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(when == null ? '' : _rel(when), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          if (unread) const Padding(padding: EdgeInsets.only(top: 4), child: CircleAvatar(radius: 5, backgroundColor: AppColors.orange)),
        ]),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: d.id, otherName: name, otherId: other))),
      ),
    );
  }

  String _rel(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) return '${two(d.hour)}:${two(d.minute)}';
    return fmtShort(d);
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

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
  String? _photo;

  @override
  void initState() {
    super.initState();
    _photo = widget.otherPhoto;
    _markRead();
    if (_photo == null) _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    var other = widget.otherId;
    if (other == null) {
      final parts = widget.chatId.split('_');
      other = parts.firstWhere((p) => p != Session.uid, orElse: () => '');
    }
    if (other.isEmpty) return;
    final u = await Db.getUser(other);
    if (mounted && u?.photo != null) setState(() => _photo = u!.photo);
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

  @override
  Widget build(BuildContext context) {
    final me = Session.uid;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F6),
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          PhotoAvatar(photo: _photo, size: 38, fallbackIcon: Icons.person_rounded),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.otherName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text))),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: Db.chats.doc(widget.chatId).collection('messages').orderBy('createdAt', descending: true).limit(200).snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              if (snap.hasData && docs.isNotEmpty) _markRead();
              if (snap.hasData && docs.isEmpty) {
                return const EmptyState(icon: Icons.waving_hand_rounded, text: 'Diga olá! 👋');
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final m = docs[i].data();
                  final mine = m['senderId'] == me;
                  final at = tsToDate(m['createdAt']);
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                      decoration: BoxDecoration(
                        color: mine ? AppColors.teal : const Color(0xFFF2A46B),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(mine ? 18 : 4),
                          bottomRight: Radius.circular(mine ? 4 : 18),
                        ),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(m['text'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(at == null ? '' : '${two(at.hour)}:${two(at.minute)}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                      ]),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Sua mensagem',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.sentiment_satisfied_alt_rounded, color: AppColors.orange),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton.small(
                heroTag: null,
                elevation: 0,
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
                onPressed: _send,
                child: const Icon(Icons.send_rounded),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

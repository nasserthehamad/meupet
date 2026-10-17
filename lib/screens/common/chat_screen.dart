import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/push.dart';
import '../../core/theme.dart';
import '../../core/uploads.dart';
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
  bool _uploading = false;
  AudioRecorder? _rec;
  DateTime? _recStart;
  Timer? _recTimer;
  bool get _recording => _recStart != null;

  String get _otherId {
    if (widget.otherId != null && widget.otherId!.isNotEmpty) return widget.otherId!;
    return widget.chatId.split('_').firstWhere((p) => p != Session.uid, orElse: () => '');
  }

  @override
  void initState() {
    super.initState();
    Push.openChatId = widget.chatId;
    _ctrl.addListener(() => setState(() {}));
    _markRead();
    _load();
  }

  @override
  void dispose() {
    if (Push.openChatId == widget.chatId) Push.openChatId = null;
    _recTimer?.cancel();
    _rec?.dispose();
    super.dispose();
  }

  Future<void> _sendFile(Future<(List<int>, String, int)?> Function() pick) async {
    if (!Uploads.enabled) {
      showSnack(context, 'O envio de arquivos ainda está sendo configurado.', error: true);
      return;
    }
    final picked = await pick();
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final (bytes, name, seconds) = picked;
      final a = await Uploads.upload(Uint8List.fromList(bytes), name, folder: 'meupet/chat', seconds: seconds);
      await Db.sendMessage(widget.chatId, '', attachment: a);
    } catch (e) {
      if (mounted) showSnack(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _attach() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: AppColors.teal),
            title: const Text('Foto da galeria'),
            onTap: () => Navigator.pop(c, 'gallery'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded, color: AppColors.orange),
            title: const Text('Tirar foto'),
            onTap: () => Navigator.pop(c, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.red),
            title: const Text('PDF (exame, receita, nota)'),
            onTap: () => Navigator.pop(c, 'file'),
          ),
        ]),
      ),
    );
    if (choice == null) return;
    if (choice == 'file') {
      await _sendFile(() async {
        final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']);
        if (f == null) return null;
        return (await f.readAsBytes(), f.name, 0);
      });
    } else {
      await _sendFile(() async {
        final x = await ImagePicker().pickImage(
          source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 75,
        );
        if (x == null) return null;
        return (await x.readAsBytes(), x.name.isEmpty ? 'foto.jpg' : x.name, 0);
      });
    }
  }

  Future<void> _startRecording() async {
    if (!Uploads.enabled) {
      showSnack(context, 'O envio de áudio ainda está sendo configurado.', error: true);
      return;
    }
    final rec = _rec ??= AudioRecorder();
    if (!await rec.hasPermission()) {
      if (mounted) showSnack(context, 'Permita o uso do microfone para gravar áudio.', error: true);
      return;
    }
    final dir = await getTemporaryDirectory();
    await rec.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
    setState(() => _recStart = DateTime.now());
    _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _stopRecording({required bool send}) async {
    _recTimer?.cancel();
    final start = _recStart;
    setState(() => _recStart = null);
    final path = await _rec?.stop();
    if (!send || path == null || start == null) return;
    final secs = DateTime.now().difference(start).inSeconds;
    if (secs < 1) return;
    await _sendFile(() async => (await File(path).readAsBytes(), 'audio.m4a', secs));
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
    if (_recording) return _stopRecording(send: true);
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    _ctrl.clear();
    await Db.sendMessage(widget.chatId, t);
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
              color: AppColors.surface,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.maybePop(context),
                child: const Padding(padding: EdgeInsets.all(9), child: Icon(Icons.arrow_back_rounded, color: AppColors.muted)),
              ),
            ),
            const SizedBox(width: 10),
            PhotoAvatar(photo: otherPhoto, size: 40, fallbackIcon: Icons.person_rounded, border: AppColors.surface),
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
              color: AppColors.surface,
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
                      attachment: m['attachment'] is Map ? Attachment.fromMap(m['attachment'] as Map) : null,
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
                  child: _recording
                      ? Row(children: [
                          IconButton(
                            tooltip: 'Descartar',
                            onPressed: () => _stopRecording(send: false),
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                          ),
                          const Icon(Icons.fiber_manual_record_rounded, color: AppColors.red, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Gravando ${_fmtSecs(DateTime.now().difference(_recStart!).inSeconds)}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ])
                      : Row(children: [
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
                    if (_uploading)
                      const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      )
                    else
                      IconButton(
                        key: const Key('anexar'),
                        tooltip: 'Anexar',
                        onPressed: _attach,
                        icon: const Icon(Icons.attach_file_rounded, color: Colors.white),
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
                  onTap: _ctrl.text.trim().isEmpty && !_recording ? _startRecording : _send,
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Icon(_ctrl.text.trim().isEmpty && !_recording ? Icons.mic_rounded : Icons.send_rounded, color: Colors.white),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

String _fmtSecs(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

class _Bubble extends StatelessWidget {
  final String text;
  final String time;
  final bool mine;
  final bool tail;
  final String? avatar;
  final bool showAvatar;
  final Attachment? attachment;
  const _Bubble({
    required this.text,
    required this.time,
    required this.mine,
    required this.tail,
    this.avatar,
    required this.showAvatar,
    this.attachment,
  });

  Widget _attachmentView(BuildContext context, Attachment a) {
    switch (a.type) {
      case 'image':
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _ImageViewer(url: a.url))),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              a.url,
              width: 210,
              height: 210,
              fit: BoxFit.cover,
              loadingBuilder: (c, child, p) =>
                  p == null ? child : const SizedBox(width: 210, height: 210, child: Center(child: CircularProgressIndicator(color: Colors.white))),
              errorBuilder: (_, __, ___) => const SizedBox(width: 210, height: 80, child: Icon(Icons.broken_image_rounded, color: Colors.white)),
            ),
          ),
        );
      case 'audio':
        return _AudioBubble(url: a.url, seconds: a.seconds);
      default:
        return InkWell(
          onTap: () => launchUrl(Uri.parse(a.url), mode: LaunchMode.externalApplication),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 34),
            const SizedBox(width: 8),
            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.name.isEmpty ? 'Arquivo' : a.name,
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                const Text('Toque para abrir', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ]),
            ),
          ]),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final color = mine ? _bubbleMine : _bubbleOther;
    final av = SizedBox(
      width: 36,
      child: showAvatar ? PhotoAvatar(photo: avatar, size: 36, border: AppColors.surface, fallbackIcon: Icons.person_rounded) : null,
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
        if (attachment != null) _attachmentView(context, attachment!),
        if (text.isNotEmpty) Text(text, style: const TextStyle(color: Colors.white, fontSize: 15.5, height: 1.3)),
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

class _ImageViewer extends StatelessWidget {
  final String url;
  const _ImageViewer({required this.url});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(child: InteractiveViewer(child: Image.network(url))),
    );
  }
}

/// Mensagem de voz: tocar/pausar com barra de progresso.
class _AudioBubble extends StatefulWidget {
  final String url;
  final int seconds;
  const _AudioBubble({required this.url, required this.seconds});
  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  AudioPlayer? _player;
  final List<StreamSubscription> _subs = [];
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration? _dur;

  AudioPlayer _ensure() {
    if (_player != null) return _player!;
    final p = AudioPlayer();
    _subs.add(p.onPositionChanged.listen((d) => mounted ? setState(() => _pos = d) : null));
    _subs.add(p.onDurationChanged.listen((d) => mounted ? setState(() => _dur = d) : null));
    _subs.add(p.onPlayerComplete.listen((_) => mounted
        ? setState(() {
            _playing = false;
            _pos = Duration.zero;
          })
        : null));
    return _player = p;
  }

  Future<void> _toggle() async {
    final p = _ensure();
    if (_playing) {
      await p.pause();
      setState(() => _playing = false);
    } else {
      setState(() => _playing = true);
      if (_pos == Duration.zero) {
        await p.play(UrlSource(widget.url));
      } else {
        await p.resume();
      }
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _dur ?? Duration(seconds: widget.seconds);
    final v = total.inMilliseconds == 0 ? 0.0 : (_pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    return SizedBox(
      width: 200,
      child: Row(children: [
        IconButton(
          onPressed: _toggle,
          icon: Icon(_playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: Colors.white, size: 36),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            LinearProgressIndicator(value: v, color: Colors.white, backgroundColor: Colors.white30, minHeight: 4),
            const SizedBox(height: 4),
            Text(_fmtSecs((_playing || _pos > Duration.zero ? _pos : total).inSeconds),
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
        ),
      ]),
    );
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'db.dart';

/// Notificações push: o app guarda o token do aparelho no perfil e pede ao
/// Cloudflare Worker para avisar as outras pessoas (chat, agendamentos, SOS…).
class Push {
  /// Desligado nas prints automáticas.
  static bool enabled = true;

  /// Mostra avisos com o app aberto (definido no main).
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();
  static final navigatorKey = GlobalKey<NavigatorState>();

  /// Abre a tela certa ao tocar na notificação (definido no main).
  static void Function(Map<String, dynamic> data)? onOpen;

  static String? _token;
  static String? _uid;
  static final List<StreamSubscription> _subs = [];
  static bool _listening = false;

  static Future<void> register(String uid) async {
    if (!enabled || _uid == uid) return;
    _uid = uid;
    try {
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission();
      final t = await fm.getToken();
      if (t != null) await _save(uid, t);
      _subs.add(fm.onTokenRefresh.listen((t) => _save(uid, t)));
      if (!_listening) {
        _listening = true;
        _subs.add(FirebaseMessaging.onMessage.listen(_foreground));
        _subs.add(FirebaseMessaging.onMessageOpenedApp.listen((m) => onOpen?.call(m.data)));
        final initial = await fm.getInitialMessage();
        if (initial != null) onOpen?.call(initial.data);
      }
    } catch (_) {}
  }

  static Future<void> _save(String uid, String token) async {
    _token = token;
    await Db.users.doc(uid).update({'fcmTokens': FieldValue.arrayUnion([token])});
  }

  /// Ao sair da conta, este aparelho para de receber avisos dela.
  static Future<void> unregister() async {
    final uid = _uid, t = _token;
    _uid = null;
    if (!enabled || uid == null || t == null) return;
    try {
      await Db.users.doc(uid).update({'fcmTokens': FieldValue.arrayRemove([t])});
    } catch (_) {}
  }

  static void _foreground(RemoteMessage m) {
    final n = m.notification;
    if (n == null) return;
    // a conversa aberta já mostra a mensagem
    if (m.data['type'] == 'chat' && m.data['chatId'] == openChatId) return;
    final sos = m.data['channel'] == 'sos';
    messengerKey.currentState?.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: sos ? 12 : 5),
      backgroundColor: sos ? const Color(0xFFE5484D) : const Color(0xFF137C89),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(n.title ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
        if ((n.body ?? '').isNotEmpty) Text(n.body!, maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
      action: onOpen == null ? null : SnackBarAction(label: 'Ver', textColor: Colors.white, onPressed: () => onOpen!(m.data)),
    ));
  }

  /// Conversa aberta na tela (para não avisar do que a pessoa já está vendo).
  static String? openChatId;

  /// Envia o aviso para os usuários (ids). Nunca trava a tela: falhas são ignoradas.
  static Future<void> notify(List<String> uids, String title, String body, {Map<String, String> data = const {}}) async {
    if (!enabled || AppConfig.pushUrl.isEmpty) return;
    final me = Session.current.value?.id;
    final to = uids.where((u) => u.isNotEmpty && u != me).toSet().toList();
    if (to.isEmpty) return;
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return;
      await http
          .post(
            Uri.parse('${AppConfig.pushUrl}/notify'),
            headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
            body: jsonEncode({'to': to, 'title': title, 'body': body, 'data': data}),
          )
          .timeout(const Duration(seconds: 12));
    } catch (_) {}
  }
}

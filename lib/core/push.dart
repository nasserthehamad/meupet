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

  /// O usuário bloqueou as notificações do app no celular.
  static bool denied = false;

  /// Último problema ao registrar o aparelho (para o teste de notificação).
  static String? lastError;

  static Future<void> register(String uid) async {
    if (!enabled || _uid == uid) return;
    _uid = uid;
    await _registerDevice();
  }

  static Future<void> _registerDevice() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final fm = FirebaseMessaging.instance;
      final st = await fm.requestPermission();
      denied = st.authorizationStatus == AuthorizationStatus.denied;
      final t = await fm.getToken();
      if (t == null) {
        lastError = 'O celular não deu um código de notificação (Google Play Services).';
      } else {
        lastError = null;
        await _save(uid, t);
      }
      if (!_listening) {
        _listening = true;
        // O token novo vai sempre para a conta logada agora.
        _subs.add(fm.onTokenRefresh.listen((t) {
          if (_uid != null) _save(_uid!, t);
        }));
        _subs.add(FirebaseMessaging.onMessage.listen(_foreground));
        _subs.add(FirebaseMessaging.onMessageOpenedApp.listen((m) => onOpen?.call(m.data)));
        final initial = await fm.getInitialMessage();
        if (initial != null) onOpen?.call(initial.data);
      }
    } catch (e) {
      lastError = '$e';
    }
  }

  static Future<void> _save(String uid, String token) async {
    _token = token;
    await Db.users.doc(uid).update({'fcmTokens': FieldValue.arrayUnion([token])});
  }

  /// Teste: registra este aparelho de novo e pede ao servidor uma notificação
  /// para a própria conta daqui a alguns segundos. Devolve o texto para mostrar.
  static Future<String> test() async {
    if (!enabled) return 'Notificações desligadas neste modo.';
    await _registerDevice();
    if (denied) return 'As notificações do Meu Pet+ estão bloqueadas neste celular. Libere em Configurações › Apps › Meu Pet+ › Notificações.';
    if (_token == null) return lastError ?? 'Este aparelho não conseguiu se registrar para notificações.';
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null) return 'Entre na conta primeiro.';
    final r = await http
        .post(Uri.parse('${AppConfig.pushUrl}/test?delay=6'), headers: {'Authorization': 'Bearer $idToken'})
        .timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) return 'O servidor respondeu ${r.statusCode}: ${r.body}';
    final n = (jsonDecode(r.body)['devices'] as num?)?.toInt() ?? 0;
    return 'Em 6 segundos chega uma notificação de teste em $n aparelho(s) desta conta. Saia do app (botão de início) para ver na barra do celular.';
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

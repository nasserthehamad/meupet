import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'config.dart';

/// Contas de teste que podem pedir os dados de demonstração.
const kSeedEmails = {'nasser.hamad@unesp.br'};

bool canSeedDemo(String email) => kSeedEmails.contains(email.trim().toLowerCase());

/// Contas de teste (tutor e prestador) que veem as ferramentas de teste no menu.
const kTestEmails = {'nasser.hamad@unesp.br', 'nhamadxd@gmail.com'};

bool isTestAccount(String email) => kTestEmails.contains(email.trim().toLowerCase());

/// Pede ao servidor (Worker) para criar prestadores de Bauru e preencher a
/// conta de testes com a gata Zuka. Devolve um resumo ou lança o erro.
Future<String> seedDemoData() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw 'Entre na conta primeiro.';
  final token = await user.getIdToken(true);
  final r = await http
      .post(Uri.parse('${AppConfig.pushUrl}/seed'), headers: {'Authorization': 'Bearer $token'})
      .timeout(const Duration(seconds: 60));
  final body = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body) as Map<String, dynamic>;
  if (r.statusCode != 200) throw (body['detail'] ?? body['error'] ?? 'Erro ${r.statusCode}').toString();
  return '${body['providers']} prestadores em Bauru e ${body['writes']} registros (Zuka, vacinas, agenda, receitas, conversas, pedidos).';
}

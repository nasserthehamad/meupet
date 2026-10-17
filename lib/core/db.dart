import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'models.dart';

/// Usuário logado (atualizado pelo AuthGate).
class Session {
  static final ValueNotifier<AppUser?> current = ValueNotifier<AppUser?>(null);
  static AppUser get user => current.value!;
  static String get uid => current.value?.id ?? FirebaseAuth.instance.currentUser!.uid;
}

class Db {
  static FirebaseFirestore? _fs;
  static FirebaseFirestore get fs => _fs ??= FirebaseFirestore.instance;
  /// Permite trocar o banco (usado nas prints com dados de exemplo).
  static set fs(FirebaseFirestore value) => _fs = value;
  static CollectionReference<Map<String, dynamic>> get users => fs.collection('users');
  static CollectionReference<Map<String, dynamic>> get pets => fs.collection('pets');
  static CollectionReference<Map<String, dynamic>> get appointments => fs.collection('appointments');
  static CollectionReference<Map<String, dynamic>> get adoptions => fs.collection('adoptions');
  static CollectionReference<Map<String, dynamic>> get chats => fs.collection('chats');

  // ---------- Auth ----------
  static Future<void> signIn(String email, String pass) =>
      FirebaseAuth.instance.signInWithEmailAndPassword(email: email.trim(), password: pass);

  static Future<void> signUp({
    required String name,
    required String email,
    required String pass,
    required String role,
    String businessName = '',
    String phone = '',
    String city = '',
    String address = '',
    List<String> categories = const [],
    List<String> animals = const [],
  }) async {
    final cred = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email.trim(), password: pass);
    await users.doc(cred.user!.uid).set({
      'name': name.trim(),
      'email': email.trim(),
      'role': role,
      'businessName': businessName.trim(),
      'phone': phone.trim(),
      'city': city.trim(),
      'address': address.trim(),
      'description': '',
      'categories': categories,
      'animals': animals,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> resetPassword(String email) =>
      FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());

  static Future<void> signOut() => FirebaseAuth.instance.signOut();

  // ---------- Users ----------
  static Stream<AppUser> userStream(String id) =>
      users.doc(id).snapshots().map((d) => AppUser.fromDoc(d));

  static Future<AppUser?> getUser(String id) async {
    final d = await users.doc(id).get();
    return d.exists ? AppUser.fromDoc(d) : null;
  }

  static Stream<List<AppUser>> providersByCategory(String cat) => users
      .where('categories', arrayContains: cat)
      .snapshots()
      .map((q) => q.docs.map(AppUser.fromDoc).toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName)));

  /// Prestadores que oferecem qualquer uma das categorias (máx. 30).
  static Stream<List<AppUser>> providersByAny(List<String> cats) => users
      .where('categories', arrayContainsAny: cats.take(30).toList())
      .snapshots()
      .map((q) => q.docs.map(AppUser.fromDoc).toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName)));

  static Stream<List<AppUser>> allProviders() => users
      .where('role', isEqualTo: 'prestador')
      .snapshots()
      .map((q) => q.docs.map(AppUser.fromDoc).toList());

  // ---------- Pets ----------
  static Stream<List<Pet>> myPets(String uid) => pets
      .where('ownerId', isEqualTo: uid)
      .snapshots()
      .map((q) => q.docs.map(Pet.fromDoc).toList()..sort((a, b) => a.name.compareTo(b.name)));

  static Stream<Pet> petStream(String id) => pets.doc(id).snapshots().map(Pet.fromDoc);

  static String newPetCode() {
    final now = DateTime.now();
    final r = Random().nextInt(99999).toString().padLeft(5, '0');
    return 'BR | ${two(now.day)} ${two(now.month)} ${now.year} $r';
  }

  static CollectionReference<Map<String, dynamic>> petSub(String petId, String sub) =>
      pets.doc(petId).collection(sub);

  // ---------- Appointments ----------
  static Stream<List<Appointment>> tutorAppointments(String uid) => appointments
      .where('tutorId', isEqualTo: uid)
      .snapshots()
      .map((q) => _sortAppts(q.docs.map(Appointment.fromDoc).toList()));

  static Stream<List<Appointment>> providerAppointments(String uid) => appointments
      .where('providerId', isEqualTo: uid)
      .snapshots()
      .map((q) => _sortAppts(q.docs.map(Appointment.fromDoc).toList()));

  static List<Appointment> _sortAppts(List<Appointment> l) {
    l.sort((a, b) => (a.dateTime ?? DateTime(2100)).compareTo(b.dateTime ?? DateTime(2100)));
    return l;
  }

  static Future<void> setAppointmentStatus(String id, String status) =>
      appointments.doc(id).update({'status': status});

  static Future<void> reschedule(String id, DateTime dt, {required bool byProvider}) =>
      appointments.doc(id).update({
        'dateTime': Timestamp.fromDate(dt),
        'status': byProvider ? 'confirmado' : 'pendente',
      });

  // ---------- Chats ----------
  static String chatIdFor(String a, String b) {
    final l = [a, b]..sort();
    return '${l[0]}_${l[1]}';
  }

  static Future<String> openChat(String otherId, String otherName) async {
    final me = Session.user;
    final id = chatIdFor(me.id, otherId);
    await chats.doc(id).set({
      'participants': [me.id, otherId]..sort(),
      'names': {me.id: me.displayName, otherId: otherName},
    }, SetOptions(merge: true));
    return id;
  }

  static Future<void> sendMessage(String chatId, String text) async {
    final me = Session.user;
    final batch = fs.batch();
    batch.set(chats.doc(chatId).collection('messages').doc(), {
      'senderId': me.id,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(chats.doc(chatId), {
      'lastMessage': text,
      'lastSender': me.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}

/// Seleciona e comprime uma foto, devolvendo base64 (guardado direto no Firestore).
Future<String?> pickPhotoBase64({ImageSource source = ImageSource.gallery}) async {
  final x = await ImagePicker().pickImage(
    source: source,
    maxWidth: 480,
    maxHeight: 480,
    imageQuality: 60,
  );
  if (x == null) return null;
  final bytes = await x.readAsBytes();
  return base64Encode(bytes);
}

final Map<String, Uint8List> _imgCache = {};
Uint8List? decodePhoto(String? b64) {
  if (b64 == null || b64.isEmpty) return null;
  final key = '${b64.length}:${b64.hashCode}';
  return _imgCache.putIfAbsent(key, () => base64Decode(b64));
}

String authErrorPt(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'email-already-in-use':
        return 'Este e-mail já está cadastrado.';
      case 'weak-password':
        return 'A senha precisa ter pelo menos 6 caracteres.';
      case 'network-request-failed':
        return 'Sem conexão com a internet.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente em alguns minutos.';
    }
    return e.message ?? 'Erro de autenticação.';
  }
  return e.toString();
}

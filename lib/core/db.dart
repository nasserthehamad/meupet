import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'models.dart';
import 'push.dart';

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
  static CollectionReference<Map<String, dynamic>> get prescriptions => fs.collection('prescriptions');
  static CollectionReference<Map<String, dynamic>> get emergencies => fs.collection('emergencies');
  static CollectionReference<Map<String, dynamic>> get reviews => fs.collection('reviews');
  static CollectionReference<Map<String, dynamic>> get rides => fs.collection('rides');
  static CollectionReference<Map<String, dynamic>> get orders => fs.collection('orders');
  static CollectionReference<Map<String, dynamic>> get products => fs.collection('products');

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

  static Future<void> signOut() async {
    await Push.unregister();
    await FirebaseAuth.instance.signOut();
  }

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

  static Future<void> setAppointmentStatus(String id, String status) async {
    await appointments.doc(id).update({'status': status});
    _notifyAppointment(id, status);
  }

  static Future<void> reschedule(String id, DateTime dt, {required bool byProvider}) async {
    await appointments.doc(id).update({
      'dateTime': Timestamp.fromDate(dt),
      'status': byProvider ? 'confirmado' : 'pendente',
    });
    _notifyAppointment(id, 'reagendado');
  }

  static Future<void> _notifyAppointment(String id, String what) async {
    try {
      final a = Appointment.fromDoc(await appointments.doc(id).get());
      final byProvider = Session.uid == a.providerId;
      final when = '${fmtDate(a.dateTime)} às ${fmtTime(a.dateTime)}';
      final title = switch (what) {
        'confirmado' => 'Agendamento confirmado ✅',
        'recusado' => 'Agendamento recusado',
        'concluido' => 'Atendimento concluído',
        'cancelado' => 'Agendamento cancelado',
        'reagendado' => 'Agendamento reagendado',
        _ => 'Agendamento atualizado',
      };
      final who = byProvider ? a.providerName : a.tutorName;
      Push.notify([byProvider ? a.tutorId : a.providerId], title, '${a.petName} · ${a.service} · $when — $who',
          data: {'type': 'appointment', 'id': id});
    } catch (_) {}
  }

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

  static Future<void> sendMessage(String chatId, String text, {Attachment? attachment}) async {
    final me = Session.user;
    final preview = attachment == null ? text : (text.isEmpty ? attachment.label : '${attachment.label} · $text');
    final batch = fs.batch();
    batch.set(chats.doc(chatId).collection('messages').doc(), {
      'senderId': me.id,
      'text': text,
      if (attachment != null) 'attachment': attachment.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(chats.doc(chatId), {
      'lastMessage': preview,
      'lastSender': me.id,
      'updatedAt': FieldValue.serverTimestamp(),
      'readBy': {me.id: true},
    });
    await batch.commit();
    final other = chatId.split('_').where((p) => p != me.id).toList();
    Push.notify(other, me.displayName, preview,
        data: {'type': 'chat', 'chatId': chatId, 'otherId': me.id, 'otherName': me.displayName});
  }

  /// Abre (ou cria) a conversa e manda uma mensagem automática.
  static Future<String> notifyByChat(String otherId, String otherName, String text) async {
    final id = await openChat(otherId, otherName);
    await sendMessage(id, text);
    return id;
  }

  // ---------- Receitas e pedidos de exame ----------
  static List<Prescription> _sortRx(List<Prescription> l) =>
      l..sort((a, b) => (b.signedAt ?? DateTime(1900)).compareTo(a.signedAt ?? DateTime(1900)));

  /// Do pet: o tutor vê as dele; prestadores veem o histórico do paciente.
  static Stream<List<Prescription>> petPrescriptions(String petId) {
    Query<Map<String, dynamic>> q = prescriptions.where('petId', isEqualTo: petId);
    if (Session.current.value?.isProvider != true) q = q.where('ownerId', isEqualTo: Session.uid);
    return q.snapshots().map((s) => _sortRx(s.docs.map(Prescription.fromDoc).toList()));
  }

  static Stream<List<Prescription>> providerPrescriptions(String uid) => prescriptions
      .where('providerId', isEqualTo: uid)
      .snapshots()
      .map((s) => _sortRx(s.docs.map(Prescription.fromDoc).toList()));

  static Future<String> sendPrescription(Prescription p) async {
    final ref = await prescriptions.add({...p.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    final what = p.isExam ? 'um pedido de exame' : 'uma nova receita';
    try {
      await notifyByChat(p.ownerId, p.ownerName,
          'Enviei $what para ${p.petName}. Está em Meus Pets › Histórico Clínico.');
    } catch (_) {}
    return ref.id;
  }

  static Future<void> markPrescriptionSeen(String id) => prescriptions.doc(id).update({'seen': true});

  static String newCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    String part() => List.generate(4, (_) => chars[r.nextInt(chars.length)]).join();
    return 'MP-${part()}-${part()}';
  }

  // ---------- SOS / Emergências ----------
  static List<Emergency> _sortEm(List<Emergency> l) =>
      l..sort((a, b) => (b.createdAt ?? DateTime(2100)).compareTo(a.createdAt ?? DateTime(2100)));

  static Stream<List<Emergency>> openEmergencies() => emergencies
      .where('status', isEqualTo: 'aberto')
      .snapshots()
      .map((s) => _sortEm(s.docs.map(Emergency.fromDoc).toList()));

  static Stream<List<Emergency>> emergenciesAcceptedByMe() => emergencies
      .where('acceptedBy', isEqualTo: Session.uid)
      .snapshots()
      .map((s) => _sortEm(s.docs.map(Emergency.fromDoc).toList()));

  static Stream<List<Emergency>> myEmergencies() => emergencies
      .where('tutorId', isEqualTo: Session.uid)
      .snapshots()
      .map((s) => _sortEm(s.docs.map(Emergency.fromDoc).toList()));

  static Future<String> createEmergency(Pet pet, String description) async {
    final me = Session.user;
    final ref = await emergencies.add({
      'tutorId': me.id,
      'tutorName': me.name,
      'tutorPhone': me.phone,
      'petId': pet.id,
      'petName': pet.name,
      'petSpecies': pet.species,
      'petPhoto': pet.photo,
      'description': description.trim(),
      'city': me.city,
      'status': 'aberto',
      'createdAt': FieldValue.serverTimestamp(),
    });
    try {
      final clinics = await users.where('categories', arrayContains: 'Emergência 24h').get();
      Push.notify([for (final d in clinics.docs) d.id], '🚨 SOS: ${pet.name} (${pet.species})',
          '${description.trim().isEmpty ? 'Emergência' : description.trim()} — ${me.name}${me.city.isEmpty ? '' : ', ${me.city}'}',
          data: {'type': 'emergency', 'id': ref.id, 'channel': 'sos'});
    } catch (_) {}
    return ref.id;
  }

  /// A primeira clínica que aceitar fica com o chamado.
  static Future<bool> acceptEmergency(String id) {
    final me = Session.user;
    final ref = emergencies.doc(id);
    return fs.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      if (snap.data()?['status'] != 'aberto') return false;
      tx.update(ref, {
        'status': 'aceito',
        'acceptedBy': me.id,
        'acceptedByName': me.displayName,
        'acceptedByPhone': me.phone,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      return true;
    }).then((ok) async {
      if (ok) {
        final e = Emergency.fromDoc(await ref.get());
        Push.notify([e.tutorId], '${me.displayName} aceitou seu SOS', 'Abra o app para falar com a clínica sobre ${e.petName}.',
            data: {'type': 'emergency', 'id': id, 'channel': 'sos'});
      }
      return ok;
    });
  }

  static Future<void> setEmergencyStatus(String id, String status) => emergencies.doc(id).update({'status': status});

  // ---------- Avaliações ----------
  static Stream<Map<String, RatingInfo>> ratings() => reviews.snapshots().map((s) {
        final sum = <String, int>{};
        final cnt = <String, int>{};
        for (final d in s.docs) {
          final p = d.data()['providerId'] as String? ?? '';
          final st = ((d.data()['stars'] as num?) ?? 0).toInt();
          if (p.isEmpty || st <= 0) continue;
          sum[p] = (sum[p] ?? 0) + st;
          cnt[p] = (cnt[p] ?? 0) + 1;
        }
        return {for (final p in cnt.keys) p: RatingInfo(sum[p]! / cnt[p]!, cnt[p]!)};
      });

  static Stream<List<Review>> reviewsFor(String providerId) => reviews
      .where('providerId', isEqualTo: providerId)
      .snapshots()
      .map((s) => s.docs.map(Review.fromDoc).toList()
        ..sort((a, b) => (b.date ?? DateTime(1900)).compareTo(a.date ?? DateTime(1900))));

  /// Só avalia quem já agendou com o prestador.
  static Future<bool> canReview(String providerId) async {
    final q = await appointments.where('tutorId', isEqualTo: Session.uid).get();
    return q.docs.any((d) => d.data()['providerId'] == providerId && d.data()['status'] != 'recusado');
  }

  static Future<void> saveReview(String providerId, int stars, String text) {
    final me = Session.user;
    return reviews.doc('${providerId}_${me.id}').set({
      'providerId': providerId,
      'tutorId': me.id,
      'tutorName': me.name,
      'stars': stars,
      'text': text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------- TaxiPet ----------
  static List<Ride> _sortRides(List<Ride> l) =>
      l..sort((a, b) => (a.when ?? DateTime(2100)).compareTo(b.when ?? DateTime(2100)));

  static Stream<List<Ride>> tutorRides(String uid) =>
      rides.where('tutorId', isEqualTo: uid).snapshots().map((s) => _sortRides(s.docs.map(Ride.fromDoc).toList()));

  static Stream<List<Ride>> driverRides(String uid) =>
      rides.where('driverId', isEqualTo: uid).snapshots().map((s) => _sortRides(s.docs.map(Ride.fromDoc).toList()));

  static Stream<Ride> rideStream(String id) => rides.doc(id).snapshots().map(Ride.fromDoc);

  static Future<String> requestRide({
    required Pet pet,
    required AppUser driver,
    required String pickup,
    required String destination,
    required DateTime when,
    String notes = '',
  }) async {
    final me = Session.user;
    final ref = await rides.add({
      'tutorId': me.id,
      'tutorName': me.name,
      'tutorPhone': me.phone,
      'petId': pet.id,
      'petName': pet.name,
      'petSpecies': pet.species,
      'petPhoto': pet.photo,
      'driverId': driver.id,
      'driverName': driver.displayName,
      'driverPhone': driver.phone,
      'pickup': pickup.trim(),
      'destination': destination.trim(),
      'when': Timestamp.fromDate(when),
      'notes': notes.trim(),
      'status': 'pedida',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    Push.notify([driver.id], '🚕 Nova corrida: ${pet.name}', '${fmtDate(when)} às ${fmtTime(when)} · buscar em ${pickup.trim()}',
        data: {'type': 'ride', 'id': ref.id});
    return ref.id;
  }

  static Future<void> setRideStatus(Ride r, String status, {DateTime? when}) async {
    await rides.doc(r.id).update({
      'status': status,
      if (when != null) 'when': Timestamp.fromDate(when),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final byDriver = Session.uid == r.driverId;
    final label = when != null ? 'Corrida reagendada para ${fmtDate(when)} às ${fmtTime(when)}' : (rideStatusLabel[status] ?? status);
    Push.notify([byDriver ? r.tutorId : r.driverId], byDriver ? '🚕 ${r.driverName}' : '🚕 ${r.tutorName}', '$label · ${r.petName}',
        data: {'type': 'ride', 'id': r.id});
  }

  // ---------- Loja ----------
  static Stream<List<Product>> storeProducts(String storeId) => products
      .where('storeId', isEqualTo: storeId)
      .snapshots()
      .map((s) => s.docs.map(Product.fromDoc).toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())));

  static Future<void> saveProduct(Product p) =>
      p.id.isEmpty ? products.add({...p.toMap(), 'createdAt': FieldValue.serverTimestamp()}) : products.doc(p.id).update(p.toMap());

  static Future<void> deleteProduct(String id) => products.doc(id).delete();

  static List<StoreOrder> _sortOrders(List<StoreOrder> l) =>
      l..sort((a, b) => (b.createdAt ?? DateTime(2100)).compareTo(a.createdAt ?? DateTime(2100)));

  static Stream<List<StoreOrder>> tutorOrders(String uid) =>
      orders.where('tutorId', isEqualTo: uid).snapshots().map((s) => _sortOrders(s.docs.map(StoreOrder.fromDoc).toList()));

  static Stream<List<StoreOrder>> storeOrders(String uid) =>
      orders.where('storeId', isEqualTo: uid).snapshots().map((s) => _sortOrders(s.docs.map(StoreOrder.fromDoc).toList()));

  static Stream<StoreOrder> orderStream(String id) => orders.doc(id).snapshots().map(StoreOrder.fromDoc);

  static Future<String> placeOrder({
    required AppUser store,
    required List<OrderItem> items,
    required String pickupName,
    DateTime? pickupDate,
    String notes = '',
  }) async {
    final me = Session.user;
    final total = items.fold<double>(0, (a, i) => a + i.total);
    final ref = await orders.add({
      'storeId': store.id,
      'storeName': store.displayName,
      'tutorId': me.id,
      'tutorName': me.name,
      'tutorPhone': me.phone,
      'tutorPhoto': me.photo,
      'items': [for (final i in items) i.toMap()],
      'total': total,
      'pickupName': pickupName.trim(),
      'pickupDate': pickupDate == null ? null : Timestamp.fromDate(pickupDate),
      'notes': notes.trim(),
      'nfe': '',
      'status': 'novo',
      'createdAt': FieldValue.serverTimestamp(),
    });
    Push.notify([store.id], '🛒 Novo pedido de ${me.name}', '${items.length} item(ns) · ${fmtMoney(total)} · retirada: ${pickupName.trim()}',
        data: {'type': 'order', 'id': ref.id});
    return ref.id;
  }

  static Future<void> updateOrder(StoreOrder o, Map<String, dynamic> changes) async {
    await orders.doc(o.id).update(changes);
    final status = changes['status'] as String?;
    final byStore = Session.uid == o.storeId;
    String? body;
    if (status != null) body = orderStatusLabel[status];
    if (changes['pickupDate'] is Timestamp) body = 'Retirada marcada para ${fmtDate((changes['pickupDate'] as Timestamp).toDate())}';
    if (body == null) return;
    Push.notify([byStore ? o.tutorId : o.storeId], byStore ? '🛒 ${o.storeName}' : '🛒 ${o.tutorName}', '$body · pedido de ${fmtMoney(o.total)}',
        data: {'type': 'order', 'id': o.id});
  }

  // ---------- Avaliação do PET (comportamento) ----------
  static Stream<List<PetNote>> petNotes(String petId) => petSub(petId, 'behavior').snapshots().map((s) =>
      s.docs.map(PetNote.fromDoc).toList()..sort((a, b) => (b.date ?? DateTime(1900)).compareTo(a.date ?? DateTime(1900))));

  static Future<void> addPetNote(String petId, int stars, String text) {
    final me = Session.user;
    return petSub(petId, 'behavior').add({
      'providerId': me.id,
      'providerName': me.displayName,
      'stars': stars,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
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

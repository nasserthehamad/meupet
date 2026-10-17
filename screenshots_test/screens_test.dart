// Gera prints de todas as telas com dados de exemplo (sem Firebase real).
// Rodar: flutter test --update-goldens screenshots_test/screens_test.dart
// As imagens vão para a pasta screenshots/.
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meupet/core/db.dart';
import 'package:meupet/core/models.dart';
import 'package:meupet/core/theme.dart';
import 'package:meupet/screens/auth/login_screen.dart';
import 'package:meupet/screens/auth/signup_screen.dart';
import 'package:meupet/screens/common/chat_list_screen.dart';
import 'package:meupet/screens/common/chat_screen.dart';
import 'package:meupet/screens/common/emergency_screen.dart';
import 'package:meupet/screens/common/profile_screen.dart';
import 'package:meupet/screens/provider/provider_shell.dart';
import 'package:meupet/screens/tutor/adoption_screen.dart';
import 'package:meupet/screens/tutor/agenda_screen.dart';
import 'package:meupet/screens/tutor/my_pets_screen.dart';
import 'package:meupet/screens/tutor/pet_detail_screen.dart';
import 'package:meupet/screens/tutor/pet_form_screen.dart';
import 'package:meupet/screens/tutor/providers_screen.dart';
import 'package:meupet/screens/tutor/tutor_shell.dart';
import 'package:meupet/widgets/login_hero.dart';

String photo(String name) => base64Encode(File('screenshots_test/fixtures/$name.jpg').readAsBytesSync());
Timestamp ts(DateTime d) => Timestamp.fromDate(d);

late AppUser tutor;
late AppUser vet;

Future<void> loadFonts() async {
  final manifest = json.decode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
  for (final f in manifest) {
    final loader = FontLoader(f['family'] as String);
    for (final font in f['fonts'] as List<dynamic>) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

Future<FakeFirebaseFirestore> seed() async {
  final db = FakeFirebaseFirestore();
  final now = DateTime.now();
  DateTime day(int d, int h, [int m = 0]) => DateTime(now.year, now.month, now.day + d, h, m);

  final users = {
    'tutor1': {
      'name': 'Jiara Martins', 'email': 'jiara@email.com', 'role': 'tutor', 'photo': photo('jiara'),
      'phone': '(11) 98888-1234', 'city': 'São Paulo', 'categories': <String>[],
    },
    'vet1': {
      'name': 'Dra. Adeline Palmerston', 'email': 'contato@amicao.com', 'role': 'prestador', 'photo': photo('amicao'),
      'businessName': 'Vet Amicão', 'address': 'Av. do Estado, 1200', 'city': 'São Paulo', 'phone': '(11) 3333-0000',
      'description': 'Clínica veterinária 24h com atendimento humanizado, vacinas, exames e TaxiPet.',
      'categories': ['Veterinário', 'Vacinação', 'Exames', 'Emergência 24h', 'TaxiPet'],
    },
    'shop1': {
      'name': 'Carla Souza', 'email': 'mania@bicho.com', 'role': 'prestador', 'photo': photo('maniadebicho'),
      'businessName': 'Mania de Bicho', 'address': 'R. Gerson França, 88', 'city': 'São Paulo',
      'categories': ['Banho e Tosa', 'Petshop', 'Hotel', 'Creche'],
    },
    'taxi1': {
      'name': 'Bruno Lima', 'email': 'pet@taxi.com', 'role': 'prestador', 'photo': photo('pettaxi'),
      'businessName': 'Pet Taxi', 'address': 'Atende toda a zona sul', 'city': 'São Paulo',
      'categories': ['TaxiPet', 'DogWalker', 'Banho e Tosa'],
    },
  };
  for (final e in users.entries) {
    await db.collection('users').doc(e.key).set(e.value);
  }
  tutor = AppUser.fromDoc(await db.collection('users').doc('tutor1').get());
  vet = AppUser.fromDoc(await db.collection('users').doc('vet1').get());

  final pets = {
    'zuka': ['Zuka', 'Gato', 'SRD', 'F', DateTime(now.year - 2, 3, 10), '4', 'zuka'],
    'athos': ['Athos', 'Cachorro', 'Pastor Alemão', 'M', DateTime(now.year - 8, 1, 5), '37', 'athos'],
    'lolla': ['Lolla', 'Coelho', 'Mini Lop', 'F', DateTime(now.year - 1, now.month - 2, 1), '1.8', 'lolla'],
    'sanna': ['Sanna', 'Aves', 'Calopsita', 'F', DateTime(now.year - 3, 6, 1), '0.1', 'sanna'],
    'chico': ['Chico', 'Roedor', 'Porquinho-da-índia', 'M', DateTime(now.year - 2, 2, 2), '1', 'chico'],
    'rambo': ['Rambo', 'Réptil', 'Jabuti', 'M', DateTime(now.year - 4, 9, 9), '3', 'rambo'],
  };
  for (final e in pets.entries) {
    final v = e.value;
    await db.collection('pets').doc(e.key).set({
      'ownerId': 'tutor1', 'ownerName': 'Jiara Martins', 'name': v[0], 'species': v[1], 'breed': v[2], 'sex': v[3],
      'birthDate': ts(v[4] as DateTime), 'weight': v[5], 'height': e.key == 'athos' ? '65' : '', 'photo': photo(v[6] as String),
      'allergies': e.key == 'athos' ? 'Cefalexina' : '', 'treatments': e.key == 'athos' ? 'Dermatite, leishmaniose' : '',
      'food': e.key == 'athos' ? 'Ração Golden Plus (articulação), frutas e proteínas' : '',
      'plan': e.key == 'zuka' ? 'Meu Pet Cute | Padrão' : '',
      'code': 'SP | 22 10 2023 0000${e.key.length}',
    });
  }

  for (final pid in ['athos', 'zuka']) {
    final r = db.collection('pets').doc(pid).collection('records');
    await r.add({'type': 'consulta', 'title': 'Consulta de rotina', 'professional': 'Vet Amicão', 'crm': '123456-SP', 'date': ts(day(-20, 10)), 'notes': 'Pet saudável.'});
    await r.add({'type': 'receita', 'title': 'Antibiótico — 7 dias', 'professional': 'Dr. Toles', 'crm': '123456-SP', 'date': ts(day(-35, 10)), 'notes': '1 comprimido a cada 12h.'});
    await r.add({'type': 'receita', 'title': 'Shampoo dermatológico', 'professional': 'Dra. Zabomi', 'crm': '234679-SP', 'date': ts(day(-90, 10)), 'notes': ''});
    await r.add({'type': 'exame', 'title': 'Condições renais e fígado', 'professional': 'LaborCare', 'date': ts(day(-25, 9)), 'notes': 'Normal'});
    await r.add({'type': 'exame', 'title': 'Hemograma completo', 'professional': 'VetScan', 'date': ts(day(-60, 9)), 'notes': 'Normal'});
    final v = db.collection('pets').doc(pid).collection('vaccines');
    await v.add({'name': 'V10', 'vet': 'Vet Amicão', 'date': ts(day(-120, 10)), 'nextDate': ts(day(245, 10))});
    await v.add({'name': 'Antirrábica', 'vet': 'Vet Amicão', 'date': ts(day(-120, 10)), 'nextDate': ts(day(30, 10))});
    final p = db.collection('pets').doc(pid).collection('parasites');
    await p.add({'product': 'Drontal Plus', 'weight': '37', 'date': ts(day(-75, 10)), 'nextDate': ts(day(15, 10))});
    await p.add({'product': 'Bravecto', 'weight': '35', 'date': ts(day(-200, 10)), 'nextDate': null});
  }

  Future<void> appt(String pet, String petName, String species, String prov, String provName, String service, DateTime when, String status,
      {bool taxi = false, String notes = '', String address = ''}) async {
    await db.collection('appointments').add({
      'tutorId': 'tutor1', 'tutorName': 'Jiara Martins', 'petId': pet, 'petName': petName, 'species': species,
      'petPhoto': photo(pet), 'providerId': prov, 'providerName': provName, 'service': service, 'dateTime': ts(when),
      'status': status, 'notes': notes, 'taxiPet': taxi, 'address': address,
    });
  }

  await appt('zuka', 'Zuka', 'Gato', 'vet1', 'Vet Amicão', 'Veterinário', day(1, 10), 'confirmado', taxi: true, address: 'R. José Miguel, 45');
  await appt('lolla', 'Lolla', 'Coelho', 'shop1', 'Mania de Bicho', 'Banho e Tosa', day(3, 13, 30), 'pendente', notes: 'Hidratação');
  await appt('athos', 'Athos', 'Cachorro', 'vet1', 'Vet Amicão', 'Vacinação', day(0, 15), 'confirmado');
  await appt('chico', 'Chico', 'Roedor', 'vet1', 'Vet Amicão', 'Exames', day(2, 8, 30), 'pendente', notes: 'Hemograma');
  await appt('sanna', 'Sanna', 'Aves', 'vet1', 'Vet Amicão', 'Veterinário', day(4, 9, 15), 'pendente', taxi: true, address: 'Av. Nações Unidas, 300');
  await appt('athos', 'Athos', 'Cachorro', 'vet1', 'Vet Amicão', 'Veterinário', day(-10, 11), 'concluido');

  final adopt = [
    ['Zeca', 'Cachorro', '2 anos', 'M', 'zeca'], ['Amarelo', 'Cachorro', '1,5 anos', 'M', 'amarelo'], ['Fofs', 'Gato', '7 meses', 'F', 'fofs'],
    ['Bella', 'Gato', '2 meses', 'F', 'bella'], ['Bilu', 'Cachorro', '4 anos', 'M', 'bilu'], ['Jorge', 'Cachorro', '3 anos', 'M', 'jorge'],
    ['Donatello', 'Réptil', '7 anos', 'M', 'donatello'], ['Rantaro', 'Roedor', '2 anos', 'M', 'rantaro'], ['Boris', 'Aves', '3 anos', 'M', 'boris'],
  ];
  final adoptIds = <String>[];
  for (final a in adopt) {
    final ref = await db.collection('adoptions').add({
      'name': a[0], 'species': a[1], 'age': a[2], 'sex': a[3], 'photo': photo(a[4]), 'description': 'Dócil e brincalhão.',
      'city': 'São Paulo', 'postedBy': 'shop1', 'postedByName': 'Mania de Bicho', 'status': 'disponivel',
    });
    adoptIds.add(ref.id);
  }
  await db.collection('users').doc('tutor1').update({'favorites': [adoptIds[0], adoptIds[7]]});

  final chatId = Db.chatIdFor('tutor1', 'vet1');
  await db.collection('chats').doc(chatId).set({
    'participants': ['tutor1', 'vet1'],
    'names': {'tutor1': 'Jiara Martins', 'vet1': 'Vet Amicão'},
    'lastMessage': 'Obrigada!', 'lastSender': 'tutor1', 'updatedAt': ts(day(0, 10, 47)),
  });
  final msgs = [
    ['tutor1', 'Oi, ocorreu um imprevisto e chegarei uns 10 minutinhos atrasada. Tudo bem se eu for ou preciso remarcar?', day(0, 10, 44)],
    ['vet1', 'Bom dia, Jiara! Tudo bem?', day(0, 10, 45)],
    ['vet1', 'Fique tranquila, estaremos à sua espera com a Zuka!', day(0, 10, 46)],
    ['tutor1', 'Obrigada!', day(0, 10, 47)],
  ];
  for (final m in msgs) {
    await db.collection('chats').doc(chatId).collection('messages').add({'senderId': m[0], 'text': m[1], 'createdAt': ts(m[2] as DateTime)});
  }
  await db.collection('chats').doc(Db.chatIdFor('tutor1', 'shop1')).set({
    'participants': ['shop1', 'tutor1'],
    'names': {'tutor1': 'Jiara Martins', 'shop1': 'Mania de Bicho'},
    'lastMessage': 'A Lolla pode ir às 13h30?', 'lastSender': 'shop1', 'updatedAt': ts(day(0, 9, 12)),
  });
  return db;
}

Widget app(Widget home) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

Future<void> precacheAll(WidgetTester t) async {
  final providers = <ImageProvider>{};
  for (final e in find.byType(Image, skipOffstage: false).evaluate()) {
    providers.add((e.widget as Image).image);
  }
  for (final e in find.byType(CircleAvatar, skipOffstage: false).evaluate()) {
    final w = e.widget as CircleAvatar;
    if (w.backgroundImage != null) providers.add(w.backgroundImage!);
  }
  for (final e in find.byType(Container, skipOffstage: false).evaluate()) {
    final d = (e.widget as Container).decoration;
    if (d is BoxDecoration && d.image != null) providers.add(d.image!.image);
  }
  if (providers.isEmpty) return;
  final ctx = t.element(find.byType(MaterialApp));
  await t.runAsync(() async {
    for (final p in providers) {
      await precacheImage(p, ctx);
    }
  });
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await t.pump(const Duration(milliseconds: 100));
  }
  await precacheAll(t);
  await t.pump(const Duration(milliseconds: 400));
  await precacheAll(t);
  await t.pump(const Duration(milliseconds: 400));
}

Future<void> shot(WidgetTester t, String name, Widget Function() home, {String? as, Future<void> Function(WidgetTester)? act}) async {
  debugDisableShadows = false;
  t.view.physicalSize = const Size(1080, 2340);
  t.view.devicePixelRatio = 2.75;
  t.view.padding = const FakeViewPadding(top: 66);
  Db.fs = await t.runAsync(seed) as FirebaseFirestore;
  Session.current.value = as == 'vet' ? vet : (as == 'tutor' ? tutor : null);
  await t.pumpWidget(app(home()));
  await settle(t);
  if (act != null) {
    await act(t);
    await settle(t);
  }
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('../screenshots/$name.png'));
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
  t.view.reset();
  debugDisableShadows = true;
}

Future<void> Function(WidgetTester) tapKey(String key) => (t) async {
      await t.tap(find.byKey(Key(key)).first);
    };

void main() {
  LoginHero.enableVideo = false;
  setUpAll(loadFonts);

  testWidgets('01 login', (t) => shot(t, '01_login', () => const LoginScreen()));
  testWidgets('02 cadastro', (t) => shot(t, '02_cadastro_prestador', () => const SignupScreen(),
      act: (t) async => t.tap(find.text('Prestador'))));
  testWidgets('03 inicio vida', (t) => shot(t, '03_inicio_vida', () => const TutorShell(), as: 'tutor'));
  testWidgets('04 inicio saude', (t) => shot(t, '04_inicio_saude', () => const TutorShell(), as: 'tutor', act: tapKey('grupo_saude')));
  testWidgets('05 inicio cuidado', (t) => shot(t, '05_inicio_cuidado', () => const TutorShell(), as: 'tutor', act: tapKey('grupo_cuidado')));
  testWidgets('06 inicio produto', (t) => shot(t, '06_inicio_produto', () => const TutorShell(), as: 'tutor', act: tapKey('grupo_produtos')));
  testWidgets('07 menu', (t) => shot(t, '07_menu_tutor', () => const TutorShell(), as: 'tutor', act: tapKey('menu')));
  testWidgets('08 meus pets', (t) => shot(t, '08_meus_pets', () => const MyPetsScreen(), as: 'tutor'));
  testWidgets('09 carteirinha', (t) => shot(t, '09_carteirinha', () => const CarteirinhaScreen(petId: 'zuka'), as: 'tutor'));
  testWidgets('10 historico', (t) => shot(t, '10_historico_clinico', () => const HistoricoScreen(petId: 'athos'), as: 'tutor'));
  testWidgets('11 vacinas', (t) => shot(t, '11_vacinacao', () => const VacinasScreen(petId: 'athos'), as: 'tutor'));
  testWidgets('12 adocao', (t) => shot(t, '12_adocao', () => const AdoptionScreen(), as: 'tutor'));
  testWidgets('13 prestadores', (t) => shot(t, '13_lista_prestadores',
      () => const ProvidersListScreen(title: 'Banho e Tosa', categories: ['Banho e Tosa']), as: 'tutor'));
  testWidgets('14 prestador detalhe', (t) => shot(t, '14_prestador_detalhe', () => ProviderDetailScreen(provider: vet), as: 'tutor'));
  testWidgets('15 agendar', (t) => shot(t, '15_agendar', () => BookingScreen(provider: vet, initialService: 'Veterinário'), as: 'tutor',
      act: (t) async => t.tap(find.text('Athos').first)));
  testWidgets('16 petchat', (t) => shot(t, '16_petchat', () => const ChatListScreen(), as: 'tutor'));
  testWidgets('17 chat', (t) => shot(t, '17_chat', () => ChatScreen(chatId: Db.chatIdFor('tutor1', 'vet1'), otherName: 'Vet Amicão', otherId: 'vet1'), as: 'tutor'));
  testWidgets('18 sos', (t) => shot(t, '18_sos', () => const EmergencyScreen(), as: 'tutor'));
  testWidgets('19 agenda', (t) => shot(t, '19_agenda_tutor', () => const AgendaScreen(), as: 'tutor'));
  testWidgets('20 perfil', (t) => shot(t, '20_perfil_tutor', () => const ProfileScreen(), as: 'tutor'));
  testWidgets('21 novo pet', (t) => shot(t, '21_novo_pet', () => const PetFormScreen(), as: 'tutor'));
  testWidgets('22 prestador inicio', (t) => shot(t, '22_prestador_inicio', () => const ProviderShell(), as: 'vet'));
  testWidgets('23 prestador menu', (t) => shot(t, '23_prestador_menu', () => const ProviderShell(), as: 'vet', act: tapKey('menu')));
}

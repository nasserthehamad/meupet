import 'package:cloud_firestore/cloud_firestore.dart';

import 'location.dart';

DateTime? tsToDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

String two(int n) => n.toString().padLeft(2, '0');
String fmtDate(DateTime? d) => d == null ? '-' : '${two(d.day)}/${two(d.month)}/${d.year}';
String fmtShort(DateTime? d) => d == null ? '-' : '${two(d.day)}/${two(d.month)}';
String fmtTime(DateTime? d) => d == null ? '-' : '${two(d.hour)}:${two(d.minute)}h';

/// R$ 120 · R$ 89,90
String fmtMoney(num v) {
  final s = v.toStringAsFixed(2).replaceAll('.', ',');
  return 'R\$ ${s.endsWith(',00') ? s.substring(0, s.length - 3) : s}';
}

/// Aceita "89,90", "89.90", "R$ 1.200,00".
double? parseMoney(String raw) {
  var s = raw.replaceAll('R\$', '').replaceAll(' ', '').trim();
  if (s.isEmpty) return null;
  if (s.contains(',')) s = s.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(s);
}

String timeAgo(DateTime? d) {
  if (d == null) return '';
  final m = DateTime.now().difference(d).inMinutes;
  if (m < 1) return 'agora';
  if (m < 60) return 'há $m min';
  final h = m ~/ 60;
  if (h < 24) return 'há $h h';
  return fmtDate(d);
}

String ageLabel(DateTime? birth) {
  if (birth == null) return '-';
  final now = DateTime.now();
  int months = (now.year - birth.year) * 12 + now.month - birth.month;
  if (now.day < birth.day) months--;
  if (months < 0) months = 0;
  if (months < 12) return months <= 1 ? '$months mês' : '$months meses';
  final y = months ~/ 12;
  final m = months % 12;
  final ys = y == 1 ? '1 ano' : '$y anos';
  return m == 0 ? ys : '$ys e $m m';
}

class AppUser {
  final String id;
  final String name;
  final String email;
  final String role; // tutor | prestador
  final String? photo;
  final String phone;
  final String city;
  final String businessName;
  final String address;
  final String description;
  final List<String> categories;
  final List<String> favorites;
  final List<String> animals; // espécies atendidas (prestador); vazio = todas
  final String crmv; // registro do veterinário (vai na receita)
  final Map<String, double> prices; // "a partir de" por serviço
  final double? lat;
  final double? lng;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.photo,
    this.phone = '',
    this.city = '',
    this.businessName = '',
    this.address = '',
    this.description = '',
    this.categories = const [],
    this.favorites = const [],
    this.animals = const [],
    this.crmv = '',
    this.prices = const {},
    this.lat,
    this.lng,
  });

  bool get hasLocation => lat != null && lng != null;

  bool get isProvider => role == 'prestador';
  String get displayName => isProvider && businessName.isNotEmpty ? businessName : name;

  factory AppUser.fromDoc(DocumentSnapshot d) {
    final m = (d.data() as Map<String, dynamic>?) ?? {};
    return AppUser(
      id: d.id,
      name: m['name'] ?? '',
      email: m['email'] ?? '',
      role: m['role'] ?? 'tutor',
      photo: m['photo'],
      phone: m['phone'] ?? '',
      city: m['city'] ?? '',
      businessName: m['businessName'] ?? '',
      address: m['address'] ?? '',
      description: m['description'] ?? '',
      categories: List<String>.from(m['categories'] ?? const []),
      favorites: List<String>.from(m['favorites'] ?? const []),
      animals: List<String>.from(m['animals'] ?? const []),
      crmv: m['crmv'] ?? '',
      prices: {
        for (final e in ((m['prices'] as Map?) ?? const {}).entries)
          if (e.value is num) e.key.toString(): (e.value as num).toDouble(),
      },
      lat: (m['lat'] as num?)?.toDouble(),
      lng: (m['lng'] as num?)?.toDouble(),
    );
  }
}

class Pet {
  final String id;
  final String ownerId;
  final String ownerName;
  final String name;
  final String species;
  final String breed;
  final String sex; // M | F
  final DateTime? birthDate;
  final String weight;
  final String height;
  final String? photo;
  final String allergies;
  final String treatments;
  final String food;
  final String plan;
  final String code;

  Pet({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.name,
    required this.species,
    this.breed = '',
    this.sex = 'M',
    this.birthDate,
    this.weight = '',
    this.height = '',
    this.photo,
    this.allergies = '',
    this.treatments = '',
    this.food = '',
    this.plan = '',
    this.code = '',
  });

  factory Pet.fromDoc(DocumentSnapshot d) {
    final m = (d.data() as Map<String, dynamic>?) ?? {};
    return Pet(
      id: d.id,
      ownerId: m['ownerId'] ?? '',
      ownerName: m['ownerName'] ?? '',
      name: m['name'] ?? '',
      species: m['species'] ?? 'Cachorro',
      breed: m['breed'] ?? '',
      sex: m['sex'] ?? 'M',
      birthDate: tsToDate(m['birthDate']),
      weight: m['weight'] ?? '',
      height: m['height'] ?? '',
      photo: m['photo'],
      allergies: m['allergies'] ?? '',
      treatments: m['treatments'] ?? '',
      food: m['food'] ?? '',
      plan: m['plan'] ?? '',
      code: m['code'] ?? '',
    );
  }
}

class Appointment {
  final String id;
  final String tutorId;
  final String tutorName;
  final String petId;
  final String petName;
  final String species;
  final String? petPhoto;
  final String providerId;
  final String providerName;
  final String service;
  final DateTime? dateTime;
  final String status; // pendente | confirmado | recusado | concluido | cancelado
  final String notes;
  final bool taxiPet;
  final String address;

  Appointment({
    required this.id,
    required this.tutorId,
    required this.tutorName,
    required this.petId,
    required this.petName,
    required this.species,
    this.petPhoto,
    required this.providerId,
    required this.providerName,
    required this.service,
    this.dateTime,
    required this.status,
    this.notes = '',
    this.taxiPet = false,
    this.address = '',
  });

  factory Appointment.fromDoc(DocumentSnapshot d) {
    final m = (d.data() as Map<String, dynamic>?) ?? {};
    return Appointment(
      id: d.id,
      tutorId: m['tutorId'] ?? '',
      tutorName: m['tutorName'] ?? '',
      petId: m['petId'] ?? '',
      petName: m['petName'] ?? '',
      species: m['species'] ?? '',
      petPhoto: m['petPhoto'],
      providerId: m['providerId'] ?? '',
      providerName: m['providerName'] ?? '',
      service: m['service'] ?? '',
      dateTime: tsToDate(m['dateTime']),
      status: m['status'] ?? 'pendente',
      notes: m['notes'] ?? '',
      taxiPet: m['taxiPet'] ?? false,
      address: m['address'] ?? '',
    );
  }
}

class Adoption {
  final String id;
  final String name;
  final String species;
  final String age;
  final String sex;
  final String? photo;
  final String description;
  final String city;
  final String postedBy;
  final String postedByName;
  final String status;

  Adoption({
    required this.id,
    required this.name,
    required this.species,
    required this.age,
    required this.sex,
    this.photo,
    required this.description,
    required this.city,
    required this.postedBy,
    required this.postedByName,
    required this.status,
  });

  factory Adoption.fromDoc(DocumentSnapshot d) {
    final m = (d.data() as Map<String, dynamic>?) ?? {};
    return Adoption(
      id: d.id,
      name: m['name'] ?? '',
      species: m['species'] ?? '',
      age: m['age'] ?? '',
      sex: m['sex'] ?? 'M',
      photo: m['photo'],
      description: m['description'] ?? '',
      city: m['city'] ?? '',
      postedBy: m['postedBy'] ?? '',
      postedByName: m['postedByName'] ?? '',
      status: m['status'] ?? 'disponivel',
    );
  }
}

const speciesList = ['Cachorro', 'Gato', 'Coelho', 'Aves', 'Roedor', 'Réptil', 'Peixe', 'Outro'];

const appointmentStatusLabel = {
  'pendente': 'Aguardando',
  'confirmado': 'Confirmado',
  'recusado': 'Recusado',
  'concluido': 'Concluído',
  'cancelado': 'Cancelado',
};


// ======================= Fase 2 =======================

/// Item da receita: medicamento, via (oral, tópico…) e como usar.
class RxItem {
  final String name;
  final String route;
  final String use;
  const RxItem({required this.name, this.route = 'Oral', this.use = ''});
  factory RxItem.fromMap(Map m) => RxItem(name: m['name'] ?? '', route: m['route'] ?? 'Oral', use: m['use'] ?? '');
  Map<String, dynamic> toMap() => {'name': name, 'route': route, 'use': use};
}

const rxRoutes = ['Oral', 'Tópico', 'Injetável', 'Oftálmico', 'Otológico'];

/// Receita ou pedido de exame emitido por um veterinário.
class Prescription {
  final String id;
  final String kind; // receita | exame
  final String petId;
  final String petName;
  final String petSpecies;
  final String petBreed;
  final String petAge;
  final String petWeight;
  final String petHeight;
  final String ownerId;
  final String ownerName;
  final String providerId;
  final String providerName;
  final String professional;
  final String crmv;
  final List<RxItem> items;
  final List<String> exams;
  final String notes;
  final DateTime? consultaDate;
  final DateTime? returnDate;
  final DateTime? signedAt;
  final String code;
  final bool seen;

  const Prescription({
    this.id = '',
    required this.kind,
    required this.petId,
    required this.petName,
    this.petSpecies = '',
    this.petBreed = '',
    this.petAge = '',
    this.petWeight = '',
    this.petHeight = '',
    required this.ownerId,
    this.ownerName = '',
    required this.providerId,
    required this.providerName,
    this.professional = '',
    this.crmv = '',
    this.items = const [],
    this.exams = const [],
    this.notes = '',
    this.consultaDate,
    this.returnDate,
    this.signedAt,
    this.code = '',
    this.seen = false,
  });

  bool get isExam => kind == 'exame';
  String get title => isExam
      ? (exams.isEmpty ? 'Pedido de exame' : exams.join(', '))
      : (items.isEmpty ? 'Receita' : items.map((e) => e.name).join(', '));

  factory Prescription.fromDoc(DocumentSnapshot d) {
    final m = (d.data() as Map<String, dynamic>?) ?? {};
    return Prescription(
      id: d.id,
      kind: m['kind'] ?? 'receita',
      petId: m['petId'] ?? '',
      petName: m['petName'] ?? '',
      petSpecies: m['petSpecies'] ?? '',
      petBreed: m['petBreed'] ?? '',
      petAge: m['petAge'] ?? '',
      petWeight: m['petWeight'] ?? '',
      petHeight: m['petHeight'] ?? '',
      ownerId: m['ownerId'] ?? '',
      ownerName: m['ownerName'] ?? '',
      providerId: m['providerId'] ?? '',
      providerName: m['providerName'] ?? '',
      professional: m['professional'] ?? '',
      crmv: m['crmv'] ?? '',
      items: [for (final i in (m['items'] as List?) ?? const []) RxItem.fromMap(i as Map)],
      exams: List<String>.from(m['exams'] ?? const []),
      notes: m['notes'] ?? '',
      consultaDate: tsToDate(m['consultaDate']),
      returnDate: tsToDate(m['returnDate']),
      signedAt: tsToDate(m['signedAt']),
      code: m['code'] ?? '',
      seen: m['seen'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'kind': kind,
        'petId': petId,
        'petName': petName,
        'petSpecies': petSpecies,
        'petBreed': petBreed,
        'petAge': petAge,
        'petWeight': petWeight,
        'petHeight': petHeight,
        'ownerId': ownerId,
        'ownerName': ownerName,
        'providerId': providerId,
        'providerName': providerName,
        'professional': professional,
        'crmv': crmv,
        'items': [for (final i in items) i.toMap()],
        'exams': exams,
        'notes': notes,
        'consultaDate': consultaDate == null ? null : Timestamp.fromDate(consultaDate!),
        'returnDate': returnDate == null ? null : Timestamp.fromDate(returnDate!),
        'signedAt': signedAt == null ? null : Timestamp.fromDate(signedAt!),
        'code': code,
        'seen': seen,
      };

  /// Texto para compartilhar (WhatsApp).
  String shareText() {
    final b = StringBuffer(isExam ? 'PEDIDO DE EXAMES\n' : 'RECEITUÁRIO PET\n');
    b.writeln('$providerName');
    b.writeln('Pet: $petName${petSpecies.isEmpty ? '' : ' ($petSpecies)'} · Tutor: $ownerName');
    if (consultaDate != null) b.writeln('Consulta: ${fmtDate(consultaDate)}');
    b.writeln();
    if (isExam) {
      for (var i = 0; i < exams.length; i++) {
        b.writeln('${i + 1}. ${exams[i]}');
      }
    } else {
      for (var i = 0; i < items.length; i++) {
        b.writeln('${i + 1}. ${items[i].name} (uso ${items[i].route.toLowerCase()})');
        if (items[i].use.isNotEmpty) b.writeln('   ${items[i].use}');
      }
    }
    if (notes.isNotEmpty) b.writeln('\nObs.: $notes');
    if (returnDate != null) b.writeln('Retorno: ${fmtDate(returnDate)}');
    b.writeln('\n$professional${crmv.isEmpty ? '' : ' · CRMV $crmv'}');
    if (code.isNotEmpty) b.writeln('Assinado eletronicamente em ${fmtDate(signedAt)} · código $code');
    b.write('Emitido pelo app Meu Pet+');
    return b.toString();
  }
}

/// Chamado de SOS do tutor para as clínicas 24h.
class Emergency {
  final String id;
  final String tutorId;
  final String tutorName;
  final String tutorPhone;
  final String petId;
  final String petName;
  final String petSpecies;
  final String? petPhoto;
  final String description;
  final String city;
  final String status; // aberto | aceito | cancelado | encerrado
  final DateTime? createdAt;
  final String acceptedBy;
  final String acceptedByName;
  final String acceptedByPhone;
  final DateTime? acceptedAt;

  const Emergency({
    required this.id,
    required this.tutorId,
    required this.tutorName,
    this.tutorPhone = '',
    required this.petId,
    required this.petName,
    this.petSpecies = '',
    this.petPhoto,
    this.description = '',
    this.city = '',
    required this.status,
    this.createdAt,
    this.acceptedBy = '',
    this.acceptedByName = '',
    this.acceptedByPhone = '',
    this.acceptedAt,
  });

  bool get isActive => status == 'aberto' || status == 'aceito';

  factory Emergency.fromDoc(DocumentSnapshot d) {
    final m = (d.data() as Map<String, dynamic>?) ?? {};
    return Emergency(
      id: d.id,
      tutorId: m['tutorId'] ?? '',
      tutorName: m['tutorName'] ?? '',
      tutorPhone: m['tutorPhone'] ?? '',
      petId: m['petId'] ?? '',
      petName: m['petName'] ?? '',
      petSpecies: m['petSpecies'] ?? '',
      petPhoto: m['petPhoto'],
      description: m['description'] ?? '',
      city: m['city'] ?? '',
      status: m['status'] ?? 'aberto',
      createdAt: tsToDate(m['createdAt']),
      acceptedBy: m['acceptedBy'] ?? '',
      acceptedByName: m['acceptedByName'] ?? '',
      acceptedByPhone: m['acceptedByPhone'] ?? '',
      acceptedAt: tsToDate(m['acceptedAt']),
    );
  }
}

class Review {
  final String id;
  final String providerId;
  final String tutorId;
  final String tutorName;
  final int stars;
  final String text;
  final DateTime? date;
  const Review({
    required this.id,
    required this.providerId,
    required this.tutorId,
    required this.tutorName,
    required this.stars,
    this.text = '',
    this.date,
  });
  factory Review.fromDoc(DocumentSnapshot d) {
    final m = (d.data() as Map<String, dynamic>?) ?? {};
    return Review(
      id: d.id,
      providerId: m['providerId'] ?? '',
      tutorId: m['tutorId'] ?? '',
      tutorName: m['tutorName'] ?? '',
      stars: ((m['stars'] as num?) ?? 0).toInt().clamp(0, 5),
      text: m['text'] ?? '',
      date: tsToDate(m['updatedAt'] ?? m['createdAt']),
    );
  }
}

class RatingInfo {
  final double avg;
  final int count;
  const RatingInfo(this.avg, this.count);
  String get label => avg.toStringAsFixed(1).replaceAll('.', ',');
}

// ======================= Fase 3 =======================

/// Corrida do TaxiPet.
class Ride {
  final String id;
  final String tutorId;
  final String tutorName;
  final String tutorPhone;
  final String petId;
  final String petName;
  final String petSpecies;
  final String? petPhoto;
  final String driverId;
  final String driverName;
  final String driverPhone;
  final String pickup;
  final String destination;
  final DateTime? when;
  final String notes;
  final String status;
  final DateTime? updatedAt;
  // Mapa (corridas novas): partida, destino, rota e preço.
  final double? pickupLat;
  final double? pickupLng;
  final double? destLat;
  final double? destLng;
  final double? km;
  final int? minutes;
  final double? price;
  final double? priceMin;
  final double? priceMax;
  // Posição do motorista ao vivo.
  final double? driverLat;
  final double? driverLng;
  final DateTime? driverAt;

  const Ride({
    required this.id,
    required this.tutorId,
    required this.tutorName,
    this.tutorPhone = '',
    required this.petId,
    required this.petName,
    this.petSpecies = '',
    this.petPhoto,
    required this.driverId,
    required this.driverName,
    this.driverPhone = '',
    required this.pickup,
    required this.destination,
    this.when,
    this.notes = '',
    required this.status,
    this.updatedAt,
    this.pickupLat,
    this.pickupLng,
    this.destLat,
    this.destLng,
    this.km,
    this.minutes,
    this.price,
    this.priceMin,
    this.priceMax,
    this.driverLat,
    this.driverLng,
    this.driverAt,
  });

  /// Pedido aberto: vai para os motoristas perto, o primeiro que aceitar leva.
  bool get isOpen => driverId.isEmpty && status == 'pedida';
  GeoPos? get pickupPos => pickupLat == null || pickupLng == null ? null : GeoPos(pickupLat!, pickupLng!);
  GeoPos? get destPos => destLat == null || destLng == null ? null : GeoPos(destLat!, destLng!);
  GeoPos? get driverPos => driverLat == null || driverLng == null ? null : GeoPos(driverLat!, driverLng!);
  bool get hasMap => pickupPos != null && destPos != null;

  /// Preço combinado, faixa estimada (pedido aberto) ou vazio.
  String get priceLabel {
    if (price != null) return fmtMoney(price!);
    if (priceMin != null && priceMax != null) {
      return priceMin == priceMax ? fmtMoney(priceMin!) : '${fmtMoney(priceMin!)} – ${fmtMoney(priceMax!)}';
    }
    return '';
  }

  static const flow = ['pedida', 'aceita', 'a_caminho', 'pet_a_bordo', 'chegou', 'concluida'];
  bool get isActive => !const ['concluida', 'recusada', 'cancelada'].contains(status);
  int get step => flow.indexOf(status);

  /// Próximo passo do motorista (null quando não há).
  String? get nextStatus {
    final i = step;
    if (i < 1 || i >= flow.length - 1) return null;
    return flow[i + 1];
  }

  factory Ride.fromDoc(DocumentSnapshot d) {
    final m = (d.data() as Map<String, dynamic>?) ?? {};
    return Ride(
      id: d.id,
      tutorId: m['tutorId'] ?? '',
      tutorName: m['tutorName'] ?? '',
      tutorPhone: m['tutorPhone'] ?? '',
      petId: m['petId'] ?? '',
      petName: m['petName'] ?? '',
      petSpecies: m['petSpecies'] ?? '',
      petPhoto: m['petPhoto'],
      driverId: m['driverId'] ?? '',
      driverName: m['driverName'] ?? '',
      driverPhone: m['driverPhone'] ?? '',
      pickup: m['pickup'] ?? '',
      destination: m['destination'] ?? '',
      when: tsToDate(m['when']),
      notes: m['notes'] ?? '',
      status: m['status'] ?? 'pedida',
      updatedAt: tsToDate(m['updatedAt']),
      pickupLat: _d(m['pickupLat']),
      pickupLng: _d(m['pickupLng']),
      destLat: _d(m['destLat']),
      destLng: _d(m['destLng']),
      km: _d(m['km']),
      minutes: (m['minutes'] as num?)?.toInt(),
      price: _d(m['price']),
      priceMin: _d(m['priceMin']),
      priceMax: _d(m['priceMax']),
      driverLat: _d(m['driverLat']),
      driverLng: _d(m['driverLng']),
      driverAt: tsToDate(m['driverAt']),
    );
  }
}

double? _d(dynamic v) => (v as num?)?.toDouble();

/// Chave do preço por km do TaxiPet no perfil do motorista.
const kTaxiKm = 'TaxiPet km';

/// Preço da corrida pelo que o motorista informou: "a partir de" + valor por km.
double? taxiFare(AppUser d, double km) {
  final base = d.prices['TaxiPet'];
  final perKm = d.prices[kTaxiKm];
  if (base == null && perKm == null) return null;
  return (((base ?? 0) + (perKm ?? 0) * km) * 100).roundToDouble() / 100;
}

/// Situação da corrida em texto ("Procurando motorista" quando está aberta).
String rideStatusText(Ride r) => r.isOpen ? 'Procurando motorista' : (rideStatusLabel[r.status] ?? r.status);

const rideStatusLabel = {
  'pedida': 'Aguardando o motorista',
  'aceita': 'Corrida confirmada',
  'a_caminho': 'Motorista a caminho',
  'pet_a_bordo': 'Pet a bordo',
  'chegou': 'Chegou ao destino',
  'concluida': 'Corrida concluída',
  'recusada': 'Recusada pelo motorista',
  'cancelada': 'Cancelada',
};

/// Texto do botão do motorista para avançar a corrida.
const rideActionLabel = {
  'a_caminho': 'Saí para buscar',
  'pet_a_bordo': 'Pet a bordo',
  'chegou': 'Chegou ao destino',
  'concluida': 'Concluir corrida',
};

/// Produto da loja.
class Product {
  final String id;
  final String storeId;
  final String name;
  final double price;
  final String category;
  final String photoUrl;
  final String description;
  final bool available;

  const Product({
    this.id = '',
    required this.storeId,
    required this.name,
    required this.price,
    this.category = '',
    this.photoUrl = '',
    this.description = '',
    this.available = true,
  });

  factory Product.fromDoc(DocumentSnapshot d) {
    final m = (d.data() as Map<String, dynamic>?) ?? {};
    return Product(
      id: d.id,
      storeId: m['storeId'] ?? '',
      name: m['name'] ?? '',
      price: ((m['price'] as num?) ?? 0).toDouble(),
      category: m['category'] ?? '',
      photoUrl: m['photoUrl'] ?? '',
      description: m['description'] ?? '',
      available: m['available'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'storeId': storeId,
        'name': name,
        'price': price,
        'category': category,
        'photoUrl': photoUrl,
        'description': description,
        'available': available,
      };
}

class OrderItem {
  final String productId;
  final String name;
  final double price;
  final int qty;
  const OrderItem({required this.productId, required this.name, required this.price, required this.qty});
  double get total => price * qty;
  factory OrderItem.fromMap(Map m) => OrderItem(
        productId: m['productId'] ?? '',
        name: m['name'] ?? '',
        price: ((m['price'] as num?) ?? 0).toDouble(),
        qty: ((m['qty'] as num?) ?? 1).toInt(),
      );
  Map<String, dynamic> toMap() => {'productId': productId, 'name': name, 'price': price, 'qty': qty};
}

/// Pedido feito na loja (retirada no local, pagamento na loja).
class StoreOrder {
  final String id;
  final String storeId;
  final String storeName;
  final String tutorId;
  final String tutorName;
  final String tutorPhone;
  final String? tutorPhoto;
  final List<OrderItem> items;
  final double total;
  final String pickupName;
  final DateTime? pickupDate;
  final String notes;
  final String nfe;
  final String status;
  final DateTime? createdAt;

  const StoreOrder({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.tutorId,
    required this.tutorName,
    this.tutorPhone = '',
    this.tutorPhoto,
    required this.items,
    required this.total,
    this.pickupName = '',
    this.pickupDate,
    this.notes = '',
    this.nfe = '',
    required this.status,
    this.createdAt,
  });

  bool get isActive => !const ['retirado', 'recusado', 'cancelado'].contains(status);
  int get count => items.fold(0, (a, i) => a + i.qty);

  factory StoreOrder.fromDoc(DocumentSnapshot d) {
    final m = (d.data() as Map<String, dynamic>?) ?? {};
    return StoreOrder(
      id: d.id,
      storeId: m['storeId'] ?? '',
      storeName: m['storeName'] ?? '',
      tutorId: m['tutorId'] ?? '',
      tutorName: m['tutorName'] ?? '',
      tutorPhone: m['tutorPhone'] ?? '',
      tutorPhoto: m['tutorPhoto'],
      items: [for (final i in (m['items'] as List?) ?? const []) OrderItem.fromMap(i as Map)],
      total: ((m['total'] as num?) ?? 0).toDouble(),
      pickupName: m['pickupName'] ?? '',
      pickupDate: tsToDate(m['pickupDate']),
      notes: m['notes'] ?? '',
      nfe: m['nfe'] ?? '',
      status: m['status'] ?? 'novo',
      createdAt: tsToDate(m['createdAt']),
    );
  }
}

const orderStatusLabel = {
  'novo': 'Aguardando a loja',
  'confirmado': 'Confirmado — separando',
  'pronto': 'Pronto para retirada',
  'retirado': 'Retirado',
  'recusado': 'Recusado pela loja',
  'cancelado': 'Cancelado',
};

/// "Avaliação do PET": como o pet se comporta, segundo os prestadores.
class PetNote {
  final String id;
  final String providerId;
  final String providerName;
  final int stars;
  final String text;
  final DateTime? date;
  const PetNote({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.stars,
    this.text = '',
    this.date,
  });
  factory PetNote.fromDoc(DocumentSnapshot d) {
    final m = (d.data() as Map<String, dynamic>?) ?? {};
    return PetNote(
      id: d.id,
      providerId: m['providerId'] ?? '',
      providerName: m['providerName'] ?? '',
      stars: ((m['stars'] as num?) ?? 0).toInt(),
      text: m['text'] ?? '',
      date: tsToDate(m['createdAt']),
    );
  }
}

/// Anexo de mensagem do chat (arquivo no Cloudinary).
class Attachment {
  final String url;
  final String type; // image | pdf | audio | file
  final String name;
  final int seconds; // duração do áudio
  const Attachment({required this.url, required this.type, this.name = '', this.seconds = 0});
  factory Attachment.fromMap(Map m) => Attachment(
        url: m['url'] ?? '',
        type: m['type'] ?? 'file',
        name: m['name'] ?? '',
        seconds: ((m['seconds'] as num?) ?? 0).toInt(),
      );
  Map<String, dynamic> toMap() => {'url': url, 'type': type, 'name': name, 'seconds': seconds};
  String get label => switch (type) {
        'image' => '📷 Foto',
        'pdf' => '📄 ${name.isEmpty ? 'PDF' : name}',
        'audio' => '🎤 Áudio',
        _ => '📎 ${name.isEmpty ? 'Arquivo' : name}',
      };
}

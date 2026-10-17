import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? tsToDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

String two(int n) => n.toString().padLeft(2, '0');
String fmtDate(DateTime? d) => d == null ? '-' : '${two(d.day)}/${two(d.month)}/${d.year}';
String fmtShort(DateTime? d) => d == null ? '-' : '${two(d.day)}/${two(d.month)}';
String fmtTime(DateTime? d) => d == null ? '-' : '${two(d.hour)}:${two(d.minute)}h';

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
  });

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

const speciesList = ['Cachorro', 'Gato', 'Coelho', 'Aves', 'Roedor', 'Réptil', 'Outro'];

const appointmentStatusLabel = {
  'pendente': 'Aguardando',
  'confirmado': 'Confirmado',
  'recusado': 'Recusado',
  'concluido': 'Concluído',
  'cancelado': 'Cancelado',
};

import 'package:flutter/material.dart';

class ServiceCat {
  final String name;
  final IconData icon;
  const ServiceCat(this.name, this.icon);
}

class ServiceGroup {
  final String key;
  final String title;
  final String image;
  final String subtitle;
  final List<ServiceCat> items;
  const ServiceGroup(this.key, this.title, this.subtitle, this.image, this.items);
}

const serviceGroups = <ServiceGroup>[
  ServiceGroup('saude', '+Saúde', 'Cuidar da saúde é cuidar da vida', 'assets/images/cat_saude.jpg', [
    ServiceCat('Veterinário', Icons.medical_services_rounded),
    ServiceCat('Vacinação', Icons.vaccines_rounded),
    ServiceCat('Exames', Icons.biotech_rounded),
    ServiceCat('Farmácia', Icons.medication_rounded),
    ServiceCat('Odontologia', Icons.health_and_safety_rounded),
  ]),
  ServiceGroup('cuidado', '+Cuidado', 'Bem-estar todos os dias', 'assets/images/cat_cuidado.jpg', [
    ServiceCat('Banho e Tosa', Icons.shower_rounded),
    ServiceCat('Hotel', Icons.hotel_rounded),
    ServiceCat('Creche', Icons.child_friendly_rounded),
    ServiceCat('PetSitter', Icons.volunteer_activism_rounded),
    ServiceCat('Adestramento', Icons.sports_rounded),
    ServiceCat('DogWalker', Icons.directions_walk_rounded),
    ServiceCat('TaxiPet', Icons.local_taxi_rounded),
  ]),
  ServiceGroup('produtos', '+Produtos', 'Tudo que seu pet precisa', 'assets/images/cat_produtos.jpg', [
    ServiceCat('Petshop', Icons.storefront_rounded),
    ServiceCat('Ração', Icons.rice_bowl_rounded),
    ServiceCat('Acessórios', Icons.shopping_bag_rounded),
  ]),
];

List<ServiceCat> get allServiceCats => [for (final g in serviceGroups) ...g.items];

IconData iconForService(String name) {
  for (final c in allServiceCats) {
    if (c.name == name) return c.icon;
  }
  return Icons.pets_rounded;
}

IconData iconForSpecies(String s) {
  switch (s) {
    case 'Aves':
      return Icons.flutter_dash;
    default:
      return Icons.pets_rounded;
  }
}

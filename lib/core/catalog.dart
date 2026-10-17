import 'package:flutter/material.dart';

/// O que acontece ao tocar num item da grade de categorias.
enum CatKind {
  /// Lista os prestadores desta categoria.
  provider,

  /// Profissionais perto de mim.
  nearby,

  /// Avaliações (prestadores mais bem avaliados do grupo).
  reviews,

  /// Agendar (escolher prestador e marcar).
  schedule,

  /// Custo médio dos serviços.
  averageCost,
}

class ServiceCat {
  final String name;
  final IconData icon;

  /// Ícone desenhado do protótipo (branco), quando existir.
  final String? asset;
  final CatKind kind;
  const ServiceCat(this.name, this.icon, [this.asset, this.kind = CatKind.provider]);

  bool get isProviderCategory => kind == CatKind.provider;
}

class ServiceGroup {
  final String key;
  final String title; // "+Saúde"
  final String heroTitle; // "+SAÚDE"
  final String subtitle;
  final String image; // foto do cartão na Início
  final String hero; // foto grande do carrossel
  final Color color; // cor dos círculos
  final List<ServiceCat> items; // grade 4x2 do protótipo

  /// Categorias extras que o prestador pode escolher (não aparecem na grade).
  final List<ServiceCat> extra;
  const ServiceGroup(this.key, this.title, this.heroTitle, this.subtitle, this.image, this.hero, this.color, this.items,
      [this.extra = const []]);

  List<ServiceCat> get providerCategories => [...items.where((c) => c.isProviderCategory), ...extra];
}

const _i = 'assets/icons/';

const kSaudeColor = Color(0xFF1B9AAA);
const kCuidadoColor = Color(0xFFEA7A2F);
const kProdutoColor = Color(0xFF5E7A1C);

const serviceGroups = <ServiceGroup>[
  ServiceGroup(
    'saude',
    '+Saúde',
    '+SAÚDE',
    'Cuidar da saúde é cuidar da vida',
    'assets/images/cat_saude.jpg',
    'assets/images/hero_saude.jpg',
    kSaudeColor,
    [
      ServiceCat('Veterinário', Icons.medical_services_rounded, '${_i}veterinario.png'),
      ServiceCat('Odontologia', Icons.health_and_safety_rounded, '${_i}odontologia.png'),
      ServiceCat('Exames', Icons.biotech_rounded, '${_i}exames.png'),
      ServiceCat('Nutrição', Icons.restaurant_rounded, '${_i}nutricao.png'),
      ServiceCat('Profissionais perto de mim', Icons.place_rounded, '${_i}perto.png', CatKind.nearby),
      ServiceCat('Avaliações', Icons.thumb_up_rounded, '${_i}avaliacoes.png', CatKind.reviews),
      ServiceCat('Agendar', Icons.event_available_rounded, '${_i}agendar.png', CatKind.schedule),
      ServiceCat('Custo médio', Icons.payments_rounded, '${_i}custo.png', CatKind.averageCost),
    ],
    [
      ServiceCat('Vacinação', Icons.vaccines_rounded),
      ServiceCat('Emergência 24h', Icons.emergency_rounded),
    ],
  ),
  ServiceGroup(
    'cuidado',
    '+Cuidado',
    '+CUIDADO',
    'Bem-estar todos os dias',
    'assets/images/cat_cuidado.jpg',
    'assets/images/hero_cuidado.jpg',
    kCuidadoColor,
    [
      ServiceCat('Hotel', Icons.hotel_rounded, '${_i}hotel.png'),
      ServiceCat('Creche', Icons.child_friendly_rounded, '${_i}creche.png'),
      ServiceCat('PetSitter', Icons.volunteer_activism_rounded, '${_i}petsitter.png'),
      ServiceCat('Adestramento', Icons.sports_rounded, '${_i}adestramento.png'),
      ServiceCat('TaxiPet', Icons.local_taxi_rounded, '${_i}taxipet.png'),
      ServiceCat('Farmácia', Icons.medication_rounded, '${_i}farmacia.png'),
      ServiceCat('Banho e Tosa', Icons.shower_rounded, '${_i}banho_tosa.png'),
      ServiceCat('DogWalker', Icons.directions_walk_rounded, '${_i}dogwalker.png'),
    ],
  ),
  ServiceGroup(
    'produtos',
    '+Produtos',
    '+PRODUTO',
    'Tudo que seu pet precisa',
    'assets/images/cat_produtos.jpg',
    'assets/images/hero_produto.jpg',
    kProdutoColor,
    [
      ServiceCat('Ração', Icons.rice_bowl_rounded, '${_i}racao.png'),
      ServiceCat('Suplementos', Icons.medication_liquid_rounded, '${_i}suplementos.png'),
      ServiceCat('Roupas e Acessórios', Icons.checkroom_rounded, '${_i}roupas.png'),
      ServiceCat('Higiene e Limpeza', Icons.cleaning_services_rounded, '${_i}higiene.png'),
      ServiceCat('Brinquedos', Icons.toys_rounded, '${_i}brinquedos.png'),
      ServiceCat('Cama e Casa', Icons.bed_rounded, '${_i}cama_casa.png'),
      ServiceCat('Transporte', Icons.local_shipping_rounded, '${_i}transporte.png'),
      ServiceCat('Avaliações', Icons.thumb_up_rounded, '${_i}avaliacoes.png', CatKind.reviews),
    ],
  ),
];

/// Todas as categorias que um prestador pode oferecer.
List<ServiceCat> get allServiceCats => [for (final g in serviceGroups) ...g.providerCategories];

ServiceCat? findCat(String name) {
  for (final c in allServiceCats) {
    if (c.name == name) return c;
  }
  return null;
}

ServiceGroup? groupOfCategory(String name) {
  for (final g in serviceGroups) {
    if (g.providerCategories.any((c) => c.name == name)) return g;
  }
  return null;
}

IconData iconForService(String name) => findCat(name)?.icon ?? Icons.pets_rounded;

IconData iconForSpecies(String s) {
  switch (s) {
    case 'Aves':
      return Icons.flutter_dash;
    default:
      return Icons.pets_rounded;
  }
}

/// Categorias de animal da tela inicial (com foto, como no protótipo).
const animalCategories = <(String label, String species, String image)>[
  ('Gato', 'Gato', 'assets/images/animal_gato.jpg'),
  ('Cachorro', 'Cachorro', 'assets/images/animal_cachorro.jpg'),
  ('Coelho', 'Coelho', 'assets/images/animal_coelho.jpg'),
  ('Aves', 'Aves', 'assets/images/animal_passaro.jpg'),
];

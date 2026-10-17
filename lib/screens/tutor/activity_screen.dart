import 'package:flutter/material.dart';

import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../common/ride_screens.dart';
import '../common/store_screens.dart';

/// Tutor: corridas do TaxiPet e pedidos nas lojas.
class ActivityScreen extends StatelessWidget {
  final int initialTab;
  const ActivityScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        body: Column(children: [
          PetHeader(
            showBack: true,
            title: 'Corridas e Pedidos',
            photo: Session.current.value?.photo,
            bottom: const TabBar(
              labelColor: AppColors.teal,
              indicatorColor: AppColors.orange,
              unselectedLabelColor: AppColors.muted,
              tabs: [
                Tab(icon: Icon(Icons.local_taxi_rounded), text: 'TaxiPet'),
                Tab(icon: Icon(Icons.shopping_bag_rounded), text: 'Pedidos'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(children: [
              StreamBuilder<List<Ride>>(
                stream: Db.tutorRides(Session.uid),
                builder: (context, snap) {
                  final all = snap.data ?? [];
                  final active = all.where((r) => r.isActive).toList();
                  final past = all.where((r) => !r.isActive).toList().reversed.toList();
                  return _list(
                    loading: !snap.hasData,
                    empty: 'Nenhuma corrida ainda.\nPeça em +Cuidado › TaxiPet.',
                    icon: Icons.local_taxi_rounded,
                    children: [
                      if (active.isNotEmpty) ...[const SectionTitle('Em andamento'), for (final r in active) _pad(RideTile(r: r))],
                      if (past.isNotEmpty) ...[const SectionTitle('Anteriores'), for (final r in past) _pad(RideTile(r: r))],
                    ],
                  );
                },
              ),
              StreamBuilder<List<StoreOrder>>(
                stream: Db.tutorOrders(Session.uid),
                builder: (context, snap) {
                  final all = snap.data ?? [];
                  final active = all.where((o) => o.isActive).toList();
                  final past = all.where((o) => !o.isActive).toList();
                  return _list(
                    loading: !snap.hasData,
                    empty: 'Nenhum pedido ainda.\nEscolha uma loja em +Produto.',
                    icon: Icons.shopping_bag_rounded,
                    children: [
                      if (active.isNotEmpty) ...[const SectionTitle('Em andamento'), for (final o in active) _pad(OrderTile(o: o))],
                      if (past.isNotEmpty) ...[const SectionTitle('Anteriores'), for (final o in past) _pad(OrderTile(o: o))],
                    ],
                  );
                },
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _pad(Widget w) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: w);

  Widget _list({required bool loading, required String empty, required IconData icon, required List<Widget> children}) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (children.isEmpty) return EmptyState(icon: icon, text: empty);
    return ListView(padding: const EdgeInsets.only(bottom: 40), children: children);
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/catalog.dart';
import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/uploads.dart';
import '../../widgets/common.dart';
import 'prescription_screens.dart' show cachedUser;
import 'ride_screens.dart' show callPhone, openChatWith, openMap;

/// Foto do produto (Cloudinary) com reserva quando não há foto.
class ProductPhoto extends StatelessWidget {
  final String url;
  final double size;
  final double radius;
  const ProductPhoto({super.key, required this.url, this.size = 64, this.radius = 14});
  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      color: const Color(0xFFEFF3F3),
      child: Icon(Icons.inventory_2_rounded, color: kProdutoColor.withValues(alpha: 0.6), size: size * 0.45),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url.isEmpty
          ? fallback
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
              loadingBuilder: (c, child, p) => p == null ? child : fallback,
            ),
    );
  }
}

// ============================================================ vitrine (tutor)

class StoreScreen extends StatefulWidget {
  final AppUser store;
  const StoreScreen({super.key, required this.store});
  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final Map<String, int> _cart = {};
  String? _cat;
  String _q = '';

  void _add(Product p, int d) => setState(() {
        final n = (_cart[p.id] ?? 0) + d;
        if (n <= 0) {
          _cart.remove(p.id);
        } else {
          _cart[p.id] = n;
        }
      });

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return Scaffold(
      body: StreamBuilder<List<Product>>(
        stream: Db.storeProducts(s.id),
        builder: (context, snap) {
          final all = (snap.data ?? []).where((p) => p.available).toList();
          final cats = {for (final p in all) if (p.category.isNotEmpty) p.category}.toList()..sort();
          final q = _q.trim().toLowerCase();
          final list = all.where((p) => (_cat == null || p.category == _cat) && (q.isEmpty || p.name.toLowerCase().contains(q))).toList();
          final items = [
            for (final p in all)
              if ((_cart[p.id] ?? 0) > 0) OrderItem(productId: p.id, name: p.name, price: p.price, qty: _cart[p.id]!),
          ];
          final total = items.fold<double>(0, (a, i) => a + i.total);
          return Stack(children: [
            ListView(
              padding: EdgeInsets.zero,
              children: [
                PetHeader(showBack: true, title: s.displayName, subtitle: 'Retirada na loja', photo: s.photo, fallbackIcon: Icons.storefront_rounded),
                SnakeBand(
                  index: 1,
                  roundBottom: false,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: TextField(
                        onChanged: (v) => setState(() => _q = v),
                        decoration: inputDeco('Buscar produto', icon: Icons.search_rounded),
                      ),
                    ),
                    if (cats.length > 1)
                      SizedBox(
                        height: 50,
                        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.only(top: 8), children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(label: const Text('Tudo'), selected: _cat == null, onSelected: (_) => setState(() => _cat = null)),
                          ),
                          for (final c in cats)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(label: Text(c), selected: _cat == c, onSelected: (_) => setState(() => _cat = c)),
                            ),
                        ]),
                      ),
                    const SizedBox(height: 8),
                    if (!snap.hasData)
                      const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                    else if (all.isEmpty)
                      const EmptyState(icon: Icons.inventory_2_rounded, text: 'Esta loja ainda não cadastrou produtos.\nUse o chat para pedir.')
                    else
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.66,
                        children: [for (final p in list) _ProductCard(p: p, qty: _cart[p.id] ?? 0, onAdd: (d) => _add(p, d))],
                      ),
                  ]),
                ),
              ],
            ),
            if (items.isNotEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16 + MediaQuery.paddingOf(context).bottom,
                child: SizedBox(
                  height: 56,
                  child: FilledButton(
                    key: const Key('ver_pedido'),
                    style: FilledButton.styleFrom(
                      backgroundColor: kProdutoColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CheckoutScreen(store: s, products: all, cart: _cart)),
                      );
                      if (mounted) setState(() {});
                    },
                    child: Row(children: [
                      const Icon(Icons.shopping_bag_rounded),
                      const SizedBox(width: 10),
                      Text('Ver pedido · ${items.fold<int>(0, (a, i) => a + i.qty)} item(ns)',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const Spacer(),
                      Text(fmtMoney(total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ]),
                  ),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product p;
  final int qty;
  final ValueChanged<int> onAdd;
  const _ProductCard({required this.p, required this.qty, required this.onAdd});
  @override
  Widget build(BuildContext context) {
    return WhiteBlock(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: LayoutBuilder(builder: (c, k) => ProductPhoto(url: p.photoUrl, size: k.maxWidth, radius: 14))),
        const SizedBox(height: 6),
        Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, height: 1.2)),
        const SizedBox(height: 2),
        Text(fmtMoney(p.price), style: const TextStyle(fontWeight: FontWeight.w800, color: kProdutoColor, fontSize: 15)),
        const SizedBox(height: 4),
        qty == 0
            ? SizedBox(
                height: 34,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.orange, padding: EdgeInsets.zero),
                  onPressed: () => onAdd(1),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Adicionar'),
                ),
              )
            : _Stepper(qty: qty, onAdd: onAdd),
      ]),
    );
  }
}

class _Stepper extends StatelessWidget {
  final int qty;
  final ValueChanged<int> onAdd;
  const _Stepper({required this.qty, required this.onAdd});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(border: Border.all(color: AppColors.orange, width: 1.5), borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        IconButton(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          onPressed: () => onAdd(-1),
          icon: Icon(qty == 1 ? Icons.delete_outline_rounded : Icons.remove_rounded, color: AppColors.orange, size: 18),
        ),
        Expanded(child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800))),
        IconButton(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          onPressed: () => onAdd(1),
          icon: const Icon(Icons.add_rounded, color: AppColors.orange, size: 18),
        ),
      ]),
    );
  }
}

// ============================================================ fechar pedido

class CheckoutScreen extends StatefulWidget {
  final AppUser store;
  final List<Product> products;
  final Map<String, int> cart;
  const CheckoutScreen({super.key, required this.store, required this.products, required this.cart});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late final _pickup = TextEditingController(text: Session.current.value?.name ?? '');
  final _notes = TextEditingController();
  DateTime? _date;
  bool _saving = false;

  List<OrderItem> get _items => [
        for (final p in widget.products)
          if ((widget.cart[p.id] ?? 0) > 0) OrderItem(productId: p.id, name: p.name, price: p.price, qty: widget.cart[p.id]!),
      ];

  Future<void> _send() async {
    if (_items.isEmpty) return;
    if (_pickup.text.trim().isEmpty) {
      showSnack(context, 'Diga quem vai retirar o pedido.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final id = await Db.placeOrder(store: widget.store, items: _items, pickupName: _pickup.text, pickupDate: _date, notes: _notes.text);
      widget.cart.clear();
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OrderScreen(orderId: id)));
    } catch (e) {
      if (mounted) showSnack(context, 'Não foi possível enviar o pedido: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final total = items.fold<double>(0, (a, i) => a + i.total);
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          PetHeader(showBack: true, title: 'Seu pedido', subtitle: widget.store.displayName, photo: widget.store.photo, fallbackIcon: Icons.storefront_rounded),
          SnakeBand(
            index: 1,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final p in widget.products)
                if ((widget.cart[p.id] ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      ProductPhoto(url: p.photoUrl, size: 52),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(fmtMoney(p.price * widget.cart[p.id]!), style: const TextStyle(color: kProdutoColor, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                      SizedBox(
                        width: 112,
                        child: _Stepper(
                          qty: widget.cart[p.id]!,
                          onAdd: (d) => setState(() {
                            final n = widget.cart[p.id]! + d;
                            if (n <= 0) {
                              widget.cart.remove(p.id);
                            } else {
                              widget.cart[p.id] = n;
                            }
                          }),
                        ),
                      ),
                    ]),
                  ),
              const Divider(height: 24),
              Row(children: [
                const Expanded(child: Text('Total', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
                Text(fmtMoney(total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kProdutoColor)),
              ]),
              const Text('Pagamento na loja, na hora da retirada.', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ]),
          ),
          SnakeBand(
            index: 2,
            roundBottom: false,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 50),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(
                controller: _pickup,
                textCapitalization: TextCapitalization.words,
                decoration: inputDeco('Quem vai retirar?', icon: Icons.person_pin_rounded),
              ),
              const SizedBox(height: 10),
              WhiteBlock(
                margin: EdgeInsets.zero,
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.event_rounded, color: AppColors.teal),
                  title: Text(_date == null ? 'Quando pretende retirar? (opcional)' : 'Retirada em ${fmtDate(_date)}'),
                  onTap: () async {
                    final now = DateTime.now();
                    final d = await pickDate(context, initial: _date ?? now, first: DateTime(now.year, now.month, now.day));
                    if (d != null) setState(() => _date = d);
                  },
                ),
              ),
              const SizedBox(height: 10),
              TextField(controller: _notes, maxLines: 2, decoration: inputDeco('Observações (opcional)')),
              const SizedBox(height: 18),
              OrangeButton(
                label: 'Enviar pedido',
                icon: Icons.send_rounded,
                loading: _saving,
                onPressed: items.isEmpty ? null : _send,
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ============================================================ acompanhar pedido

class OrderScreen extends StatelessWidget {
  final String orderId;
  const OrderScreen({super.key, required this.orderId});

  static const _flow = ['novo', 'confirmado', 'pronto', 'retirado'];
  static const _labels = {'novo': 'Pedido enviado', 'confirmado': 'Confirmado — separando', 'pronto': 'Pronto para retirada', 'retirado': 'Retirado'};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<StoreOrder>(
        stream: Db.orderStream(orderId),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final o = snap.data!;
          final store = Session.uid == o.storeId;
          final cur = _flow.indexOf(o.status);
          return FutureBuilder<AppUser?>(
            future: cachedUser(store ? o.tutorId : o.storeId),
            builder: (context, us) {
              final other = us.data;
              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  PetHeader(
                    showBack: true,
                    title: store ? 'Pedido de ${o.tutorName.split(' ').first}' : 'Meu pedido',
                    subtitle: orderStatusLabel[o.status],
                    photo: other?.photo,
                    fallbackIcon: store ? Icons.person_rounded : Icons.storefront_rounded,
                  ),
                  SnakeBand(
                    index: 1,
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (cur < 0)
                        Text(orderStatusLabel[o.status] ?? o.status, style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w700))
                      else
                        for (var i = 0; i < _flow.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(children: [
                              Icon(
                                i < cur ? Icons.check_circle_rounded : (i == cur ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded),
                                color: i <= cur ? kProdutoColor : const Color(0xFFCBD1D3),
                              ),
                              const SizedBox(width: 10),
                              Text(_labels[_flow[i]]!,
                                  style: TextStyle(
                                    fontWeight: i == cur ? FontWeight.w800 : FontWeight.w500,
                                    color: i <= cur ? const Color(0xFF3E4446) : AppColors.muted,
                                  )),
                            ]),
                          ),
                    ]),
                  ),
                  SnakeBand(
                    index: 2,
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      for (final i in o.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            Text('${i.qty}×  ', style: const TextStyle(fontWeight: FontWeight.w700)),
                            Expanded(child: Text(i.name)),
                            Text(fmtMoney(i.total)),
                          ]),
                        ),
                      const Divider(height: 20),
                      Row(children: [
                        const Expanded(child: Text('Total (pagar na loja)', style: TextStyle(fontWeight: FontWeight.w700))),
                        Text(fmtMoney(o.total), style: const TextStyle(fontWeight: FontWeight.w800, color: kProdutoColor, fontSize: 17)),
                      ]),
                      const SizedBox(height: 10),
                      _kv('Cliente', o.tutorName),
                      _kv('Retirada', o.pickupName.isEmpty ? '-' : o.pickupName),
                      _kv('Data da retirada', o.pickupDate == null ? 'a combinar' : fmtDate(o.pickupDate)),
                      _kv('NFe', o.nfe.isEmpty ? '-' : o.nfe),
                      if (o.notes.isNotEmpty) _kv('Obs.', o.notes),
                    ]),
                  ),
                  SnakeBand(
                    index: 3,
                    roundBottom: false,
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 50),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Wrap(alignment: WrapAlignment.spaceEvenly, spacing: 10, runSpacing: 8, children: [
                        RoundAction(
                          icon: Icons.chat_rounded,
                          label: 'Conversar',
                          color: AppColors.teal,
                          onTap: () => openChatWith(context, store ? o.tutorId : o.storeId, store ? o.tutorName : o.storeName),
                        ),
                        RoundAction(
                          icon: Icons.call_rounded,
                          label: 'Ligar',
                          color: AppColors.green,
                          onTap: () => callPhone(context, store ? o.tutorPhone : (other?.phone ?? ''), store ? o.tutorName : o.storeName),
                        ),
                        if (!store && other != null && (other.address.isNotEmpty || other.hasLocation))
                          RoundAction(
                            icon: Icons.place_rounded,
                            label: 'Local',
                            color: AppColors.red,
                            onTap: () => openMap(other.hasLocation ? '${other.lat},${other.lng}' : '${other.address}, ${other.city}'),
                          ),
                        if (store && o.isActive)
                          RoundAction(
                            icon: Icons.receipt_rounded,
                            label: 'NFe',
                            color: AppColors.brown,
                            onTap: () => _askNfe(context, o),
                          ),
                        if (o.isActive && o.status != 'pronto')
                          RoundAction(
                            icon: Icons.edit_calendar_rounded,
                            label: 'Reagendar',
                            color: AppColors.orange,
                            onTap: () => rescheduleOrder(context, o),
                          ),
                      ]),
                      const SizedBox(height: 16),
                      ..._mainActions(context, o, store),
                    ]),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  List<Widget> _mainActions(BuildContext context, StoreOrder o, bool store) {
    if (!o.isActive) return const [];
    if (store) {
      final next = {'novo': 'confirmado', 'confirmado': 'pronto', 'pronto': 'retirado'}[o.status];
      final label = {'confirmado': 'Confirmar pedido', 'pronto': 'Pronto para retirada', 'retirado': 'Cliente retirou'}[next];
      return [
        if (next != null)
          OrangeButton(label: label!, icon: Icons.check_rounded, onPressed: () => Db.updateOrder(o, {'status': next})),
        if (o.status == 'novo')
          TextButton(
            onPressed: () async {
              if (await confirm(context, 'Recusar pedido?', 'O cliente será avisado.', ok: 'Recusar')) {
                await Db.updateOrder(o, {'status': 'recusado'});
              }
            },
            child: const Text('Recusar', style: TextStyle(color: AppColors.red)),
          ),
      ];
    }
    if (o.status == 'novo') {
      return [
        TextButton(
          onPressed: () async {
            if (await confirm(context, 'Cancelar pedido?', 'A loja será avisada.', ok: 'Cancelar pedido')) {
              await Db.updateOrder(o, {'status': 'cancelado'});
            }
          },
          child: const Text('Cancelar pedido', style: TextStyle(color: AppColors.muted)),
        ),
      ];
    }
    return const [];
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 130, child: Text(k, style: const TextStyle(color: AppColors.muted))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}

Future<void> rescheduleOrder(BuildContext context, StoreOrder o) async {
  final now = DateTime.now();
  final d = await pickDate(context, initial: o.pickupDate ?? now, first: DateTime(now.year, now.month, now.day));
  if (d == null) return;
  await Db.updateOrder(o, {
    'pickupDate': Timestamp.fromDate(d),
    if (o.status == 'novo' && Session.uid == o.storeId) 'status': 'confirmado',
  });
  if (context.mounted) showSnack(context, 'Retirada marcada para ${fmtDate(d)}.');
}

Future<void> _askNfe(BuildContext context, StoreOrder o) async {
  final c = TextEditingController(text: o.nfe);
  final v = await showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Número da NFe'),
      content: TextField(controller: c, autofocus: true, textCapitalization: TextCapitalization.characters, decoration: inputDeco('Ex.: NB2540')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('Salvar')),
      ],
    ),
  );
  if (v == null) return;
  await Db.updateOrder(o, {'nfe': v});
}

/// Item de pedido em listas (loja e tutor).
class OrderTile extends StatelessWidget {
  final StoreOrder o;
  final bool storeView;
  final List<Widget> actions;
  const OrderTile({super.key, required this.o, this.storeView = false, this.actions = const []});
  @override
  Widget build(BuildContext context) {
    const st = TextStyle(fontSize: 12, color: Color(0xFF6B7477), height: 1.25);
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderScreen(orderId: o.id))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          DateBadge(o.pickupDate ?? o.createdAt, big: true),
          const SizedBox(width: 6),
          storeView
              ? PhotoAvatar(photo: o.tutorPhoto, size: 46, border: Colors.white, fallbackIcon: Icons.person_rounded)
              : const CircleAvatar(radius: 23, backgroundColor: Colors.white, child: Icon(Icons.shopping_bag_rounded, color: kProdutoColor)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(storeView ? 'Cliente: ${o.tutorName}' : o.storeName,
                  style: st.copyWith(color: AppColors.text, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('NFe: ${o.nfe.isEmpty ? '-' : o.nfe}', style: st),
              Text(storeView ? 'Retirada: ${o.pickupName.isEmpty ? '-' : o.pickupName}' : '${o.count} item(ns) · ${fmtMoney(o.total)}',
                  style: st, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (!storeView)
                Text(orderStatusLabel[o.status] ?? '', style: st.copyWith(color: AppColors.orange, fontSize: 11)),
            ]),
          ),
          ...actions,
        ]),
      ),
    );
  }
}

// ============================================================ meus produtos (loja)

class ManageProductsScreen extends StatelessWidget {
  const ManageProductsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('novo_produto'),
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductFormScreen())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo produto'),
      ),
      body: StreamBuilder<List<Product>>(
        stream: Db.storeProducts(Session.uid),
        builder: (context, snap) {
          final list = snap.data ?? [];
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              PetHeader(showBack: true, title: 'Meus Produtos', photo: Session.current.value?.photo, fallbackIcon: Icons.storefront_rounded),
              SnakeBand(
                index: 1,
                roundBottom: false,
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 100),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (!snap.hasData)
                    const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                  else if (list.isEmpty)
                    const EmptyState(icon: Icons.inventory_2_rounded, text: 'Cadastre seus produtos para os tutores fazerem pedidos.')
                  else
                    for (final p in list)
                      WhiteBlock(
                        padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                        child: InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductFormScreen(product: p))),
                          child: Row(children: [
                            ProductPhoto(url: p.photoUrl, size: 56),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text('${fmtMoney(p.price)}${p.category.isEmpty ? '' : ' · ${p.category}'}',
                                    style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                              ]),
                            ),
                            Switch(
                              value: p.available,
                              activeThumbColor: kProdutoColor,
                              onChanged: (v) => Db.products.doc(p.id).update({'available': v}),
                            ),
                          ]),
                        ),
                      ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ProductFormScreen extends StatefulWidget {
  final Product? product;
  const ProductFormScreen({super.key, this.product});
  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  late final _name = TextEditingController(text: widget.product?.name);
  late final _price = TextEditingController(text: widget.product == null ? '' : fmtMoney(widget.product!.price).replaceAll('R\$ ', ''));
  late final _desc = TextEditingController(text: widget.product?.description);
  late String _cat = widget.product?.category ?? '';
  late String _photo = widget.product?.photoUrl ?? '';
  late bool _available = widget.product?.available ?? true;
  bool _uploading = false;
  bool _saving = false;

  Future<void> _pickPhoto() async {
    if (!Uploads.enabled) {
      showSnack(context, 'O envio de fotos ainda está sendo configurado.', error: true);
      return;
    }
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 900, maxHeight: 900, imageQuality: 75);
    if (x == null) return;
    setState(() => _uploading = true);
    try {
      final a = await Uploads.upload(await x.readAsBytes(), x.name.isEmpty ? 'produto.jpg' : x.name, folder: 'meupet/produtos');
      if (mounted) setState(() => _photo = a.url);
    } catch (e) {
      if (mounted) showSnack(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    final price = parseMoney(_price.text);
    if (_name.text.trim().isEmpty || price == null) {
      showSnack(context, 'Informe o nome e o preço.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await Db.saveProduct(Product(
        id: widget.product?.id ?? '',
        storeId: Session.uid,
        name: _name.text.trim(),
        price: price,
        category: _cat,
        photoUrl: _photo,
        description: _desc.text.trim(),
        available: _available,
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, 'Erro ao salvar: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = storeCategoryNames.toList();
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          PetHeader(showBack: true, title: widget.product == null ? 'Novo produto' : 'Editar produto', photo: Session.current.value?.photo),
          SnakeBand(
            index: 1,
            roundBottom: false,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 50),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(
                child: GestureDetector(
                  onTap: _uploading ? null : _pickPhoto,
                  child: Stack(alignment: Alignment.center, children: [
                    ProductPhoto(url: _photo, size: 140, radius: 22),
                    if (_uploading) const CircularProgressIndicator(),
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: CircleAvatar(
                        radius: 17,
                        backgroundColor: AppColors.orange,
                        child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              TextField(controller: _name, textCapitalization: TextCapitalization.sentences, decoration: inputDeco('Nome do produto')),
              const SizedBox(height: 10),
              TextField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: inputDeco('Preço').copyWith(prefixText: 'R\$ '),
              ),
              const SizedBox(height: 12),
              const Text('Categoria', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 2, children: [
                for (final c in cats)
                  ChoiceChip(label: Text(c), selected: _cat == c, onSelected: (_) => setState(() => _cat = c)),
              ]),
              const SizedBox(height: 10),
              TextField(controller: _desc, maxLines: 3, decoration: inputDeco('Descrição (opcional)')),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _available,
                activeThumbColor: kProdutoColor,
                title: const Text('Disponível para pedidos'),
                onChanged: (v) => setState(() => _available = v),
              ),
              const SizedBox(height: 10),
              OrangeButton(label: 'Salvar', icon: Icons.check_rounded, loading: _saving, onPressed: _save),
              if (widget.product != null)
                TextButton.icon(
                  onPressed: () async {
                    if (await confirm(context, 'Excluir produto?', 'Ele some da vitrine.', ok: 'Excluir')) {
                      await Db.deleteProduct(widget.product!.id);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
                  label: const Text('Excluir produto', style: TextStyle(color: AppColors.red)),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

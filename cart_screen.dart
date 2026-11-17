import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../state.dart';
import 'home_screen.dart' show productImage;

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  Future<void> _pay(BuildContext context, CartState cart) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Api.post('/orders', {
        'items': cart.items.values.map((i) => {'productId': i.product.id, 'qty': i.qty}).toList(),
      });
      cart.clear();
      messenger.showSnackBar(const SnackBar(content: Text('¡Compra simulada exitosa! Revisa "Mis pedidos".')));
    } on ApiError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Widget _row(String l, String v, {bool big = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(l, style: TextStyle(fontSize: big ? 18 : 14, fontWeight: big ? FontWeight.bold : FontWeight.normal)),
          Text(v, style: TextStyle(fontSize: big ? 20 : 14, fontWeight: big ? FontWeight.bold : FontWeight.normal, color: big ? Colors.indigo : null)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();
    if (cart.items.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.black26),
          SizedBox(height: 12),
          Text('Tu carrito está vacío', style: TextStyle(fontSize: 18)),
          Text('Agrega productos desde el inicio'),
        ]),
      );
    }
    return Column(children: [
      Expanded(
        child: ListView(children: [
          for (final i in cart.items.values)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              leading: SizedBox(width: 56, height: 56, child: ClipRRect(borderRadius: BorderRadius.circular(8), child: productImage(i.product.image))),
              title: Text(i.product.name),
              subtitle: Text(money(i.product.price)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => cart.setQty(i.product.id, i.qty - 1)),
                Text('${i.qty}'),
                IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => cart.setQty(i.product.id, i.qty + 1)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => cart.remove(i.product.id)),
              ]),
            ),
        ]),
      ),
      Card(
        margin: const EdgeInsets.all(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _row('Subtotal', money(cart.subtotal)),
            _row('IVA (19%)', money(cart.ivaValue)),
            _row('Envío', money(cart.shipping)),
            const Divider(),
            _row('Total', money(cart.total), big: true),
            const SizedBox(height: 10),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () => _pay(context, cart),
              child: const Text('Proceder al pago'),
            ),
          ]),
        ),
      ),
    ]);
  }
}

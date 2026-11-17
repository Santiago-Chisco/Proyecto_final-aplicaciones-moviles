import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../state.dart';
import 'home_screen.dart' show productImage;

class ProductDetail extends StatefulWidget {
  final Product product;
  const ProductDetail({super.key, required this.product});
  @override
  State<ProductDetail> createState() => _ProductDetailState();
}

class _ProductDetailState extends State<ProductDetail> {
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Scaffold(
      appBar: AppBar(title: Text(p.name), leading: const BackButton()),
      body: ListView(children: [
        SizedBox(height: 300, child: productImage(p.image)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Chip(label: Text(p.category)),
            const SizedBox(height: 6),
            Text(money(p.price), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 12),
            Text(p.description),
            const SizedBox(height: 20),
            Row(children: [
              const Text('Cantidad', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton.outlined(onPressed: _qty > 1 ? () => setState(() => _qty--) : null, icon: const Icon(Icons.remove)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('$_qty', style: const TextStyle(fontSize: 18))),
              IconButton.outlined(onPressed: () => setState(() => _qty++), icon: const Icon(Icons.add)),
            ]),
          ]),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Agregar al carrito'),
            onPressed: () {
              context.read<CartState>().add(p, _qty);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$_qty × ${p.name} agregado al carrito')));
            },
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../api.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<dynamic>> _f = Api.get('/orders').then((v) => v as List);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis pedidos')),
      body: FutureBuilder<List<dynamic>>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text('${snap.error}'));
          final list = snap.data!;
          if (list.isEmpty) return const Center(child: Text('Aún no tienes pedidos'));
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final o = list[i];
              final items = (o['items'] as List);
              return Card(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: ExpansionTile(
                  leading: const Icon(Icons.receipt_long),
                  title: Text('Pedido #${o['id']} · ${money(o['total'])}'),
                  subtitle: Text(o['date'].toString().substring(0, 10)),
                  children: [for (final it in items) ListTile(dense: true, title: Text('${it['qty']} × ${it['name']}'), trailing: Text(money(it['price'] * it['qty'])))],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

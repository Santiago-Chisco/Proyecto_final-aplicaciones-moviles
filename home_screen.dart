import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../state.dart';
import 'cart_screen.dart';
import 'product_detail.dart';
import 'profile_screen.dart';
import 'orders_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _i = 0;
  static const _titles = ['Inicio', 'Carrito', 'Perfil'];

  @override
  Widget build(BuildContext context) {
    final u = context.watch<AuthState>().user;
    if (u == null) return const SizedBox();
    final count = context.watch<CartState>().count;
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_i])),
      drawer: Drawer(
        child: ListView(padding: EdgeInsets.zero, children: [
          UserAccountsDrawerHeader(
            accountName: Text(u.full),
            accountEmail: Text(u.email),
            currentAccountPicture: CircleAvatar(backgroundColor: Colors.white, child: Text(u.initials, style: const TextStyle(fontSize: 24))),
          ),
          ListTile(leading: const Icon(Icons.home), title: const Text('Inicio'), onTap: () { Navigator.pop(context); setState(() => _i = 0); }),
          ListTile(leading: const Icon(Icons.receipt_long), title: const Text('Mis pedidos'), onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen()));
          }),
          ListTile(leading: const Icon(Icons.person), title: const Text('Perfil'), onTap: () { Navigator.pop(context); setState(() => _i = 2); }),
          const Divider(),
          ListTile(leading: const Icon(Icons.logout), title: const Text('Cerrar sesión'), onTap: () {
            Navigator.pop(context);
            context.read<CartState>().clear();
            context.read<AuthState>().logout();
          }),
        ]),
      ),
      body: IndexedStack(index: _i, children: const [HomeTab(), CartScreen(), ProfileScreen()]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _i,
        onTap: (i) => setState(() => _i = i),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Badge(isLabelVisible: count > 0, label: Text('$count'), child: const Icon(Icons.shopping_cart)), label: 'Carrito'),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  List<Product> _all = [];
  bool _loading = true;
  String? _err;
  String _cat = 'Todos', _q = '';
  final _page = PageController();
  int _bp = 0;
  Timer? _timer;

  static const _banners = [
    ['¡Ofertas de temporada!', 'Hasta 30% en ropa', Colors.indigo, Colors.blue],
    ['Tecnología al mejor precio', 'Audífonos, relojes y más', Colors.deepPurple, Colors.pink],
    ['Renueva tu hogar', 'Envío rápido a todo el país', Colors.teal, Colors.green],
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_page.hasClients) return;
      _page.animateToPage((_bp + 1) % _banners.length, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _err = null; });
    try {
      final l = await Api.get('/products') as List;
      _all = l.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
    } on ApiError catch (e) {
      _err = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_err != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_err!), const SizedBox(height: 8),
        FilledButton(onPressed: _load, child: const Text('Reintentar')),
      ]));
    }
    final cats = ['Todos', ...{for (final p in _all) p.category}];
    final list = _all.where((p) =>
        (_cat == 'Todos' || p.category == _cat) && p.name.toLowerCase().contains(_q.toLowerCase())).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Column(children: [
            SizedBox(
              height: 150,
              child: PageView.builder(
                controller: _page,
                itemCount: _banners.length,
                onPageChanged: (i) => setState(() => _bp = i),
                itemBuilder: (_, i) {
                  final b = _banners[i];
                  return Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(20),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(colors: [b[2] as Color, b[3] as Color]),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(b[0] as String, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(b[1] as String, style: const TextStyle(color: Colors.white70)),
                    ]),
                  );
                },
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (int i = 0; i < _banners.length; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _bp ? 18 : 8, height: 8,
                  decoration: BoxDecoration(color: i == _bp ? Colors.indigo : Colors.black26, borderRadius: BorderRadius.circular(4)),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: TextField(
                decoration: const InputDecoration(hintText: 'Buscar productos', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (final c in cats)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: ChoiceChip(label: Text(c), selected: _cat == c, onSelected: (_) => setState(() => _cat = c)),
                    ),
                ],
              ),
            ),
          ]),
        ),
        if (list.isEmpty)
          const SliverFillRemaining(hasScrollBody: false, child: Center(child: Text('No se encontraron productos')))
        else
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.72),
              delegate: SliverChildBuilderDelegate((_, i) => _ProductCard(list[i]), childCount: list.length),
            ),
          ),
      ]),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product p;
  const _ProductCard(this.p);

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetail(product: p))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: productImage(p.image)),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(money(p.price), style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
            ]),
          ),
        ]),
      ),
    );
  }
}

Widget productImage(String url, {BoxFit fit = BoxFit.cover}) => Image.network(
      url,
      fit: fit,
      width: double.infinity,
      loadingBuilder: (c, child, prog) => prog == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      errorBuilder: (_, __, ___) => Container(color: Colors.black12, child: const Icon(Icons.image_not_supported, size: 40)),
    );

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

class AuthState extends ChangeNotifier {
  User? user;
  bool loading = true;

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    Api.token = p.getString('token');
    if (Api.token != null) {
      try {
        user = User.fromJson(await Api.get('/me'));
      } on ApiError catch (e) {
        // Solo borra la sesión si el servidor dice que el token no sirve.
        if (e.status == 401) {
          Api.token = null;
          await p.remove('token');
        }
      }
    }
    loading = false;
    notifyListeners();
  }

  Future<void> login(String identifier, String password) async {
    final d = await Api.post('/auth/login', {'identifier': identifier, 'password': password});
    Api.token = d['token'];
    (await SharedPreferences.getInstance()).setString('token', d['token']);
    user = User.fromJson(d['user']);
    notifyListeners();
  }

  Future<void> logout() async {
    Api.token = null;
    user = null;
    await (await SharedPreferences.getInstance()).remove('token');
    notifyListeners();
  }

  Future<void> updateProfile(String nombre, String apellidos, String username) async {
    user = User.fromJson(await Api.put('/me', {'nombre': nombre, 'apellidos': apellidos, 'username': username}));
    notifyListeners();
  }
}

class CartItem {
  final Product product;
  int qty;
  CartItem(this.product, this.qty);
}

class CartState extends ChangeNotifier {
  static const double iva = 0.19;
  static const int envio = 8000;
  final Map<int, CartItem> items = {};

  int get count => items.values.fold(0, (a, i) => a + i.qty);
  num get subtotal => items.values.fold<num>(0, (a, i) => a + i.product.price * i.qty);
  num get ivaValue => (subtotal * iva).round();
  num get shipping => items.isEmpty ? 0 : envio;
  num get total => subtotal + ivaValue + shipping;

  void add(Product p, int qty) {
    items.update(p.id, (i) => i..qty += qty, ifAbsent: () => CartItem(p, qty));
    notifyListeners();
  }

  void setQty(int id, int qty) {
    if (qty < 1) return;
    items[id]?.qty = qty;
    notifyListeners();
  }

  void remove(int id) {
    items.remove(id);
    notifyListeners();
  }

  void clear() {
    items.clear();
    notifyListeners();
  }
}

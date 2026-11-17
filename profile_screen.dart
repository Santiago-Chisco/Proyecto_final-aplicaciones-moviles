import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../state.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _n, _a, _u;
  String? _userErr;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<AuthState>().user!;
    _n = TextEditingController(text: u.nombre);
    _a = TextEditingController(text: u.apellidos);
    _u = TextEditingController(text: u.username);
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null;

  Future<void> _save() async {
    _userErr = null;
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AuthState>().updateProfile(_n.text.trim(), _a.text.trim(), _u.text.trim());
      messenger.showSnackBar(const SnackBar(content: Text('Datos actualizados')));
    } on ApiError catch (e) {
      if (e.field == 'username') {
        _userErr = e.message;
        _form.currentState!.validate();
      } else {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final u = context.watch<AuthState>().user;
    if (u == null) return const SizedBox();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _form,
        child: Column(children: [
          CircleAvatar(radius: 44, child: Text(u.initials, style: const TextStyle(fontSize: 30))),
          const SizedBox(height: 10),
          Text(u.full, style: Theme.of(context).textTheme.titleLarge),
          Text('@${u.username}'),
          Text(u.email, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 20),
          TextFormField(controller: _n, decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()), validator: _req),
          const SizedBox(height: 14),
          TextFormField(controller: _a, decoration: const InputDecoration(labelText: 'Apellidos', border: OutlineInputBorder()), validator: _req),
          const SizedBox(height: 14),
          TextFormField(
            controller: _u,
            decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
            onChanged: (_) => _userErr = null,
            validator: (v) => _req(v) ?? (v!.trim().length < 3 ? 'Mínimo 3 caracteres' : _userErr),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: _busy ? null : _save,
            child: const Text('Guardar cambios'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.lock_reset),
            label: const Text('Cambiar contraseña'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
          ),
        ]),
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _cur = TextEditingController(), _new = TextEditingController(), _new2 = TextEditingController();
  bool _busy = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Api.put('/me/password', {'actual': _cur.text, 'nueva': _new.text});
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('Contraseña actualizada')));
      return;
    } on ApiError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _f(TextEditingController c, String l, String? Function(String?) v) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(controller: c, obscureText: true, decoration: InputDecoration(labelText: l, border: const OutlineInputBorder()), validator: v),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar contraseña')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _form,
          child: Column(children: [
            _f(_cur, 'Contraseña actual', (v) => (v == null || v.isEmpty) ? 'Campo obligatorio' : null),
            _f(_new, 'Nueva contraseña', (v) => (v == null || v.length < 8) ? 'Mínimo 8 caracteres' : null),
            _f(_new2, 'Confirmar nueva contraseña', (v) => v != _new.text ? 'Las contraseñas no coinciden' : null),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: _busy ? null : _save,
              child: const Text('Actualizar contraseña'),
            ),
          ]),
        ),
      ),
    );
  }
}

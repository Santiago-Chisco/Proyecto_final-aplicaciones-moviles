import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../state.dart';

final _emailRx = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

void _snack(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

class _AuthScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _AuthScaffold(this.title, this.children);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Icon(Icons.shopping_bag, size: 64, color: Colors.indigo),
              const SizedBox(height: 8),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),
              ...children,
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------------- LOGIN ----------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController(), _pw = TextEditingController();
  bool _hide = true, _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await context.read<AuthState>().login(_id.text.trim(), _pw.text);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold('Iniciar sesión', [
      Form(
        key: _form,
        child: Column(children: [
          TextFormField(
            controller: _id,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Username o correo', prefixIcon: Icon(Icons.person), border: OutlineInputBorder()),
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) return 'Campo obligatorio';
              if (t.contains('@') && !_emailRx.hasMatch(t)) return 'Correo no válido';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _pw,
            obscureText: _hide,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _hide = !_hide),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Campo obligatorio';
              if (v.length < 6) return 'Mínimo 6 caracteres';
              return null;
            },
          ),
        ]),
      ),
      if (_error != null)
        Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Iniciar sesión'),
        ),
      ),
      TextButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotScreen())),
        child: const Text('¿Olvidaste tu contraseña?'),
      ),
      TextButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
        child: const Text('Crear cuenta'),
      ),
    ]);
  }
}

// ---------------- REGISTRO ----------------
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _c = {for (final k in ['nombre', 'apellidos', 'username', 'email', 'password', 'password2']) k: TextEditingController()};
  final Map<String, String?> _server = {};
  bool _busy = false;
  String? _error;

  String? _req(String k, String? v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : _server[k];

  Widget _field(String k, String label, {bool pw = false, TextInputType? type, String? Function(String?)? extra}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: _c[k],
        obscureText: pw,
        keyboardType: type,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        onChanged: (_) => _server[k] = null,
        validator: (v) => _req(k, v) ?? (extra == null ? null : extra(v)),
      ),
    );
  }

  Future<void> _submit() async {
    _server.clear();
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await Api.post('/auth/register', {
        'nombre': _c['nombre']!.text, 'apellidos': _c['apellidos']!.text,
        'username': _c['username']!.text, 'email': _c['email']!.text,
        'password': _c['password']!.text,
      });
      if (!mounted) return;
      Navigator.pop(context);
      _snack(context, 'Cuenta creada. Inicia sesión.');
      return;
    } on ApiError catch (e) {
      if (e.field != null && _c.containsKey(e.field)) {
        _server[e.field!] = e.message;
        _form.currentState!.validate();
      } else {
        _error = e.message;
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(children: [
            _field('nombre', 'Nombre'),
            _field('apellidos', 'Apellidos'),
            _field('username', 'Username'),
            _field('email', 'Correo electrónico', type: TextInputType.emailAddress,
                extra: (v) => _emailRx.hasMatch(v!.trim()) ? null : 'Correo no válido'),
            _field('password', 'Contraseña', pw: true,
                extra: (v) => v!.length < 8 ? 'Mínimo 8 caracteres' : null),
            _field('password2', 'Verificar contraseña', pw: true,
                extra: (v) => v != _c['password']!.text ? 'Las contraseñas no coinciden' : null),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(onPressed: _busy ? null : _submit, child: const Text('Registrarse')),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ya tengo cuenta')),
          ]),
        ),
      ),
    );
  }
}

// ---------------- RECUPERAR CONTRASEÑA ----------------
class ForgotScreen extends StatefulWidget {
  const ForgotScreen({super.key});
  @override
  State<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends State<ForgotScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final d = await Api.post('/auth/forgot', {'email': _email.text.trim()});
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ResetScreen(email: _email.text.trim(), devCode: d['devCode']?.toString())));
    } on ApiError catch (e) {
      if (mounted) _snack(context, e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(children: [
            const Text('Ingresa tu correo registrado y te enviaremos un enlace para restablecer tu contraseña.'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Correo electrónico', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : (_emailRx.hasMatch(v.trim()) ? null : 'Correo no válido'),
            ),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, height: 48, child: FilledButton(onPressed: _busy ? null : _send, child: const Text('Enviar enlace'))),
          ]),
        ),
      ),
    );
  }
}

class ResetScreen extends StatefulWidget {
  final String email;
  final String? devCode;
  const ResetScreen({super.key, required this.email, this.devCode});
  @override
  State<ResetScreen> createState() => _ResetScreenState();
}

class _ResetScreenState extends State<ResetScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController(), _pw = TextEditingController();
  String? _codeErr;
  bool _busy = false;

  Future<void> _save() async {
    _codeErr = null;
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Api.post('/auth/reset', {'email': widget.email, 'code': _code.text.trim(), 'password': _pw.text});
      if (!mounted) return;
      Navigator.popUntil(context, (r) => r.isFirst);
      _snack(context, 'Contraseña actualizada. Inicia sesión.');
      return;
    } on ApiError catch (e) {
      if (e.field == 'code') {
        _codeErr = e.message;
        _form.currentState!.validate();
      } else if (mounted) {
        _snack(context, e.message);
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva contraseña')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(children: [
            Text('Enviamos un enlace de recuperación a ${widget.email}. Ábrelo desde tu correo para crear la nueva contraseña, o ingresa aquí el código del correo.'),
            if (widget.devCode != null)
              Card(
                color: Colors.amber.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Modo demo (correo no configurado): tu código es ${widget.devCode}'),
                ),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _code,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Código de 6 dígitos', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : _codeErr,
              onChanged: (_) => _codeErr = null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _pw,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nueva contraseña', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.length < 8) ? 'Mínimo 8 caracteres' : null,
            ),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, height: 48, child: FilledButton(onPressed: _busy ? null : _save, child: const Text('Restablecer'))),
          ]),
        ),
      ),
    );
  }
}

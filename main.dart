import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state.dart';
import 'screens/auth_screens.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthState()..init()),
      ChangeNotifierProvider(create: (_) => CartState()),
    ],
    child: const App(),
  ));
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tienda',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: Consumer<AuthState>(builder: (context, auth, _) {
        if (auth.loading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return auth.user == null ? const LoginScreen() : const HomeShell();
      }),
    );
  }
}

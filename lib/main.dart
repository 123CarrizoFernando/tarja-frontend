import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/admin_screen.dart'; // IMPORTANTE AGREGAR ESTO

void main() {
  runApp(const TarjaApp());
}

class TarjaApp extends StatelessWidget {
  const TarjaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tarja Municipal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/admin': (context) => const AdminScreen(), // LA NUEVA RUTA
      },
    );
  }
}

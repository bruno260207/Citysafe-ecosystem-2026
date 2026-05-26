import 'package:flutter/material.dart';
import 'screens/role_selection_screen.dart';
import 'screens/home_page.dart';
import 'screens/central_home_page.dart';
import 'services/auth_service.dart';

void main() => runApp(const CitySafeApp());

class CitySafeApp extends StatelessWidget {
  const CitySafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CitySafe',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4FC3F7)),
        useMaterial3: true,
      ),
      home: FutureBuilder<String?>(
        future: AuthService().getRole(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF1A1A2E),
              body: Center(child: CircularProgressIndicator(color: Color(0xFF4FC3F7))),
            );
          }
          final role = snapshot.data;
          if (role == null) return const RoleSelectionScreen();
          if (role == 'central') return const CentralHomePage();
          return const HomePage();
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_page.dart';
import 'register_screen.dart';
import 'role_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;

  void _handleLogin() async {
    if (_emailController.text.isEmpty || _passController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos')),
      );
      return;
    }
    setState(() => _isLoading = true);
    final role = await AuthService().login(
      _emailController.text.trim(),
      _passController.text.trim(),
    );
    setState(() => _isLoading = false);
    if (!mounted) return;

    if (role == 'ciudadano') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } else if (role == 'central') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta cuenta es de la Central. Usa el acceso correcto.'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Credenciales incorrectas o servidor offline')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white54),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person, size: 72, color: Color(0xFF4FC3F7)),
              const SizedBox(height: 16),
              const Text(
                'Ciudadano',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Text(
                'Inicia sesion para reportar incidentes',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.email, color: Color(0xFF4FC3F7)),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passController,
                obscureText: _obscure,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Contrasena',
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.lock, color: Color(0xFF4FC3F7)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white38,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFF4FC3F7)),
                      )
                    : ElevatedButton(
                        onPressed: _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4FC3F7),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Iniciar Sesion',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
                child: const Text(
                  'No tienes cuenta? Registrate',
                  style: TextStyle(color: Color(0xFF4FC3F7)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
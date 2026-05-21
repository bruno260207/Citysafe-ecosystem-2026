import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  bool _isLoading = false;

  void _handleRegister() async {
    if (_emailController.text.isEmpty || _passController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
      Uri.parse('${AuthService.baseUrl}/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _passController.text.trim(),
        }),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Cuenta creada! Inicia sesión')),
        );
        Navigator.pop(context);
      } else if (response.statusCode == 400) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El email ya está registrado')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al registrar')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo conectar al servidor')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Crear cuenta', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Icon(Icons.person_add, size: 64, color: Color(0xFF4FC3F7)),
              const SizedBox(height: 24),
              TextField(
                controller: _emailController,
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
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.lock, color: Color(0xFF4FC3F7)),
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
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF4FC3F7)))
                    : ElevatedButton(
                        onPressed: _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4FC3F7),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Crear cuenta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'central_login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield, size: 80, color: Color(0xFF4FC3F7)),
              const SizedBox(height: 16),
              const Text(
                'CitySafe',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              const Text(
                'Sistema de Monitoreo Urbano',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 60),
              const Text(
                '¿Cómo deseas ingresar?',
                style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 28),
              _RoleCard(
                icon: Icons.person,
                title: 'Ciudadano',
                subtitle: 'Reportar incidentes en tu zona',
                color: const Color(0xFF4FC3F7),
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.radio_button_checked,
                title: 'Central',
                subtitle: 'Gestionar y atender incidentes',
                color: const Color(0xFFFF6B6B),
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const CentralLoginScreen()),
                ),
              ),
              const SizedBox(height: 48),
              const Text(
                'v2.0 — UNMSM FISI 2026',
                style: TextStyle(color: Colors.white24, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              radius: 28,
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}
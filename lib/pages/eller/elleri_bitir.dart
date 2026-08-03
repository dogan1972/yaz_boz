import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// ELLER FAB — yeni el ekleme düğmesi.
//   oyunBitti=true ise geceye gömülür: son ele ulaşıldığında ekleme yok.
//   (Bitir/Paylaş artık burada değil; Paylaş koordinatörde AppBar'da.)
// ─────────────────────────────────────────────────────────────
class EllerFab extends StatelessWidget {
  final bool oyunBitti;
  final VoidCallback? onPressed;

  const EllerFab({super.key, required this.oyunBitti, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: FloatingActionButton.extended(
        onPressed: oyunBitti ? null : onPressed,
        backgroundColor: oyunBitti
            ? const Color(0xFF1E293B)
            : const Color(0xFFF59E0B),
        foregroundColor: oyunBitti
            ? const Color(0xFF64748B)
            : const Color(0xFF1A1206),
        elevation: oyunBitti ? 0 : 8,
        icon: Icon(oyunBitti ? Icons.block : Icons.add),
        label: Text(
          oyunBitti ? 'El Tamam' : 'Yeni El',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

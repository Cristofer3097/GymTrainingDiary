// lib/widgets/app_bottom_nav_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../ai_screen.dart';
import '../calendar.dart';
import '../extras.dart';
import '../main.dart';
import '../settings.dart';

class AppBottomNavBar extends StatelessWidget {
  // Esta variable nos dirá qué pantalla está activa para pintarla de blanco
  final String? activeRoute;

  const AppBottomNavBar({super.key, this.activeRoute});

  // Widget reutilizable para crear cada botón
  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    // El color será blanco si está activo, de lo contrario, será el amarillo principal
    final Color color = isActive ? Colors.white : Theme.of(context).primaryColor;

    return Expanded(
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: color), // Aplica el color al ícono
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: color)), // Aplica el color al texto
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Obtenemos la referencia a la función onLocaleChange para pasarla a Settings
    final myAppState = context.findAncestorStateOfType<MyAppState>();

    const menuLabel = 'Menú';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [

          _buildNavItem(
            context: context,
            icon: Icons.auto_awesome,
            label: l10n.ai_title,
            isActive: activeRoute == l10n.ai_title,
            onPressed: () {
              if (activeRoute == l10n.ai_title) return;
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AiScreen()));
            },
          ),
          _buildNavItem(
            context: context,
            icon: Icons.calendar_month,
            label: l10n.calendar,
            isActive: activeRoute == l10n.calendar,
            onPressed: () {
              if (activeRoute == l10n.calendar) return;
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CalendarScreen()));
            },
          ),
          _buildNavItem(
            context: context,
            icon: Icons.home_rounded, // Un ícono de inicio
            label: menuLabel,
            isActive: activeRoute == menuLabel,
            onPressed: () {
              if (activeRoute == menuLabel || myAppState == null) return;
              // Navega de vuelta a la pantalla principal
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => HomeScreen(onLocaleChange: myAppState.setLocale)),
              );
            },
          ),
          _buildNavItem(
            context: context,
            icon: Icons.lightbulb,
            label: l10n.tipsAndExtras,
            isActive: activeRoute == l10n.tipsAndExtras,
            onPressed: () {
              if (activeRoute == l10n.tipsAndExtras) return;
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TipsExtrasScreen()));
            },
          ),
          _buildNavItem(
            context: context,
            icon: Icons.settings,
            label: l10n.settings_title,
            isActive: activeRoute == l10n.settings_title,
            onPressed: () {
              if (activeRoute == l10n.settings_title) return;
              if (myAppState != null) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => Settings(onLocaleChange: myAppState.setLocale)));
              }
            },
          ),
        ],
      ),
    );
  }
}
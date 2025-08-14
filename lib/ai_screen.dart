// lib/ai_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  bool _isLoading = false;
  String? _generatedPlan;

  // Simula una llamada a la API de DeepSeek
  Future<void> _generateAiRoutine() async {
    setState(() {
      _isLoading = true;
      _generatedPlan = null; // Limpia el plan anterior
    });

    // Simula una espera de 2 segundos, como si la IA estuviera "pensando"
    await Future.delayed(const Duration(seconds: 2));

    // TODO: Aquí es donde implementarías la llamada real a la API de DeepSeek.
    // Deberías usar un paquete como 'http' o 'dio' para hacer la petición HTTP.
    // El texto que se muestra a continuación es un ejemplo de lo que la IA podría devolver.

    setState(() {
      _generatedPlan = """
      **Plan de Entrenamiento (Hipertrofia de Alta Intensidad):**
      - **Calentamiento:** 10 min de cardio ligero y movilidad articular.
      - **Press de Banca:** 3 series de 6-8 repeticiones (cerca del fallo).
      - **Sentadilla con Barra:** 3 series de 6-8 repeticiones (cerca del fallo).
      - **Remo con Barra:** 3 series de 8-10 repeticiones.
      - **Press Militar:** 2 series de 8-10 repeticiones.

      **Nutrición Pre-Entrenamiento:**
      - **Comida (1-2 horas antes):** 150g de pechuga de pollo a la plancha con 100g de arroz integral y brócoli. Esto proporciona proteínas de digestión lenta y carbohidratos complejos para energía sostenida.
      """;
      _isLoading = false;
    });
  }

  String _getFormattedDate() {
    // Formatea la fecha para mostrarla en el saludo.
    final now = DateTime.now();
    // 'EEEE' para el nombre completo del día, 'd' para el día, 'MMMM' para el mes, 'y' para el año.
    // Asegúrate de tener inicializado el locale en tu main.dart para que esto funcione en español.
    return DateFormat('EEEE, d \'de\' MMMM \'de\' y', 'es_ES').format(now);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String todayDate = _getFormattedDate();

    return Scaffold(
      // La AppBar se controlará desde la pantalla principal para consistencia
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Text(
              '¡Buen día!',
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Crea tu plan personalizado para hoy\n$todayDate',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[400]),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface, // Usa el color de las tarjetas del tema
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: theme.primaryColor.withOpacity(0.1),
                    child: Icon(
                      Icons.auto_awesome, // Un ícono representativo de IA
                      color: theme.primaryColor,
                      size: 35,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Rutina Personalizada con IA',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Genera un plan único basado en tus objetivos, nivel de actividad y preferencias personales.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.auto_awesome_motion),
                      label: const Text('Generar Rutina con IA'),
                      onPressed: _isLoading ? null : _generateAiRoutine,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.black, // Estilo oscuro como en la imagen
                        side: BorderSide(color: theme.primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      child: const Text('Usar Rutina Estándar'),
                      onPressed: () {
                        // TODO: Implementar lógica para cargar rutinas predefinidas
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey[700]!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            if (_isLoading)
              const CircularProgressIndicator(),
            if (_generatedPlan != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _generatedPlan!,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
// En ai_screen.dart (versión simplificada para mostrar la lógica)

import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../database/database_helper.dart'; // Asegúrate de importar tu helper

// --- Modelo para los mensajes del chat ---
class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {

  final genAI = GenerativeModel(model: 'gemini-1.5-flash-latest', apiKey: 'key');
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;


  @override
  void initState() {
    super.initState();
    // --- Mensaje de bienvenida automático del bot ---
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: "¡Hola! Soy GymGenie, tu entrenador personal. ¿Qué tipo de rutina te gustaría generar hoy? Puedes pedirme algo para hipertrofia, fuerza, o simplemente dime en qué músculos te quieres enfocar.",
              isUser: false,
            ),
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- Función para hacer scroll automático hacia el último mensaje ---
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty) return;

    final userMessage = _controller.text;
    setState(() {
      _messages.add(ChatMessage(text: userMessage, isUser: true));
      _isLoading = true;
    });
    _controller.clear();

    final db = DatabaseHelper.instance;

    // --- 1. Lógica para interpretar la intención del usuario y actualizar la DB ---
    String confirmationMessage = "";
    final userMessageLower = userMessage.toLowerCase();

    // El usuario quiere AÑADIR un ejercicio NO deseado
    if (userMessageLower.contains("no me gusta") || userMessageLower.contains("odio")) {
      final exercise = userMessageLower.split(RegExp(r'no me gusta|odio')).last.trim();
      if (exercise.isNotEmpty) {
        await db.addPreferenceToList('disliked_exercise', exercise);
        await db.removePreferenceFromList('liked_exercise', exercise); // Lo quita de los gustados por si acaso
        confirmationMessage = "Entendido, añadiré '$exercise' a los ejercicios que no te gustan.";
      }
    }
    // El usuario quiere QUITAR un ejercicio de los NO deseados
    else if (userMessageLower.contains("ahora quiero usar") || userMessageLower.contains("ya me gusta")) {
      final exercise = userMessageLower.split(RegExp(r'ahora quiero usar|ya me gusta')).last.trim();
      if (exercise.isNotEmpty) {
        await db.removePreferenceFromList('disliked_exercise', exercise);
        confirmationMessage = "¡Genial! Quitaré '$exercise' de tu lista de no deseados.";
      }
    }
    // El usuario quiere AÑADIR un ejercicio deseado
    else if (userMessageLower.contains("me gusta") || userMessageLower.contains("me encanta")) {
      final exercise = userMessageLower.split(RegExp(r'me gusta|me encanta')).last.trim();
      if (exercise.isNotEmpty) {
        await db.addPreferenceToList('liked_exercise', exercise);
        await db.removePreferenceFromList('disliked_exercise', exercise); // Lo quita de los no gustados
        confirmationMessage = "Perfecto, recordaré que te gusta hacer '$exercise'.";
      }
    }
    // El usuario define su OBJETIVO
    else if (userMessageLower.contains("mi objetivo es")) {
      final goal = userMessageLower.split("mi objetivo es").last.trim();
      if (goal.isNotEmpty) {
        await db.setPreference('user_goal', goal);
        confirmationMessage = "Tu objetivo ha sido actualizado a: '$goal'.";
      }
    }
    // El usuario define su EQUIPO
    else if (userMessageLower.contains("solo tengo") || userMessageLower.contains("puedo usar")) {
      final equipment = userMessageLower.split(RegExp(r'solo tengo|puedo usar')).last.trim();
      if (equipment.isNotEmpty) {
        await db.setPreference('equipment_available', equipment);
        confirmationMessage = "Hecho. Adaptaré las rutinas para usar: '$equipment'.";
      }
    }

    // Si hubo un mensaje de confirmación, lo mostramos y no llamamos a la IA todavía.
    if (confirmationMessage.isNotEmpty) {
      setState(() {
        _messages.add(ChatMessage(text: confirmationMessage, isUser: false));
        _isLoading = false;
      });
      return; // Salimos de la función
    }

    // --- 2. Cargar TODAS las preferencias para construir el prompt ---
    final goal = await db.getPreference('user_goal') ?? "No especificado";
    final equipment = await db.getPreference('equipment_available') ?? "No especificado";
    final likedExercises = await db.getPreferenceList('liked_exercise');
    final dislikedExercises = await db.getPreferenceList('disliked_exercise');
    final favoriteMuscles = await db.getPreferenceList('favorite_muscle');

    // --- 3. Construir el Super Prompt ---
    final prompt = """
    Eres "GymGenie", un entrenador personal experto en fitness y nutrición.
    Tu objetivo es crear planes personalizados basados en la información del usuario.
    Tus respuestas deben ser claras, motivadoras y en formato Markdown.

    Aquí tienes la información sobre el usuario para personalizar el plan:
    - **Objetivo Principal:** $goal
    - **Músculos Favoritos:** ${favoriteMuscles.isNotEmpty ? favoriteMuscles.join(', ') : "Ninguno"}
    - **Equipo Disponible:** $equipment
    - **Ejercicios Preferidos (Intenta incluirlos si es posible):** ${likedExercises.isNotEmpty ? '- ' + likedExercises.join('\n- ') : "Ninguno"}
    - **Ejercicios No Deseados (NUNCA los incluyas):** ${dislikedExercises.isNotEmpty ? '- ' + dislikedExercises.join('\n- ') : "Ninguno"}

    ---
    Pregunta del usuario:
    $userMessage
  """;

    // --- 4. Llamar a la API y mostrar la respuesta ---
    try {
      final response = await genAI.generateContent([Content.text(prompt)]);
      final aiResponse = response.text ?? "Lo siento, no pude procesar tu solicitud.";

      setState(() {
        _messages.add(ChatMessage(text: aiResponse, isUser: false));
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(text: "Error: No se pudo conectar con la IA.", isUser: false));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Plan IA")),
      body: Column(
        children: [
          // --- Lista de mensajes del chat ---
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return ChatMessageBubble(message: message);
              },
            ),
          ),
          // --- Indicador de carga ---
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: LinearProgressIndicator(),
            ),
          // --- Campo de texto para enviar mensajes ---
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: "Pregúntale a GymGenie..."),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- WIDGET PARA LAS BURBUJAS DE CHAT ---
class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  const ChatMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;

    return Row(
      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: BoxDecoration(
            color: isUser ? theme.primaryColor : theme.colorScheme.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(0),
              bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(20),
            ),
          ),
          child: Text(
            message.text,
            style: TextStyle(
              color: isUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
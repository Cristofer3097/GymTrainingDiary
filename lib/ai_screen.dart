// En ai_screen.dart (versión simplificada para mostrar la lógica)

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../database/database_helper.dart';
import 'main.dart';
import 'widgets/app_bottom_nav_bar.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';


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

  final genAI = GenerativeModel(model: 'gemini-1.5-flash-latest', apiKey: dotenv.env['GEMINI_API_KEY']!);
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  final _languageIdentifier = LanguageIdentifier(confidenceThreshold: 0.5);

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _languageIdentifier.close();
    super.dispose();
  }

// función para cargar el historial
  Future<void> _loadChatHistory() async {
    final db = DatabaseHelper.instance;
    final history = await db.getChatHistory();

    if (mounted) {
      setState(() {
        _messages.addAll(history);
        if (_messages.isEmpty) {
          final welcomeMessage = ChatMessage(
            text: "¡Hola! Soy GymGenie. ¿Qué rutina te gustaría generar hoy?",
            isUser: false,
          );
          _messages.add(welcomeMessage);
          db.saveChatMessage(welcomeMessage);
        }
      });
      _scrollToBottom(initial: true);
    }
  }



  // --- Función para hacer scroll automático hacia el último mensaje ---
  void _scrollToBottom({bool initial = false}) {
    // WidgetsBinding asegura que el scroll ocurra después de que la UI se haya renderizado.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (initial) {
          // Para la carga inicial, saltamos directamente al final sin animación.

          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        } else {
          // Para nuevos mensajes, usamos una animación suave.
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  // --- NUEVA FUNCIÓN PARA CONSTRUIR EL PROMPT EN ESPAÑOL ---
  String _buildSpanishPrompt({
    required Map<String, dynamic> prefs,
    required String userMessage,
  }) {
    return """
      Eres "GymGenie", un entrenador personal experto en fitness y nutrición.
      Tu objetivo es crear planes personalizados. Tus respuestas deben ser claras, motivadoras y en formato Markdown.
      **REGLA MUY IMPORTANTE:** Debes responder SIEMPRE en español.

      Aquí tienes la información sobre el usuario para personalizar el plan:
      - **Objetivo Principal:** ${prefs['goal']}
      - **Músculos Favoritos:** ${prefs['favoriteMuscles']}
      - **Equipo Disponible:** ${prefs['equipment']}
      - **Ejercicios Preferidos (Intenta incluirlos si es posible):**\n${prefs['likedExercises']}
      - **Ejercicios No Deseados (NUNCA los incluyas):**\n${prefs['dislikedExercises']}

      ---
      Pregunta del usuario:
      $userMessage
    """;
  }

  // --- NUEVA FUNCIÓN PARA CONSTRUIR EL PROMPT EN INGLÉS ---
  String _buildEnglishPrompt({
    required Map<String, dynamic> prefs,
    required String userMessage,
  }) {
    return """
      You are 'GymGenie', an expert fitness and nutrition coach.
      Your goal is to create personalized plans. Your answers must be clear, motivating, and in Markdown format.
      **VERY IMPORTANT RULE:** You MUST ALWAYS respond in English.

      Here is the user's information to personalize the plan:
      - **Main Goal:** ${prefs['goal']}
      - **Favorite Muscles:** ${prefs['favoriteMuscles']}
      - **Available Equipment:** ${prefs['equipment']}
      - **Preferred Exercises (Try to include if possible):**\n${prefs['likedExercises']}
      - **Disliked Exercises (NEVER include them):**\n${prefs['dislikedExercises']}

      ---
      User's question:
      $userMessage
    """;
  }
  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty || _isLoading) return;

    final userMessageText = _controller.text;
    final userMessage = ChatMessage(text: userMessageText, isUser: true);
    final db = DatabaseHelper.instance;
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    await db.saveChatMessage(userMessage);


    // --- 1. Lógica para interpretar la intención del usuario y actualizar la DB ---
    final detectedLanguage = await _languageIdentifier.identifyLanguage(userMessageText);
    final languageForAI = (detectedLanguage == 'und' || detectedLanguage.isEmpty)
        ? l10n.localeName
        : detectedLanguage;


    String confirmationMessage = "";
    final userMessageLower = userMessageText.toLowerCase();
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
      final botMessage = ChatMessage(text: confirmationMessage, isUser: false);
      setState(() {
        _messages.add(botMessage);
        _isLoading = false;
      });
      await db.saveChatMessage(botMessage);
      _scrollToBottom();
      return;
    }

    // --- 2. Cargar TODAS las preferencias para construir el prompt ---
    final prefs = {
      'goal': await db.getPreference('user_goal') ?? l10n.ai_unspecified,
      'equipment': await db.getPreference('equipment_available') ?? l10n.ai_unspecified,
      'favoriteMuscles': (await db.getPreferenceList('favorite_muscle')).isNotEmpty
          ? (await db.getPreferenceList('favorite_muscle')).join(', ') : l10n.ai_none,
      'likedExercises': (await db.getPreferenceList('liked_exercise')).isNotEmpty
          ? '- ' + (await db.getPreferenceList('liked_exercise')).join('\n- ') : l10n.ai_none,
      'dislikedExercises': (await db.getPreferenceList('disliked_exercise')).isNotEmpty
          ? '- ' + (await db.getPreferenceList('disliked_exercise')).join('\n- ') : l10n.ai_none,
    };

    // --- 3. SELECCIONAR Y CONSTRUIR EL PROMPT FINAL ---
    String finalPrompt;
    if (languageForAI == 'es') {
      finalPrompt = _buildSpanishPrompt(prefs: prefs, userMessage: userMessageText);
    } else {
      // Por defecto, usamos inglés para cualquier otro idioma detectado
      finalPrompt = _buildEnglishPrompt(prefs: prefs, userMessage: userMessageText);
    }

    // --- 4. Llamar a la API y mostrar la respuesta ---
    try {
      final response = await genAI.generateContent([Content.text(finalPrompt)]);
      final aiResponse = response.text ?? l10n.ai_fallen;
      final botMessage = ChatMessage(text: aiResponse, isUser: false);


      setState(() {
        _messages.add(botMessage);
      });
      await db.saveChatMessage(botMessage);
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(text: l10n.ai_error, isUser: false));
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
          title: Text(l10n.ai_title)

      ),
      bottomNavigationBar: AppBottomNavBar(activeRoute: l10n.ai_title),
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
                    decoration:  InputDecoration(hintText: l10n.ai_placeholder),
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
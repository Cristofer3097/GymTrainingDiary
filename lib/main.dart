import 'package:flutter/material.dart';
import 'training_screen.dart'; //
import '../database/database_helper.dart'; //
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../utils/localization_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/app_bottom_nav_bar.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

//colores principales
const Color amarilloPrincipal = Color(0xFFFFC107); // Un tono de amarillo vibrante (Ámbar)
const Color fondoOscuro = Color(0xFF121212); // Un gris muy oscuro, casi negro para el fondo
const Color colorAppBar = Color(0xFF000000); // Negro para la AppBar
const Color negroBoton = Color(0xFF121212); //Colors.black; // Fondo de los botones principales
const Color grisContenedor = Color(0xFF1E1E1E); // Un gris oscuro para tarjetas y diálogos
const Color grisTextField = Color(0xFF2C2C2C); // Un gris para el fondo de campos de texto

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Asegurar que los bindings estén inicializados
  await dotenv.load(fileName: ".env");
  await initializeDateFormatting('es_ES', null); // Inicializar datos para español
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static void setLocale(BuildContext context, Locale newLocale) {
    MyAppState? state = context.findAncestorStateOfType<MyAppState>();
    state?.setLocale(newLocale);
  }

  @override
  State<MyApp> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  Locale _locale = const Locale('en');
  static const String _kLanguagePreferenceKey = 'user_preferred_language';

  @override
  void initState() {
    super.initState();
    _loadLocale();
  }

// Método para cargar el idioma guardado
  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final String? languageCode = prefs.getString(_kLanguagePreferenceKey);

    if (languageCode != null && languageCode.isNotEmpty) {
      // 1. Prioridad: El usuario ya guardó una preferencia. La usamos.
      if (mounted) {
        setState(() {
          _locale = Locale(languageCode);
        });
      }
    } else {

      final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;

      for (var supportedLocale in AppLocalizations.supportedLocales) {
        if (supportedLocale.languageCode == deviceLocale.languageCode) {

          if (mounted) {
            setState(() {
              _locale = deviceLocale;
            });
          }

          return; // Salimos de la función, ya encontramos el idioma correcto.
        }
      }

    }
  }

  // Método para guardar el idioma seleccionado
  Future<void> _saveLocale(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguagePreferenceKey, languageCode);
  }

  // Este setLocale es el que se llama desde HomeScreen a través de MyApp.setLocale
  void setLocale(Locale locale) {
    if (!mounted) return;
    setState(() {
      _locale = locale;
    });
    _saveLocale(locale.languageCode); // Guardar la nueva preferencia
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        onGenerateTitle: (BuildContext context) {
        return AppLocalizations.of(context)?.appTitle ?? 'Gym Diary';
        },
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: fondoOscuro,
        primaryColor: amarilloPrincipal, // Color primario para acentos
        colorScheme: ColorScheme.dark(
          primary: amarilloPrincipal,
          secondary: amarilloPrincipal, // Usado para elementos como el color del cursor, etc.
          surface: grisContenedor, // Color de superficie para Cards, Dialogs
          onPrimary: negroBoton, // Color del texto/iconos sobre el color primario
          onSecondary: negroBoton,
          onSurface: Colors.white, // Color del texto/iconos sobre el color de superficie
          background: fondoOscuro,
          onBackground: Colors.white,
          error: Colors.redAccent,
          onError: Colors.white,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: colorAppBar,
          foregroundColor: Colors.white, // Color para el título e iconos en la AppBar
          elevation: 0, // La AppBar en la imagen no tiene sombra
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold, // El título "Post" en la imagen se ve en negrita
          ),
          iconTheme: IconThemeData(color: Colors.white), // Para iconos como la flecha de retroceso
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: negroBoton, // Fondo negro para los botones
            foregroundColor: amarilloPrincipal, // Texto e iconos en amarillo
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), // Padding generoso
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0), // Esquinas redondeadas
              side: BorderSide(color: amarilloPrincipal, width: 1.5), // Borde amarillo
            ),
            textStyle: TextStyle(
              fontWeight: FontWeight.w500, // Un peso de fuente medio para los botones
              fontSize: 15,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: amarilloPrincipal, // Texto amarillo para TextButtons
            textStyle: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        cardTheme: CardTheme(
          color: grisContenedor, // Color de fondo para las Cards
          elevation: 1, // Una elevación sutil
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
          margin: EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
        ),
        dialogTheme: DialogTheme(
          backgroundColor: grisContenedor, // Fondo oscuro para diálogos
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
          contentTextStyle: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 15),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: grisTextField, // Fondo oscuro para campos de texto
          hintStyle: TextStyle(color: Colors.grey[500]),
          labelStyle: TextStyle(color: amarilloPrincipal.withOpacity(0.9)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide.none, // Sin borde por defecto cuando está relleno
          ),
          enabledBorder: OutlineInputBorder( // Borde cuando el campo no está enfocado pero está habilitado
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.grey[700]!, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: amarilloPrincipal, width: 1.5), // Borde amarillo cuando está enfocado
          ),
          prefixIconColor: Colors.grey[400], // Color para iconos de prefijo
        ),
        navigationBarTheme: NavigationBarThemeData( // <-- NUEVO: Estilo para la barra de navegación
          backgroundColor: colorAppBar,
          indicatorColor: amarilloPrincipal,
          labelTextStyle: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return const TextStyle(color: amarilloPrincipal, fontSize: 12, fontWeight: FontWeight.w500);
            }
            return TextStyle(color: Colors.grey[400], fontSize: 12);
          }),
          iconTheme: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return const IconThemeData(color: negroBoton);
            }
            return IconThemeData(color: Colors.grey[400]);
          }),
        ),
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates, // Usar el generado
      supportedLocales: AppLocalizations.supportedLocales,       // Usar el generado
      locale: _locale, // El locale actual del estado
      home: HomeScreen(onLocaleChange: setLocale),

    );
  }
}
// ---- WIDGET PRINCIPAL DE NAVEGACIÓN ----
class HomeScreen extends StatefulWidget {
  final void Function(Locale) onLocaleChange;
  const HomeScreen({Key? key, required this.onLocaleChange}) : super(key: key);
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> templates = [];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  void _loadTemplates() async {
    await DatabaseHelper.instance.database;
    final db = DatabaseHelper.instance;
    final tpls = await db.getAllTemplates();
    if (mounted) {
      setState(() {
        templates = List.from(tpls);
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        //title: const Text('Gym Diary'), // Título de la AppBar
        title: Text(l10n.appTitle),
        centerTitle: true, //

      ),
      bottomNavigationBar: AppBottomNavBar(activeRoute: l10n.diary),

      body: Padding(
        padding: const EdgeInsets.all(16.0), //
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // Para que los botones ocupen el ancho
          children: [
            // Considera si la imagen del logo es necesaria o cómo se ve en tema oscuro
            // Image.asset('assets/logo.png', height: 80, color: amarilloPrincipal), //
            // const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TrainingScreen(),
                    settings: const RouteSettings(name: 'TrainingScreen'),
                  ),
                );
                if (result == true) {
                  _loadTemplates(); //
                }
              },

              child: Text(l10n.startTraining),
            ),
            const SizedBox(height: 24),
      Expanded( // Para que esta sección tome el espacio disponible
        child: Container(
          padding: const EdgeInsets.all(12.0), // Padding interno para el contenido
          decoration: BoxDecoration(
            color: grisContenedor, // Color de fondo gris
            borderRadius: BorderRadius.circular(10.0), // Bordes redondeados como las cards
          ),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
            Text(
              l10n.templates,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Colors.white.withOpacity(0.9),
              ), //
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
          Expanded(
            child: templates.isEmpty
                ? Center(
                child: Text(
                  l10n.noTemplatesSaved,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500], fontSize: 15),
                ))
                : ReorderableGridView.builder(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 100),
                physics: const AlwaysScrollableScrollPhysics(),
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    final element = templates.removeAt(oldIndex);
                    if (newIndex > templates.length) {
                      newIndex = templates.length;
                    }

                    templates.insert(newIndex, element);
                  });

                  DatabaseHelper.instance.updateTemplatesOrder(templates);
                },
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.2,
                ),
                itemCount: templates.length,
                itemBuilder: (context, index) {
                  final template = templates[index];
                  final String displayTemplateName = getLocalizedTemplateName(context, template);
                  final templateId = template['id'];

                  final Key itemKey = ValueKey(templateId);
                  if (templateId == null) return Container(key: itemKey);
                  return ReorderableDragStartListener(
                    key: itemKey, // identificar el item
                    index: index, // saber qué posición se mueve
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        elevation: 3,
                        shadowColor: Colors.black45,
                      ),
                      onPressed: () async {
                        final db = DatabaseHelper.instance;
                        final exercises = await db.getTemplateExercises(templateId);

                        final dynamic dialogResult = await showDialog(
                          context: context,
                          builder: (BuildContext dialogContext) {
                            return TemplatePreviewDialog(
                              templateId: templateId,
                              templateName: displayTemplateName,
                              exercises: exercises,
                            );
                          },
                        );
                        if (mounted) {
                          _loadTemplates();
                        }
                      },
                      child: Text(displayTemplateName,
                          textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  );
                }),
          ),
    ],
    ),
        ),
      ),
          ],
        ),
      ),
    );
  }
}

class HomeView extends StatelessWidget {
  final List<Map<String, dynamic>> templates;
  final VoidCallback onLoadTemplates; // Callback para recargar plantillas

  const HomeView({
    Key? key,
    required this.templates,
    required this.onLoadTemplates,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TrainingScreen()),
              );
              if (result == true) {
                onLoadTemplates();
              }
            },
            child: Text(l10n.startTraining),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: grisContenedor,
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.templates,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: templates.isEmpty
                        ? Center(
                        child: Text(
                          l10n.noTemplatesSaved,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[500], fontSize: 15),
                        ))
                        : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 2.2,
                        ),
                        itemCount: templates.length,
                        itemBuilder: (context, index) {
                          // ... (El código de GridView.builder se mantiene igual)
                          final template = templates[index];
                          final String displayTemplateName = getLocalizedTemplateName(context, template);
                          final templateId = template['id'];
                          final Key itemKey = ValueKey(templateId);
                          if (templateId == null) return Container(key: itemKey);
                          if (templateId == null) {
                            return Card(
                                child: Center(
                                    child: Text(l10n.template_id,
                                        style: TextStyle(color: Theme.of(context).colorScheme.error))));
                          }



                          return GestureDetector(
                            onLongPress: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(l10n.template_question),
                                  content: Text(l10n.template_question1(displayTemplateName)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: Text(l10n.cancel),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: Text(l10n.deleteButton,
                                          style: TextStyle(color: Theme.of(context).colorScheme.error)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                final db = DatabaseHelper.instance;
                                await db.deleteTemplate(templateId);
                                onLoadTemplates();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l10n.templateDeletedSuccessMessage(displayTemplateName)),
                                      backgroundColor: Theme.of(context).cardTheme.color,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  );
                                }
                              }
                            },
                            child: ElevatedButton(
                              onPressed: () async {
                                final db = DatabaseHelper.instance;
                                final exercises = await db.getTemplateExercises(templateId);

                                final dynamic dialogResult = await showDialog(
                                  context: context,
                                  builder: (BuildContext dialogContext) {
                                    return TemplatePreviewDialog(
                                      templateId: templateId,
                                      templateName: displayTemplateName,
                                      exercises: exercises,
                                    );
                                  },
                                );
                                if (dialogResult == true && context.mounted) {
                                  onLoadTemplates();
                                }
                              },
                              child: Text(displayTemplateName, textAlign: TextAlign.center),
                            ),
                          );
                        }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TemplatePreviewDialog extends StatefulWidget {
  final int templateId; //
  final String templateName; //
  final List<Map<String, dynamic>> exercises; //

  const TemplatePreviewDialog({
    Key? key, //
    required this.templateId, //
    required this.templateName, //
    required this.exercises, //
  }) : super(key: key);

  @override
  State<TemplatePreviewDialog> createState() => _TemplatePreviewDialogState();
}
class _TemplatePreviewDialogState extends State<TemplatePreviewDialog> {
  late String currentName;

  @override
  void initState() {
    super.initState();
    currentName = widget.templateName;
  }

  void _renameTemplate() {
    final l10n = AppLocalizations.of(context)!;
    TextEditingController controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.training_edit_title), // O usa "Renombrar Plantilla"
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l10n.training_template_name,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final newName = controller.text.trim();
                await DatabaseHelper.instance.updateTemplateName(widget.templateId, newName);
                setState(() {
                  currentName = newName;
                });
                Navigator.pop(ctx);
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog( // Se aplica DialogTheme
      titlePadding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              currentName,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, color: Theme.of(context).primaryColor, size: 20),
            tooltip: "Renombrar",
            onPressed: _renameTemplate,
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.exercises.isEmpty
            ? Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0), //
              child: Text(l10n.template_exercise), //
            ))
            : ListView.builder(
          shrinkWrap: true,
          itemCount: widget.exercises.length,
          itemBuilder: (context, index) {
            final exercise = widget.exercises[index];
            final exerciseName = getLocalizedExerciseName(context, exercise);
            return ListTile(
              title: Text('${index + 1}. $exerciseName'),
              contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
            );
          },
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween, //
      actionsPadding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0), //
      actions: <Widget>[
        ElevatedButton( // Usa TextButtonTheme
          child: Text(l10n.returnbutton), //
          onPressed: () { //
            Navigator.of(context).pop(); //
          },
        ),
        ElevatedButton( // Botón de Borrar
          style: Theme.of(context).elevatedButtonTheme.style?.copyWith( // Hereda del tema pero cambia colores
            backgroundColor: MaterialStateProperty.all(Colors.red.shade700),
            foregroundColor: MaterialStateProperty.all(Colors.white),
            side: MaterialStateProperty.all(BorderSide(color: amarilloPrincipal, width: 1.5)), // Mantiene borde amarillo
          ),
          child: Text(l10n.deleteButton), //
          onPressed: () async { //
            final bool? confirmedDelete = await showDialog<bool>(
              context: context,
              builder: (BuildContext confirmDialogContext) {
                return ConfirmDeleteDialog(
                  templateId: widget.templateId,
                  templateName: currentName,
                );
              },
            );
            if (confirmedDelete == true) {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop(true);
              }
            }
          },
        ),
        ElevatedButton( // Botón Iniciar, usa ElevatedButtonTheme global
          child: Text(l10n.go), //
          onPressed: () async { //
            final dynamic trainingScreenResult = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TrainingScreen(
                  initialExercises: widget.exercises,
                  templateName: currentName,
                ),
                settings: const RouteSettings(name: 'TrainingScreen'),
              ),
            );
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop(trainingScreenResult);
            }
          },
        ),
      ],
    );
  }
}

class SelectTemplateToDeleteDialog extends StatelessWidget {
  final List<Map<String, dynamic>> templates; //

  const SelectTemplateToDeleteDialog({
    Key? key, //
    required this.templates, //
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog( // Aplicará DialogTheme
      title: Text(l10n.template_delete
      ), //
      content: Container( //
        width: double.maxFinite, //
        child: templates.isEmpty
            ? Center( //
            child: Padding( //
              padding: EdgeInsets.all(8.0), //
              child: Text(l10n.template_donthave), //
            ))
            : ListView.builder( //
          shrinkWrap: true, //
          itemCount: templates.length, //
          itemBuilder: (BuildContext context, int index) {
            final template = templates[index]; //
            final String templateName = template['name']?.toString() ?? 'Plantilla'; //
            final int templateId = template['id']; //

            return ListTile( // Aplicará ListTileTheme
              title: Text(templateName), //
              onTap: () async { //
                final bool? confirmedDelete = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext confirmDialogContext) {
                    return ConfirmDeleteDialog( //
                      templateId: templateId, //
                      templateName: templateName, //
                    );
                  },
                );
                if (confirmedDelete == true) { //
                  Navigator.of(context).pop(true); //
                }
              },
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton( // Aplicará TextButtonTheme
          child: Text(l10n.cancel), //
          onPressed: () { //
            Navigator.of(context).pop(false); //
          },
        ),
      ],
    );
  }
}

class ConfirmDeleteDialog extends StatelessWidget {
  final int templateId; //
  final String templateName; //

  const ConfirmDeleteDialog({
    Key? key, //
    required this.templateId, //
    required this.templateName, //
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog( // Aplicará DialogTheme
      title:  Text(l10n.template_question), //
      content: Text(l10n.template_question2(templateName)), //
      actionsAlignment: MainAxisAlignment.spaceAround, //
      actions: <Widget>[
        TextButton( // Aplicará TextButtonTheme
          child: Text(l10n.cancel), //
          onPressed: () { //
            Navigator.of(context).pop(false); //
          },
        ),
        ElevatedButton( // Botón de confirmación de borrado
          style: Theme.of(context).elevatedButtonTheme.style?.copyWith( // Hereda del tema pero cambia colores
            backgroundColor: MaterialStateProperty.all(Theme.of(context).colorScheme.error), // Usa el color de error del tema
            foregroundColor: MaterialStateProperty.all(Theme.of(context).colorScheme.onError),
            side: MaterialStateProperty.all(BorderSide(color: amarilloPrincipal, width: 1.5)), // Mantiene borde amarillo
          ),
          child: Text(l10n.deleteButton), //
          onPressed: () async { //
            final db = DatabaseHelper.instance; //
            await db.deleteTemplate(templateId); //
            Navigator.of(context).pop(true); //
          },
        ),
      ],
    );
  }
}

import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../database/database_helper.dart'; // Asegúrate que la ruta sea correcta
import 'package:device_info_plus/device_info_plus.dart';
import 'package:intl/intl.dart'; // Para formateo de fechas si es necesario
import '../utils/localization_utils.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../settings.dart';
import 'package:diacritic/diacritic.dart';
import 'widgets/stopwatch.dart';



enum ProgressStatus { improvement, decline, neutral, noData }
// Clase principal de la pantalla de Entrenamiento
class TrainingScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? initialExercises;
  final String? templateName;
  final Map<String, dynamic>? sessionToEdit;

  const TrainingScreen({
    Key? key,
    this.initialExercises,
    this.templateName,
    this.sessionToEdit,
  }) : super(key: key);

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  late String trainingTitle;
  List<Map<String, dynamic>> selectedExercises = [];
  List<Map<String, dynamic>> availableExercises = [];
  bool _didDataChange = false;
  bool _isTitleInitialized = false;

  DateTime? _startTime;
  Timer? _uiUpdateTimer;
  Duration _staticDurationForEditing = Duration.zero;

  void _removeExerciseFromTraining(int index) {

    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      if (index >= 0 && index < selectedExercises.length) {
        final Map<String, dynamic> exerciseToRemove = selectedExercises[index];
        final String localizedExerciseName = getLocalizedExerciseName(context, exerciseToRemove);

        setState(() {
          selectedExercises.removeAt(index);
          _didDataChange = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(l10n.training_quit_exercise(localizedExerciseName))),
        );
      } else {
        debugPrint(
            "Error en _removeExerciseFromTraining: Índice $index está fuera de los límites para selectedExercises de tamaño ${selectedExercises.length}.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(l10n.training_quit_error),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getFormattedCurrentDate(BuildContext context) {
    final now = DateTime.now();
    // Cambiamos el formato a 'dd/MM/yyyy'
    // El locale 'es_ES' no es estrictamente necesario para este formato numérico,
    // pero es bueno mantenerlo por si decides cambiar a otros formatos que sí dependan del idioma.
    final String localeName = AppLocalizations.of(context)!.localeName;

    final formatter = DateFormat('dd/MM/yyyy', localeName);
    return formatter.format(now); // Esto producirá algo como "25/05/2025"
  }

  void _initializeAndStartStopwatch() {
    if (widget.sessionToEdit == null) {
      // MODO NUEVO ENTRENAMIENTO: Guardamos la hora de inicio
      _startTime = DateTime.now();

      // Iniciamos un temporizador que solo actualiza la UI para que el cronómetro "avance"
      _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            // No necesitamos calcular nada aquí, solo redibujar.
          });
        }
      });
    } else {
      // MODO EDICIÓN: No iniciamos el cronómetro. Solo mostramos la duración guardada.
      _staticDurationForEditing =
          Duration(seconds: widget.sessionToEdit?['duration'] as int? ?? 0);
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeAndStartStopwatch();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        final String formattedDate = _getFormattedCurrentDate(context);
        setState(() {
          if (widget.sessionToEdit != null) {
            trainingTitle = widget.sessionToEdit!['session_title']?.toString() ?? l10n.training_title_date(formattedDate);
          } else if (widget.templateName != null && widget.templateName!.isNotEmpty) {
            trainingTitle = widget.templateName!;
          } else {
            trainingTitle = l10n.training_title_date(formattedDate);
          }
          _isTitleInitialized = true;
        });
      }
    });

    if (widget.initialExercises != null) {
      selectedExercises = widget.initialExercises!.map((ex) {
        var newEx = Map<String, dynamic>.from(ex);
        if (newEx['reps'] is String) {
          newEx['reps'] = (newEx['reps'] as String)
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        } else if (newEx['reps'] == null || newEx['reps'] is! List) {
          newEx['reps'] = <String>[];
        }

        newEx['weight'] = newEx['weight']?.toString() ?? '';
        // weightUnit ahora será una cadena de unidades separadas por comas, o una sola si es antigua.
        // Por defecto, 'lb' si no existe.
        newEx['weightUnit'] = newEx['weightUnit']?.toString() ?? 'lb';
        newEx['series'] = newEx['series']?.toString() ?? '';
        newEx['notes'] = newEx['notes']?.toString() ?? '';
        newEx['db_category_id'] = ex['category_id'] ?? ex['id'];
        newEx['isManual'] = (ex['is_predefined'] ?? 1) == 0;
        return newEx;
      }).toList();
    }
    _loadAvailableExercises();
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Este método se llama después de initState y también cuando las dependencias del widget cambian.
    // Es un lugar seguro para usar AppLocalizations.of(context) si el título no ha sido inicializado por la plantilla.
    if (!_isTitleInitialized) { // Solo si no se inicializó con widget.templateName
      final l10n = AppLocalizations.of(context)!;
      final String formattedDate = _getFormattedCurrentDate(context);
      if (widget.templateName != null && widget.templateName!.isNotEmpty) {
        trainingTitle = widget.templateName!;
      } else {
        final String formattedDate = _getFormattedCurrentDate(context);
        trainingTitle = l10n.training_title_date(formattedDate);
      }
      _isTitleInitialized = true;
    }
  }

  Future<List<Map<String, dynamic>>> _loadAvailableExercises() async {
    final l10n = AppLocalizations.of(context)!;
    final db = DatabaseHelper.instance;
    debugPrint("Cargando ejercicios disponibles desde DB...");


    List<Map<String, dynamic>> exercisesFromDb;
    try {
      // getCategories fetches all exercises, both predefined and user-created
      exercisesFromDb = await db.getCategories(); //
    } catch (e) {
      debugPrint("Error cargando ejercicios de la DB: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(l10n.training_db_error(e.toString())),
              backgroundColor: Colors.red),
        );
      }
      return availableExercises; // Return current list or empty if error
    }

    final Map<String, Map<String, dynamic>> allAvailableExercisesMap = {};

    for (var ex in exercisesFromDb) {
      final name = ex['name']?.toString();
      if (name != null && name.isNotEmpty) {
        // The 'is_predefined' column should exist if DB version is updated.
        // It's 1 for predefined exercises, 0 or null for user-created ones.
        bool isPredefined = (ex['is_predefined'] == 1);

        allAvailableExercisesMap[name] = {
          'id': ex['id'], // ID from the 'categories' table
          'name': name,
          'image': ex['image']?.toString() ?? '',
          'category': ex['muscle_group']?.toString() ?? '', //
          'description': ex['description']?.toString() ?? '', //
          'isManual': !isPredefined, // THIS IS THE KEY CHANGE: 'isManual' is true if NOT predefined
          'db_category_id': ex['id'], // Using the exercise's own ID from 'categories' table
          // Ensure all fields expected by ExerciseOverlay are present
          'is_predefined': isPredefined ? 1 : 0,
          'original_id': ex['original_id'],
        };
      }
    }

    final allUniqueAvailableExercises = allAvailableExercisesMap.values.toList();
    allUniqueAvailableExercises.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));


    if (mounted) {
      setState(() {
        availableExercises = allUniqueAvailableExercises; //
      });
    }
    debugPrint(
        "Total de ejercicios cargados para el overlay: ${allUniqueAvailableExercises.length}"); //
    if (allUniqueAvailableExercises.isEmpty) {
      debugPrint(
          "Advertencia: La lista de 'availableExercises' está vacía después de cargar."); //
    }
    return allUniqueAvailableExercises;
  }


  void _onExerciseCheckedInOverlay(Map<String, dynamic> exercise) {
    setState(() {
      if (!selectedExercises.any((ex) => ex['name'] == exercise['name'])) {
        selectedExercises.add({
          'name': exercise['name'],
          'series': '',
          'weight': '',
          'weightUnit': '',
          'reps': <String>[],
          'notes': '',
          'image': exercise['image'],
          'category': exercise['category'],
          'description': exercise['description'],
          'isManual': exercise['isManual'] ?? false,
          'id': exercise['id'], // ID de la tabla template_exercises (si existe)
          'db_category_id': exercise['id'], // ID de la tabla categories
          'is_predefined': exercise['is_predefined'],
          'original_id': exercise['original_id'],
        });
        _didDataChange = true;
      }
    });
  }

  // Esta función se encarga de actualizar el orden de la lista
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final Map<String, dynamic> item = selectedExercises.removeAt(oldIndex);
      selectedExercises.insert(newIndex, item);
      _didDataChange = true;
    });
  }
  void _onExerciseUncheckedInOverlay(Map<String, dynamic> exercise) {
    setState(() {
      selectedExercises.removeWhere((ex) => ex['name'] == exercise['name']);
      _didDataChange = true;
    });
  }

  void _openExerciseOverlay() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext sbfContext, StateSetter setDialogState) {
            return Dialog(
              insetPadding: EdgeInsets.all(
                  MediaQuery.of(sbfContext).size.width * 0.05),
              child: ExerciseOverlay(
                getAvailableExercises: _loadAvailableExercises,
                availableExercises: availableExercises,
                selectedExercisesForCheckboxes: selectedExercises,
                onNewExercise: (newExerciseMap) async {
                  await _loadAvailableExercises();
                  setDialogState(() {});
                  if (mounted) {
                    final l10n = AppLocalizations.of(sbfContext)!;
                    final String exerciseName = newExerciseMap['name']?.toString() ?? '';
                    ScaffoldMessenger.of(sbfContext).showSnackBar(
                      SnackBar(
                          content: Text(l10n.training_create_exercise(exerciseName)))
                      );
                  }
                },
                onExerciseChecked: (exercise) {
                  _onExerciseCheckedInOverlay(exercise);
                  setDialogState(() {});
                },
                onExerciseUnchecked: (exercise) {
                  _onExerciseUncheckedInOverlay(exercise);
                  setDialogState(() {});
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _onWillPop() async {
    final l10n = AppLocalizations.of(context)!;
    if (selectedExercises.isEmpty && !_didDataChange) {
      Navigator.of(context).pop(false);
      return false;
    }
    final String dialogMessage = l10n.training_cancel_training;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.training_cancel_training_message),
        content: Text(dialogMessage),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text("No")),
          ElevatedButton( // Para destacar la acción de salida
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.training_cancel_exit)),
        ],
      ),
    );
    if (result == true) {
      Navigator.of(context).pop(_didDataChange);
      return false;
    }
    return false;
  }

  Future<void> _saveTemplate(
      String name, List<Map<String, dynamic>> exercisesToSave) async {
    final db = DatabaseHelper.instance;

    try {
      // Insertar la plantilla
      final templateId = await db.insertTemplate(name);

      // Obtener los IDs correctos de los ejercicios
      final categoryIds = exercisesToSave.map<int>((ex) {
        // Prioridad 1: Usar db_category_id si existe
        if (ex['db_category_id'] != null) {
          return ex['db_category_id'] as int;
        }
        // Prioridad 2: Usar id si existe
        else if (ex['id'] != null) {
          return ex['id'] as int;
        }
        // Prioridad 3: Si no hay ID, buscar por nombre
        else {
          debugPrint("Advertencia: Ejercicio sin ID, buscando por nombre: ${ex['name']}");
          return -1; // Marcador temporal, se manejará después
        }
      }).where((id) => id != -1).toList();

      if (categoryIds.isEmpty) {
        throw Exception("No se pudieron obtener IDs válidos para los ejercicios");
      }

      // Insertar las relaciones ejercicio-plantilla
      await db.insertTemplateExercises(templateId, categoryIds);

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.training_template_success(name))),
        );
        setState(() {
          _didDataChange = true;
        });
      }
    } catch (e) {
      debugPrint("Error al guardar plantilla: $e");
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openExerciseDataDialog(Map<String, dynamic> exercise, int index) {
    final db = DatabaseHelper.instance;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: db.getLastExerciseLog(exercise['name']?.toString() ?? ''),
          builder: (context, snapshot) {
            return ExerciseDataDialog(
              exercise: Map<String, dynamic>.from(selectedExercises[index]),
              lastLog: snapshot.data,
              onDataUpdated: (updatedExercise) {
                if (mounted) {
                  setState(() {
                    selectedExercises[index] = updatedExercise;
                    _didDataChange = true;
                  });
                }
              },
              onExerciseDefinitionChanged: () async {
                debugPrint(
                    "TrainingScreen: Definición de ejercicio cambiada. Recargando availableExercises...");
                await _loadAvailableExercises();
                if (mounted) {
                  final String oldName = exercise['name'];
                  final updatedExerciseDefinition = availableExercises.firstWhere(
                        (ex) => ex['id'] == exercise['id'] && ex['isManual'] == true,
                    orElse: () => selectedExercises[index],
                  );
                  setState(() { // Actualizar datos de definición en selectedExercises
                    selectedExercises[index]['name'] = updatedExerciseDefinition['name'];
                    selectedExercises[index]['description'] = updatedExerciseDefinition['description'];
                    selectedExercises[index]['image'] = updatedExerciseDefinition['image'];
                    selectedExercises[index]['category'] = updatedExerciseDefinition['category'];
                  });
                }
              },
            );
          },
        );
      },
    );
  }

  void _editTrainingTitle() {
    final l10n = AppLocalizations.of(context)!;
    TextEditingController controller = TextEditingController(text: trainingTitle);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.training_edit),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: l10n.title),
          autofocus: true,
          onSubmitted: (newTitle) {
            if (mounted && newTitle.trim().isNotEmpty) {
              setState(() {
                trainingTitle = newTitle.trim();
                _didDataChange = true;
              });
            }
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () {
              if (mounted && controller.text.trim().isNotEmpty) {
                setState(() {
                  trainingTitle = controller.text.trim();
                  _didDataChange = true;
                });
              }
              Navigator.of(context).pop();
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void _confirmFinishTraining() async {
    final l10n = AppLocalizations.of(context)!;
    if (selectedExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.training_exercise_required)),
      );
      return;
    }

    for (var exercise in selectedExercises) {
      final seriesStr = exercise['series']?.toString() ?? '';
      final repsValue = exercise['reps'];
      final weightsStr = exercise['weight']?.toString() ?? '';
      final unitsStr = exercise['weightUnit']?.toString() ?? '';
      final l10n = AppLocalizations.of(context)!;


      final String displayExerciseName = getLocalizedExerciseName(context, exercise);

      if (seriesStr.isEmpty || seriesStr == '0') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.training_edit_message(displayExerciseName))),
        );
        return;
      }
      int seriesCount = int.tryParse(seriesStr) ?? 0;
      List<String> repsList = [];
      if (repsValue is List) {
        repsList = List<String>.from(repsValue);
      } else if (repsValue is String) {
        repsList = repsValue.split(',').map((s) => s.trim()).toList();
      }
      List<String> weightsList = weightsStr.split(',').map((s) => s.trim()).toList();
      List<String> unitsList = unitsStr.split(',').map((s) => s.trim()).toList();


      if (repsList.length != seriesCount || repsList.any((r) => r.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.training_edit_reps_message(displayExerciseName))),
        );
        return;
      }
      if (weightsList.length != seriesCount || weightsList.any((w) => w.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.training_edit_weight_message(displayExerciseName))),
        );
        return;
      }
      if (unitsList.length != seriesCount || unitsList.any((u) => u.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.training_edit_weight_units_message(displayExerciseName))),
        );
        return;
      }
    }
    final confirm = await showDialog<bool>(

      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.training_confirm_finish),
        content: Text(l10n.training_confirm_finish_message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("No")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.yesSaveChanges)),
        ],
      ),
    );

    if (confirm == true) {
      final db = DatabaseHelper.instance;
      _uiUpdateTimer?.cancel();
      final int durationInSeconds = (widget.sessionToEdit == null && _startTime != null)
          ? DateTime.now().difference(_startTime!).inSeconds
          : (widget.sessionToEdit?['duration'] as int? ?? 0);

      final String currentSessionTitle = trainingTitle;

      try {
        int sessionId;
        String sessionDateTimeStr;
        int? finalDuration;

        if (widget.sessionToEdit != null) {
          // los datos de la sesión original
          sessionId = widget.sessionToEdit!['id'] as int;
          sessionDateTimeStr = widget.sessionToEdit!['session_dateTime']; // <-- Usamos la fecha original
          finalDuration = widget.sessionToEdit!['duration'] as int?;


          // Actualizamos el título si ha cambiado
          await db.updateTrainingSession(sessionId, currentSessionTitle, sessionDateTimeStr, finalDuration);
          // Borramos los logs antiguos para reinsertar los nuevos (actualizados)
          await db.clearExerciseLogsForSession(sessionId);
          print("Sesión ID $sessionId actualizada.");

        } else {
          // Creamos una nueva sesión con la fecha actual
          sessionDateTimeStr = DateTime.now().toIso8601String();
          finalDuration = durationInSeconds;
          sessionId = await db.insertTrainingSession(currentSessionTitle, sessionDateTimeStr, finalDuration);
          print("Nueva sesión guardada con ID: $sessionId y duración: $finalDuration segs");
        }

        // Insertamos los registros de ejercicios (ya sean nuevos o actualizados)
        for (final exercise in selectedExercises) {
          String repsForDb = (exercise['reps'] as List? ?? []).join(',');
          String weightForDb = exercise['weight']?.toString() ?? '';
          String unitsForDb = exercise['weightUnit']?.toString() ?? '';

          await db.insertExerciseLogWithSessionId({
            'exercise_name': exercise['name'],
            'dateTime': sessionDateTimeStr, // Usamos la fecha correcta (original o nueva)
            'series': exercise['series']?.toString() ?? '',
            'reps': repsForDb,
            'weight': weightForDb,
            'weightUnit': unitsForDb,
            'notes': exercise['notes']?.toString() ?? '',
          }, sessionId);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.training_save_success(currentSessionTitle)),
          behavior: SnackBarBehavior.floating, // <-- AÑADE ESTO
    margin: const EdgeInsets.all(12.0), // <-- AÑADE UN MARGEN
    shape: RoundedRectangleBorder( // <-- FORMA OPCIONAL
    borderRadius: BorderRadius.circular(8.0),
    ),
    )
    );
    _didDataChange = true;
          Navigator.pop(context, _didDataChange);
        }
      } catch (e) {
        //debug
        print("Error al guardar la sesión de entrenamiento: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(l10n.training_save_error),
              backgroundColor: Colors.red));
        }
      }
    }
  }

  void _confirmSaveTemplate() async {
    final l10n = AppLocalizations.of(context)!;

    if (selectedExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
            content: Text(
                l10n.training_template_add)),
      );
      return;
    }
    final nameController = TextEditingController(text: trainingTitle);
    final templateNameFromDialog = await showDialog<String>(

      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.training_template_save),
        content: Column( // Envuelve el contenido en un Column
          mainAxisSize: MainAxisSize.min, // Para que la columna no ocupe todo el espacio vertical
          children: <Widget>[

          SizedBox(height: 10),

          TextField(
          controller: nameController,
          decoration: InputDecoration(labelText: l10n.training_template_name),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          ),
             SizedBox(height: 2),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context, nameController.text.trim());
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                      Text(l10n.training_template_name_message)),
                );
              }
            },
            child: Text(l10n.training_template_button),
          ),
        ],
      ),
    );
    if (templateNameFromDialog != null && templateNameFromDialog.isNotEmpty) {
      final db = DatabaseHelper.instance;
      final actualDb = await db.database; // Obtener la instancia de Database

      List<Map<String, dynamic>> existingTemplates = await actualDb.query( // Usar actualDb.query
        'templates',
        where: 'LOWER(name) = ?',
        whereArgs: [templateNameFromDialog.toLowerCase()],
        limit: 1,
      );

      if (existingTemplates.isNotEmpty) {
        if (mounted) {
          showDialog(
            context: context, // Usar el contexto de _TrainingScreenState
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                title: Text(l10n.training_template_duplicate),
                content: Text(l10n.training_template_duplicate_message(templateNameFromDialog)),
                actions: <Widget>[
                  TextButton(
                    child: Text(l10n.close),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                  ),
                ],
              );
            },
          );
        }
        return; // Detener la ejecución si el nombre está duplicado
      }
      await _saveTemplate(templateNameFromDialog, selectedExercises);
    }
  }


  void _confirmCancelTraining() async {
    await _onWillPop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Duration displayDuration;
    if (widget.sessionToEdit != null) {
      // Si estamos editando, mostramos la duración estática guardada
      displayDuration = _staticDurationForEditing;
    } else {
      // Si es un nuevo entrenamiento, calculamos la diferencia con la hora de inicio
      displayDuration = _startTime != null ? DateTime.now().difference(_startTime!) : Duration.zero;
    }
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.training_title),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: _confirmCancelTraining,
          ),
          actions: [
            TextButton(
              onPressed: _confirmCancelTraining,
              child: Text(l10n.cancel, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                    child: Text(trainingTitle,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))),
                IconButton(icon: Icon(Icons.edit, color: Theme.of(context).primaryColor), onPressed: _editTrainingTitle)
              ]),
              SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                Expanded(
                    child: ElevatedButton.icon(
                        icon: Icon(Icons.add),
                        onPressed: _openExerciseOverlay,
                        label: Text(l10n.training_add_exercise))),
                SizedBox(width: 10),
                Expanded(
                    child: ElevatedButton.icon(
                        icon: Icon(Icons.save_alt),
                        onPressed: _confirmSaveTemplate,
                        label: Text(l10n.training_create_template))),
              ]),
              if (_isTitleInitialized)
                StopwatchWidget(
                  elapsed: displayDuration,
                ),
              SizedBox(height: 2),
              if (selectedExercises.isEmpty)
                Expanded(
                    child: Center(
                        child: Text(l10n.training_add_exercises_to_training,
                            style:
                            TextStyle(fontSize: 16, color: Colors.grey))))
              else
                Expanded(
                  child: ReorderableListView.builder(
                    itemCount: selectedExercises.length,
                    onReorder: _onReorder,
                    itemBuilder: (context, index) {
                      final exercise = selectedExercises[index];
                      final itemKey = ValueKey(exercise['name']! + index.toString());
                      final exerciseName = getLocalizedExerciseName(context, exercise);
                      String seriesText = exercise['series']?.toString() ?? "-";
                      String repsText = "-";
                      if (exercise['reps'] is List && (exercise['reps'] as List).isNotEmpty) {
                        repsText = (exercise['reps'] as List).join(" | ");
                      } else if (exercise['reps'] is String && (exercise['reps'] as String).isNotEmpty) {
                        repsText = (exercise['reps'] as String).split(',').join(' | ');
                      }

                      String weightText = "-";
                      if (exercise['weight'] is String && (exercise['weight'] as String).isNotEmpty) {
                        List<String> weights = (exercise['weight'] as String).split(',');
                        List<String> units = (exercise['weightUnit']?.toString() ?? 'lb').split(',');
                        StringBuffer sb = StringBuffer();
                        for(int i=0; i < weights.length; i++) {
                          sb.write(weights[i].trim());
                          if (i < units.length && units[i].trim().isNotEmpty) {
                            sb.write(" ${units[i].trim()}");
                          } else if (units.isNotEmpty && units[0].trim().isNotEmpty) { // Fallback a la primera unidad si no hay suficientes
                            sb.write(" ${units[0].trim()}");
                          } else {
                            sb.write(" lb"); // Fallback general
                          }
                          if (i < weights.length - 1) sb.write(" | ");
                        }
                        weightText = sb.toString();
                      }
                      final String? exerciseImage = exercise['image'] as String?;
                      Widget imageWidget;
                      if (exerciseImage != null && exerciseImage.isNotEmpty) {
                        if (exerciseImage.startsWith('assets/')) {
                          imageWidget = Image.asset(exerciseImage, fit: BoxFit.cover, height: 60, width: 60);
                        } else {
                          imageWidget = Image.file(File(exerciseImage), fit: BoxFit.cover, height: 60, width: 60);
                        }
                      } else {
                        imageWidget = Icon(Icons.fitness_center, color: Colors.grey[600], size: 40);
                      }

                      return Row(
                        key: itemKey,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4.0),
                              child: Icon(Icons.drag_handle, color: Colors.grey),
                            ),
                          ),

                          Expanded(
                            child: Card(
                              margin: const EdgeInsets.symmetric(vertical: 6.0),
                              child: InkWell(
                                onLongPress: () async {
                                  final bool? confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text(l10n.removeExerciseDialogTitle),
                                      content: Text(l10n.training_quit_message(exerciseName)),
                                      actions: [
                                        TextButton(
                                            onPressed: () => Navigator.pop(ctx, false),
                                            child: Text("No")),
                                        ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: Text(l10n.training_quit_confirm)),
                                      ],
                                    ),
                                  );

                                  if (confirmed == true && mounted) {
                                    _removeExerciseFromTraining(index);
                                  }
                                },
                                child: Dismissible(
                                  key: Key('dismiss_${itemKey.toString()}'),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    decoration: BoxDecoration(
                                        color: Colors.red.shade700,
                                        borderRadius: BorderRadius.circular(10.0)),
                                    alignment: Alignment.centerRight,
                                    padding: EdgeInsets.symmetric(horizontal: 20),
                                    child: Icon(Icons.delete_sweep, color: Colors.white),
                                  ),
                                  confirmDismiss: (direction) async {
                                    return await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text(l10n.removeExerciseDialogTitle),
                                        content: Text(l10n.training_quit_message(exerciseName)),
                                        actions: [
                                          TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: Text("No")),
                                          ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: Text(l10n.training_quit_confirm)),
                                        ],
                                      ),
                                    ) ?? false;
                                  },
                                  onDismissed: (direction) {
                                    if (mounted) {
                                      _removeExerciseFromTraining(index);
                                    }
                                  },
                                  child: ListTile(
                                    contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                                    title: Row(
                                      children: [
                                        // El número vuelve a estar al inicio del título
                                        Text(
                                          '${index + 1}. ',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 17,
                                              color: Theme.of(context).primaryColor),
                                        ),
                                        Expanded(
                                          child: Text(
                                            exerciseName,
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              width: 60,
                                              height: 60,
                                              clipBehavior: Clip.antiAlias,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8.0),
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .surfaceVariant
                                                    .withOpacity(0.5),
                                              ),
                                              child: imageWidget,
                                            ),
                                            SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('${l10n.serie}: $seriesText',
                                                      style: TextStyle(fontSize: 14, height: 1.4)),
                                                  Text('${l10n.weight}: $weightText',
                                                      style: TextStyle(fontSize: 14, height: 1.4)),
                                                  Text('Reps: $repsText',
                                                      style: TextStyle(fontSize: 14, height: 1.4)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    trailing: IconButton(
                                      icon: Icon(Icons.edit_note,
                                          color: Theme.of(context).primaryColor, size: 28),
                                      onPressed: () => _openExerciseDataDialog(exercise, index),
                                    ),
                                    onTap: () => _openExerciseDataDialog(exercise, index),
                                    isThreeLine: true,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              SizedBox(height: 10),
              ElevatedButton.icon(
                icon: Icon(Icons.check_circle),
                onPressed: _confirmFinishTraining,
                label: Text(l10n.training_finish_and_save),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------- ExerciseOverlay Widget (Sin cambios importantes en esta iteración, se mantiene igual que la anterior) -----------
class ExerciseOverlay extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function() getAvailableExercises;
  final List<Map<String, dynamic>> availableExercises;
  final List<Map<String, dynamic>> selectedExercisesForCheckboxes;
  final Function(Map<String, dynamic> exerciseMap) onNewExercise;
  final Function(Map<String, dynamic> exercise) onExerciseChecked;
  final Function(Map<String, dynamic> exercise) onExerciseUnchecked;

  const ExerciseOverlay({
    Key? key,
    required this.getAvailableExercises,
    required this.availableExercises,
    required this.selectedExercisesForCheckboxes,
    required this.onNewExercise,
    required this.onExerciseChecked,
    required this.onExerciseUnchecked,
  }) : super(key: key);

  @override
  _ExerciseOverlayState createState() => _ExerciseOverlayState();
}

class _ExerciseOverlayState extends State<ExerciseOverlay> {
  List<Map<String, dynamic>> exercises = [];
  String searchQuery = '';
  String filterCategory = '';
  static const double iconButtonWidth = 48.0;
  final List<String> _canonicalMuscleGroupKeys = [
    '', // Representa "Todas las Categorías"
    'Chest', 'Quadriceps', 'Back', 'Biceps','Triceps', 'Shoulders','Trapeze', 'Glutes','Hamstrings', 'Calves', 'Abs', 'Other'

  ];

  @override
  void initState() {
    super.initState();
    exercises = List.from(widget.availableExercises);
    if (exercises.isEmpty) {
      debugPrint("ExerciseOverlay initState: La lista inicial 'availableExercises' está vacía. Intentando refrescar...");
      refreshExercises();
    }
  }

  @override
  void didUpdateWidget(covariant ExerciseOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.availableExercises != oldWidget.availableExercises) {
      setState(() {
        exercises = List.from(widget.availableExercises);
      });
    }
  }

  void _handleUncheck(Map<String, dynamic> exerciseToUncheck) {
    final l10n = AppLocalizations.of(context)!;

    // Busca el ejercicio correspondiente en la lista que contiene los datos del usuario.
    final exerciseWithData = widget.selectedExercisesForCheckboxes.firstWhere(
          (ex) => ex['name'] == exerciseToUncheck['name'],
      orElse: () => <String, dynamic>{}, // Devuelve un mapa vacío si no lo encuentra
    );

    // Verifica si alguno de los campos de datos tiene contenido.
    final bool hasSeries = exerciseWithData['series']?.toString().isNotEmpty ?? false;
    final bool hasReps = (exerciseWithData['reps'] is List) && (exerciseWithData['reps'] as List).isNotEmpty;
    final bool hasWeight = exerciseWithData['weight']?.toString().isNotEmpty ?? false;

    if (hasSeries || hasReps || hasWeight) {
      // Si hay datos, muestra un mensaje y no hagas nada más.
      showDialog(
        context: context, // Usa el contexto del _ExerciseOverlayState
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.training_unselect_error), // Nuevo título
          content: Text(l10n.training_unselect_error), // Mismo mensaje de antes
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.close), // Usa tu clave para "Cerrar"
            ),
          ],
        ),
      );
    } else {
      // Si no hay datos, procede a deseleccionar el ejercicio.
      widget.onExerciseUnchecked(exerciseToUncheck);
    }
  }


  Future<void> refreshExercises() async {
    debugPrint("ExerciseOverlay: Refrescando ejercicios...");
    final freshList = await widget.getAvailableExercises();
    if (mounted) {
      setState(() {
        exercises = freshList;
      });
      debugPrint(
          "ExerciseOverlay refreshExercises: ${freshList.length} ejercicios cargados. Lista vacía: ${freshList.isEmpty}");
    }
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    List<Map<String, dynamic>> filteredExercises = exercises.where((exercise) {
      String localizedName = removeDiacritics(getLocalizedExerciseName(context, exercise).trim().toLowerCase());

      String query = removeDiacritics(searchQuery.trim().toLowerCase());


      // Filtro de categoría SIEMPRE debe aplicarse
      final categoryOfExercise = exercise['category']?.toString() ?? exercise['muscle_group']?.toString() ?? '';
      final categoryMatch = filterCategory.isEmpty || categoryOfExercise == filterCategory;

      // Si el query está vacío, solo filtra por categoría
      if (query.isEmpty) return categoryMatch;

      // Divide el query en palabras
      final queryWords = query.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);

      // Cada palabra del query debe estar en el nombre del ejercicio
      final matchesAllWords = queryWords.every((word) => localizedName.contains(word));

      // Aplica ambos filtros
      return matchesAllWords && categoryMatch;
    }).toList();

    filteredExercises.sort((a, b) {
      final String nameA = getLocalizedExerciseName(context, a);
      final String nameB = getLocalizedExerciseName(context, b);
      return nameA.toLowerCase().compareTo(nameB.toLowerCase());
    });

    return Container(

      constraints:
      BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Theme.of(context).dialogTheme.backgroundColor ?? Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12.0)
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
                child: TextField(
                    decoration: InputDecoration(
                        labelText: l10n.training_search_exercise,
                        prefixIcon: Icon(Icons.search)),
                    onChanged: (value) =>
                        setState(() => searchQuery = value))),
            IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.pop(context))
          ]),
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(children: [
              Text("${AppLocalizations.of(context)!.category}: ",style: Theme.of(context).textTheme.titleSmall),
                SizedBox(width: 10),
                Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: filterCategory.isEmpty ? null : filterCategory,
                      hint: Text(getLocalizedCategoryName(context, '')),
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                      dropdownColor: Theme.of(context).cardColor,
                        items: _canonicalMuscleGroupKeys.map((key) {
                          return DropdownMenuItem<String>(
                            value: key, // El valor del item es la clave canónica
                            child: Text(getLocalizedCategoryName(context, key)), // El texto mostrado es traducido
                          );
                        }).toList(),
                      onChanged: (value) =>
                          setState(() => filterCategory = value ?? ''),
                    )),
              ])),
          Flexible(
              child: filteredExercises.isEmpty
                  ? Center(
                  child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                          exercises.isEmpty
                              ? l10n.loadingOrNoExercises
                              : l10n.noExercisesFoundWithFilters,
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500]))))
                  : ListView.builder(
                shrinkWrap: true,
                itemCount: filteredExercises.length,
                itemBuilder: (context, index) {
                  final exercise = filteredExercises[index];
                  final bool isSelected = widget
                      .selectedExercisesForCheckboxes
                      .any((selectedEx) =>
                  selectedEx['name'] == exercise['name']);
                  final String? exerciseImage =
                  exercise['image'] as String?;
                  final String exerciseName = getLocalizedExerciseName(context, exercise);

                  List<Widget> trailingItems = [];

                  if (exercise['isManual'] == true) {
                    trailingItems.add(SizedBox(
                        width: iconButtonWidth,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.delete_forever,
                              color: Colors.red.shade700),
                          tooltip: l10n.deletePermanentlyTooltip,
                          onPressed: () async {
                            final String exerciseNameForDialog =
                                exercise['name']?.toString() ??
                                    l10n.training_no_name;
                            final confirmed =
                            await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(l10n.training_delete_exercise),
                                  content: Text(l10n.training_delete_exercise_message(exerciseNameForDialog)
                                      ),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(
                                                ctx, false),
                                        child: Text(l10n.cancel)),
                                    ElevatedButton( // Destacar acción de borrado
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                        onPressed: () =>
                                            Navigator.pop(
                                                ctx, true),
                                        child: Text(l10n.deleteButton)),
                                  ],
                                ));
                            if (confirmed == true) {
                              bool wasSelectedInTraining = widget
                                  .selectedExercisesForCheckboxes
                                  .any((ex) =>
                              ex['name'] == exercise['name']);
                              await DatabaseHelper.instance
                                  .deleteCategory(exercise['id']);
                              if (wasSelectedInTraining) {
                                widget.onExerciseUnchecked(exercise);
                              }
                              await refreshExercises();
                              if (mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                    content: Text(
                                        l10n.training_delete_exercise_success(exerciseNameForDialog)))
                                );

                              }
                            }
                          },
                        )));
                  } else {
                    trailingItems.add(SizedBox(width: iconButtonWidth));
                  }
                  trailingItems.add(Checkbox(
                      value: isSelected,
                      activeColor: Theme.of(context).primaryColor,
                      onChanged: (bool? newValue) {
                        if (newValue == true)
                          widget.onExerciseChecked(exercise);
                        else
                          _handleUncheck(exercise);
                      }));

                  return Card(
                    elevation: 2,
                    margin: EdgeInsets.symmetric(vertical: 5.0),
                    child: ListTile(
                      leading: Container(
                        width: 50,
                        height: 50,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: (exerciseImage != null &&
                            exerciseImage.isNotEmpty)
                            ? (exerciseImage.startsWith('assets/'))
                            ? Image.asset(
                          exerciseImage,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stackTrace) =>
                              Icon(Icons.fitness_center,
                                  color: Colors.grey[600],
                                  size: 30),
                        )
                            : Image.file(
                          File(exerciseImage),
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stackTrace) =>
                              Icon(Icons.broken_image,
                                  color: Colors.grey[600],
                                  size: 30),
                        )
                            : Icon(Icons.fitness_center,
                            color: Colors.grey[600], size: 30),
                      ),
                      title: Text(exerciseName, style: TextStyle(fontWeight: FontWeight.w500)),
                      trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: trailingItems),
                      onTap: () {
                        if (isSelected) {
                          _handleUncheck(exercise);
                        } else {
                          widget.onExerciseChecked(exercise);
                        }
                      },
                    ),
                  );
                },
              )),
          Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: ElevatedButton.icon(
                icon: Icon(Icons.add_circle_outline),
                label: Text(l10n.training_new_exercise),
                style:
                ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 44)),
                onPressed: () async {
                  await showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (dialogCtx) => NewExerciseDialog(
                        onExerciseCreated: (newExerciseData) {
                          widget.onNewExercise(newExerciseData);
                        },
                      ));
                  await refreshExercises();
                },
              )),
        ],
      ),
    );
  }
}


// ----------- NewExerciseDialog Widget (Sin cambios importantes en esta iteración, se mantiene igual que la anterior) -----------
class NewExerciseDialog extends StatefulWidget {
  final Function(Map<String, dynamic> newExerciseData)? onExerciseCreated;
  final Map<String, dynamic>? exerciseToEdit;

  const NewExerciseDialog({
    Key? key,
    this.onExerciseCreated,
    this.exerciseToEdit,
  }) : super(key: key);

  @override
  _NewExerciseDialogState createState() => _NewExerciseDialogState();
}

class _NewExerciseDialogState extends State<NewExerciseDialog> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController nameController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  String? selectedMuscleGroup;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _imageWasRemovedOrReplaced = false;
  String? _initialImagePathPreview;

  final List<String> _canonicalMuscleGroupKeysForDialog = [
    'Chest', 'Quadriceps', 'Back', 'Biceps', 'Triceps', 'Shoulders','Trapeze', 'Glutes', 'Hamstrings', 'Calves', 'Abs', 'Other'
  ];

  bool get isEditMode => widget.exerciseToEdit != null;

  @override
  void initState() {
    super.initState();
    if (isEditMode && widget.exerciseToEdit != null) {
      final exerciseData = widget.exerciseToEdit!;
      nameController.text = exerciseData['name'] ?? '';
      descriptionController.text = exerciseData['description'] ?? '';

      // --- MODIFICACIÓN IMPORTANTE AQUÍ ---
      // Obtiene el valor del grupo muscular que viene del ejercicio a editar.
      // Recuerda que en _openEditExerciseDialog, 'muscle_group' se pobló con widget.exercise['category'].
      String? initialCanonicalMuscleGroup = exerciseData['muscle_group']?.toString();

      if (initialCanonicalMuscleGroup != null &&
          _canonicalMuscleGroupKeysForDialog.contains(initialCanonicalMuscleGroup)) {
        selectedMuscleGroup = initialCanonicalMuscleGroup;
      } else {
        // Si no es válida o es nula, puedes dejarlo como nulo para que el hint se muestre,
        // o asignar un valor por defecto si lo prefieres y el campo es requerido.
        selectedMuscleGroup = null;
        if (initialCanonicalMuscleGroup != null && initialCanonicalMuscleGroup.isNotEmpty) {
          debugPrint(
              "Advertencia en NewExerciseDialog: El ejercicio a editar tiene un grupo muscular canónico desconocido ('$initialCanonicalMuscleGroup'). Se restablecerá.");
        }
      }

      final String? imagePath = exerciseData['image'];
      if (imagePath != null && imagePath.isNotEmpty) {
        _initialImagePathPreview = imagePath;
        if (!imagePath.startsWith('assets/')) {
          if (Uri.tryParse(imagePath)?.isAbsolute ?? true) {
            try { _imageFile = File(imagePath); } catch (e) { _imageFile = null; }
          }
        }
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final l10n = AppLocalizations.of(context)!;

    debugPrint(" Iniciando _pickImage con fuente: $source");
    PermissionStatus status;
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        status = source == ImageSource.camera ? await Permission.camera.request() : await Permission.photos.request();
      } else {
        status = source == ImageSource.camera ? await Permission.camera.request() : await Permission.storage.request();
      }
    } else {
      status = source == ImageSource.camera ? await Permission.camera.request() : await Permission.photos.request();
    }

    if (status.isGranted) {
      try {
        final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 70, maxWidth: 800);
        if (pickedFile != null) {
          debugPrint(" Imagen seleccionada: ${pickedFile.path}");
          if (mounted) {
            setState(() {
              _imageFile = File(pickedFile.path);
              _imageWasRemovedOrReplaced = true;
              _initialImagePathPreview = null;
            });
          }
        } else { debugPrint(" Selección de imagen cancelada o pickedFile es null."); }
      } catch (e) {
        debugPrint(" EXCEPCIÓN al seleccionar imagen: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al seleccionar imagen: ${e.toString().substring(0, (e.toString().length > 100) ? 100 : e.toString().length)}')),
          );
        }
      }
    } else if (status.isPermanentlyDenied) {
      debugPrint(" Permiso DENEGADO PERMANENTEMENTE.");
      if (mounted) {

        await showDialog(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(l10n.training_required),
            content: Text(l10n.training_invalid),
            actions: <Widget>[
              TextButton( child: Text(l10n.cancel), onPressed: () => Navigator.of(dialogContext).pop(), ),
              ElevatedButton( child: Text(l10n.training_required_message), onPressed: () { Navigator.of(dialogContext).pop(); openAppSettings(); }, ),
            ],
          ),
        );
      }
    } else {
      debugPrint(" Permisos NO concedidos. Estado: $status");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar( SnackBar(content:
        Text(l10n.training_image_required)), );
      }
    }
  }


  @override
  Widget build(BuildContext context) {

    final l10n = AppLocalizations.of(context)!;
    Widget imagePreviewWidget;
    if (_imageFile != null) {
      imagePreviewWidget = Image.file( _imageFile!, height: 120, width: double.infinity, fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Container( height: 120, width: double.infinity, decoration: BoxDecoration( color: Colors.grey[300], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200) ), child: Center( child: Padding( padding: const EdgeInsets.all(8.0),
          child: Text(l10n.training_archive_error, textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700, fontSize: 12)), ))), );
    } else if (_initialImagePathPreview != null && _initialImagePathPreview!.isNotEmpty) {
      if (_initialImagePathPreview!.startsWith('assets/')) {
        imagePreviewWidget = Image.asset(_initialImagePathPreview!, height: 120, width: double.infinity, fit: BoxFit.contain);
      } else {
        imagePreviewWidget = Image.file(File(_initialImagePathPreview!), height: 120, width: double.infinity, fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Container( height: 120, width: double.infinity, decoration: BoxDecoration( color: Colors.grey[300], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade200) ), child: Center( child: Padding( padding: const EdgeInsets.all(8.0), child: Icon(Icons.broken_image_outlined, color: Colors.orange.shade700, size: 40), ))));
      }
    } else {
      imagePreviewWidget = Container( height: 120, width: double.infinity, decoration: BoxDecoration( color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3), border: Border.all(color: Colors.grey.shade400, width: 0.5), borderRadius: BorderRadius.circular(8)), child: Center( child: Icon(Icons.image_not_supported_outlined, color: Colors.grey[600], size: 50)), );
    }

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
            key: _formKey,
            child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Expanded( child: Text( isEditMode ?
                    (widget.exerciseToEdit!['name'] ?? l10n.training_edit_title) :
                    l10n.training_new_title, style: Theme.of(context).textTheme.titleLarge, overflow: TextOverflow.ellipsis, ), ),
                      IconButton( icon: Icon(Icons.close), onPressed: () => Navigator.pop(context)) ]),
                    SizedBox(height: 20),
                    TextFormField( controller: nameController, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(
                        labelText: l10n.training_name_exercise, border: OutlineInputBorder(),
                        hintText: l10n.training_name_exercise_hint), validator: (value) => (value == null || value.trim().isEmpty)
                        ? l10n.training_name_exercise_required : null, ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedMuscleGroup,
                      decoration: InputDecoration(
                          labelText: "${AppLocalizations.of(context)!.category} *", // Traduce "Grupo Muscular"
                          border: OutlineInputBorder()),
                      hint: Text(AppLocalizations.of(context)!.selectCategoryHint ?? "Selecciona un grupo"), // Añade una clave para el hint
                      items: _canonicalMuscleGroupKeysForDialog
                          .map((canonicalKey) => DropdownMenuItem(
                        value: canonicalKey, // El valor es la clave canónica
                        child: Text(getLocalizedCategoryName(context, canonicalKey)), // Muestra el nombre traducido
                      ))
                          .toList(),
                      onChanged: (value) => setState(() => selectedMuscleGroup = value),
                      validator: (value) => value == null
                          ? (AppLocalizations.of(context)!.selectCategoryValidator ?? 'Selecciona un grupo muscular') // Añade clave para el validador
                          : null,
                    ),
                    SizedBox(height: 16),
                    TextFormField( controller: descriptionController, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(
                        labelText: l10n.training_description, border: OutlineInputBorder(), alignLabelWithHint: true,
                        hintText: l10n.training_description_hint), maxLines: 3, minLines: 1, ),
                    SizedBox(height: 16),
                    Text(l10n.training_image, style: Theme.of(context).textTheme.titleSmall), SizedBox(height: 8),
                    Center(child: imagePreviewWidget),
                    Row( mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [ TextButton.icon( icon: Icon(Icons.photo_library_outlined),
                        label: Text(l10n.training_gallery), onPressed: () => _pickImage(ImageSource.gallery)), TextButton.icon( icon: Icon(Icons.camera_alt_outlined),
                        label: Text(l10n.training_camera), onPressed: () => _pickImage(ImageSource.camera)), ]),
                    if (_imageFile != null || (_initialImagePathPreview != null && _initialImagePathPreview!.isNotEmpty)) TextButton.icon( icon: Icon(Icons.delete_outline, color: Colors.red.shade600),
                      label: Text(l10n.training_image_quit, style: TextStyle(color: Colors.red.shade600)), onPressed: () { setState(() { _imageFile = null; _initialImagePathPreview = null; _imageWasRemovedOrReplaced = true; }); }, ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 44),
                          textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)
                      ),
                      onPressed: () async {

                        if (_formKey.currentState!.validate()) {
                          final l10n = AppLocalizations.of(context)!;
                          String trimmedName = nameController.text.trim();
                          String? imagePathToSave;

                          // --- INICIO DE LA LÓGICA CORREGIDA ---
                          if (_imageFile != null) {
                            // 1. Obtener el directorio de documentos de la app (lugar seguro y permanente).
                            final directory = await getApplicationDocumentsDirectory();

                            // 2. Crear un nombre de archivo único para evitar colisiones.
                            final String fileName = p.basename(_imageFile!.path);
                            final String newPath = p.join(directory.path, fileName);

                            // 3. Copiar el archivo desde la caché temporal a la nueva ruta permanente.
                            await _imageFile!.copy(newPath);

                            // 4. Usar la NUEVA ruta permanente para guardarla en la base de datos.
                            imagePathToSave = newPath;

                          } else if (_imageWasRemovedOrReplaced) {
                            // Si el usuario quitó la imagen, se guarda un valor nulo.
                            imagePathToSave = null;
                          } else if (isEditMode) {
                            // Si no se tocó la imagen en modo edición, se mantiene la ruta que ya tenía.
                            imagePathToSave = widget.exerciseToEdit!['image'];
                          }
                          // --- FIN DE LA LÓGICA CORREGIDA ---

                          Map<String, dynamic> exerciseDataForDb = {
                            'name': trimmedName,
                            'muscle_group': selectedMuscleGroup,
                            'image': imagePathToSave, // Aquí se usa la ruta correcta y permanente
                            'description': descriptionController.text.trim(),
                          };


                          final db = DatabaseHelper.instance;
                          if (isEditMode) {
                            final idToUpdate = widget.exerciseToEdit!['id'];
                            final String oldName = widget.exerciseToEdit!['name'];



                            if (trimmedName.toLowerCase() != oldName.toLowerCase()) {

                              final actualDb = await db.database;
                              List<Map<String, dynamic>> existingExercises = await actualDb.query(
                                'categories',
                                where: 'LOWER(name) = ?',
                                whereArgs: [trimmedName.toLowerCase()],
                                limit: 1,
                              );
                              if (existingExercises.isNotEmpty) {
                                if (mounted) {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext dialogContext) {
                                      return AlertDialog(
                                        title: Text(l10n.training_name_duplicated),
                                        content: Text(l10n.training_name_message(trimmedName)),
                                        actions: <Widget>[
                                          TextButton(
                                            child: Text(l10n.close),
                                            onPressed: () {
                                              Navigator.of(dialogContext).pop();
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                }
                                return; // Detener la ejecución
                              }
                            }
                            // Proceder con la actualización
                            await db.updateCategory(idToUpdate, exerciseDataForDb);
                            if (trimmedName.toLowerCase() != oldName.toLowerCase()) {
                              await db.updateExerciseLogsName(oldName, trimmedName);
                            }
                            if (mounted) {
                              Navigator.pop(context, {
                                'id': idToUpdate,
                                ...exerciseDataForDb,
                                'category': selectedMuscleGroup, // 'category' es como se usa 'muscle_group' en la app
                                'isManual': true, // Los ejercicios editados desde aquí son manuales
                              });
                            }
                          } else { // Creando un nuevo ejercicio
                            // --- Verificación de nombre duplicado ANTES de insertar ---
                            final actualDb = await db.database;
                            List<Map<String, dynamic>> existingExercises = await actualDb.query(
                              'categories',
                              where: 'LOWER(name) = ?',
                              whereArgs: [trimmedName.toLowerCase()],
                              limit: 1,
                            );

                            if (existingExercises.isNotEmpty) {
                              if (mounted) {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext dialogContext) {
                                    return AlertDialog(
                                      title: Text(l10n.training_name_duplicated),
                                      content: Text(l10n.training_name_message(trimmedName)),
                                      actions: <Widget>[
                                        TextButton(
                                          child: Text(l10n.close),
                                          onPressed: () {
                                            Navigator.of(dialogContext).pop();
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                );
                              }
                              return; // Detener la ejecución si el nombre está duplicado
                            }
                            // --- Fin de la verificación ---

                            // Si no hay duplicados, proceder con la inserción
                            final newExerciseId = await db.insertCategory(exerciseDataForDb);
                            Map<String, dynamic> newExerciseFullData = {
                              'id': newExerciseId,
                              ...exerciseDataForDb,
                              'isManual': true, // Los ejercicios nuevos son manuales
                              'category': selectedMuscleGroup, // 'category' es como se usa 'muscle_group' en la app
                            };
                            widget.onExerciseCreated?.call(newExerciseFullData);
                            if (mounted) {
                              Navigator.pop(context); // Cerrar el diálogo de NewExerciseDialog
                            }
                          }
                        }
                      },
                      child: Text(isEditMode ? l10n.training_name_edit : l10n.training_name_confirm),
                    ),
                  ],
                ))),
      ),
    );
  }
}

// ----------- ExerciseDataDialog Widget (CON CAMBIOS IMPORTANTES) -----------
class ExerciseDataDialog extends StatefulWidget {
  final Map<String, dynamic> exercise;
  final Map<String, dynamic>? lastLog;
  final Function(Map<String, dynamic> updatedExerciseData) onDataUpdated;
  final VoidCallback onExerciseDefinitionChanged;

  const ExerciseDataDialog({
    Key? key,
    required this.exercise,
    this.lastLog,
    required this.onDataUpdated,
    required this.onExerciseDefinitionChanged,
  }) : super(key: key);

  @override
  _ExerciseDataDialogState createState() => _ExerciseDataDialogState();
}

class _ExerciseDataDialogState extends State<ExerciseDataDialog>
    with SingleTickerProviderStateMixin {
  final _formKeyCurrentDataTab = GlobalKey<FormState>();
  late TabController _tabController;

  late TextEditingController seriesController;
  late List<TextEditingController> repControllers;
  late List<TextEditingController> weightControllers;
  late String weightUnit;
  late TextEditingController notesController;

  late List<String> repWarnings;
  late List<String> weightWarnings;
  late int seriesCountFromInput;
  String seriesWarningText = '';

  late Map<String, dynamic> _currentExerciseDataLog;
  bool _isUnitInitialized = false;

  late List<ProgressStatus> _progressStatuses;

  @override
  void initState() {
    super.initState();
    _currentExerciseDataLog = Map<String, dynamic>.from(widget.exercise);
    _tabController = TabController(length: 3, vsync: this);

    seriesController = TextEditingController(
        text: _currentExerciseDataLog['series']?.toString() ?? '');
    notesController = TextEditingController(
        text: _currentExerciseDataLog['notes']?.toString() ?? '');
    seriesCountFromInput = int.tryParse(seriesController.text.trim()) ?? 0;
    _initializeUnit();


    repControllers = [];
    weightControllers = [];
    repWarnings = [];
    weightWarnings = [];
    _progressStatuses = [];
    _initializeSeriesSpecificFields(); // Configura la cantidad de campos

    // Poblar controladores y unidades después de _initializeSeriesSpecificFields
    // Reps
    final repsValue = _currentExerciseDataLog['reps'];
    List<String> initialReps = [];
    if (repsValue is List) {
      initialReps = List<String>.from(repsValue.map((r) => r.toString()));
    } else if (repsValue is String && repsValue.isNotEmpty) {
      initialReps = repsValue.split(',').map((s) => s.trim()).toList();
    }
    for (int i = 0; i < repControllers.length && i < initialReps.length; i++) {
      repControllers[i].text = initialReps[i];
    }

    final String weightsString = _currentExerciseDataLog['weight']
        ?.toString() ?? '';
    if (weightsString.isNotEmpty) {
      List<String> initialWeights = weightsString.split(',').map((s) =>
          s.trim()).toList();
      for (int i = 0; i < weightControllers.length &&
          i < initialWeights.length; i++) {
        weightControllers[i].text = initialWeights[i];
      }
    }
    _updateAllProgressStatuses();
  }

  Future<void> _initializeUnit() async {
    // Prioridad 1: Usar la unidad guardada en el log del ejercicio (al editar)
    final dynamic existingUnitData = _currentExerciseDataLog['weightUnit'];
    if (existingUnitData is String && existingUnitData.isNotEmpty) {
      // Si el log tiene datos de unidades (ej. 'kg,kg,lb'), usa la primera como la unidad seleccionada.
      if (existingUnitData.contains(',')) {
        List<String> unitsList = existingUnitData.split(',');
        if (unitsList.isNotEmpty) {
          final firstUnit = unitsList[0].trim().toLowerCase();
          weightUnit = (firstUnit == 'kg' || firstUnit == 'lb') ? firstUnit : 'lb';
        }
      } else { // Si es una sola unidad (formato antiguo o una sola serie)
        final singleUnit = existingUnitData.trim().toLowerCase();
        weightUnit = (singleUnit == 'kg' || singleUnit == 'lb') ? singleUnit : 'lb';
      }
    } else {
      // Prioridad 2: Si no hay datos en el log, usa la preferencia guardada
      final prefs = await SharedPreferences.getInstance();
      weightUnit = prefs.getString(kUnitPreferenceKey) ?? 'lb'; // Fallback a 'lb'
    }

    // Asegura que el widget se reconstruya con la unidad correcta
    if(mounted) {
      setState(() {
        _isUnitInitialized = true;
      });
    }
  }

  void _initializeSeriesSpecificFields() {
    int targetSeriesForRepFields = min(seriesCountFromInput, 4);

    List<String> oldRepValues = repControllers.map((c) => c.text).toList();
    List<String> oldWeightValues = weightControllers
        .map((c) => c.text)
        .toList();

    repControllers = List.generate(targetSeriesForRepFields,
            (i) =>
            TextEditingController(
                text: i < oldRepValues.length ? oldRepValues[i] : ''));
    repWarnings = List.generate(targetSeriesForRepFields, (_) => '');

    weightControllers = List.generate(targetSeriesForRepFields,
            (i) =>
            TextEditingController(
                text: i < oldWeightValues.length ? oldWeightValues[i] : ''));
    weightWarnings = List.generate(targetSeriesForRepFields, (_) => '');
    _progressStatuses = List.generate(targetSeriesForRepFields, (_) => ProgressStatus.noData);
    _updateAllProgressStatuses();
  }
  void _updateProgressStatus(int index) {
    if (widget.lastLog == null) {
      if (mounted) setState(() => _progressStatuses[index] = ProgressStatus.neutral);
      return;
    }

    final List<String> lastRepsList = (widget.lastLog!['reps'] as String? ?? '').split(',');
    final List<String> lastWeightsList = (widget.lastLog!['weight'] as String? ?? '').split(',');

    if (index >= lastRepsList.length || index >= lastWeightsList.length) {
      if (mounted) setState(() => _progressStatuses[index] = ProgressStatus.neutral);
      return;
    }

    final double? lastWeight = double.tryParse(lastWeightsList[index].trim());
    final int? lastReps = int.tryParse(lastRepsList[index].trim());
    final double? currentWeight = double.tryParse(weightControllers[index].text.trim().replaceAll(',', '.'));
    final int? currentReps = int.tryParse(repControllers[index].text.trim());

    if (currentWeight == null || currentReps == null || lastWeight == null || lastReps == null) {
      if (mounted) setState(() => _progressStatuses[index] = ProgressStatus.noData);
      return;
    }

    ProgressStatus newStatus;
    if (currentWeight > lastWeight || (currentWeight == lastWeight && currentReps > lastReps)) {
      newStatus = ProgressStatus.improvement;
    } else if (currentWeight < lastWeight || (currentWeight == lastWeight && currentReps < lastReps)) {
      newStatus = ProgressStatus.decline;
    } else {
      newStatus = ProgressStatus.neutral;
    }

    if (mounted) setState(() => _progressStatuses[index] = newStatus);
  }
  // Función para actualizar todos los estados
  void _updateAllProgressStatuses() {
    for (int i = 0; i < repControllers.length; i++) {
      _updateProgressStatus(i);
    }
  }

  // Función que devuelve el ícono correspondiente
  Widget _buildProgressIcon(int index) {
    if (index >= _progressStatuses.length) {
      return const SizedBox(width: 24);
    }

    IconData iconData;
    Color iconColor;

    switch (_progressStatuses[index]) {
      case ProgressStatus.improvement:
        iconData = Icons.check_circle;
        iconColor = Colors.green;
        break;
      case ProgressStatus.decline:
        iconData = Icons.cancel;
        iconColor = Colors.red;
        break;
      case ProgressStatus.neutral:
        iconData = Icons.horizontal_rule_rounded;
        iconColor = Colors.grey;
        break;
      case ProgressStatus.noData:
        return const SizedBox(width: 24);
    }

    return Icon(iconData, color: iconColor);
  }

  // Dialogo informativo
  void _showProgressInfoDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.training_progress_info_title),
        content: Text(l10n.training_progress_info_content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          )
        ],
      ),
    );
  }

  void _validateRepValue(String value, int index) {
    final l10n = AppLocalizations.of(context)!;
    if (index >= repControllers.length) return;
    String trimmedValue = value.trim();
    setState(() {
      if (trimmedValue.isEmpty) {
        repWarnings[index] = l10n.calculator_required;
      } else {
        int? reps = int.tryParse(trimmedValue);
        if (reps != null) {
          if (reps < 1)
            repWarnings[index] = "Mín. 1";
          else if (reps > 99)
            repWarnings[index] = "Máx. 99";
          else if (reps < 6 && (weightWarnings[index].isEmpty ||
              !weightWarnings[index].contains("Mín. 1")))
            repWarnings[index] = l10n.training_weight_recommend;
          else if (reps > 12 && (weightWarnings[index].isEmpty ||
              !weightWarnings[index].contains("Mín. 1")))
            repWarnings[index] = l10n.training_weight_recommend2;
          else
            repWarnings[index] = "";
        } else {
          repWarnings[index] = l10n.training_set_invalid;
        }
      }
    });
    _updateProgressStatus(index);
  }

  void _validateWeightValue(String value, int index) {
    final l10n = AppLocalizations.of(context)!;
    if (index >= weightControllers.length) return;
    String trimmedValue = value.trim().replaceAll(',', '.');
    setState(() {
      if (trimmedValue.isEmpty) {
        weightWarnings[index] = l10n.calculator_required;
      } else {
        double? weightVal = double.tryParse(trimmedValue);
        if (weightVal != null) {
          if (weightVal < 1)
            weightWarnings[index] = "Mín. 1";
          else if (weightVal > 9999)
            weightWarnings[index] = "Máx. 9999";
          else
            weightWarnings[index] = "";
        } else {
          weightWarnings[index] = l10n.training_set_invalid;
        }
      }
      _updateProgressStatus(index);
    });
  }


  void _confirmAndSaveData() {
    final l10n = AppLocalizations.of(context)!;
    if (_tabController.index == 0) {
      if (!_formKeyCurrentDataTab.currentState!.validate()) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.training_error_form),
            backgroundColor: Colors.redAccent));
        return;
      }
    }

    bool hasBlockingErrors = false;
    int currentSeriesCount = int.tryParse(seriesController.text.trim()) ?? 0;

    if (seriesCountFromInput > 4) { // Límite que quieres restaurar
      seriesWarningText = l10n.training_set_recommend;
      seriesCountFromInput = 4; // Limitar a 4 campos
    } else if (seriesCountFromInput < 0) {
      seriesWarningText = l10n.training_set_error;
      seriesCountFromInput = 0; // No mostrar campos si es inválido
    } else {
      seriesWarningText =
      ""; // Limpiar advertencia para casos válidos (0 a 4 series)
    }

    if (currentSeriesCount > 0) {
      for (int i = 0; i < repControllers.length; i++) {
        String repVal = repControllers[i].text.trim();
        // --- CAMBIO 2: Se valida solo si el campo de repeticiones NO está vacío ---
        if (repVal.isNotEmpty) {
          int? r = int.tryParse(repVal);
          if (r == null) {
            setState(() => repWarnings[i] = l10n.training_set_invalid);
            hasBlockingErrors = true;
          } else if (r < 1) {
            setState(() => repWarnings[i] = "Mín. 1");
            hasBlockingErrors = true;
          } else if (r > 99) {
            setState(() => repWarnings[i] = "Máx. 99");
            hasBlockingErrors = true;
          } else {
            // Limpia advertencias si el valor es válido
            if (repWarnings[i] == l10n.calculator_required ||
                repWarnings[i] == l10n.training_set_invalid ||
                repWarnings[i] == "Mín. 1" ||
                repWarnings[i] == "Máx. 99") {} else {
              setState(() => repWarnings[i] = "");
            }
          }
        } else {
          // Si el campo está vacío, nos aseguramos de que no haya advertencias
          setState(() => repWarnings[i] = "");
        }


        String weightValStr = weightControllers[i].text.trim().replaceAll(
            ',', '.');
        // --- CAMBIO 3: Se valida solo si el campo de peso NO está vacío ---
        if (weightValStr.isNotEmpty) {
          double? w = double.tryParse(weightValStr);
          if (w == null) {
            setState(() => weightWarnings[i] = l10n.training_set_invalid);
            hasBlockingErrors = true;
          } else if (w <= 0) {
            setState(() => weightWarnings[i] = "Min. 1");
            hasBlockingErrors = true;
          } else if (w > 9999) {
            setState(() => weightWarnings[i] = "Máx. 9999");
            hasBlockingErrors = true;
          } else {
            setState(() => weightWarnings[i] = "");
          }
        } else {
          // Si el campo está vacío, nos aseguramos de que no haya advertencias
          setState(() => weightWarnings[i] = "");
        }
      }
    }

    if (hasBlockingErrors) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.training_image_required),
          backgroundColor: Colors.redAccent));
      return;
    }

    List<String> repsData = currentSeriesCount > 0 ? repControllers.map((c) =>
        c.text.trim()).toList() : [];
    List<String> weightsData = currentSeriesCount > 0 ? weightControllers.map((
        c) => c.text.trim().replaceAll(',', '.')).toList() : [];

    String unitsForDb;
    if (currentSeriesCount > 0) {
      // Repite la unidad de peso seleccionada para cada serie
      unitsForDb =
          List.generate(currentSeriesCount, (_) => weightUnit.trim()).join(',');
    } else {
      // Si no hay series, la cadena de unidades debe estar vacía
      unitsForDb = "";
    }
    _currentExerciseDataLog['series'] = seriesController.text.trim();
    _currentExerciseDataLog['reps'] = repsData;
    _currentExerciseDataLog['weight'] = weightsData.join(',');
    _currentExerciseDataLog['weightUnit'] =
        unitsForDb; // Guardar string de unidades
    _currentExerciseDataLog['notes'] = notesController.text.trim();

    widget.onDataUpdated(_currentExerciseDataLog);
    Navigator.pop(context);
  }

  double _calculate1RM(double weight, int reps) {
    if (reps <= 0) return 0;
    if (reps == 1) return weight;
    // Usamos la fórmula de O'Conner para una estimación más conservadora.
    // 1RM = Peso * (1 + 0.025 * Repeticiones)
    return weight * (1 + (0.025 * reps));
  }

// Widget que construye el gráfico
  Widget _buildHistoryChart(BuildContext context,
      List<Map<String, dynamic>> logs) {
    final l10n = AppLocalizations.of(context)!;
    final String localeName = l10n.localeName;
    final limitedLogs = logs.length > 5 ? logs.sublist(0, 5) : logs;
    final List<FlSpot> spots = [];
    final List<String> bottomTitles = [];
    final reversedLogs = limitedLogs.reversed.toList();

    for (int i = 0; i < reversedLogs.length; i++) {
      final log = reversedLogs[i];
      final List<String> repsList = (log['reps'] as String? ?? '').split(',');
      final List<String> weightsList = (log['weight'] as String? ?? '').split(
          ',');

      if (repsList.isNotEmpty && weightsList.isNotEmpty) {
        final lastRepStr = repsList.lastWhere((r) => r.isNotEmpty,
            orElse: () => '');
        final lastWeightStr = weightsList.lastWhere((w) => w.isNotEmpty,
            orElse: () => '');

        if (lastRepStr.isNotEmpty && lastWeightStr.isNotEmpty) {
          final int? reps = int.tryParse(lastRepStr);
          final double? weight = double.tryParse(lastWeightStr);
          final DateTime? logDate = DateTime.tryParse(
              log['dateTime'] as String? ?? '');

          if (reps != null && weight != null && logDate != null && reps > 0 &&
              weight > 0) {
            //en base a tu fuerza maxima 1RM
            //final double rm = _calculate1RM(weight, reps);
            //spots.add(FlSpot(i.toDouble(), rm));
            spots.add(FlSpot(i.toDouble(), weight));
            bottomTitles.add(DateFormat('d MMM', localeName).format(
                logDate)); // Formato como "9 oct."
          }
        }
      }
    }

    if (spots.isEmpty) {
      return const SizedBox.shrink(); // No mostrar nada si no hay datos
    }

    // Configuración y estilo del gráfico
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (index >= 0 && index < bottomTitles.length) {
                  // Muestra títulos de manera inteligente para evitar superposición
                  if (bottomTitles.length <= 5 || index == 0 ||
                      index == bottomTitles.length - 1 ||
                      index == (bottomTitles.length / 2).floor()) {
                    return SideTitleWidget(
                      meta: meta,
                      space: 8.0,
                      child: Text(bottomTitles[index],
                          style: const TextStyle(color: Colors.grey,
                              fontSize: 10)),
                    );
                  }
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(value.toStringAsFixed(0),
                    style: const TextStyle(color: Colors.grey, fontSize: 10));
              },
              reservedSize: 40,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: spots.map((s) => s.y).reduce(min) * 0.95,
        // Margen inferior
        maxY: spots.map((s) => s.y).reduce(max) * 1.05,
        // Margen superior
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: Theme
                .of(context)
                .primaryColor,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Theme
                  .of(context)
                  .primaryColor
                  .withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    seriesController.dispose();
    notesController.dispose();
    for (var controller in repControllers)
      controller.dispose();
    for (var controller in weightControllers)
      controller.dispose();
    super.dispose();
  }

  Future<void> _openEditExerciseDialog(BuildContext parentDialogContext) async {
    Map<String, dynamic> definitionDataToEdit = {
      'id': widget.exercise['id'],
      'name': widget.exercise['name'],
      'description': widget.exercise['description'],
      'image': widget.exercise['image'],
      'muscle_group': widget.exercise['category'],
      'isManual': widget.exercise['isManual'],
    };

    final result = await showDialog<Map<String, dynamic>>(
      context: parentDialogContext,
      barrierDismissible: false,
      builder: (dialogCtx) =>
          NewExerciseDialog(exerciseToEdit: definitionDataToEdit,),
    );

    if (result != null && mounted) {
      setState(() {
        _currentExerciseDataLog['name'] =
            result['name'] ?? _currentExerciseDataLog['name'];
        _currentExerciseDataLog['description'] =
            result['description'] ?? _currentExerciseDataLog['description'];
        _currentExerciseDataLog['image'] = result['image'];
        _currentExerciseDataLog['category'] =
            result['category'] ?? _currentExerciseDataLog['category'];
      });
      widget.onExerciseDefinitionChanged();
      debugPrint(
          "Definición de ejercicio actualizada en ExerciseDataDialog: ${_currentExerciseDataLog['name']}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final exerciseDefinitionForInfoTab = {
      'name': _currentExerciseDataLog['name'],
      'description': _currentExerciseDataLog['description'],
      'image': _currentExerciseDataLog['image'],
      'category': _currentExerciseDataLog['category'],
      'isManual': _currentExerciseDataLog['isManual'],
      'id': _currentExerciseDataLog['id'],
      'is_predefined': _currentExerciseDataLog['is_predefined'],
      // Asegúrate que esté
      'original_id': _currentExerciseDataLog['original_id']
    };

    return Dialog(

        insetPadding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(alignment: Alignment.centerRight, children: [
              TabBar(controller: _tabController, labelColor: Theme
                  .of(context)
                  .primaryColor, unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(text: l10n.training_current),
                  Tab(text: l10n.training_history),
                  Tab(text: 'Info'),
                ],),
              Positioned(right: 0,
                top: 0,
                bottom: 0,
                child: IconButton(icon: Icon(Icons.close),
                    onPressed: _confirmAndSaveData,
                    tooltip: l10n.close),)
            ]),
            Flexible(
                child: Container(
                  constraints: BoxConstraints(maxHeight: MediaQuery
                      .of(context)
                      .size
                      .height * 0.75),
                  child: TabBarView(controller: _tabController,
                    children: [
                      _buildCurrentDataTab(),
                      _buildHistoryTab(
                          exerciseNameToQuery: _currentExerciseDataLog['name'] ??
                              widget.exercise['name'] ?? ''),
                      _buildDescriptionTab(exerciseDefinitionForInfoTab),
                    ],),
                )),
          ],
        ));
  }

  Widget _buildCurrentDataTab() {
    final theme = Theme.of(context);
    final inputDecorationTheme = theme.inputDecorationTheme;
    // Determina si la advertencia "Se recomienda..." está activa
    bool isAdvisoryWarningActive = seriesWarningText.isNotEmpty;

    // Define los estilos del campo "Número de Series" basados en si la advertencia está activa
    // y permite que los estilos de error del validador tomen precedencia si hay un error de validación.

    // Color para la etiqueta del campo de Series
    TextStyle seriesLabelStyle = TextStyle(
      color: isAdvisoryWarningActive
          ? theme.colorScheme.error // Rojo si la advertencia está activa
          : inputDecorationTheme.labelStyle
          ?.color, // Color normal del tema si no
    );

    // BorderSide para el campo de Series cuando está habilitado (no enfocado)
    BorderSide seriesEnabledBorderSide = isAdvisoryWarningActive
        ? BorderSide(color: theme.colorScheme.error, width: 1.0) // Borde rojo si advertencia activa
        : inputDecorationTheme.enabledBorder?.borderSide ??
        BorderSide(color: Colors.grey[700]!, width: 0.5);

    // BorderSide para el campo de Series cuando está enfocado
    BorderSide seriesFocusedBorderSide = isAdvisoryWarningActive
        ? BorderSide(color: theme.colorScheme.error, width: 2.0) // Borde rojo más grueso si advertencia activa
        : inputDecorationTheme.focusedBorder?.borderSide ?? BorderSide(
        color: const Color(0xFFFFC107),
        width: 1.5); // Amarillo (amarilloPrincipal)
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKeyCurrentDataTab,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                getLocalizedExerciseName(context, _currentExerciseDataLog),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold,
                    fontSize: 20), // Cambia 'fontSize' a 20 o el tamaño deseado
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                // Alinea los elementos al inicio si tienen alturas diferentes (debido a errores)
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: seriesController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.training_num_series,
                        labelStyle: seriesLabelStyle,
                        // Aplicar estilo de etiqueta dinámico
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0)),
                        // Borde base
                        enabledBorder: OutlineInputBorder( // Borde cuando está habilitado
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: seriesEnabledBorderSide,
                        ),
                        focusedBorder: OutlineInputBorder( // Borde cuando está enfocado
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: seriesFocusedBorderSide,
                        ),
                        // No se establece errorText aquí; el validador se encarga.
                        // Si el validador retorna un error, TextFormField usará errorBorder, errorStyle, etc.
                      ),
                      onChanged: (value) {
                        final l10n = AppLocalizations.of(
                            context)!; // Obtén l10n aquí
                        setState(() {
                          seriesCountFromInput = int.tryParse(value.trim()) ??
                              0;

                          // --- LÓGICA DE ADVERTENCIA MOVIDA AQUÍ ---
                          if (seriesCountFromInput >
                              4) { // Límite que quieres restaurar
                            seriesWarningText = l10n.training_set_recommend;
                            seriesCountFromInput = 4; // Limitar a 4 campos
                          } else if (seriesCountFromInput < 0) {
                            seriesWarningText = l10n.training_set_error;
                            seriesCountFromInput =
                            0; // No mostrar campos si es inválido
                          } else {
                            seriesWarningText =
                            ""; // Limpiar advertencia para casos válidos (0 a 4 series)
                          }
                          _initializeSeriesSpecificFields(); // Ahora esta función solo prepara los campos
                        });
                      },
                      validator: (value) {
                        // Si el campo está vacío, no mostramos ningún error.
                        if (value == null || value.trim().isEmpty) {
                          return null;
                        }
                        // Si no está vacío, aplicamos las demás validaciones.
                        final n = int.tryParse(value.trim());
                        if (n == null) return l10n.training_set_invalid;
                        if (n < 0) return l10n.training_negative;
                        if (n > 99) return 'Máx. 99';
                        return null; // El valor es válido
                      },
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: _isUnitInitialized // Solo muestra el dropdown cuando la unidad ha sido inicializada
                        ? DropdownButtonFormField<String>(
                      value: weightUnit,
                      decoration: InputDecoration(
                        labelText: l10n.training_units,
                        border: OutlineInputBorder(),
                      ),
                      items: ['lb', 'kg']
                          .map((unit) =>
                          DropdownMenuItem(value: unit, child: Text(unit)))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => weightUnit = value ?? ''),
                      validator: (value) =>
                      value == null || value.isEmpty
                          ? l10n.training_selection_units
                          : null,
                    )
                        : Center(
                        child: SizedBox(
                            width: 24,
                            height: 24,
                            child:
                            CircularProgressIndicator(strokeWidth: 2.0))),
                  ),
                ],
              ),
              if (seriesWarningText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(
                      top: 5.0, left: 4.0, right: 4.0),
                  child: Text(
                    seriesWarningText,
                    style: TextStyle(
                      color: Theme
                          .of(context)
                          .colorScheme
                          .error,
                      fontSize: 12.0,
                    ),
                  ),
                ),
              SizedBox(height: 24),
              if (seriesCountFromInput <= 0)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Text(l10n.training_details_text,
                        style: TextStyle(
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic)))
              else
                ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: repControllers.length,
                    itemBuilder: (context, index) {
                      return Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Título "Set X" centrado
                                  Center(
                                    child: Text(
                                      '${l10n.serie} ${index + 1}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.85),
                                      ),
                                    ),
                                  ),
                                  if (index == 0)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: IconButton(
                                        icon: Icon(Icons.info_outline, color: theme.primaryColor),
                                        onPressed: _showProgressInfoDialog,
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 6),
                              // --- FILA DE CAMPOS DE ENTRADA ---
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: TextFormField(
                                      controller: repControllers[index],
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: l10n.repetitions,
                                        border: OutlineInputBorder(),
                                        errorMaxLines: 2,
                                        errorText: (repWarnings.length > index &&
                                            repWarnings[index].isNotEmpty)
                                            ? repWarnings[index]
                                            : null,
                                      ),
                                      onChanged: (value) =>
                                          _validateRepValue(value, index),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    flex: 5,
                                    child: TextFormField(
                                      controller: weightControllers[index],
                                      keyboardType:
                                      TextInputType.numberWithOptions(
                                          decimal: true),
                                      decoration: InputDecoration(
                                        labelText: l10n.weight,
                                        border: OutlineInputBorder(),
                                        errorMaxLines: 2,
                                        errorText:
                                        (weightWarnings.length > index &&
                                            weightWarnings[index].isNotEmpty)
                                            ? weightWarnings[index]
                                            : null,
                                      ),
                                      onChanged: (value) =>
                                          _validateWeightValue(value, index),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  SizedBox(
                                    width: 40,
                                    height: 60,
                                    child: Center(
                                        child: _buildProgressIcon(index)),
                                  ),
                                ],
                              )
                            ],
                          ));
                    }),
              SizedBox(height: 20),
              TextFormField(
                  controller: notesController,
                  decoration: InputDecoration(
                      labelText: l10n.training_notes,
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                      hintText: l10n.training_notes_hint),
                  maxLines: 3,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences),
              SizedBox(height: 24),
              if (widget.lastLog != null) ...[
                Text(l10n.training_register,
                    style: Theme.of(context).textTheme.titleMedium),
                SizedBox(height: 8),
                Builder(builder: (context) {
                  String formattedDate = l10n.training_date_unknown;
                  if (widget.lastLog!['dateTime'] != null) {
                    try {
                      DateTime dt = DateTime.parse(widget.lastLog!['dateTime']);
                      formattedDate =
                          DateFormat.yMMMMd(l10n.localeName).format(dt);
                    } catch (e) {
                      print(l10n.training_error_format);
                    }
                  }
                  return Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[400],
                      fontStyle: FontStyle.italic,
                    ),
                  );
                }),
                SizedBox(height: 8),
                LogRecordTable(log: widget.lastLog!),
                SizedBox(height: 24),
              ] else ...[
                Text(l10n.training_register,
                    style: Theme.of(context).textTheme.titleMedium),
                SizedBox(height: 8),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: Text(
                      l10n.training_register_error,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                SizedBox(height: 24),
              ],
              ElevatedButton(
                  onPressed: _confirmAndSaveData,
                  child: Text(l10n.training_update),
                  style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12))),
            ]),
      ),
    );
  }


  Widget _buildHistoryTab({required String exerciseNameToQuery}) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.instance.getExerciseLogs(exerciseNameToQuery),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(l10n.training_history_error,
                textAlign: TextAlign.center)));
        final logs = snapshot.data ?? [];
        if (logs.isEmpty) return Center(child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
                l10n.history_exercise_error(exerciseNameToQuery),
                textAlign: TextAlign.center)));

        return SingleChildScrollView( // Permite el scroll de toda la vista
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Contenedor para el gráfico con altura definida
                SizedBox(
                  height: MediaQuery
                      .of(context)
                      .size
                      .height * 0.3, // Aprox. mitad de la ventana
                  child: _buildHistoryChart(context, logs),

                ),
                const SizedBox(height: 4),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0), // Espacio antes del siguiente título
                    child: Text(
                      l10n.history_chart_description, // Nueva clave de localización
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 8),// Espacio entre gráfico y tablas
                Text(
                  l10n.training_history_all,
                  // Usamos la nueva clave de localización
                  style: Theme
                      .of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // ListView de las tablas de historial
                ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  // Deshabilita el scroll de esta lista
                  shrinkWrap: true,
                  // Se encoge para caber en la Column
                  itemCount: logs.length,
                  separatorBuilder: (_, __) =>
                  const Divider(height: 28, thickness: 1),
                  itemBuilder: (context, index) {
                    final l10n = AppLocalizations.of(context)!;
                    final log = logs[index];
                    String formattedDate = l10n.training_date_unknown;
                    if (log['dateTime'] != null) {
                      try {
                        DateTime dt = DateTime.parse(log['dateTime']);
                        formattedDate = DateFormat
                            .yMd(l10n.localeName)
                            .add_Hm()
                            .format(dt);
                      } catch (_) {}
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(formattedDate, style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 15)),
                        const SizedBox(height: 8),
                        LogRecordTable(log: log),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
        // --- FIN DEL CAMBIO ---
      },
    );
  }



  Widget _buildDescriptionTab(Map<String, dynamic> exerciseDefinition) {
    final exerciseImage = exerciseDefinition['image'] as String?;
    // exerciseDescription = exerciseDefinition['description'] as String?;
    final exerciseName = exerciseDefinition['name']?.toString();
    final bool isManualExercise = exerciseDefinition['isManual'] == true;
    final String localizedExerciseName = getLocalizedExerciseName(
        context, exerciseDefinition);
    final String localizedExerciseDescription = getLocalizedExerciseDescription(
        context, exerciseDefinition);
    final String canonicalCategoryKey = exerciseDefinition['category']
        ?.toString() ?? ''; // Suponiendo que 'category' tiene la clave canónica
    final String localizedCategory = getLocalizedCategoryName(
        context, canonicalCategoryKey);
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (exerciseImage != null && exerciseImage.isNotEmpty) Center(
            child: Padding(padding: const EdgeInsets.only(bottom: 16.0),
              child: Container(height: 180,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10.0),),
                child: exerciseImage.startsWith('assets/') ? Image.asset(
                  exerciseImage, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      Center(child: Icon(Icons.broken_image_outlined, size: 60,
                          color: Colors.grey.shade400)),)
                    : Image.file(File(exerciseImage), fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      Center(child: Icon(Icons.broken_image_outlined, size: 60,
                          color: Colors.grey.shade400)),),),),)
          else
            Center(child: Padding(padding: const EdgeInsets.only(bottom: 16.0),
              child: Container(height: 180,
                width: double.infinity,
                decoration: BoxDecoration(color: Theme
                    .of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(
                        color: Colors.grey.shade400, width: 0.5)),
                child: Icon(Icons.image_search_outlined, size: 80,
                    color: Colors.grey[500]),),),),
          Center(child: Text(
            localizedExerciseName,
            style: Theme
                .of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,),),
          SizedBox(height: 10), Divider(), SizedBox(height: 10),
          Text(
            AppLocalizations.of(context)!.category,
            // Ejemplo de cómo usar l10n para "Descripción:"
            style: Theme
                .of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6),
          Text(
            localizedExerciseDescription.isNotEmpty
                ? localizedExerciseDescription
                : l10n.training_description_unknown,
            // Usar descripción localizada
            style: Theme
                .of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(height: 1.5),
          ),
          if (isManualExercise) ...[
            const SizedBox(height: 24), // Espacio antes del botón
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: Text(l10n.training_edit_title), // Usamos la nueva clave
                onPressed: () {
                  _openEditExerciseDialog(context);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
// En training_screen.dart (al final del archivo)

class LogRecordTable extends StatelessWidget {
  final Map<String, dynamic> log;

  const LogRecordTable({
    Key? key,
    required this.log,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final int seriesCount = int.tryParse(log['series']?.toString() ?? '0') ?? 0;
    final List<String> reps = (log['reps']?.toString() ?? '').split(',');
    final List<String> weights = (log['weight']?.toString() ?? '').split(',');
    final List<String> units = (log['weightUnit']?.toString() ?? '').split(',');
    final String notes = log['notes']?.toString() ?? '';

    const TextStyle whiteBoldTextStyle = TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13);
    const TextStyle whiteTextStyle = TextStyle(color: Colors.white, fontSize: 13);

    List<TableRow> rows = [
      TableRow(
        decoration: BoxDecoration(color: theme.colorScheme.surfaceVariant.withOpacity(0.2)),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: Text(l10n.serie, style: whiteBoldTextStyle, textAlign: TextAlign.center),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: Text('Reps', style: whiteBoldTextStyle, textAlign: TextAlign.center),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: Text(l10n.weight, style: whiteBoldTextStyle, textAlign: TextAlign.center),
          ),
        ],
      ),
    ];

    for (int i = 0; i < seriesCount; i++) {
      // Determina la unidad para esta serie específica
      String unitForSet = 'lb'; // Fallback por defecto
      if (i < units.length && units[i].trim().isNotEmpty) {
        unitForSet = units[i].trim();
      } else if (units.isNotEmpty && units[0].trim().isNotEmpty) {
        unitForSet = units[0].trim();
      }

      rows.add(TableRow(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
            child: Text('${i + 1}', style: whiteTextStyle, textAlign: TextAlign.center),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
            child: Text(i < reps.length ? reps[i].trim() : '-', style: whiteTextStyle, textAlign: TextAlign.center),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
            child: Text(
              '${i < weights.length ? weights[i].trim() : '-'} $unitForSet',
              textAlign: TextAlign.center,
              style: whiteTextStyle,
            ),
          ),
        ],
      ));
    }

    if (seriesCount == 0) {
      rows.add(TableRow(children: [
        Padding(padding: const EdgeInsets.all(6.0), child: Text('-', style: whiteTextStyle, textAlign: TextAlign.center)),
        Padding(padding: const EdgeInsets.all(6.0), child: Text('-', style: whiteTextStyle, textAlign: TextAlign.center)),
        Padding(padding: const EdgeInsets.all(6.0), child: Text('-', style: whiteTextStyle, textAlign: TextAlign.center)),
      ]));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Table(
          border: TableBorder.all(color: theme.primaryColor, width: 1.0),
          columnWidths: const {
            0: FlexColumnWidth(0.8),
            1: FlexColumnWidth(1.2),
            2: FlexColumnWidth(1.8),
          },
          children: rows,
        ),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text("${l10n.notes} $notes", style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.white70)),
        ]
      ],
    );
  }
}
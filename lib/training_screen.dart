import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../database/database_helper.dart'; // Asegúrate que la ruta sea correcta
import 'package:device_info_plus/device_info_plus.dart';
import 'package:intl/intl.dart'; // Para formateo de fechas si es necesario




// Clase principal de la pantalla de Entrenamiento
class TrainingScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? initialExercises;
  final String? templateName;

  const TrainingScreen({
    Key? key,
    this.initialExercises,
    this.templateName,
  }) : super(key: key);

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  late String trainingTitle; // Declarar aquí
  List<Map<String, dynamic>> selectedExercises = [];
  List<Map<String, dynamic>> availableExercises = [];
  bool _didDataChange = false;

  void _removeExerciseFromTraining(int index) {
    if (mounted) {
      if (index >= 0 && index < selectedExercises.length) {
        final String exerciseNameToRemove =
            selectedExercises[index]['name']?.toString() ?? 'Ejercicio';

        setState(() {
          selectedExercises.removeAt(index);
          _didDataChange = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
              Text("'$exerciseNameToRemove' quitado del entrenamiento")),
        );
      } else {
        debugPrint(
            "Error en _removeExerciseFromTraining: Índice $index está fuera de los límites para selectedExercises de tamaño ${selectedExercises.length}.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Error al quitar el ejercicio. Índice inválido."),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getFormattedCurrentDate() {
    final now = DateTime.now();
    // Cambiamos el formato a 'dd/MM/yyyy'
    // El locale 'es_ES' no es estrictamente necesario para este formato numérico,
    // pero es bueno mantenerlo por si decides cambiar a otros formatos que sí dependan del idioma.
    final formatter = DateFormat('dd/MM/yyyy', 'es_ES');
    return formatter.format(now); // Esto producirá algo como "25/05/2025"
  }
  @override
  void initState() {
    super.initState();
    if (widget.templateName != null && widget.templateName!.isNotEmpty) {
      trainingTitle = widget.templateName!;
    } else {
      // Usar la fecha actual formateada para el título por defecto
      trainingTitle = "Entrenamiento del ${_getFormattedCurrentDate()}";
    }

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
        newEx['db_category_id'] = ex['category_id'];
        newEx['isManual'] = false;
        return newEx;
      }).toList();
    }
    _loadAvailableExercises();
  }

  Future<List<Map<String, dynamic>>> _loadAvailableExercises() async {
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
              content: Text("Error al cargar ejercicios: $e"),
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
          // 'category' for filtering in overlay, 'muscle_group' is the DB field name
          'category': ex['muscle_group']?.toString() ?? '', //
          'description': ex['description']?.toString() ?? '', //
          'isManual': !isPredefined, // THIS IS THE KEY CHANGE: 'isManual' is true if NOT predefined
          'db_category_id': ex['id'], // Using the exercise's own ID from 'categories' table
          // Ensure all fields expected by ExerciseOverlay are present
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
          'weightUnit': 'lb', // Por defecto 'lb', el diálogo lo expandirá a lista si es necesario
          'reps': <String>[],
          'notes': '',
          'image': exercise['image'],
          'category': exercise['category'],
          'description': exercise['description'],
          'isManual': exercise['isManual'] ?? false,
          'id': exercise['id'],
          'db_category_id': exercise['db_category_id'],
        });
        _didDataChange = true;
      }
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
      barrierDismissible: false,
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
                    ScaffoldMessenger.of(sbfContext).showSnackBar(
                      SnackBar(
                          content:
                          Text("Ejercicio '${newExerciseMap['name']}' creado y disponible.")),
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
    if (selectedExercises.isEmpty && !_didDataChange) {
      Navigator.of(context).pop(false);
      return false;
    }
    final String dialogMessage = "Los datos del entrenamiento actual no guardados se perderán. ¿Seguro que quieres salir?";
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Cancelar Entrenamiento"),
        content: Text(dialogMessage),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text("No")),
          ElevatedButton( // Para destacar la acción de salida
              onPressed: () => Navigator.of(context).pop(true),
              child: Text("Sí, Salir")),
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
    final templateId = await db.insertTemplate(name);
    final exercisesForTemplateDb = exercisesToSave.map((ex) {
      return {
        'template_id': templateId,
        'name': ex['name'],
        'image': ex['image'],
        'category_id': ex['db_category_id'] ?? ex['id'],
        'description': ex['description'],
      };
    }).toList();
    await db.insertTemplateExercises(templateId, exercisesForTemplateDb);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Plantilla '$name' guardada")),
      );
      setState(() {
        _didDataChange = true;
      });
    }
  }

  void _openExerciseDataDialog(Map<String, dynamic> exercise, int index) {
    final db = DatabaseHelper.instance;
    showDialog(
      context: context,
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
    TextEditingController controller = TextEditingController(text: trainingTitle);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Editar Título del Entrenamiento"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: "Título"),
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
              child: Text("Cancelar")),
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
            child: Text("Guardar"),
          ),
        ],
      ),
    );
  }

  void _confirmFinishTraining() async {
    if (selectedExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Añade al menos un ejercicio para terminar el entrenamiento.")),
      );
      return;
    }

    for (var exercise in selectedExercises) {
      final seriesStr = exercise['series']?.toString() ?? '';
      final repsValue = exercise['reps'];
      final weightsStr = exercise['weight']?.toString() ?? '';
      final unitsStr = exercise['weightUnit']?.toString() ?? '';

      if (seriesStr.isEmpty || seriesStr == '0') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("El ejercicio '${exercise['name']}' no tiene series definidas.")),
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
          SnackBar(content: Text("Datos de repeticiones incompletos para '${exercise['name']}'.")),
        );
        return;
      }
      if (weightsList.length != seriesCount || weightsList.any((w) => w.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Datos de peso incompletos para '${exercise['name']}'.")),
        );
        return;
      }
      if (unitsList.length != seriesCount || unitsList.any((u) => u.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Unidades de peso incompletas para '${exercise['name']}'.")),
        );
        return;
      }
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Terminar Entrenamiento"),
        content: Text("¿Guardar y terminar el entrenamiento actual?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("No")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text("Sí, Guardar")),
        ],
      ),
    );

    if (confirm == true) {
      final db = DatabaseHelper.instance;
      final String sessionDateTimeStr = DateTime.now().toIso8601String();
      final String currentSessionTitle = trainingTitle;

      try {
        int sessionId = await db.insertTrainingSession(currentSessionTitle, sessionDateTimeStr);
        print("Nueva sesión guardada con ID: $sessionId, Título: '$currentSessionTitle'");

        for (final exercise in selectedExercises) {
          String repsForDb;
          if (exercise['reps'] is List) {
            repsForDb = (exercise['reps'] as List).join(',');
          } else {
            repsForDb = exercise['reps']?.toString() ?? '';
          }
          String weightForDb = exercise['weight']?.toString() ?? ''; // Ya es "w1,w2,w3"
          String unitsForDb = exercise['weightUnit']?.toString() ?? ''; // Ya es "u1,u2,u3"

          await db.insertExerciseLogWithSessionId({
            'exercise_name': exercise['name'],
            'dateTime': DateTime.now().toIso8601String(),
            'series': exercise['series']?.toString() ?? '',
            'reps': repsForDb,
            'weight': weightForDb,
            'weightUnit': unitsForDb, // Guardar el string de unidades
            'notes': exercise['notes']?.toString() ?? '',
          }, sessionId);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Entrenamiento '$currentSessionTitle' guardado con éxito"),
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
        print("Error al guardar la sesión de entrenamiento: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("Error al guardar entrenamiento: $e"),
              backgroundColor: Colors.red));
        }
      }
    }
  }

  void _confirmSaveTemplate() async {
    if (selectedExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "Añade ejercicios al entrenamiento para guardarlo como plantilla.")),
      );
      return;
    }
    final nameController = TextEditingController(text: trainingTitle);
    final templateNameFromDialog = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Guardar como Nueva Plantilla"),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(labelText: "Nombre de la plantilla"),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,

        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context, nameController.text.trim());
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                      Text("El nombre de la plantilla no puede estar vacío.")),
                );
              }
            },
            child: Text("Guardar Plantilla"),
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
                title: Text("Nombre Duplicado"),
                content: Text("Ya existe una plantilla con el nombre '$templateNameFromDialog'. Por favor, elige un nombre diferente."),
                actions: <Widget>[
                  TextButton(
                    child: Text("Cerrar"),
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
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Entrenamiento"),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: _confirmCancelTraining,
          ),
          actions: [
            TextButton(
              onPressed: _confirmCancelTraining,
              child: Text("Cancelar", style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
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
                        label: Text("Añadir Ejer."))),
                SizedBox(width: 10),
                Expanded(
                    child: ElevatedButton.icon(
                        icon: Icon(Icons.save_alt),
                        onPressed: _confirmSaveTemplate,
                        label: Text("Crear Plantilla"))),
              ]),
              SizedBox(height: 16),
              if (selectedExercises.isEmpty)
                Expanded(
                    child: Center(
                        child: Text("Añade ejercicios a tu entrenamiento.",
                            style:
                            TextStyle(fontSize: 16, color: Colors.grey))))
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: selectedExercises.length,
                    itemBuilder: (context, index) {
                      final exercise = selectedExercises[index];
                      final exerciseName =
                          exercise['name']?.toString() ?? "Ejercicio";

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


                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Dismissible(
                          key: UniqueKey(),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            decoration: BoxDecoration(
                                color: Colors.red.shade700,
                                borderRadius: BorderRadius.circular(10.0)
                            ),
                            alignment: Alignment.centerRight,
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Icon(Icons.delete_sweep, color: Colors.white),
                          ),
                          confirmDismiss: (direction) async {
                            return await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text("Quitar Ejercicio"),
                                content: Text(
                                    "¿Quitar '$exerciseName' del entrenamiento? Los datos ingresados para este ejercicio se perderán."),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: Text("No")),
                                  ElevatedButton( // Destacar acción de quitar
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      child: Text("Sí, Quitar")),
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
                            title: Text(exerciseName,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                            subtitle: Column( // Usar Column para mejor estructura
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 4),
                                Text('Series: $seriesText', style: TextStyle(fontSize: 14, height: 1.4)),
                                Text('Peso: $weightText', style: TextStyle(fontSize: 14, height: 1.4)),
                                Text('Reps: $repsText', style: TextStyle(fontSize: 14, height: 1.4)),
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.edit_note,
                                  color: Theme.of(context).primaryColor, size: 28),
                              onPressed: () =>
                                  _openExerciseDataDialog(exercise, index),
                            ),
                            onTap: () =>
                                _openExerciseDataDialog(exercise, index),
                            isThreeLine: true, // Ajustar según sea necesario
                          ),
                        ),
                      );
                    },
                  ),
                ),
              SizedBox(height: 10),
              ElevatedButton.icon(
                icon: Icon(Icons.check_circle),
                onPressed: _confirmFinishTraining,
                label: Text("Terminar y Guardar Entrenamiento"),
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
    List<Map<String, dynamic>> filteredExercises = exercises.where((exercise) {
      final name = exercise['name']?.toString() ?? '';
      final nameMatch = name.toLowerCase().contains(searchQuery.toLowerCase());
      final categoryOfExercise =
          exercise['category']?.toString() ?? exercise['muscle_group']?.toString() ?? '';
      final categoryMatch =
          filterCategory.isEmpty || categoryOfExercise == filterCategory;
      return nameMatch && categoryMatch;
    }).toList();
    filteredExercises.sort((a, b) =>
        (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? ''));

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
                        labelText: "Buscar ejercicio",
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
                Text("Categoría: ", style: Theme.of(context).textTheme.titleSmall),
                SizedBox(width: 10),
                Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: filterCategory.isEmpty ? null : filterCategory,
                      hint: Text("Todas"),
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                      dropdownColor: Theme.of(context).cardColor,
                      items: <String>[
                        '', 'Pecho', 'Pierna', 'Espalda', 'Brazos', 'Hombros', 'Abdomen', 'Otro'
                      ]
                          .map((cat) => DropdownMenuItem(
                          value: cat, child: Text(cat.isEmpty ? "Todas" : cat)))
                          .toList(),
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
                              ? "Cargando o no hay ejercicios definidos..."
                              : "No se encontraron ejercicios con los filtros actuales.",
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
                  final String exerciseName =
                      exercise['name']?.toString() ?? "Ejercicio sin nombre";

                  List<Widget> trailingItems = [];

                  if (exercise['isManual'] == true) {
                    trailingItems.add(SizedBox(
                        width: iconButtonWidth,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.delete_forever,
                              color: Colors.red.shade700),
                          tooltip: "Borrar permanentemente",
                          onPressed: () async {
                            final String exerciseNameForDialog =
                                exercise['name']?.toString() ??
                                    'Ejercicio sin nombre';
                            final confirmed =
                            await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text("¿Borrar Ejercicio?"),
                                  content: Text(
                                      "'$exerciseNameForDialog' se eliminará permanentemente de la lista de ejercicios disponibles. Esta acción no se puede deshacer."),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(
                                                ctx, false),
                                        child: Text("Cancelar")),
                                    ElevatedButton( // Destacar acción de borrado
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                        onPressed: () =>
                                            Navigator.pop(
                                                ctx, true),
                                        child: Text("Borrar")),
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
                                        "Ejercicio '$exerciseNameForDialog' eliminado.")));
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
                          widget.onExerciseUnchecked(exercise);
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
                          widget.onExerciseUnchecked(exercise);
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
                label: Text('Crear Nuevo Ejercicio'),
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

  final List<String> muscleGroups = [
    'Pecho', 'Pierna', 'Espalda', 'Brazos', 'Hombros', 'Abdomen', 'Otro'
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
      String? initialMuscleGroupValue = exerciseData['muscle_group']?.toString();

      if (initialMuscleGroupValue != null && initialMuscleGroupValue.isEmpty) {
        // Si el valor es una cadena vacía, trátalo como nulo para el Dropdown.
        selectedMuscleGroup = null;
      } else if (initialMuscleGroupValue != null && !muscleGroups.contains(initialMuscleGroupValue)) {
        // Si el valor no es nulo, no está vacío, PERO NO ESTÁ EN LA LISTA de opciones válidas,
        // también trátalo como nulo. Esto puede pasar con datos antiguos o inconsistentes.
        print(
            "Advertencia: El ejercicio a editar tiene un grupo muscular desconocido ('$initialMuscleGroupValue'). Se restablecerá para que selecciones uno nuevo.");
        selectedMuscleGroup = null;
      } else {
        // Si el valor es nulo o es una cadena válida de la lista, úsalo.
        selectedMuscleGroup = initialMuscleGroupValue;
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
            title: Text("Permiso Requerido"),
            content: Text( "Esta función requiere permisos que fueron denegados permanentemente. Por favor, habilítalos en la configuración de la aplicación."),
            actions: <Widget>[
              TextButton( child: Text("Cancelar"), onPressed: () => Navigator.of(dialogContext).pop(), ),
              ElevatedButton( child: Text("Abrir Configuración"), onPressed: () { Navigator.of(dialogContext).pop(); openAppSettings(); }, ),
            ],
          ),
        );
      }
    } else {
      debugPrint(" Permisos NO concedidos. Estado: $status");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Se requieren permisos para acceder a las imágenes.')), );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    Widget imagePreviewWidget;
    if (_imageFile != null) {
      imagePreviewWidget = Image.file( _imageFile!, height: 120, width: double.infinity, fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Container( height: 120, width: double.infinity, decoration: BoxDecoration( color: Colors.grey[300], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200) ), child: Center( child: Padding( padding: const EdgeInsets.all(8.0), child: Text("Error al cargar preview de archivo", textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700, fontSize: 12)), ))), );
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
                    Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Expanded( child: Text( isEditMode ? (widget.exerciseToEdit!['name'] ?? 'Editar Ejercicio') : "Crear Nuevo Ejercicio", style: Theme.of(context).textTheme.titleLarge, overflow: TextOverflow.ellipsis, ), ), IconButton( icon: Icon(Icons.close), onPressed: () => Navigator.pop(context)) ]),
                    SizedBox(height: 20),
                    TextFormField( controller: nameController, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration( labelText: "Nombre del ejercicio *", border: OutlineInputBorder(), hintText: "Ej: Press de Banca"), validator: (value) => (value == null || value.trim().isEmpty) ? 'El nombre es requerido' : null, ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedMuscleGroup,
                      decoration: InputDecoration( labelText: "Grupo Muscular *", border: OutlineInputBorder()), hint: Text("Selecciona un grupo"), items: muscleGroups .map((group) => DropdownMenuItem(value: group, child: Text(group))) .toList(), onChanged: (value) => setState(() => selectedMuscleGroup = value), validator: (value) => value == null ? 'Selecciona un grupo muscular' : null, ),
                    SizedBox(height: 16),
                    TextFormField( controller: descriptionController, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration( labelText: "Descripción (opcional)", border: OutlineInputBorder(), alignLabelWithHint: true, hintText: "Ej: Movimiento principal para pectorales..."), maxLines: 3, minLines: 1, ),
                    SizedBox(height: 16),
                    Text("Imagen del Ejercicio (opcional):", style: Theme.of(context).textTheme.titleSmall), SizedBox(height: 8),
                    Center(child: imagePreviewWidget),
                    Row( mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [ TextButton.icon( icon: Icon(Icons.photo_library_outlined), label: Text("Galería"), onPressed: () => _pickImage(ImageSource.gallery)), TextButton.icon( icon: Icon(Icons.camera_alt_outlined), label: Text("Cámara"), onPressed: () => _pickImage(ImageSource.camera)), ]),
                    if (_imageFile != null || (_initialImagePathPreview != null && _initialImagePathPreview!.isNotEmpty)) TextButton.icon( icon: Icon(Icons.delete_outline, color: Colors.red.shade600), label: Text("Quitar Imagen", style: TextStyle(color: Colors.red.shade600)), onPressed: () { setState(() { _imageFile = null; _initialImagePathPreview = null; _imageWasRemovedOrReplaced = true; }); }, ),
                    SizedBox(height: 24),
                    ElevatedButton( style: ElevatedButton.styleFrom( minimumSize: Size(double.infinity, 44), textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          String trimmedName = nameController.text.trim();
                          String? imagePathToSave;

                          if (_imageFile != null) {
                            imagePathToSave = _imageFile!.path;
                          } else if (_imageWasRemovedOrReplaced) {
                            imagePathToSave = null;
                          } else if (isEditMode) {
                            imagePathToSave = widget.exerciseToEdit!['image']; }


                          Map<String, dynamic> exerciseDataForDb = { 'name': trimmedName,
                            'muscle_group': selectedMuscleGroup,
                            'image': imagePathToSave, 'description': descriptionController.text.trim(), };
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
                                        title: Text("Nombre Duplicado"),
                                        content: Text("Ya existe otro ejercicio con el nombre '$trimmedName'. Por favor, elige un nombre diferente."),
                                        actions: <Widget>[
                                          TextButton(
                                            child: Text("Cerrar"),
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
                            if (trimmedName != oldName) {
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
                                      title: Text("Nombre Duplicado"),
                                      content: Text("Ya existe un ejercicio con el nombre '$trimmedName'. Por favor, elige un nombre diferente."),
                                      actions: <Widget>[
                                        TextButton(
                                          child: Text("Cerrar"),
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
                      child: Text(isEditMode ? "Guardar Cambios" : "Confirmar y Guardar"),
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

  @override
  void initState() {
    super.initState();
    _currentExerciseDataLog = Map<String, dynamic>.from(widget.exercise);
    _tabController = TabController(length: 3, vsync: this);

    seriesController = TextEditingController(text: _currentExerciseDataLog['series']?.toString() ?? '');
    notesController = TextEditingController(text: _currentExerciseDataLog['notes']?.toString() ?? '');
    seriesCountFromInput = int.tryParse(seriesController.text.trim()) ?? 0;

    String initialUnit = 'lb'; // Default a 'lb'
    final dynamic existingUnitData = _currentExerciseDataLog['weightUnit'];
    if (existingUnitData is String && existingUnitData.isNotEmpty) {
      if (existingUnitData.contains(',')) { // Era una lista de unidades
        List<String> unitsList = existingUnitData.split(',');
        if (unitsList.isNotEmpty) {
          initialUnit = unitsList[0].trim().toLowerCase();
          if (initialUnit != 'kg' && initialUnit != 'lb') initialUnit = 'lb';
        }
      } else { // Era una sola unidad
        initialUnit = existingUnitData.trim().toLowerCase();
        if (initialUnit != 'kg' && initialUnit != 'lb') initialUnit = 'lb';
      }
    }
    weightUnit = initialUnit;

    repControllers = [];
    weightControllers = [];
    repWarnings = [];
    weightWarnings = [];

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

    final String weightsString = _currentExerciseDataLog['weight']?.toString() ?? '';
    if (weightsString.isNotEmpty) {
      List<String> initialWeights = weightsString.split(',').map((s) => s.trim()).toList();
      for (int i = 0; i < weightControllers.length && i < initialWeights.length; i++) {
        weightControllers[i].text = initialWeights[i];
      }
    }
    // No es necesario poblar currentSeriesWeightUnits
  }

  void _initializeSeriesSpecificFields() {
    int targetSeriesForRepFields = seriesCountFromInput;
    if (seriesCountFromInput > 4) { // Límite que quieres restaurar
      seriesWarningText = "Se recomienda menos de 4 series para no sobrentrenar";
      targetSeriesForRepFields = 4; // Limitar a 4 campos
    } else if (seriesCountFromInput < 0) {
      seriesWarningText = "Número de series inválido.";
      targetSeriesForRepFields = 0; // No mostrar campos si es inválido
    } else {
      seriesWarningText = ""; // Limpiar advertencia para casos válidos (0 a 4 series)
    }

    List<String> oldRepValues = repControllers.map((c) => c.text).toList();
    List<String> oldWeightValues = weightControllers.map((c) => c.text).toList();

    repControllers = List.generate(targetSeriesForRepFields, (i) => TextEditingController(text: i < oldRepValues.length ? oldRepValues[i] : ''));
    repWarnings = List.generate(targetSeriesForRepFields, (_) => '');

    weightControllers = List.generate(targetSeriesForRepFields, (i) => TextEditingController(text: i < oldWeightValues.length ? oldWeightValues[i] : ''));
    weightWarnings = List.generate(targetSeriesForRepFields, (_) => '');
  }


  void _validateRepValue(String value, int index) {
    if (index >= repControllers.length) return;
    String trimmedValue = value.trim();
    setState(() {
      if (trimmedValue.isEmpty) {
        repWarnings[index] = "Requerido";
      } else {
        int? reps = int.tryParse(trimmedValue);
        if (reps != null) {
          if (reps < 1) repWarnings[index] = "Mín. 1";
          else if (reps > 99) repWarnings[index] = "Máx. 99";
          else if (reps < 6 && (weightWarnings[index].isEmpty || !weightWarnings[index].contains("Debe ser >0"))) repWarnings[index] = 'Se recomienda bajar el peso';
          else if (reps > 12 && (weightWarnings[index].isEmpty || !weightWarnings[index].contains("Debe ser >0"))) repWarnings[index] = 'Se recomienda subir el peso';
          else repWarnings[index] = "";
        } else {
          repWarnings[index] = "Inválido";
        }
      }
    });
  }

  void _validateWeightValue(String value, int index) {
    if (index >= weightControllers.length) return;
    String trimmedValue = value.trim().replaceAll(',', '.');
    setState(() {
      if (trimmedValue.isEmpty) {
        weightWarnings[index] = "Requerido";
      } else {
        double? weightVal = double.tryParse(trimmedValue);
        if (weightVal != null) {
          if (weightVal <= 0) weightWarnings[index] = "Debe ser >0";
          else if (weightVal > 9999) weightWarnings[index] = "Máx. 9999";
          else weightWarnings[index] = "";
        } else {
          weightWarnings[index] = "Inválido";
        }
      }
    });
  }


  void _confirmAndSaveData() {
    if (!_formKeyCurrentDataTab.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Por favor, corrige los errores en el formulario."),
          backgroundColor: Colors.redAccent));
      return;
    }

    bool hasBlockingErrors = false;
    int currentSeriesCount = int.tryParse(seriesController.text.trim()) ?? 0;

    if (currentSeriesCount < 0) {
      setState(() => seriesWarningText = "Número de series inválido."); hasBlockingErrors = true;
    } else if (currentSeriesCount > 10) {
      setState(() => seriesWarningText = "Máximo 4 series permitidas."); hasBlockingErrors = true;
    } else {
      setState(() => seriesWarningText = "");
    }

    if (currentSeriesCount > 0) {
      for (int i = 0; i < repControllers.length; i++) {
        String repVal = repControllers[i].text.trim();
        if (repVal.isEmpty) { setState(() => repWarnings[i] = "Requerido"); hasBlockingErrors = true;
        } else {
          int? r = int.tryParse(repVal);
          if (r == null) { setState(() => repWarnings[i] = "Inválido"); hasBlockingErrors = true;}
          else if (r < 1) { setState(() => repWarnings[i] = "Mín. 1"); hasBlockingErrors = true;}
          else if (r > 99) { setState(() => repWarnings[i] = "Máx. 99"); hasBlockingErrors = true;}
          else { if(repWarnings[i] == "Requerido" || repWarnings[i] == "Inválido" || repWarnings[i] == "Mín. 1" || repWarnings[i] == "Máx. 99") {} else {setState(() => repWarnings[i] = "");} }
        }

        String weightValStr = weightControllers[i].text.trim().replaceAll(',', '.');
        if (weightValStr.isEmpty) { setState(() => weightWarnings[i] = "Requerido"); hasBlockingErrors = true;
        } else {
          double? w = double.tryParse(weightValStr);
          if (w == null) { setState(() => weightWarnings[i] = "Inválido"); hasBlockingErrors = true;}
          else if (w <= 0) { setState(() => weightWarnings[i] = "Debe ser >0"); hasBlockingErrors = true;}
          else if (w > 9999) { setState(() => weightWarnings[i] = "Máx. 9999"); hasBlockingErrors = true;}
          else { setState(() => weightWarnings[i] = "");}
        }
      }
    }

    if (hasBlockingErrors) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Corrige los errores marcados antes de guardar."),
          backgroundColor: Colors.redAccent));
      return;
    }

    List<String> repsData = currentSeriesCount > 0 ? repControllers.map((c) => c.text.trim()).toList() : [];
    List<String> weightsData = currentSeriesCount > 0 ? weightControllers.map((c) => c.text.trim().replaceAll(',', '.')).toList() : [];

    String unitsForDb;
    if (currentSeriesCount > 0) {
      // Repite la unidad de peso seleccionada para cada serie
      unitsForDb = List.generate(currentSeriesCount, (_) => weightUnit.trim()).join(',');
    } else {
      // Si no hay series, la cadena de unidades debe estar vacía
      unitsForDb = "";
    }
    _currentExerciseDataLog['series'] = seriesController.text.trim();
    _currentExerciseDataLog['reps'] = repsData;
    _currentExerciseDataLog['weight'] = weightsData.join(',');
    _currentExerciseDataLog['weightUnit'] = unitsForDb;  // Guardar string de unidades
    _currentExerciseDataLog['notes'] = notesController.text.trim();

    widget.onDataUpdated(_currentExerciseDataLog);
    Navigator.pop(context);
  }


  @override
  void dispose() {
    _tabController.dispose();
    seriesController.dispose();
    notesController.dispose();
    for (var controller in repControllers) controller.dispose();
    for (var controller in weightControllers) controller.dispose();
    super.dispose();
  }

  Future<void> _openEditExerciseDialog( BuildContext parentDialogContext) async {
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
      builder: (dialogCtx) => NewExerciseDialog( exerciseToEdit: definitionDataToEdit, ),
    );

    if (result != null && mounted) {
      setState(() {
        _currentExerciseDataLog['name'] = result['name'] ?? _currentExerciseDataLog['name'];
        _currentExerciseDataLog['description'] = result['description'] ?? _currentExerciseDataLog['description'];
        _currentExerciseDataLog['image'] = result['image'];
        _currentExerciseDataLog['category'] = result['category'] ?? _currentExerciseDataLog['category'];
      });
      widget.onExerciseDefinitionChanged();
      debugPrint( "Definición de ejercicio actualizada en ExerciseDataDialog: ${_currentExerciseDataLog['name']}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastLogData = widget.lastLog;
    final exerciseDefinitionForInfoTab = {
      'name': _currentExerciseDataLog['name'],
      'description': _currentExerciseDataLog['description'],
      'image': _currentExerciseDataLog['image'],
      'category': _currentExerciseDataLog['category'],
      'isManual': _currentExerciseDataLog['isManual'],
      'id': _currentExerciseDataLog['id'],
    };

    return Dialog(
        insetPadding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(alignment: Alignment.centerRight, children: [
              TabBar( controller: _tabController, labelColor: Theme.of(context).primaryColor, unselectedLabelColor: Colors.grey, tabs: const [ Tab(text: 'Actual'), Tab(text: 'Historial'), Tab(text: 'Info'), ], ),
              Positioned( right: 0, top: 0, bottom: 0, child: IconButton( icon: Icon(Icons.close), onPressed: () => Navigator.pop(context), tooltip: "Cerrar"), )
            ]),
            Flexible(
                child: Container(
                  constraints: BoxConstraints( maxHeight: MediaQuery.of(context).size.height * 0.75),
                  child: TabBarView( controller: _tabController, children: [ _buildCurrentDataTab(), _buildHistoryTab(exerciseNameToQuery: _currentExerciseDataLog['name'] ?? widget.exercise['name'] ?? ''), _buildDescriptionTab(exerciseDefinitionForInfoTab), ], ),
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
          : inputDecorationTheme.labelStyle?.color, // Color normal del tema si no
    );

    // BorderSide para el campo de Series cuando está habilitado (no enfocado)
    BorderSide seriesEnabledBorderSide = isAdvisoryWarningActive
        ? BorderSide(color: theme.colorScheme.error, width: 1.0) // Borde rojo si advertencia activa
        : inputDecorationTheme.enabledBorder?.borderSide ?? BorderSide(color: Colors.grey[700]!, width: 0.5);

    // BorderSide para el campo de Series cuando está enfocado
    BorderSide seriesFocusedBorderSide = isAdvisoryWarningActive
        ? BorderSide(color: theme.colorScheme.error, width: 2.0) // Borde rojo más grueso si advertencia activa
        : inputDecorationTheme.focusedBorder?.borderSide ?? BorderSide(color: const Color(0xFFFFC107), width: 1.5); // Amarillo (amarilloPrincipal)

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKeyCurrentDataTab,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start, // Alinea los elementos al inicio si tienen alturas diferentes (debido a errores)
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: seriesController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Número de Series *',
                        labelStyle: seriesLabelStyle, // Aplicar estilo de etiqueta dinámico
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)), // Borde base
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
                        setState(() {
                          seriesCountFromInput = int.tryParse(value.trim()) ?? 0;
                          _initializeSeriesSpecificFields();
                        });
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Requerido';
                        final n = int.tryParse(value.trim());
                        if (n == null) return 'Inválido';
                        if (n < 0) return 'No negativo';
                        if (n > 10) return 'Máx. 10';
                        return null;
                      },
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      value: weightUnit,
                      decoration: InputDecoration(
                        labelText: 'Unidad de Peso',
                        border: OutlineInputBorder(),
                        // Los estilos de error para este campo son manejados por defecto
                      ),
                      items: ['lb', 'kg']
                          .map((unit) => DropdownMenuItem(value: unit, child: Text(unit)))
                          .toList(),
                      onChanged: (value) => setState(() => weightUnit = value ?? 'lb'),
                      validator: (value) => value == null || value.isEmpty ? 'Selecciona unidad' : null,
                    ),
                  ),
                ],
              ),
              if (seriesWarningText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 5.0, left: 4.0, right: 4.0),
                  child: Text(
                    seriesWarningText,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12.0,
                    ),
                  ),
                ),
              SizedBox(height: 12),
              Text('Detalles por Serie:', style: Theme.of(context).textTheme.titleMedium),
              if (seriesCountFromInput <= 0 && repControllers.isEmpty && weightControllers.isEmpty) Padding( padding: const EdgeInsets.symmetric(vertical: 10.0), child: Text("Define el número de series arriba.", style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic)))
              else if (repControllers.isEmpty && weightControllers.isEmpty && seriesCountFromInput > 0) Padding( padding: const EdgeInsets.symmetric(vertical: 10.0), child: Text("Ajustando campos para $seriesCountFromInput series...", style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic)))
              else
                ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: repControllers.length,
                    itemBuilder: (context, index) {
                      return Padding(
                          padding: const EdgeInsets.only(top: 10.0),

                          child: Column(

                            children: [
                          Text(
                          'Serie ${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.w500, // Un poco más de énfasis
                              fontSize: 16, // Tamaño legible
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85), // Color del texto
                            ),
                          ),
                          SizedBox(height: 6), // Espacio entre el título de la serie y los campos de entrada

                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 2, // 2/3 para reps
                                    child: TextFormField(
                                      controller: repControllers[index],
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Repeticiones',
                                        border: OutlineInputBorder(),
                                        errorMaxLines: 2,
                                        errorText: (repWarnings.length > index && repWarnings[index].isNotEmpty)
                                            ? repWarnings[index]
                                            : null,
                                      ),
                                      onChanged: (value) => _validateRepValue(value, index),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    flex: 1, // 1/3 para peso
                                    child: TextFormField(
                                      controller: weightControllers[index],
                                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        labelText: 'Peso',
                                        border: OutlineInputBorder(),
                                        errorMaxLines: 2,
                                        errorText: (weightWarnings.length > index && weightWarnings[index].isNotEmpty)
                                            ? weightWarnings[index]
                                            : null,
                                      ),
                                      onChanged: (value) => _validateWeightValue(value, index),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ));
                    }),
              SizedBox(height: 20),
              TextFormField( controller: notesController, decoration: InputDecoration( labelText: 'Notas (opcional)', border: OutlineInputBorder(), alignLabelWithHint: true, hintText: "Técnica, sensaciones, etc."), maxLines: 3, minLines: 1, textCapitalization: TextCapitalization.sentences),
              SizedBox(height: 24),

              if (widget.lastLog != null) ...[
                Text("Último Registro:", style: Theme.of(context).textTheme.titleMedium),
                SizedBox(height: 8),
                Builder( // Usar Builder para acceder al context dentro de la condición
                    builder: (context) {
                      String formattedDate = "Fecha no disponible";
                      if (widget.lastLog!['dateTime'] != null) {
                        try {
                          DateTime dt = DateTime.parse(widget.lastLog!['dateTime']);
                          // Puedes elegir el formato que prefieras. Ej: "dd 'de' MMMM 'de' yyyy" o "dd/MM/yyyy"
                          formattedDate = DateFormat.yMMMMd('es_ES').format(dt); // Ej: "25 de mayo de 2025"
                        } catch (e) {
                          print("Error al formatear fecha del último log: $e");
                        }
                      }
                      return Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[400], // Un color sutil para la fecha
                          fontStyle: FontStyle.italic,
                        ),
                      );
                    }
                ),
                SizedBox(height: 8),
                _buildLastLogTable(widget.lastLog!), // Usar el nuevo método para la tabla
                SizedBox(height: 24),
              ],
              ElevatedButton( onPressed: _confirmAndSaveData, child: Text('Actualizar Registro'), style: ElevatedButton.styleFrom( padding: EdgeInsets.symmetric(vertical: 12))),
            ]
        ),
      ),
    );
  }

  Widget _buildLastLogTable(Map<String, dynamic> lastLog) {
    final theme = Theme.of(context);
    final int seriesCount = int.tryParse(lastLog['series']?.toString() ?? '0') ?? 0;
    final List<String> reps = (lastLog['reps']?.toString() ?? '').split(',');
    final List<String> weights = (lastLog['weight']?.toString() ?? '').split(',');
    // Ahora 'weightUnit' del log es una sola string.
    final String logUnit = (lastLog['weightUnit']?.toString() ?? 'lb').split(',')[0].trim(); // Tomar la primera si era lista, o la unidad.
    final String notes = lastLog['notes']?.toString() ?? '';

    List<TableRow> rows = [
      TableRow(
        decoration: BoxDecoration(color: theme.colorScheme.surfaceVariant.withOpacity(0.3)),
        children: [
          Padding(padding: const EdgeInsets.all(8.0), child: Text('Serie', style: TextStyle(fontWeight: FontWeight.bold))),
          Padding(padding: const EdgeInsets.all(8.0), child: Text('Reps', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          Padding(padding: const EdgeInsets.all(8.0), child: Text('Peso', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
        ],
      ),
    ];

    for (int i = 0; i < seriesCount; i++) {
      rows.add(TableRow(
        children: [
          Padding(padding: const EdgeInsets.all(8.0), child: Text('${i + 1}')),
          Padding(padding: const EdgeInsets.all(8.0), child: Text(i < reps.length ? reps[i].trim() : '-', textAlign: TextAlign.center)),
          Padding(padding: const EdgeInsets.all(8.0), child: Text(
              (i < weights.length ? weights[i].trim() : '-') + " " + logUnit, // Usar la unidad global del log
              textAlign: TextAlign.center
          )),
        ],
      ));
    }
    if (seriesCount == 0) {
      rows.add(TableRow(children: [
        Padding(padding: const EdgeInsets.all(8.0), child: Text('-', textAlign: TextAlign.center)),
        Padding(padding: const EdgeInsets.all(8.0), child: Text('-', textAlign: TextAlign.center)),
        Padding(padding: const EdgeInsets.all(8.0), child: Text('-', textAlign: TextAlign.center)),
      ]));
    }


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Table(
          border: TableBorder.all(color: theme.primaryColor, width: 0.7),
          columnWidths: const {
            0: FlexColumnWidth(1), // Serie
            1: FlexColumnWidth(1.5), // Reps
            2: FlexColumnWidth(2), // Peso
          },
          children: rows,
        ),
        if (lastLog['notes'] != null && (lastLog['notes'] as String).isNotEmpty) ...[
          SizedBox(height: 8),
          Text("Notas: ${lastLog['notes']}", style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
        ]
      ],
    );
  }


  Widget _buildHistoryTab({required String exerciseNameToQuery}) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.instance.getExerciseLogs(exerciseNameToQuery),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("Error cargando historial: ${snapshot.error}", textAlign: TextAlign.center)));
        final logs = snapshot.data ?? [];
        if (logs.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("No hay registros anteriores para '$exerciseNameToQuery'.", textAlign: TextAlign.center)));

        return ListView.separated(
          padding: EdgeInsets.all(16),
          itemCount: logs.length,
          separatorBuilder: (_, __) => Divider(height: 28, thickness: 1),
          itemBuilder: (context, index) {
            final log = logs[index];
            String formattedDate = "Fecha desconocida";
            if (log['dateTime'] != null) {
              try {
                DateTime dt = DateTime.parse(log['dateTime']);
                formattedDate = DateFormat.yMd('es_ES').add_Hm().format(dt); // "d/M/yyyy HH:mm"
              } catch (_) {}
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formattedDate, style: TextStyle(fontWeight: FontWeight.bold,
                    color: Colors.white, fontSize: 15)),
                SizedBox(height: 8),
                _buildLogTableForHistory(log), // Usar la tabla para cada log
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLogTableForHistory(Map<String, dynamic> log) { // Similar a _buildLastLogTable
    final theme = Theme.of(context);
    final int seriesCount = int.tryParse(log['series']?.toString() ?? '0') ?? 0;
    final List<String> reps = (log['reps']?.toString() ?? '').split(',');
    final List<String> weights = (log['weight']?.toString() ?? '').split(',');
    // 'weightUnit' del log es una sola string.
    final String logUnit = (log['weightUnit']?.toString() ?? 'lb').split(',')[0].trim(); // Tomar la primera si era lista, o la unidad.
    final String notes = log['notes']?.toString() ?? '';

    const TextStyle whiteTextStyle = TextStyle(color: Colors.white, fontSize: 13);
    const TextStyle whiteBoldTextStyle = TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13);


    List<TableRow> rows = [
      TableRow(
        decoration: BoxDecoration(color: theme.colorScheme.surfaceVariant.withOpacity(0.2)),
        children: [
          Padding(padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0), child: Text('Serie', style: whiteBoldTextStyle, textAlign: TextAlign.center)),
          Padding(padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0), child: Text('Reps', style: whiteBoldTextStyle, textAlign: TextAlign.center)),
          Padding(padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0), child: Text('Peso', style: whiteBoldTextStyle, textAlign: TextAlign.center)),
          // Quitar columna Notas si se decide así para el historial también
          // Padding(padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0), child: Text('Notas', style: whiteBoldTextStyle, textAlign: TextAlign.center)),
        ],
      ),
    ];

    for (int i = 0; i < seriesCount; i++) {
      rows.add(TableRow(
        children: [
          Padding(padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0), child: Text('${i + 1}', style: whiteTextStyle, textAlign: TextAlign.center)),
          Padding(padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0), child: Text(i < reps.length ? reps[i].trim() : '-', style: whiteTextStyle, textAlign: TextAlign.center)),
          Padding(padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0), child: Text(
              (i < weights.length ? weights[i].trim() : '-') + " " + logUnit, // Usar la unidad global del log
              textAlign: TextAlign.center
          )),
          // Quitar celda de Notas si se quita la columna
          // Padding(padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0), child: Text(i == 0 ? notes : '', style: whiteTextStyle.copyWith(fontStyle: FontStyle.italic, fontSize: 12), textAlign: TextAlign.left)),
        ],
      ));
    }
    if (seriesCount == 0) {
      rows.add(TableRow(children: [
        Padding(padding: const EdgeInsets.all(6.0), child: Text('-', style: whiteTextStyle, textAlign: TextAlign.center)),
        Padding(padding: const EdgeInsets.all(6.0), child: Text('-', style: whiteTextStyle, textAlign: TextAlign.center)),
        Padding(padding: const EdgeInsets.all(6.0), child: Text('-', style: whiteTextStyle, textAlign: TextAlign.center)),
        // Quitar celda de Notas si se quita la columna
        // Padding(padding: const EdgeInsets.all(6.0), child: Text(notes, style: whiteTextStyle.copyWith(fontStyle: FontStyle.italic, fontSize: 12), textAlign: TextAlign.left)),
      ]));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Table(
          border: TableBorder.all(color: theme.primaryColor, width: 1.0),
          // Ajustar columnWidths si la columna Notas se quita
          columnWidths: const {
            0: FlexColumnWidth(0.8),
            1: FlexColumnWidth(1.2),
            2: FlexColumnWidth(1.8),
            // 3: FlexColumnWidth(2.2), // Para Notas, si se mantiene en la tabla
          },
          children: rows,
        ),
        // Si las notas no están en la tabla, mostrarlas aquí:
        if (notes.isNotEmpty) ...[
          SizedBox(height: 6),
          Text("Notas: $notes", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.white70)),
        ]
      ],
    );
  }


  Widget _buildDescriptionTab(Map<String, dynamic> exerciseDefinition) {
    final exerciseImage = exerciseDefinition['image'] as String?;
    final exerciseDescription = exerciseDefinition['description'] as String?;
    final exerciseName = exerciseDefinition['name']?.toString();
    final bool isManualExercise = exerciseDefinition['isManual'] == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (exerciseImage != null && exerciseImage.isNotEmpty) Center( child: Padding( padding: const EdgeInsets.only(bottom: 16.0), child: Container( height: 180, width: double.infinity, clipBehavior: Clip.antiAlias, decoration: BoxDecoration( color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10.0), ),
            child: exerciseImage.startsWith('assets/') ? Image.asset( exerciseImage, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Center(child: Icon(Icons.broken_image_outlined, size: 60, color: Colors.grey.shade400)), )
                : Image.file( File(exerciseImage), fit: BoxFit.contain, errorBuilder: (_, __, ___) => Center(child: Icon(Icons.broken_image_outlined, size: 60, color: Colors.grey.shade400)), ), ), ), )
          else Center( child: Padding( padding: const EdgeInsets.only(bottom: 16.0), child: Container( height: 180, width: double.infinity, decoration: BoxDecoration( color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3), borderRadius: BorderRadius.circular(10.0), border: Border.all(color: Colors.grey.shade400, width: 0.5) ), child: Icon(Icons.image_search_outlined, size: 80, color: Colors.grey[500]), ), ), ),
          Center( child: Text( exerciseName ?? "Ejercicio", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center, ), ),
          SizedBox(height: 10), Divider(), SizedBox(height: 10),
          Text( "Descripción:", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600) ), SizedBox(height: 6),
          Text( exerciseDescription != null && exerciseDescription.isNotEmpty ? exerciseDescription : "No hay descripción disponible para este ejercicio.", style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5), ),
          SizedBox(height: 24),
          if (isManualExercise) Center( child: ElevatedButton.icon( icon: Icon(Icons.edit_outlined), label: Text('Editar Información del Ejercicio'), style: ElevatedButton.styleFrom( padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12) ), onPressed: () { _openEditExerciseDialog(context); }, ), ),
        ],
      ),
    );
  }
}
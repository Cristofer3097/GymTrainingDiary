
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../training_screen.dart';
import '../utils/localization_utils.dart';
import 'widgets/app_bottom_nav_bar.dart';



class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<dynamic>> _events = {};
  List<Map<String, dynamic>> _selectedDaySessions = []; // Almacenará las sesiones del día

  //Duracion del entrenamiento
  String _formatDuration(int? totalSeconds) {
    if (totalSeconds == null || totalSeconds < 0) {
      return '--:--:--';
    }
    final duration = Duration(seconds: totalSeconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }


  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadDatesWithTrainingSessions();
    _loadSessionsForSelectedDay(_focusedDay);
  }

  Future<void> _loadDatesWithTrainingSessions() async {
    final db = DatabaseHelper.instance;
    final dates = await db.getDatesWithTrainingSessions(); // Usa el método actualizado
    final Map<DateTime, List<dynamic>> eventsMap = {};
    for (var date in dates) {
      final utcDate = DateTime.utc(date.year, date.month, date.day);
      eventsMap[utcDate] = ['Sesión']; // Marcador
    }
    if (mounted) {
      setState(() {
        _events = eventsMap;
      });
    }
  }

  Future<void> _loadSessionsForSelectedDay(DateTime day) async {
    final db = DatabaseHelper.instance;
    final sessions = await db.getTrainingSessionsForDate(day); // Obtiene las sesiones
    if (mounted) {
      setState(() {
        _selectedDaySessions = sessions;
      });
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    final utcDay = DateTime.utc(day.year, day.month, day.day);
    return _events[utcDay] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      _loadSessionsForSelectedDay(selectedDay);
    }
  }


  Future<void> _editTrainingSession(Map<String, dynamic> session) async {
    final db = DatabaseHelper.instance;
    final sessionTitle = session['session_title']?.toString() ?? 'Entrenamiento';
    final sessionId = session['id'] as int;

    // 1. OBTENER TODO CON UNA SOLA CONSULTA OPTIMIZADA
    final List<Map<String, dynamic>> fullLogs = await db.getFullExerciseLogsForSession(sessionId);

    // 2. Reconstruir la lista (ahora sin bucles de consultas a la BD)
    List<Map<String, dynamic>> reconstructedExercises = [];
    for (var log in fullLogs) {
      Map<String, dynamic> exerciseData = Map.from(log);
      exerciseData['category'] = exerciseData['muscle_group'];
      exerciseData['isManual'] = (exerciseData['is_predefined'] ?? 1) == 0;
      exerciseData['db_category_id'] = exerciseData['exercise_definition_id'];
      exerciseData['name'] = log['exercise_name']; // <--- ASEGÚRATE DE ESTO
      reconstructedExercises.add(exerciseData);
    }

    if (!mounted) return;

    // 3. Navegar a TrainingScreen en modo edición
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrainingScreen(
          sessionToEdit: session,
          initialExercises: reconstructedExercises,
          templateName: sessionTitle,
        ),
        settings: const RouteSettings(name: 'TrainingScreen'),
      ),
    );

    // 4. Refrescar la vista del calendario al volver
    if (result == true && _selectedDay != null) {
      _loadSessionsForSelectedDay(_selectedDay!);
    }
  }

  // Diálogo para confirmar borrado de una SESIÓN COMPLETA
  Future<bool?> _showConfirmDeleteSessionDialog(BuildContext parentContext, Map<String, dynamic> session) async {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: parentContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.calendar_confirm),
          content: Text(l10n.confirmDeleteSessionDialogContent(session['session_title']?.toString() ?? 'Entrenamiento')),
          actionsAlignment: MainAxisAlignment.spaceAround,
          actions: <Widget>[
            TextButton(
              child: Text(l10n.cancel),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: Text(l10n.deleteButton),
              onPressed: () async {
                final db = DatabaseHelper.instance;
                await db.deleteTrainingSessionAndLogs(session['id'] as int); // Borra la sesión y sus logs
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );
  }


  // Diálogo de acciones para una SESIÓN COMPLETA


  Widget _buildExerciseTableForCalendar(Map<String, dynamic> log, BuildContext context) {
    final theme = Theme.of(context);
    final int seriesCount = int.tryParse(log['series']?.toString() ?? '0') ?? 0;
    final List<String> reps = (log['reps']?.toString() ?? '').split(',');
    final List<String> weights = (log['weight']?.toString() ?? '').split(',');
    final List<String> units = (log['weightUnit']?.toString() ?? '').split(',');
    final String logUnit = (log['weightUnit']?.toString() ?? 'lb').split(',')[0].trim(); // Tomar la primera unidad o la unidad única
    final String notes = log['notes']?.toString() ?? '';
    final l10n = AppLocalizations.of(context)!;


    List<TableRow> rows = [
      TableRow(
        decoration: BoxDecoration(color: theme.colorScheme.onSurface.withOpacity(0.08)),
        children: [
          Padding(padding: const EdgeInsets.symmetric(vertical: 7.0, horizontal: 5.0), child: Text(l10n.serie, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5), textAlign: TextAlign.center)),
          Padding(padding: const EdgeInsets.symmetric(vertical: 7.0, horizontal: 5.0), child: Text("Reps", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5), textAlign: TextAlign.center)),
          Padding(padding: const EdgeInsets.symmetric(vertical: 7.0, horizontal: 5.0), child: Text(l10n.weight, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5), textAlign: TextAlign.center)),
        ],
      ),
    ];

    for (int i = 0; i < seriesCount; i++) {
      rows.add(TableRow(
        children: [
          Padding(padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 5.0), child: Text('${i + 1}', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5))),
          Padding(padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 5.0), child: Text(i < reps.length ? reps[i].trim() : '-', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5))),
          Padding(padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 5.0), child: Text(
              (i < weights.length ? weights[i].trim() : '-') + " " + (i < units.length ? units[i].trim() : (units.isNotEmpty ? units[0].trim() : 'lb')),
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5)
          )),
        ],
      ));
    }
    if (seriesCount == 0) {
      rows.add(TableRow(children: [
        Padding(padding: const EdgeInsets.all(6.0), child: Text('-', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5))),
        Padding(padding: const EdgeInsets.all(6.0), child: Text('-', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5))),
        Padding(padding: const EdgeInsets.all(6.0), child: Text('-', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5))),
      ]));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Table(
          // Asegurar que todos los bordes (internos y externos) sean visibles y amarillos.
          // Cambiamos el width a 1.0 para mayor consistencia en el renderizado.
          border: TableBorder.all(color: theme.primaryColor, width: 1.0), // Borde amarillo y más grueso
          columnWidths: const {
            0: FlexColumnWidth(0.8), // Serie
            1: FlexColumnWidth(1.2), // Reps
            2: FlexColumnWidth(1.8), // Peso
          },
          children: rows,
        ),
        if (notes.isNotEmpty) ...[
          SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4.0, right: 4.0),
            child: Text(
              l10n.calendar_notes(notes),
              style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Colors.grey.shade400),
            ),
          )
        ]
      ],
    );
  }
  @override
  Widget build(BuildContext context) {

    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.calendar_title),
      ),
      bottomNavigationBar: AppBottomNavBar(activeRoute: l10n.calendar),

      body: Column(
        children: [
          TableCalendar(
            locale: l10n.localeName,
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: _onDaySelected,
            eventLoader: _getEventsForDay,
            availableCalendarFormats: {
              CalendarFormat.month: l10n.calendarFormatMonth,
              CalendarFormat.twoWeeks: l10n.calendarFormatTwoWeeks,
              CalendarFormat.week: l10n.calendarFormatWeek,
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isNotEmpty) {
                  return Positioned(
                    right: 1, bottom: 1,
                    child: Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).primaryColor.withOpacity(0.8)),
                      width: 6.0, height: 6.0,
                    ),
                  );
                }
                return null;
              },
            ),
            headerStyle: HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonShowsNext: false),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(color: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
                  shape: BoxShape.circle),
              selectedDecoration: BoxDecoration(color: Theme.of(context).primaryColor, shape: BoxShape.circle),
            ),
            onFormatChanged: (format) {
              if (_calendarFormat != format) { setState(() { _calendarFormat = format; });}
            },
            onPageChanged: (focusedDay) { _focusedDay = focusedDay;},
          ),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 12.0),
          if (_selectedDay != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                l10n.calendar_date(DateFormat.yMMMMd(l10n.localeName).format(_selectedDay!)), // <<< CAMBIO y usa localeName para DateFormat                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(height: 8.0),
          Expanded(
            child: _selectedDaySessions.isEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                    _selectedDay != null
                        ? l10n.calendar_no_sessions
                        : l10n.calendar_select,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              itemCount: _selectedDaySessions.length,
              itemBuilder: (context, sessionIndex) {
                final session = _selectedDaySessions[sessionIndex];
                final String sessionTitle = session['session_title']?.toString() ?? 'Entrenamiento Sin Título';
                final int? durationInSeconds = session['duration'] as int?;
                String sessionTime = "Hora desconocida";

                try {
                  DateTime dt = DateTime.parse(session['session_dateTime']);
                  // Usa el formato de 12 horas con am/pm
                  sessionTime = DateFormat.jm(l10n.localeName).format(dt);
                } catch (_) {}
                final bool isTrainingActive =
                    TrainingScreen.isTrainingInProgress;

                final String buttonTooltip = isTrainingActive
                    ? "Termina tu entrenamiento actual para poder ${l10n.training_edit_title}" // Puedes crear una nueva clave l10n si prefieres
                    : l10n.training_edit_title;

                final String deleteTooltip = isTrainingActive
                    ? "Termina tu entrenamiento actual para poder ${l10n.deleteButton}"
                    : l10n.deleteButton;

                return Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 8.0, 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // Fila para el título y los botones
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center, // Centrar verticalmente los botones
                            children: [
                              Expanded(
                                child: Text(
                                  "${sessionIndex + 1}. $sessionTitle",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ),
                              Row( // Un Row para los botones
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit_note,
                                      color: isTrainingActive
                                          ? Colors.grey
                                          : Theme.of(context)
                                          .primaryColor,
                                    ),
                                    tooltip: buttonTooltip,
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () {
                                      if (isTrainingActive) {
                                        // 3. Muestra el SnackBar si está activo
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(l10n.calendar_action_disabled_message),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );
                                      } else {
                                        _editTrainingSession(session);
                                      }
                                    },
                                  ),

                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: isTrainingActive
                                          ? Colors.grey
                                          : Colors.red.shade400,
                                    ),
                                    tooltip: deleteTooltip,
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () async {
                                      if (isTrainingActive) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(l10n.calendar_action_disabled_message),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );
                                      } else {
                                      final bool? deletionConfirmed =
                                      await _showConfirmDeleteSessionDialog(
                                          context, session);
                                      if (deletionConfirmed ==
                                          true) {
                                        if (mounted &&
                                            _selectedDay != null) {
                                          await _loadSessionsForSelectedDay(
                                              _selectedDay!);
                                          await _loadDatesWithTrainingSessions();
                                          ScaffoldMessenger.of(
                                              context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text(l10n
                                                    .calendar_session_delete(
                                                    sessionTitle))),
                                          );
                                        }
                                      }
    }
    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 0.0, bottom: 4.0),// Pequeño espacio desde el título
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  sessionTime,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                Text(
                                  _formatDuration(durationInSeconds),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 12.0),
                          FutureBuilder<List<Map<String, dynamic>>>(
                            future: DatabaseHelper.instance.getFullExerciseLogsForSession(session['id'] as int),
                            builder: (context, exerciseSnapshot) {
                              if (exerciseSnapshot.connectionState == ConnectionState.waiting) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0, left: 16.0),
                                  child: Text(l10n.calendar_loading, style: TextStyle(fontStyle: FontStyle.italic)),
                                );
                              }
                              if (exerciseSnapshot.hasError || !exerciseSnapshot.hasData || exerciseSnapshot.data!.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0, left: 16.0),
                                  child: Text(l10n.calendar_error, style: TextStyle(fontStyle: FontStyle.italic)),
                                );
                              }
                              final exercisesInSession = exerciseSnapshot.data!;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: exercisesInSession.asMap().entries.map((entry) {
                                  int exerciseIdx = entry.key;
                                  Map<String, dynamic> log = entry.value;
                                  return Padding(
                                    padding: const EdgeInsets.only(top:10.0, bottom: 4.0),
                                    child: Column( // Columna para nombre de ejercicio y luego la tabla
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Nombre del ejercicio (como en la imagen de referencia)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 8.0, bottom: 6.0), // Indentación y espacio
                                          child: Text(
                                          "${exerciseIdx + 1}. ${getLocalizedExerciseName(context, log)}",
                                            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16.5), // Tamaño consistente
                                          ),
                                        ),
                                        // Tabla de detalles del ejercicio
                                        Padding(
                                          padding: const EdgeInsets.only(left: 8.0, right: 4.0), // Indentación para la tabla
                                          child: _buildExerciseTableForCalendar(log, context),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'database/database_helper.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:archive/archive_io.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kUnitPreferenceKey = 'preferred_weight_unit';

class Settings extends StatefulWidget {
  final void Function(Locale) onLocaleChange;

  const Settings({Key? key, required this.onLocaleChange}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<Settings> {
  bool _isLoading = false;
  String _loadingMessage = '';
  String _preferredUnit = 'lb'; // Valor por defecto

  @override
  void initState() {
    super.initState();
    // --- INICIO DE CAMBIO: Cargar preferencia al iniciar ---
    _loadPreferredUnit();
    // --- FIN DE CAMBIO ---
  }
  Future<void> _loadPreferredUnit() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _preferredUnit = prefs.getString(kUnitPreferenceKey) ?? 'lb';
    });
  }

  Future<void> _savePreferredUnit(String unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kUnitPreferenceKey, unit);
    setState(() {
      _preferredUnit = unit;
    });
  }

  void _showUnitSelectionDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        String tempUnit = _preferredUnit;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.settings_unit_preference_dialog_title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: ['lb', 'kg'].map((unit) {
                  return RadioListTile<String>(
                    title: Text(unit.toUpperCase()),
                    value: unit,
                    groupValue: tempUnit,
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          tempUnit = value;
                        });
                      }
                    },
                    activeColor: Theme.of(context).primaryColor,
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    _savePreferredUnit(tempUnit);
                    Navigator.of(context).pop();
                  },
                  child: Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    );
  }



  /// Muestra el diálogo para que el usuario seleccione el idioma.
  void _showLanguageSelectionDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.changeLanguageDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                title: Text(l10n.languageEnglish),
                onTap: () {
                  widget.onLocaleChange(const Locale('en'));
                  Navigator.of(dialogContext).pop();
                },
              ),
              ListTile(
                title: Text(l10n.languageSpanish),
                onTap: () {
                  widget.onLocaleChange(const Locale('es'));
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          ),
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

  /// Inicia el proceso de exportación de la base de datos.
  Future<void> _exportDatabase() async {
    final l10n = AppLocalizations.of(context)!;
    if (!await _requestPermissions()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.settings_permission_denied)));
      return;
    }

    setState(() {
      _isLoading = true;
      String _loadingMessage = '';

    });
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dbFolder.path, 'gym_diary.db'));

      // Obtener las rutas de las imágenes de los ejercicios creados por el usuario
      final imagePaths = await DatabaseHelper.instance.getAllUserImagePaths();
      final List<File> imageFiles = imagePaths.map((path) => File(path)).toList();

      // Crear un archivo ZIP en memoria
      final archive = Archive();

      // 1. Añadir la base de datos al ZIP
      if (await dbFile.exists()) {
        archive.addFile(ArchiveFile('gym_diary.db', dbFile.lengthSync(), dbFile.readAsBytesSync()));
      }

      // 2. Añadir las imágenes al ZIP dentro de una carpeta 'images'
      for (var imageFile in imageFiles) {
        if (await imageFile.exists()) {
          archive.addFile(ArchiveFile('images/${p.basename(imageFile.path)}', imageFile.lengthSync(), imageFile.readAsBytesSync()));
        }
      }

      // 3. Comprimir el archivo
      final zipEncoder = ZipEncoder();
      final zipData = zipEncoder.encode(archive);

      if (zipData == null) {
        throw Exception("Error al crear el archivo ZIP.");
      }

      // 4. Permitir al usuario elegir dónde guardar el archivo .zip
      final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final String backupFileName = 'gym_diary_backup_$timestamp.zip';

      String? resultPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: l10n.settings_export_dialog_title,
      );

      if (resultPath != null) {
        final finalZipFile = File(p.join(resultPath, backupFileName));
        await finalZipFile.writeAsBytes(zipData);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.settings_export_success(finalZipFile.path))));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.settings_no_folder_selected)));
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.settings_error(e.toString()))));
    } finally {
      if(mounted) setState(() { _isLoading = false; _loadingMessage = ''; });
    }
  }

  /// Inicia el proceso de importación de la base de datos.
  Future<void> _importDatabase() async {
    final l10n = AppLocalizations.of(context)!;
    final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.settings_import_warning_title),
          content: Text(l10n.settings_import_warning_content),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.settings_import_confirm),
            )
          ],
        ));

    if (confirm != true) return;

    if (!await _requestPermissions()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.settings_permission_denied)));
      return;
    }

    // 1. Permitir al usuario seleccionar el archivo .zip
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.single.path == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.settings_no_file_selected)));
      return;
    }
    setState(() { _isLoading = true;
      _loadingMessage = l10n.settings_loading_export; });

    try {
      final zipFile = File(result.files.single.path!);
      final appDocDir = await getApplicationDocumentsDirectory();

      // Crear un directorio temporal para la extracción
      final tempDir = Directory(p.join(appDocDir.path, 'backup_temp'));
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
      await tempDir.create(recursive: true);

      final inputStream = InputFileStream(zipFile.path);
      final archive = ZipDecoder().decodeBuffer(inputStream);

      // Extraer todos los archivos al directorio temporal
      for (final file in archive) {
        final filename = p.join(tempDir.path, file.name);
        if (file.isFile) {
          final outFile = File(filename);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        } else {
          await Directory(filename).create(recursive: true);
        }
      }

      final tempDbFile = File(p.join(tempDir.path, 'gym_diary.db'));
      if (!await tempDbFile.exists()) {
        // En lugar de 'throw Exception', mostramos un error localizado y salimos.
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.settings_error_no_db_in_backup), backgroundColor: Colors.red)
          );
        }
        // Limpiamos el directorio temporal y detenemos la ejecución de la función.
        await tempDir.delete(recursive: true);
        setState(() { _isLoading = false; _loadingMessage = ''; });
        return;
      }
      Database tempDb = await openDatabase(tempDbFile.path);

      // 2. Obtener la lista de ejercicios de usuario de la DB temporal.
      final userExercises = await tempDb.query(
        'categories',
        where: 'is_predefined = ? AND image IS NOT NULL AND image != ?',
        whereArgs: [0, ''],
      );

      // 3. Iterar y actualizar cada ruta de imagen.
      for (var exercise in userExercises) {
        final oldPath = exercise['image'] as String;
        final filename = p.basename(oldPath); // Extrae 'image_picker_xyz.jpg'
        final newPath = p.join(appDocDir.path, filename); // Crea la nueva ruta correcta

        await tempDb.update(
          'categories',
          {'image': newPath},
          where: 'id = ?',
          whereArgs: [exercise['id']],
        );
      }
      await tempDb.close(); // Cerrar la base de datos temporal después de modificarla.
      // --- **FIN DEL BLOQUE DE CORRECCIÓN DE RUTAS** ---

      // Ahora que la base de datos temporal está corregida, procedemos a restaurar todo.
      // CERRAR la base de datos principal de la app.
      await DatabaseHelper.instance.closeDB();

      // Mover la DB corregida a su lugar definitivo.
      await tempDbFile.rename(p.join(appDocDir.path, 'gym_diary.db'));

      // Mover las imágenes a su lugar definitivo.
      final tempImagesDir = Directory(p.join(tempDir.path, 'images'));
      if (await tempImagesDir.exists()) {
        await for (var entity in tempImagesDir.list()) {
          if (entity is File) {
            await entity.rename(p.join(appDocDir.path, p.basename(entity.path)));
          }
        }
      }

      // Limpiar el directorio temporal.
      await tempDir.delete(recursive: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.settings_import_success)));
        Navigator.of(context).pop(true);
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.settings_error(e.toString()))));
    } finally {
      if(mounted) setState(() { _isLoading = false; _loadingMessage = ''; });
    }
  }

  /// Solicita los permisos de almacenamiento necesarios.
  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
      }
      return status.isGranted;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings_title),
      ),
      body: _isLoading
          ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(_loadingMessage, style: Theme.of(context).textTheme.titleMedium),
            ],
          ))
          : ListView(
        padding: const EdgeInsets.all(8.0),
        children: [
          _buildSectionTitle(context, l10n.settings_section_general),
          Card(
            child: ListTile(
              leading: const Icon(Icons.language),
              title: Text(l10n.settings_language),
              subtitle: Text(l10n.settings_language_subtitle),
              onTap: () => _showLanguageSelectionDialog(context),
            ),
          ),
          const Divider(height: 24),
          _buildSectionTitle(context, l10n.settings_section_preferences),
          Card(
            child: ListTile(
              leading: const Icon(Icons.straighten), // Icono de regla/medida
              title: Text(l10n.settings_unit_preference),
              subtitle: Text(l10n.settings_unit_preference_subtitle),
              trailing: Text(
                _preferredUnit.toUpperCase(),
                style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16
                ),
              ),
              onTap: _showUnitSelectionDialog,
            ),
          ),
          const Divider(height: 24),
          _buildSectionTitle(context, l10n.settings_section_data),
          Card(
            child: ListTile(
              leading: const Icon(Icons.upload_file),
              title: Text(l10n.settings_export),
              subtitle: Text(l10n.settings_export_subtitle),
              onTap: _exportDatabase,
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.download_for_offline),
              title: Text(l10n.settings_import),
              subtitle: Text(l10n.settings_import_subtitle),
              onTap: _importDatabase,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2
        ),
      ),
    );
  }
}
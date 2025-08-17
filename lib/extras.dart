// lib/tips_extras_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'rm_calculator_dialog.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';


class TipsExtrasScreen extends StatelessWidget {
  const TipsExtrasScreen({Key? key}) : super(key: key);

  // TODO: Reemplaza esta URL con la URL real de tu repositorio cuando esté lista
  final String _repositoryUrl = 'https://github.com/Cristofer3097/gym';
  final String _heavyDutyBookUrl = 'https://www.amazon.com.mx/Heavy-Duty-Verdad-Entrenamiento-Intensidad-ebook/dp/B0F74PTBXZ/ref=sr_1_6?crid=1K9NUXJFDFR2C&dib=eyJ2IjoiMSJ9.BXt_LZeGSWI7WWJcjDKapprBUdFNMT6mPWI5Ualm_pFay7IwmsMDdeebzA0hcdCYYbOQ1MWxJHPH4eD3xZwT7oY5B47TJDQRJXqTVhHmHNVbfytNGdXnn579-TX74sgxKP4lMu9N6CCZvRa8n2ij4Pby9NMI4MzUqVjpboqWo_O9h0D8O1CL1DFKOM7npeMtm9wywN8edXFYUmTKzF21zvteiCEPSzfuwTYD0GkXlQ_oeX-xCafQIgh64gn1YztC8OU_JEZXTua2R7uZuec_-spF3BmL4rJE0j3Rwwr87bs.zH6MPy44BSzxenauvMRQ-n-f5ZyiTcZNRq7feA5QruE&dib_tag=se&keywords=heavy+duty+mike+mentzer&qid=1748297635&sprefix=heavy+dut%2Caps%2C180&sr=8-6';

  Future<void>  _launchGenericUrl(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    final l10n = AppLocalizations.of(context)!;
       if (!await launchUrl(url)) {
         if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text(l10n.tips_book_link_error)),
           );
         }
       }
     }
  void _showRMCalculatorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return const RMCalculatorDialog();
      },
    );
  }
  void _showRmInfoDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.tips_rm_is_title),
          content: Text(l10n.tips_rm_is),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.close),
            ),
          ],
        );
      },
    );
  }
  void _hypertrophyDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.tips_hypertrophy),
          content: Text(l10n.tips_hypertrophy_dialog),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.close),
            ),
          ],
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context); // Para usar colores y estilos del tema

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tipsAndExtras),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[

            _buildSectionTitle(context, l10n.tips_title, theme.primaryColor),
            Card( // Se mantiene la Card para el diseño
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- CAMBIO: Se quita el InkWell, ahora es solo un Row para mostrar el título y el ícono ---
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.tips_rm, // Título
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.info_outline_rounded, color: theme.primaryColor, size: 20),
                          onPressed: () => _showRmInfoDialog(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(), // Ayuda a reducir el área de toque excesiva
                        )                      ],
                    ),
                    Text( // La descripción no cambia
                      l10n.tips_rm_text,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withOpacity(0.85),
                        height: 1.4,
                      ),
                    ),
                    // --- CAMBIO: Se añade el botón de acción ---
                    const SizedBox(height: 12),
                    Center(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.calculate_outlined, size: 20),
                        label: Text(l10n.calculator_RM), // Usamos el nuevo texto
                        onPressed: () => _showRMCalculatorDialog(context), // La acción ahora está aquí
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            _buildTip(
              context,
              l10n.tips_book, // Título del consejo
              l10n.tips_book_text, // Contenido del consejo
              actionButton: ElevatedButton.icon( // El botón que quieres integrar
                icon: const Icon(Icons.menu_book_rounded, size: 20), // Icono más apropiado para un libro
                label: Text(l10n.tips_book_link), // Texto del botón
                style: ElevatedButton.styleFrom(

                ),
                onPressed: () {
                  _launchGenericUrl(context, _heavyDutyBookUrl); // Descomenta cuando tengas la URL y url_launcher


                },
              ),
            ),

            Card( // Se mantiene la Card para el diseño
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- CAMBIO: Se quita el InkWell, ahora es solo un Row para mostrar el título y el ícono ---
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.tips_hypertrophy_title, // Título
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.info_outline_rounded, color: theme.primaryColor, size: 20),
                          onPressed: () => _hypertrophyDialog(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(), // Ayuda a reducir el área de toque excesiva
                        )                      ],
                    ),
                    Text( // La descripción no cambia
                      l10n.tips_hypertrophy_text,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withOpacity(0.85),
                        height: 1.4,
                      ),
                    ),
                    // --- CAMBIO: Se añade el botón de acción ---
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            _buildTip(context, l10n.tips_proof, l10n.tips_proof_text,),
            _buildTip(context, l10n.tips_Heating, l10n.tips_Heating_text),
            _buildTip(context, l10n.tips_aprox, l10n.tips_aprox_text),
            _buildTip(context, l10n.tips_tec, l10n.tips_tec_text),
            _buildTip(context, l10n.tips_avoid, l10n.tips_avoid_text),
            _buildTip(context, l10n.tips_progression, l10n.tips_progression_text),
            _buildTip(context, l10n.tips_rest, l10n.tips_rest_text),
            _buildTip(context, l10n.tips_series, l10n.tips_series_text),
            _buildTip(context, l10n.tips_nutrition, l10n.tips_nutrition_text),

            const SizedBox(height: 24),
            _buildSectionTitle(context, l10n.tips_repositories, theme.primaryColor),
            Text(l10n.tips_repositories_text,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 12),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.code_rounded), // Icono para repositorio
                label: Text(l10n.tips_repositories_link),
                onPressed: () {
                   _launchGenericUrl(context, _repositoryUrl); // Descomenta cuando tengas la URL y url_launcher
                },
              ),
            ),

            const SizedBox(height: 24),
            _buildSectionTitle(context, l10n.tips_project, theme.primaryColor),
            Text(l10n.tips_project_text,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(l10n.creatorCredit,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTip(BuildContext context, String title, String content, {Widget? actionButton}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Card( // Usar Card para mejor separación visual
        // elevation y color se heredan del CardTheme
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white, // O theme.colorScheme.onSurface
                ),
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withOpacity(0.85), // O theme.colorScheme.onSurface.withOpacity(0.85)
                  height: 1.4,
                ),
              ),
              if (actionButton != null) ...[ // Si se proporciona un actionButton
                const SizedBox(height: 12), // Añade un espacio antes del botón
                Center(child: actionButton), // Muestra el botón, centrado
              ],
            ],
          ),
        ),
      ),
    );
  }
}




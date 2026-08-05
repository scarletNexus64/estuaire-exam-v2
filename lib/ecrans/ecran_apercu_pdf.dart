import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../app/theme.dart';
import '../widgets/communs.dart';

/// Aperçu d'un document avant impression ou export.
///
/// Les pages sont rasterisées : contrairement à `Printing.layoutPdf`,
/// l'affichage ne dépend pas d'un service d'impression système, absent
/// sur bien des postes.
class EcranApercuPdf extends StatefulWidget {
  final String titre;
  final String sousTitre;

  /// Nom proposé lors de l'export, sans extension.
  final String nomFichier;
  final Uint8List document;

  const EcranApercuPdf({
    super.key,
    required this.titre,
    required this.sousTitre,
    required this.nomFichier,
    required this.document,
  });

  @override
  State<EcranApercuPdf> createState() => _EcranApercuPdfState();
}

class _EcranApercuPdfState extends State<EcranApercuPdf> {
  final List<Uint8List> _pages = [];
  bool _rendu = false;
  String? _erreur;
  bool _occupe = false;

  @override
  void initState() {
    super.initState();
    _rendre();
  }

  Future<void> _rendre() async {
    try {
      // 110 dpi : lisible à l'écran sans alourdir la mémoire.
      await for (final page
          in Printing.raster(widget.document, dpi: 110)) {
        final image = await page.toPng();
        if (!mounted) return;
        setState(() => _pages.add(image));
      }
      if (mounted) setState(() => _rendu = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _rendu = true;
          _erreur = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fond,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _barre(context),
          Expanded(child: _corps(context)),
        ],
      ),
    );
  }

  Widget _barre(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          Espace.xl, Espace.lg, Espace.xl, Espace.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.bordure)),
      ),
      child: Row(
        children: [
          Tooltip(
            message: 'Retour',
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(rayonPetit),
              child: const Padding(
                padding: EdgeInsets.all(Espace.sm),
                child: Icon(Icons.arrow_back, size: 20),
              ),
            ),
          ),
          const SizedBox(width: Espace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.titre,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge),
                Text(widget.sousTitre,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (_pages.isNotEmpty) ...[
            Pastille.neutre(
                '${_pages.length} page${_pages.length > 1 ? "s" : ""}'),
            const SizedBox(width: Espace.lg),
          ],
          // Export et impression sont deux actions distinctes.
          OutlinedButton.icon(
            onPressed: _occupe ? null : _imprimer,
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('Imprimer'),
          ),
          const SizedBox(width: Espace.sm),
          FilledButton.icon(
            onPressed: _occupe ? null : _exporter,
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Exporter en PDF'),
          ),
        ],
      ),
    );
  }

  Widget _corps(BuildContext context) {
    if (_erreur != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 30, color: AppColors.danger),
              const SizedBox(height: Espace.md),
              Text('Aperçu indisponible',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: Espace.xs),
              Text(
                'Le document reste exportable en PDF.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: Espace.lg),
              SelectableText(
                _erreur!,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: AppColors.texteFaible,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_pages.isEmpty && !_rendu) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(Espace.xxl),
      itemCount: _pages.length,
      itemBuilder: (context, i) => Center(
        child: Container(
          margin: const EdgeInsets.only(bottom: Espace.xl),
          constraints: const BoxConstraints(maxWidth: 820),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.bordure),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Image.memory(_pages[i], fit: BoxFit.contain),
        ),
      ),
    );
  }

  Future<void> _exporter() async {
    final messager = ScaffoldMessenger.of(context);

    final String? destination;
    try {
      destination = await FilePicker.platform.saveFile(
        dialogTitle: 'Exporter ${widget.titre}',
        fileName: '${widget.nomFichier}.pdf',
        type: FileType.any,
      );
    } catch (e) {
      messager.showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        content: Text('Sélecteur de fichiers indisponible : $e'),
      ));
      return;
    }
    if (destination == null) return;

    setState(() => _occupe = true);
    try {
      final chemin = destination.toLowerCase().endsWith('.pdf')
          ? destination
          : '$destination.pdf';
      await File(chemin).writeAsBytes(widget.document);
      messager.showSnackBar(
        SnackBar(content: Text('Document exporté vers $chemin')),
      );
    } catch (e) {
      messager.showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        content: Text('Export impossible : $e'),
      ));
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _imprimer() async {
    final messager = ScaffoldMessenger.of(context);
    setState(() => _occupe = true);
    try {
      await Printing.layoutPdf(
        onLayout: (_) => widget.document,
        name: widget.nomFichier,
      );
    } catch (e) {
      // Poste sans service d'impression : l'export reste la voie normale.
      messager.showSnackBar(SnackBar(
        backgroundColor: AppColors.alerte,
        content: Text(
          'Impression indisponible sur ce poste. '
          'Exportez le PDF puis imprimez-le depuis votre lecteur.',
        ),
        duration: const Duration(seconds: 5),
      ));
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }
}

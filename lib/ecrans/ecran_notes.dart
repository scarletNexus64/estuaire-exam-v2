import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/magasin.dart';
import '../data/magasin_epreuves.dart';
import '../data/magasin_sessions.dart';
import '../data/modeles.dart';
import '../data/parametres.dart';
import '../data/session.dart';
import '../documents/export_notes_insam.dart';
import '../documents/fiche_notes.dart';
import 'ecran_apercu_pdf.dart';
import '../widgets/communs.dart';

/// Notes : consultation par matière et édition des documents officiels.
class EcranNotes extends StatefulWidget {
  const EcranNotes({super.key});

  @override
  State<EcranNotes> createState() => _EcranNotesState();
}

class _EcranNotesState extends State<EcranNotes> {
  static const _flex = <double>[0.5, 2.6, 1.6, 0.6, 1.2, 1.2, 1.2];

  String? _matiereId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        Magasin.instance,
        MagasinEpreuves.instance,
        MagasinSessions.instance,
        Session.instance,
      ]),
      builder: (context, _) {
        final magasin = Magasin.instance;
        final utilisateur = Session.instance.courant;

        // Écran réservé à l'enseignant : il ne voit que ses matières.
        final matieres = magasin.matieres
            .where((m) => utilisateur?.matiereIds.contains(m.id) ?? false)
            .toList();

        if (matieres.isEmpty) return const _AucuneMatiere();

        final choisie = matieres
                .where((m) => m.id == _matiereId)
                .firstOrNull ??
            matieres.first;
        final lignes = FicheNotes.lignesDe(choisie);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EnTetePage(
              titre: 'Notes',
              sousTitre:
                  'Report des notes par matière. Les notes sont ramenées sur 20.',
              actions: [
                OutlinedButton.icon(
                  onPressed: () => _listePresence(context, choisie),
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: const Text('Liste de présence'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _exportInsam(context, choisie),
                  icon: const Icon(Icons.table_view_outlined, size: 18),
                  label: const Text('Export INSAM'),
                ),
                FilledButton.icon(
                  onPressed: () => _fiche(context, choisie, lignes),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('Fiche de notes'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Espace.xxl, 0, Espace.xxl, Espace.lg),
              child: Row(
                children: [
                  SizedBox(
                    width: 380,
                    child: SelecteurCherchable<String>(
                      etiquette: 'Matière',
                      valeur: choisie.id,
                      options: [
                        for (final m in matieres)
                          OptionSelecteur(
                            valeur: m.id,
                            libelle: '${m.code} — ${m.intitule}',
                            detail: magasin.nomNiveau(m.niveauId),
                          ),
                      ],
                      onChange: (v) => setState(() => _matiereId = v),
                    ),
                  ),
                  const Spacer(),
                  Text('${lignes.length} étudiant(s)',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    Espace.xxl, 0, Espace.xxl, Espace.xxl),
                child: Tableau(
                  colonnes: const [
                    'N°',
                    'Noms et Prénoms',
                    'Matricule',
                    'Sexe',
                    'Contrôle continu',
                    'Session normale',
                    'Rattrapage',
                  ],
                  flex: _flex,
                  messageVide: 'Aucun étudiant dans cette promotion.',
                  lignes: [
                    for (final l in lignes)
                      LigneTableau(
                        flex: _flex,
                        cellules: [
                          cellule('${l.numero}',
                              couleur: AppColors.texteDoux),
                          cellule(l.nom, gras: true),
                          cellule(l.matricule,
                              couleur: AppColors.bleuSombre),
                          cellule(l.sexe),
                          _Note(valeur: l.controleContinu),
                          _Note(valeur: l.sessionNormale),
                          _Note(valeur: l.rattrapage),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _enseignant() =>
      Session.instance.courant?.nomComplet ?? '……………';

  Future<void> _fiche(
      BuildContext context, Matiere matiere, List<LigneNotes> lignes) async {
    final messager = ScaffoldMessenger.of(context);
    try {
      final pdf = await FicheNotes.fiche(
        matiere: matiere,
        enseignant: _enseignant(),
        lignes: lignes,
      );
      if (!context.mounted) return;

      // Aperçu d'abord : l'enseignant vérifie avant d'imprimer ou d'exporter.
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EcranApercuPdf(
          titre: 'Fiche de report de notes',
          sousTitre: '${matiere.code} · ${matiere.intitule}',
          nomFichier:
              'fiche-notes-${matiere.code}-${Parametres.instance.annee}',
          document: pdf,
        ),
      ));
    } catch (e) {
      messager.showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        content: Text('Génération impossible : $e'),
      ));
    }
  }

  /// Produit le classeur de notes attendu par le système central.
  ///
  /// Une nature d'épreuve par fichier : chez INSAM le contrôle continu,
  /// la session normale et le rattrapage sont trois examens distincts.
  Future<void> _exportInsam(BuildContext context, Matiere matiere) async {
    final nature = await showDialog<NatureEpreuve>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text('Export INSAM',
            style: Theme.of(c).textTheme.titleLarge),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Espace.lg, 0, Espace.lg, Espace.md),
            child: Text(
              'Quelle évaluation reporter ? Le fichier produit reprend les '
              'identifiants INSAM et s\'importe tel quel.',
              style: Theme.of(c).textTheme.bodySmall,
            ),
          ),
          for (final n in NatureEpreuve.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, n),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Espace.xs),
                child: Text(n.libelle,
                    style: Theme.of(c).textTheme.titleMedium),
              ),
            ),
        ],
      ),
    );

    if (nature == null || !context.mounted) return;

    final messager = ScaffoldMessenger.of(context);
    try {
      final export = await ExportNotesInsam.generer(
        matiere: matiere,
        nature: nature,
      );

      final chemin = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer le fichier de notes',
        fileName: export.nomFichier,
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        bytes: Uint8List.fromList(export.octets),
      );
      if (chemin == null) return;

      // Sur les plateformes où `saveFile` se contente de renvoyer un
      // chemin, c'est à nous d'écrire le fichier.
      final fichier = File(chemin);
      if (!await fichier.exists() || await fichier.length() == 0) {
        await fichier.writeAsBytes(export.octets, flush: true);
      }

      final orphelines = export.orphelines.length;
      messager.showSnackBar(SnackBar(
        backgroundColor: orphelines > 0 ? AppColors.alerte : null,
        content: Text(
          orphelines > 0
              ? '${export.total} lignes exportées, dont $orphelines sans '
                  'identifiant INSAM — à apparier à la main.'
              : '${export.total} lignes exportées, '
                  '${export.avecNote} avec une note.',
        ),
      ));
    } catch (e) {
      messager.showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        content: Text('Export impossible : $e'),
      ));
    }
  }

  Future<void> _listePresence(BuildContext context, Matiere matiere) async {
    final epreuves = MagasinEpreuves.instance.epreuvesDe(matiere.id);
    if (epreuves.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Aucune épreuve pour cette matière.'),
      ));
      return;
    }

    // La présence se constate par épreuve : il faut savoir laquelle.
    final choisie = await showDialog<Epreuve>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text('Liste de présence',
            style: Theme.of(c).textTheme.titleLarge),
        children: [
          for (final e in epreuves)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, e),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Espace.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e.titre,
                        style: Theme.of(c).textTheme.titleMedium),
                    Text(
                      '${e.nature.libelle} · '
                      '${MagasinSessions.instance.sessionsDe(e.id).length} présent(s)',
                      style: Theme.of(c).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    if (choisie == null || !context.mounted) return;

    final messager = ScaffoldMessenger.of(context);
    try {
      final pdf = await FicheNotes.listePresence(
        epreuve: choisie,
        matiere: matiere,
        enseignant: _enseignant(),
      );
      if (!context.mounted) return;

      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EcranApercuPdf(
          titre: 'Liste de présence',
          sousTitre: choisie.titre,
          nomFichier: 'presence-${matiere.code}-${choisie.codeAcces}',
          document: pdf,
        ),
      ));
    } catch (e) {
      messager.showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        content: Text('Génération impossible : $e'),
      ));
    }
  }
}

class _Note extends StatelessWidget {
  final double? valeur;
  const _Note({required this.valeur});

  @override
  Widget build(BuildContext context) {
    if (valeur == null) {
      return cellule('—', couleur: AppColors.texteFaible);
    }
    // Sous 10/20, la note est signalée : l'œil repère les échecs.
    return cellule(
      valeur!.toStringAsFixed(2).replaceAll('.', ','),
      gras: true,
      couleur: valeur! < 10 ? AppColors.danger : AppColors.succes,
    );
  }
}

class _AucuneMatiere extends StatelessWidget {
  const _AucuneMatiere();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EnTetePage(
          titre: 'Notes',
          sousTitre: 'Report des notes par matière.',
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                Espace.xxl, 0, Espace.xxl, Espace.xxl),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(rayon),
                border: Border.all(color: AppColors.bordure),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.assignment_outlined,
                        size: 32, color: AppColors.texteFaible),
                    const SizedBox(height: Espace.md),
                    Text('Aucune matière',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: Espace.xs),
                    Text('Aucune matière ne vous est confiée.',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

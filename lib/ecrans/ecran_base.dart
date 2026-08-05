import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../data/base_locale.dart';
import '../data/console_sql.dart';
import '../data/magasin.dart';
import '../data/magasin_epreuves.dart';
import '../data/magasin_sessions.dart';
import '../data/session.dart';
import '../widgets/communs.dart';

/// Base de données locale : sauvegarde, restauration et console SQL.
class EcranBase extends StatefulWidget {
  const EcranBase({super.key});

  @override
  State<EcranBase> createState() => _EcranBaseState();
}

class _EcranBaseState extends State<EcranBase> {
  int _onglet = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EnTetePage(
          titre: 'Base de données',
          sousTitre:
              'Sauvegarde, restauration et interrogation directe de la base locale.',
        ),
        Padding(
          padding:
              const EdgeInsets.fromLTRB(Espace.xxl, 0, Espace.xxl, Espace.lg),
          child: Row(
            children: [
              _Onglet(
                titre: 'Sauvegarde',
                icone: Icons.save_outlined,
                actif: _onglet == 0,
                onTap: () => setState(() => _onglet = 0),
              ),
              const SizedBox(width: Espace.sm),
              _Onglet(
                titre: 'Console SQL',
                icone: Icons.terminal_outlined,
                actif: _onglet == 1,
                onTap: () => setState(() => _onglet = 1),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                Espace.xxl, 0, Espace.xxl, Espace.xxl),
            child: _onglet == 0 ? const _Sauvegarde() : const _ConsoleSqlVue(),
          ),
        ),
      ],
    );
  }
}

class _Onglet extends StatelessWidget {
  final String titre;
  final IconData icone;
  final bool actif;
  final VoidCallback onTap;

  const _Onglet({
    required this.titre,
    required this.icone,
    required this.actif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(rayonPetit),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(
            horizontal: Espace.lg, vertical: Espace.md),
        decoration: BoxDecoration(
          color: actif ? AppColors.rougePale : AppColors.surface,
          borderRadius: BorderRadius.circular(rayonPetit),
          border:
              Border.all(color: actif ? AppColors.rouge : AppColors.bordure),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone,
                size: 17,
                color: actif ? AppColors.rouge : AppColors.texteDoux),
            const SizedBox(width: Espace.sm),
            Text(
              titre,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
                color: actif ? AppColors.rouge : AppColors.texte,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Sauvegarde / restauration ----------

class _Sauvegarde extends StatefulWidget {
  const _Sauvegarde();

  @override
  State<_Sauvegarde> createState() => _SauvegardeState();
}

class _SauvegardeState extends State<_Sauvegarde> {
  bool _occupe = false;

  String _formaterTaille(int octets) {
    if (octets < 1024) return '$octets o';
    if (octets < 1024 * 1024) return '${(octets / 1024).toStringAsFixed(1)} Ko';
    return '${(octets / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  @override
  Widget build(BuildContext context) {
    final m = Magasin.instance;
    return AnimatedBuilder(
      animation: m,
      builder: (context, _) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Carte(
              icone: Icons.download_outlined,
              couleur: AppColors.bleu,
              titre: 'Exporter la base',
              description:
                  'Enregistre une copie complète de la base dans un fichier. '
                  'À conserver sur une clé USB en fin de session.',
              action: 'Exporter',
              occupe: _occupe,
              onAction: _exporter,
              details: [
                '${m.specialites.length} spécialité(s)',
                '${m.niveaux.length} niveau(x)',
                '${m.matieres.length} matière(s)',
                '${m.etudiants.length} étudiant(s)',
              ],
            ),
            const SizedBox(height: Espace.lg),
            _Carte(
              icone: Icons.upload_outlined,
              couleur: AppColors.alerte,
              titre: 'Importer une base',
              description:
                  'Remplace intégralement les données actuelles par celles du '
                  'fichier choisi. Exportez d\'abord si vous souhaitez les conserver.',
              action: 'Importer',
              occupe: _occupe,
              onAction: _importer,
            ),
            const SizedBox(height: Espace.lg),
            _Carte(
              icone: Icons.delete_sweep_outlined,
              couleur: AppColors.danger,
              titre: 'Vider la base',
              description:
                  'Efface les spécialités, niveaux, matières, étudiants, '
                  'épreuves et notes. Les campus, les paramètres et le compte '
                  'administrateur sont conservés. À faire avant de réimporter '
                  'un référentiel INSAM corrigé.',
              action: 'Vider',
              occupe: _occupe,
              onAction: _vider,
            ),
            const SizedBox(height: Espace.lg),
            _Emplacement(formater: _formaterTaille),
          ],
        ),
      ),
    );
  }

  Future<void> _exporter() async {
    final horodatage = DateTime.now()
        .toIso8601String()
        .substring(0, 16)
        .replaceAll(RegExp(r'[:T]'), '-');

    final String? destination;
    try {
      destination = await FilePicker.platform.saveFile(
        dialogTitle: 'Exporter la base Estuaire Examen',
        fileName: 'estuaire-$horodatage.db',
        type: FileType.any,
      );
    } catch (e) {
      // Sans le message, un sélecteur qui ne s'ouvre pas passe pour un clic
      // sans effet et l'utilisateur ne sait pas quoi corriger.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Sélecteur de fichiers indisponible : $e'),
        ),
      );
      return;
    }
    // `null` = l'utilisateur a annulé.
    if (destination == null || !mounted) return;

    setState(() => _occupe = true);
    try {
      await BaseLocale.instance.exporterVers(destination);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Base exportée vers $destination')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Export impossible : $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _vider() async {
    final m = Magasin.instance;
    final resume = [
      if (m.specialites.isNotEmpty) '${m.specialites.length} spécialité(s)',
      if (m.niveaux.isNotEmpty) '${m.niveaux.length} niveau(x)',
      if (m.matieres.isNotEmpty) '${m.matieres.length} matière(s)',
      if (m.etudiants.isNotEmpty) '${m.etudiants.length} étudiant(s)',
    ];

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Vider la base ?',
            style: Theme.of(c).textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              resume.isEmpty
                  ? 'La base ne contient aucune donnée académique.'
                  : '${resume.join(', ')} seront effacés, ainsi que les '
                      'épreuves, les notes et les correspondances INSAM.',
              style: Theme.of(c).textTheme.bodyMedium,
            ),
            const SizedBox(height: Espace.md),
            Text(
              'Les campus, les paramètres et le compte administrateur sont '
              'conservés. Cette action est irréversible : exportez d\'abord '
              'si vous souhaitez garder une copie.',
              style: Theme.of(c).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Vider la base'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _occupe = true);
    final messager = ScaffoldMessenger.of(context);
    try {
      await BaseLocale.instance.reinitialiser();
      // Les magasins gardent les données en mémoire : sans rechargement,
      // les écrans afficheraient encore ce qui vient d'être effacé.
      await Magasin.instance.charger();
      await MagasinEpreuves.instance.charger();
      await MagasinSessions.instance.charger();
      await Session.instance.charger();
      if (!mounted) return;
      messager.showSnackBar(
        const SnackBar(content: Text('Base vidée.')),
      );
    } catch (e) {
      if (!mounted) return;
      messager.showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        content: Text('Impossible de vider la base : $e'),
      ));
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _importer() async {
    final String? chemin;
    try {
      final choix = await FilePicker.platform.pickFiles(
        dialogTitle: 'Choisir une base à importer',
        type: FileType.any,
      );
      chemin = choix?.files.single.path;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Sélecteur de fichiers indisponible : $e'),
        ),
      );
      return;
    }
    if (chemin == null || !mounted) return;
    final source = chemin;

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Remplacer la base actuelle ?',
            style: Theme.of(c).textTheme.titleLarge),
        content: Text(
          'Toutes les données présentes seront écrasées par le contenu de '
          '${source.split(Platform.pathSeparator).last}. '
          'Cette action est irréversible.',
          style: Theme.of(c).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Importer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _occupe = true);
    try {
      await BaseLocale.instance.remplacerPar(File(source));
      // Le cache mémoire décrit l'ancienne base : tout recharger.
      await Magasin.instance.charger();
      await Session.instance.charger();
      if (!mounted) return;

      // Le compte connecté peut ne pas exister dans la base importée.
      if (Session.instance.courant == null) {
        Session.instance.deconnecter();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Base importée.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Import impossible : $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }
}

/// Emplacement du fichier sur le disque, avec sa taille.
class _Emplacement extends StatelessWidget {
  final String Function(int) formater;
  const _Emplacement({required this.formater});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Espace.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(rayon),
        border: Border.all(color: AppColors.bordure),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder_outlined,
              size: 17, color: AppColors.texteFaible),
          const SizedBox(width: Espace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Fichier de la base',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                SelectableText(
                  BaseLocale.instance.chemin,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    color: AppColors.texte,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Espace.md),
          FutureBuilder<int>(
            future: BaseLocale.instance.taille(),
            builder: (context, snap) => Pastille.neutre(
                snap.hasData ? formater(snap.data!) : '…'),
          ),
          const SizedBox(width: Espace.sm),
          Tooltip(
            message: 'Copier le chemin',
            child: InkWell(
              onTap: () {
                Clipboard.setData(
                    ClipboardData(text: BaseLocale.instance.chemin));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chemin copié.')),
                );
              },
              borderRadius: BorderRadius.circular(rayonPetit),
              child: const Padding(
                padding: EdgeInsets.all(Espace.sm),
                child: Icon(Icons.copy_outlined,
                    size: 16, color: AppColors.texteDoux),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Carte extends StatelessWidget {
  final IconData icone;
  final Color couleur;
  final String titre;
  final String description;
  final String action;
  final VoidCallback onAction;
  final bool occupe;
  final List<String> details;

  const _Carte({
    required this.icone,
    required this.couleur,
    required this.titre,
    required this.description,
    required this.action,
    required this.onAction,
    this.occupe = false,
    this.details = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Espace.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(rayon),
        border: Border.all(color: AppColors.bordure),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(rayonPetit),
            ),
            child: Icon(icone, size: 19, color: couleur),
          ),
          const SizedBox(width: Espace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: Espace.xs),
                Text(description,
                    style: Theme.of(context).textTheme.bodySmall),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: Espace.md),
                  Wrap(
                    spacing: Espace.sm,
                    runSpacing: Espace.xs,
                    children: [
                      for (final d in details) Pastille.neutre(d),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Espace.lg),
          OutlinedButton(
            onPressed: occupe ? null : onAction,
            child: Text(action),
          ),
        ],
      ),
    );
  }
}

// ---------- Console SQL ----------

class _ConsoleSqlVue extends StatefulWidget {
  const _ConsoleSqlVue();

  @override
  State<_ConsoleSqlVue> createState() => _ConsoleSqlVueState();
}

class _ConsoleSqlVueState extends State<_ConsoleSqlVue> {
  final _requete = TextEditingController(
      text: 'SELECT matricule, nom_complet FROM etudiant LIMIT 20;');

  ResultatSql? _resultat;
  bool _occupe = false;

  @override
  void dispose() {
    _requete.dispose();
    super.dispose();
  }

  Future<void> _executer() async {
    final sql = _requete.text;

    // Une écriture ne se lance pas par accident : on demande confirmation.
    if (sql.trim().isNotEmpty && !ConsoleSql.estLecture(sql)) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Requête d\'écriture',
              style: Theme.of(c).textTheme.titleLarge),
          content: Text(
            'Cette requête peut modifier ou supprimer des données de façon '
            'irréversible. Exportez la base avant si nécessaire.',
            style: Theme.of(c).textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Exécuter'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    setState(() => _occupe = true);
    final r = await ConsoleSql.executer(sql);

    // Une écriture rend le cache mémoire faux : le recharger.
    if (r.aEcrit && r.ok) {
      await Magasin.instance.charger();
      await Session.instance.charger();
    }
    if (!mounted) return;
    setState(() {
      _resultat = r;
      _occupe = false;
    });
  }

  /// Enregistre le résultat courant en CSV.
  /// La requête est rejouée sans plafond : le fichier doit contenir toutes
  /// les lignes, pas seulement les 500 affichées.
  Future<void> _exporterCsv() async {
    final horodatage = DateTime.now()
        .toIso8601String()
        .substring(0, 16)
        .replaceAll(RegExp(r'[:T]'), '-');

    final String? destination;
    try {
      destination = await FilePicker.platform.saveFile(
        dialogTitle: 'Exporter le résultat en CSV',
        fileName: 'requete-$horodatage.csv',
        type: FileType.any,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Sélecteur de fichiers indisponible : $e'),
        ),
      );
      return;
    }
    if (destination == null || !mounted) return;

    setState(() => _occupe = true);
    try {
      final complet = await ConsoleSql.executerComplet(_requete.text);
      if (!complet.ok) throw Exception(complet.erreur);

      final chemin =
          destination.toLowerCase().endsWith('.csv') ? destination : '$destination.csv';
      await File(chemin).writeAsString(complet.versCsv());
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${complet.lignes.length} ligne(s) exportée(s) vers $chemin')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Export CSV impossible : $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 3, child: _editeur(context)),
        const SizedBox(width: Espace.lg),
        const SizedBox(width: 240, child: _PanneauSchema()),
      ],
    );
  }

  Widget _editeur(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(Espace.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(rayon),
              border: Border.all(color: AppColors.bordure),
            ),
            child: TextField(
              controller: _requete,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.5,
                color: AppColors.texte,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintText: 'SELECT * FROM etudiant;',
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        const SizedBox(height: Espace.md),
        Row(
          children: [
            const Icon(Icons.info_outline,
                size: 15, color: AppColors.texteFaible),
            const SizedBox(width: Espace.sm),
            Expanded(
              child: Text(
                'Une seule instruction à la fois. Les écritures sont définitives.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (_resultat?.estLecture ?? false) ...[
              OutlinedButton.icon(
                onPressed: _occupe ? null : _exporterCsv,
                icon: const Icon(Icons.table_view_outlined, size: 17),
                label: const Text('Exporter CSV'),
              ),
              const SizedBox(width: Espace.sm),
            ],
            OutlinedButton(
              onPressed: _occupe
                  ? null
                  : () => setState(() {
                        _requete.clear();
                        _resultat = null;
                      }),
              child: const Text('Effacer'),
            ),
            const SizedBox(width: Espace.sm),
            FilledButton.icon(
              onPressed: _occupe ? null : _executer,
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Exécuter'),
            ),
          ],
        ),
        const SizedBox(height: Espace.md),
        Expanded(flex: 3, child: _Resultat(resultat: _resultat)),
      ],
    );
  }
}

class _Resultat extends StatelessWidget {
  final ResultatSql? resultat;
  const _Resultat({required this.resultat});

  @override
  Widget build(BuildContext context) {
    final r = resultat;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(rayon),
        border: Border.all(
            color: r != null && !r.ok ? AppColors.danger : AppColors.bordure),
      ),
      clipBehavior: Clip.antiAlias,
      child: r == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.table_rows_outlined,
                      size: 30, color: AppColors.texteFaible),
                  const SizedBox(height: Espace.md),
                  Text('Le résultat s\'affichera ici.',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            )
          : !r.ok
              ? Padding(
                  padding: const EdgeInsets.all(Espace.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error_outline,
                              size: 16, color: AppColors.danger),
                          const SizedBox(width: Espace.sm),
                          Text('Erreur SQL',
                              style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                      const SizedBox(height: Espace.sm),
                      Expanded(
                        child: SingleChildScrollView(
                          child: SelectableText(
                            r.erreur!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              height: 1.5,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : r.estLecture
                  ? _tableau(context, r)
                  : Padding(
                      padding: const EdgeInsets.all(Espace.lg),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline,
                              size: 17, color: AppColors.succes),
                          const SizedBox(width: Espace.sm),
                          Text(
                            r.affectees == null
                                ? 'Requête exécutée.'
                                : '${r.affectees} ligne(s) affectée(s).',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const Spacer(),
                          Pastille.neutre('${r.duree.inMilliseconds} ms'),
                        ],
                      ),
                    ),
    );
  }

  Widget _tableau(BuildContext context, ResultatSql r) {
    final tronque =
        (r.affectees ?? 0) > r.lignes.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Espace.lg, vertical: Espace.sm),
          decoration: const BoxDecoration(
            color: AppColors.fond,
            border: Border(bottom: BorderSide(color: AppColors.bordure)),
          ),
          child: Row(
            children: [
              Text(
                '${r.affectees ?? r.lignes.length} ligne(s)'
                '${tronque ? ' — ${r.lignes.length} affichées' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              Pastille.neutre('${r.duree.inMilliseconds} ms'),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                headingRowHeight: 38,
                dataRowMinHeight: 34,
                dataRowMaxHeight: 34,
                horizontalMargin: Espace.lg,
                columnSpacing: Espace.xl,
                columns: [
                  for (final c in r.colonnes)
                    DataColumn(
                      label: Text(
                        c,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.bleuSombre,
                        ),
                      ),
                    ),
                ],
                rows: [
                  for (final ligne in r.lignes)
                    DataRow(
                      cells: [
                        for (final valeur in ligne)
                          DataCell(
                            Text(
                              valeur?.toString() ?? 'NULL',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: valeur == null
                                    ? AppColors.texteFaible
                                    : AppColors.texte,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Schéma réel de la base, lu depuis SQLite.
class _PanneauSchema extends StatelessWidget {
  const _PanneauSchema();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Espace.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(rayon),
        border: Border.all(color: AppColors.bordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SCHÉMA', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: Espace.md),
          Expanded(
            child: FutureBuilder<Map<String, List<String>>>(
              future: ConsoleSql.schema(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const SizedBox.shrink();
                }
                return ListView(
                  children: [
                    for (final e in snap.data!.entries) ...[
                      _Table(nom: e.key, colonnes: e.value),
                      const SizedBox(height: Espace.md),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Table du schéma : un clic copie son nom.
class _Table extends StatelessWidget {
  final String nom;
  final List<String> colonnes;

  const _Table({required this.nom, required this.colonnes});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: nom));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('« $nom » copié.')),
            );
          },
          borderRadius: BorderRadius.circular(rayonPetit),
          child: Row(
            children: [
              const Icon(Icons.table_chart_outlined,
                  size: 14, color: AppColors.bleu),
              const SizedBox(width: Espace.sm),
              Text(
                nom,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.bleuSombre,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Espace.xs),
        Padding(
          padding: const EdgeInsets.only(left: Espace.lg + 2),
          child: Text(
            colonnes.join(', '),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11.5,
              height: 1.5,
              color: AppColors.texteDoux,
            ),
          ),
        ),
      ],
    );
  }
}

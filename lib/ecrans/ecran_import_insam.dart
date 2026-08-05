import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/import_dump_insam.dart';
import '../data/magasin_campus.dart';
import '../data/magasin_insam.dart';
import '../data/referentiel_insam.dart';
import '../widgets/communs.dart';

/// Import INSAM : téléverser un dump du système central, puis reprendre
/// une année académique entière dans les campus choisis.
///
/// Sans cette étape, nos étudiants et nos matières n'ont pas
/// d'identifiant central, et les notes exportées seraient inexploitables
/// par INSAM.
class EcranImportInsam extends StatefulWidget {
  const EcranImportInsam({super.key});

  @override
  State<EcranImportInsam> createState() => _EcranImportInsamState();
}

class _EcranImportInsamState extends State<EcranImportInsam> {
  List<({int id, String intitule})> _annees = [];
  List<PromotionInsam> _promotions = [];

  int? _anneeId;
  final Set<String> _campusChoisis = {};
  final Set<String> _sansEtudiants = {...MagasinInsam.campusSansEtudiants};

  bool _chargement = true;
  bool _occupe = false;
  String _etape = '';
  double _progression = 0;

  /// Vrai tant que l'utilisateur n'a pas touché aux cases : la sélection
  /// suit alors la liste des campus, au lieu de rester figée sur l'état
  /// qu'elle avait à l'ouverture de l'écran.
  bool _campusParDefaut = true;

  @override
  void initState() {
    super.initState();
    _synchroniserCampus();
    _charger();
  }

  /// Coche tous les campus tant que l'utilisateur n'a rien décidé.
  ///
  /// Sans cela, un écran construit avant le chargement des campus gardait
  /// une sélection vide : le bouton « Tout importer » restait désactivé,
  /// et un clic ne produisait rien.
  void _synchroniserCampus() {
    if (!_campusParDefaut) return;
    _campusChoisis
      ..clear()
      ..addAll(MagasinCampus.instance.campus.map((c) => c.id));
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    final referentiel = ReferentielInsam.instance;
    if (!referentiel.estDisponible) await referentiel.ouvrir();

    if (!referentiel.estDisponible) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _annees = [];
        _promotions = [];
      });
      return;
    }

    final annees = await referentiel.annees();
    if (!mounted) return;
    setState(() {
      _annees = annees;
      // L'année la plus récente est presque toujours celle qu'on veut.
      _anneeId = annees.isEmpty ? null : annees.first.id;
      _chargement = false;
    });
    if (_anneeId != null) await _chargerPromotions(_anneeId!);
  }

  Future<void> _chargerPromotions(int anneeId) async {
    setState(() => _chargement = true);
    final promotions = await ReferentielInsam.instance.promotions(anneeId);
    if (!mounted) return;
    setState(() {
      _promotions = promotions;
      _chargement = false;
    });
  }

  // ---------- Téléversement du dump ----------

  Future<void> _televerser() async {
    final choix = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choisir le fichier SQL exporté depuis INSAM',
      type: FileType.custom,
      allowedExtensions: const ['sql'],
    );
    final chemin = choix?.files.single.path;
    if (chemin == null || !mounted) return;

    final messager = ScaffoldMessenger.of(context);
    setState(() {
      _occupe = true;
      _etape = 'Lecture du fichier…';
      _progression = 0;
    });

    try {
      final destination = await ReferentielInsam.instance.chemin();
      // Le référentiel doit être fermé avant d'être remplacé, sinon le
      // fichier reste verrouillé.
      await ReferentielInsam.instance.fermer();

      final bilan = await ImportDumpInsam.convertir(
        dump: File(chemin),
        destination: destination,
        progression: (e) {
          if (!mounted) return;
          setState(() {
            _etape = e.libelle;
            _progression = e.progression;
          });
        },
      );

      await ReferentielInsam.instance.recharger();
      if (!mounted) return;

      messager.showSnackBar(SnackBar(
        content: Text('Référentiel actualisé : ${bilan.total} lignes lues, '
            'dont ${bilan.lignes['etudiant'] ?? 0} étudiants et '
            '${bilan.lignes['matiere'] ?? 0} matières.'),
      ));
      await _charger();
    } catch (e) {
      // Le référentiel précédent n'a pas été touché : on le rouvre.
      await ReferentielInsam.instance.recharger();
      if (!mounted) return;
      messager.showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        content: Text('Lecture impossible : $e'),
      ));
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  // ---------- Import de l'année ----------

  Future<void> _importerTout() async {
    final messagerPrealable = ScaffoldMessenger.of(context);

    // Ces cas sortaient sans rien dire : l'utilisateur cliquait, et rien
    // ne se passait. Mieux vaut expliquer que rester muet.
    final annee = _annees.where((a) => a.id == _anneeId).firstOrNull;
    if (annee == null) {
      messagerPrealable.showSnackBar(const SnackBar(
        backgroundColor: AppColors.danger,
        content: Text('Choisissez d\'abord une année académique.'),
      ));
      return;
    }
    // Une sélection vide vient presque toujours d'un écran construit
    // avant le chargement des campus : on retombe sur « tous » plutôt
    // que de refuser l'import.
    if (_campusChoisis.isEmpty) {
      _campusChoisis.addAll(MagasinCampus.instance.campus.map((c) => c.id));
    }
    if (_campusChoisis.isEmpty) {
      messagerPrealable.showSnackBar(const SnackBar(
        backgroundColor: AppColors.danger,
        content: Text('Aucun campus n\'est configuré.'),
      ));
      return;
    }
    // La liste peut être vide si l'écran a été construit avant le
    // téléversement : on la relit plutôt que de renoncer.
    if (_promotions.isEmpty) {
      await _chargerPromotions(annee.id);
      if (!mounted) return;
    }
    if (_promotions.isEmpty) {
      messagerPrealable.showSnackBar(const SnackBar(
        backgroundColor: AppColors.danger,
        content: Text('Aucune promotion pour cette année.'),
      ));
      return;
    }

    final avecEtudiants =
        _campusChoisis.where((c) => !_sansEtudiants.contains(c)).length;

    final valide = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Importer toute l\'année ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Année ${annee.intitule} — ${_promotions.length} promotions',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: Espace.md),
            Text(
              'Les promotions seront installées dans '
              '${_campusChoisis.length} campus, dont $avecEtudiants avec '
              'leurs étudiants. Seuls les écarts sont ajoutés : ce qui est '
              'déjà présent reste en place.',
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
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Tout importer'),
          ),
        ],
      ),
    );

    if (valide != true || !mounted) return;

    final messager = ScaffoldMessenger.of(context);
    setState(() {
      _occupe = true;
      _etape = 'Préparation…';
      _progression = 0;
    });

    try {
      final bilan = await MagasinInsam.instance.importerAnnee(
        idAnnee: annee.id,
        campusIds: _campusChoisis,
        sansEtudiants: _sansEtudiants,
        progression: (etape, valeur) {
          if (!mounted) return;
          setState(() {
            _etape = etape;
            _progression = valeur;
          });
        },
      );
      if (!mounted) return;
      messager.showSnackBar(SnackBar(
        content: Text('${bilan.etudiantsAjoutes} étudiants et '
            '${bilan.matieresAjoutees} matières ajoutés sur '
            '${bilan.campusServis} campus.'),
      ));
    } catch (e) {
      if (!mounted) return;
      messager.showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        content: Text('Import impossible : $e'),
      ));
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  // ---------- Interface ----------

  @override
  Widget build(BuildContext context) {
    // L'écran dépend des campus et des données importées : sans écoute,
    // il resterait figé sur l'état qu'il avait à son ouverture.
    return AnimatedBuilder(
      animation: Listenable.merge([
        MagasinCampus.instance,
        MagasinInsam.instance,
      ]),
      builder: (context, _) => _contenu(context),
    );
  }

  Widget _contenu(BuildContext context) {
    final pret = ReferentielInsam.instance.estDisponible;
    _synchroniserCampus();

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EnTetePage(
              titre: 'Import INSAM',
              sousTitre: 'Téléverser un export SQL du système central, puis '
                  'reprendre une année entière avec ses identifiants.',
              actions: [
                OutlinedButton.icon(
                  onPressed: _occupe ? null : _televerser,
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Téléverser un .sql'),
                ),
                if (pret && _promotions.isNotEmpty)
                  FilledButton.icon(
                    // Le bouton reste actif même sans campus coché : il
                    // vaut mieux un message clair qu'un bouton inerte
                    // dont on ne comprend pas le refus.
                    onPressed: _occupe ? null : _importerTout,
                    icon: const Icon(Icons.download_done_outlined, size: 18),
                    label: const Text('Tout importer'),
                  ),
              ],
            ),
            Expanded(child: pret ? _configuration() : _aucunReferentiel()),
          ],
        ),
        if (_occupe)
          _Loader(etape: _etape, progression: _progression),
      ],
    );
  }

  Widget _aucunReferentiel() {
    if (_chargement) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Espace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_upload_outlined,
                size: 44, color: AppColors.texteFaible),
            const SizedBox(height: Espace.md),
            Text('Aucun référentiel',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Espace.xs),
            SizedBox(
              width: 460,
              child: Text(
                'Téléversez un export SQL du système central pour reprendre '
                'ses filières, ses matières et ses étudiants avec leurs '
                'identifiants. C\'est ce qui permettra, une fois les '
                'épreuves corrigées, de produire un fichier de notes '
                'qu\'INSAM importe directement.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _configuration() {
    if (_chargement) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(Espace.xxl, 0, Espace.xxl, Espace.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Explication(),
          const SizedBox(height: Espace.lg),
          _Carte(
            titre: 'Année académique',
            sousTitre: 'Toutes ses promotions seront reprises.',
            enfant: Row(
              children: [
                FiltreDeroulant<int>(
                  etiquette: 'Année',
                  valeur: _anneeId,
                  elements: [
                    for (final a in _annees)
                      DropdownMenuItem(value: a.id, child: Text(a.intitule)),
                  ],
                  onChange: _occupe
                      ? (_) {}
                      : (v) {
                          if (v == null) return;
                          setState(() => _anneeId = v);
                          _chargerPromotions(v);
                        },
                ),
                const SizedBox(width: Espace.lg),
                Text(
                  '${_promotions.length} promotions · '
                  '${_promotions.fold(0, (t, p) => t + p.nombreEtudiants)} '
                  'inscriptions',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: Espace.lg),
          _Carte(
            titre: 'Campus destinataires',
            sousTitre: 'Décochez « avec les étudiants » pour n\'installer '
                'que le programme.',
            enfant: Column(
              children: [
                for (final c in MagasinCampus.instance.campus)
                  _LigneCampus(
                    intitule: c.intitule,
                    choisi: _campusChoisis.contains(c.id),
                    avecEtudiants: !_sansEtudiants.contains(c.id),
                    onChoisi: (v) => setState(() {
                      // Dès le premier décochage, la sélection appartient
                      // à l'utilisateur et n'est plus recalculée.
                      _campusParDefaut = false;
                      v ? _campusChoisis.add(c.id) : _campusChoisis.remove(c.id);
                    }),
                    onEtudiants: (v) => setState(() {
                      v ? _sansEtudiants.remove(c.id) : _sansEtudiants.add(c.id);
                    }),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Voile de chargement : l'import dure, et rien d'autre ne doit être
/// touché pendant ce temps.
class _Loader extends StatelessWidget {
  final String etape;
  final double progression;

  const _Loader({required this.etape, required this.progression});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.35),
        child: Center(
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(Espace.xl),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(rayon),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Import en cours',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: Espace.sm),
                Text(etape,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: Espace.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(rayonPetit),
                  child: LinearProgressIndicator(
                    // Une barre qui n'avance pas ferait croire à un blocage :
                    // tant qu'on ne sait pas, elle reste indéterminée.
                    value: progression <= 0 ? null : progression,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: Espace.sm),
                Text(
                  progression <= 0
                      ? 'Patientez…'
                      : '${(progression * 100).round()} %',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LigneCampus extends StatelessWidget {
  final String intitule;
  final bool choisi;
  final bool avecEtudiants;
  final ValueChanged<bool> onChoisi;
  final ValueChanged<bool> onEtudiants;

  const _LigneCampus({
    required this.intitule,
    required this.choisi,
    required this.avecEtudiants,
    required this.onChoisi,
    required this.onEtudiants,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Espace.xs),
      child: Row(
        children: [
          // Une case simple plutôt qu'un CheckboxListTile : ce dernier
          // peint son fond sur le Material le plus proche, et la carte
          // qui l'entoure masquerait l'effet — Flutter le signale par
          // une assertion à chaque construction.
          SizedBox(
            width: 260,
            child: InkWell(
              onTap: () => onChoisi(!choisi),
              borderRadius: BorderRadius.circular(rayonPetit),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Espace.xs),
                child: Row(
                  children: [
                    Checkbox(
                      value: choisi,
                      onChanged: (v) => onChoisi(v ?? false),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: Espace.xs),
                    Expanded(
                      child: Text(intitule,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: Espace.lg),
          Opacity(
            opacity: choisi ? 1 : 0.4,
            child: Row(
              children: [
                Switch(
                  value: avecEtudiants,
                  onChanged: choisi ? (v) => onEtudiants(v) : null,
                ),
                const SizedBox(width: Espace.sm),
                Text(
                  avecEtudiants
                      ? 'avec les étudiants'
                      : 'programme seul, sans étudiants',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Carte extends StatelessWidget {
  final String titre;
  final String sousTitre;
  final Widget enfant;

  const _Carte({
    required this.titre,
    required this.sousTitre,
    required this.enfant,
  });

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
          Text(titre, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Espace.xs),
          Text(sousTitre, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: Espace.md),
          enfant,
        ],
      ),
    );
  }
}

/// Rappelle à quoi sert l'écran, l'import n'étant pas une opération
/// quotidienne.
class _Explication extends StatelessWidget {
  const _Explication();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Espace.md),
      decoration: BoxDecoration(
        color: AppColors.bleu.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(rayon),
        border: Border.all(color: AppColors.bleu.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.bleu),
          const SizedBox(width: Espace.sm),
          Expanded(
            child: Text(
              'Chaque téléversement remplace le référentiel par la version '
              'du fichier fourni. L\'import ne recrée pas ce qui existe : il '
              'compare et n\'ajoute que les nouveautés, si bien qu\'on peut '
              'le rejouer après chaque export d\'INSAM.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

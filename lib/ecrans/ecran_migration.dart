import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/magasin.dart';
import '../data/modeles.dart';
import '../widgets/communs.dart';

/// Migration : fait passer les étudiants d'une promotion à la suivante.
class EcranMigration extends StatefulWidget {
  const EcranMigration({super.key});

  @override
  State<EcranMigration> createState() => _EcranMigrationState();
}

class _EcranMigrationState extends State<EcranMigration> {
  String? _sourceId;
  String? _cibleId;
  final Set<String> _selection = {};

  @override
  Widget build(BuildContext context) {
    final m = Magasin.instance;
    return AnimatedBuilder(
      animation: m,
      builder: (context, _) {
        // Les promotions retenues ont pu être supprimées entre-temps.
        if (_sourceId != null && m.niveau(_sourceId!) == null) {
          _sourceId = null;
          _cibleId = null;
          _selection.clear();
        }

        final concernes =
            _sourceId == null ? <Etudiant>[] : m.etudiantsDe(_sourceId!);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EnTetePage(
              titre: 'Migration',
              sousTitre:
                  'Faire passer les étudiants d\'une promotion au niveau supérieur.',
            ),
            Expanded(
              child: m.niveaux.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.fromLTRB(
                          Espace.xxl, 0, Espace.xxl, Espace.xxl),
                      child: _AucunNiveau(),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                          Espace.xxl, 0, Espace.xxl, Espace.xxl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _EtapeSource(
                            sourceId: _sourceId,
                            onSource: (v) => setState(() {
                              _sourceId = v;
                              _cibleId =
                                  v == null ? null : m.niveauSuivant(v)?.id;
                              _selection.clear();
                            }),
                          ),
                          if (_sourceId != null) ...[
                            const SizedBox(height: Espace.lg),
                            _EtapeSelection(
                              etudiants: concernes,
                              selection: _selection,
                              onBasculer: (id) => setState(() {
                                _selection.contains(id)
                                    ? _selection.remove(id)
                                    : _selection.add(id);
                              }),
                              onTout: () => setState(() {
                                if (_selection.length == concernes.length) {
                                  _selection.clear();
                                } else {
                                  _selection
                                    ..clear()
                                    ..addAll(concernes.map((e) => e.id));
                                }
                              }),
                            ),
                            const SizedBox(height: Espace.lg),
                            _EtapeDestination(
                              sourceId: _sourceId!,
                              cibleId: _cibleId,
                              nbSelection: _selection.length,
                              onCible: (v) => setState(() => _cibleId = v),
                              onMigrer: () => _confirmer(context),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmer(BuildContext context) async {
    final m = Magasin.instance;
    final source = m.nomNiveau(_sourceId!);
    final cible = m.nomNiveau(_cibleId!);

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Confirmer la migration',
            style: Theme.of(c).textTheme.titleLarge),
        content: Text(
          '${_selection.length} étudiant(s) passeront de '
          '« $source » à « $cible ».',
          style: Theme.of(c).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Migrer'),
          ),
        ],
      ),
    );

    if (ok != true || !context.mounted) return;

    final nb = _selection.length;
    final migre = await executer(
      context,
      () => m.migrer(_selection.toList(), _cibleId!),
      succes: '$nb étudiant(s) migré(s) vers $cible.',
    );
    if (!migre || !mounted) return;

    setState(() {
      _selection.clear();
      _sourceId = null;
      _cibleId = null;
    });
  }
}

/// Carte d'étape numérotée.
class _Etape extends StatelessWidget {
  final int numero;
  final String titre;
  final String description;
  final Widget contenu;

  const _Etape({
    required this.numero,
    required this.titre,
    required this.description,
    required this.contenu,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.bleuPale,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$numero',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.bleuSombre,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              const SizedBox(width: Espace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(titre,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(description,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Espace.lg),
          contenu,
        ],
      ),
    );
  }
}

class _EtapeSource extends StatelessWidget {
  final String? sourceId;
  final ValueChanged<String?> onSource;

  const _EtapeSource({required this.sourceId, required this.onSource});

  @override
  Widget build(BuildContext context) {
    final m = Magasin.instance;
    return _Etape(
      numero: 1,
      titre: 'Promotion de départ',
      description: 'Choisissez la promotion dont les étudiants vont changer de niveau.',
      contenu: Row(
        children: [
          SizedBox(
            width: 340,
            child: SelecteurCherchable<String>(
              etiquette: 'Spécialité et niveau',
              valeur: sourceId,
              options: [
                for (final n in m.niveauxTries)
                  OptionSelecteur(
                    valeur: n.id,
                    libelle: m.nomNiveau(n.id),
                    detail: '${m.effectifNiveau(n.id)} étudiant(s)',
                  ),
              ],
              onChange: onSource,
            ),
          ),
          if (sourceId != null) ...[
            const SizedBox(width: Espace.lg),
            Text('${m.etudiantsDe(sourceId!).length} étudiant(s)',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _EtapeSelection extends StatelessWidget {
  final List<Etudiant> etudiants;
  final Set<String> selection;
  final ValueChanged<String> onBasculer;
  final VoidCallback onTout;

  const _EtapeSelection({
    required this.etudiants,
    required this.selection,
    required this.onBasculer,
    required this.onTout,
  });

  @override
  Widget build(BuildContext context) {
    final tousChoisis =
        etudiants.isNotEmpty && selection.length == etudiants.length;

    return _Etape(
      numero: 2,
      titre: 'Étudiants concernés',
      description: '${selection.length} sélectionné(s) sur ${etudiants.length}.',
      contenu: etudiants.isEmpty
          ? Text('Cette promotion ne compte aucun étudiant.',
              style: Theme.of(context).textTheme.bodySmall)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onTout,
                    icon: Icon(
                      tousChoisis
                          ? Icons.check_box_outlined
                          : Icons.check_box_outline_blank,
                      size: 18,
                    ),
                    label: Text(
                        tousChoisis ? 'Tout désélectionner' : 'Tout sélectionner'),
                  ),
                ),
                const SizedBox(height: Espace.sm),
                Container(
                  constraints: const BoxConstraints(maxHeight: 280),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(rayonPetit),
                    border: Border.all(color: AppColors.bordure),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: etudiants.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final e = etudiants[i];
                      final choisi = selection.contains(e.id);
                      return InkWell(
                        onTap: () => onBasculer(e.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: Espace.md, vertical: Espace.sm),
                          child: Row(
                            children: [
                              Checkbox(
                                value: choisi,
                                onChanged: (_) => onBasculer(e.id),
                                activeColor: AppColors.bleu,
                                visualDensity: VisualDensity.compact,
                              ),
                              const SizedBox(width: Espace.sm),
                              SizedBox(
                                width: 130,
                                child: cellule(e.matricule,
                                    couleur: AppColors.bleuSombre, gras: true),
                              ),
                              Expanded(child: cellule(e.nomComplet)),
                              if (!e.actif) Pastille.neutre('Inactif'),
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

class _EtapeDestination extends StatelessWidget {
  final String sourceId;
  final String? cibleId;
  final int nbSelection;
  final ValueChanged<String?> onCible;
  final VoidCallback onMigrer;

  const _EtapeDestination({
    required this.sourceId,
    required this.cibleId,
    required this.nbSelection,
    required this.onCible,
    required this.onMigrer,
  });

  @override
  Widget build(BuildContext context) {
    final m = Magasin.instance;
    final source = m.niveau(sourceId);
    // On ne propose que les autres promotions de la même spécialité.
    final candidates = source == null
        ? <Niveau>[]
        : m.niveauxDe(source.specialiteId).where((n) => n.id != sourceId).toList();

    final pret = cibleId != null && nbSelection > 0;

    return _Etape(
      numero: 3,
      titre: 'Promotion d\'arrivée',
      description: source?.palier.suivant == null
          ? 'Cette promotion est au dernier palier du cursus.'
          : 'Le niveau supérieur est proposé par défaut.',
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (candidates.isEmpty)
            Text(
              'Aucune autre promotion n\'est ouverte pour cette spécialité. '
              'Ouvrez le niveau supérieur depuis l\'écran « Niveaux ».',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 340,
                  child: SelecteurCherchable<String>(
                    etiquette: 'Niveau d\'arrivée',
                    valeur: cibleId,
                    options: [
                      for (final n in candidates)
                        OptionSelecteur(
                          valeur: n.id,
                          libelle: n.palier.libelleComplet,
                          detail: '${m.effectifNiveau(n.id)} étudiant(s)',
                        ),
                    ],
                    onChange: onCible,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: pret ? onMigrer : null,
                  icon: const Icon(Icons.upgrade, size: 18),
                  label: Text('Migrer $nbSelection étudiant(s)'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AucunNiveau extends StatelessWidget {
  const _AucunNiveau();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(rayon),
        border: Border.all(color: AppColors.bordure),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stairs_outlined,
                size: 32, color: AppColors.texteFaible),
            const SizedBox(height: Espace.md),
            Text('Ouvrez d\'abord un niveau',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Espace.xs),
            Text('La migration déplace les étudiants entre promotions.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

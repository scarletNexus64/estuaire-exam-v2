import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/magasin.dart';
import '../data/modeles.dart';
import '../widgets/communs.dart';

/// Migration : fait passer une promotion au niveau supérieur.
class EcranMigration extends StatefulWidget {
  const EcranMigration({super.key});

  @override
  State<EcranMigration> createState() => _EcranMigrationState();
}

class _EcranMigrationState extends State<EcranMigration> {
  String? _specialiteId;
  String? _niveauSourceId;
  String? _niveauCibleId;
  String? _salleCibleId;
  final Set<String> _selection = {};

  @override
  Widget build(BuildContext context) {
    final m = Magasin.instance;
    return AnimatedBuilder(
      animation: m,
      builder: (context, _) {
        final concernes = (_specialiteId != null && _niveauSourceId != null)
            ? m.etudiantsDe(
                specialiteId: _specialiteId, niveauId: _niveauSourceId)
            : <Etudiant>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EnTetePage(
              titre: 'Migration',
              sousTitre:
                  'Faire passer les étudiants d\'une promotion au niveau supérieur.',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    Espace.xxl, 0, Espace.xxl, Espace.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _EtapeSource(
                      specialiteId: _specialiteId,
                      niveauSourceId: _niveauSourceId,
                      onSpecialite: (v) => setState(() {
                        _specialiteId = v;
                        _selection.clear();
                      }),
                      onNiveau: (v) => setState(() {
                        _niveauSourceId = v;
                        _niveauCibleId =
                            v == null ? null : m.niveauSuivant(v)?.id;
                        _selection.clear();
                      }),
                    ),
                    if (_specialiteId != null && _niveauSourceId != null) ...[
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
                        niveauSourceId: _niveauSourceId!,
                        niveauCibleId: _niveauCibleId,
                        salleCibleId: _salleCibleId,
                        nbSelection: _selection.length,
                        onNiveauCible: (v) =>
                            setState(() => _niveauCibleId = v),
                        onSalleCible: (v) => setState(() => _salleCibleId = v),
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
    final cible = m.niveau(_niveauCibleId!)!;
    final source = m.niveau(_niveauSourceId!)!;

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Confirmer la migration',
            style: Theme.of(c).textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_selection.length} étudiant(s) passeront de '
              '« ${source.intitule} » à « ${cible.intitule} ».',
              style: Theme.of(c).textTheme.bodyMedium,
            ),
            if (_salleCibleId != null) ...[
              const SizedBox(height: Espace.sm),
              Text(
                'Ils seront affectés à ${m.nomSalle(_salleCibleId)}.',
                style: Theme.of(c).textTheme.bodySmall,
              ),
            ],
          ],
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
    m.migrer(_selection.toList(), _niveauCibleId!, _salleCibleId);
    setState(() {
      _selection.clear();
      _niveauSourceId = null;
      _niveauCibleId = null;
      _salleCibleId = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$nb étudiant(s) migré(s) vers ${cible.intitule}.'),
      ),
    );
  }
}

class _Bloc extends StatelessWidget {
  final String numero;
  final String titre;
  final String description;
  final Widget enfant;

  const _Bloc({
    required this.numero,
    required this.titre,
    required this.description,
    required this.enfant,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.rougePale,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  numero,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.rouge,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              const SizedBox(width: Espace.md),
              Text(titre, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: Espace.xs),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Text(description,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(height: Espace.lg),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: enfant,
          ),
        ],
      ),
    );
  }
}

class _EtapeSource extends StatelessWidget {
  final String? specialiteId;
  final String? niveauSourceId;
  final ValueChanged<String?> onSpecialite;
  final ValueChanged<String?> onNiveau;

  const _EtapeSource({
    required this.specialiteId,
    required this.niveauSourceId,
    required this.onSpecialite,
    required this.onNiveau,
  });

  @override
  Widget build(BuildContext context) {
    final m = Magasin.instance;
    return _Bloc(
      numero: '1',
      titre: 'Choisir la promotion',
      description:
          'Sélectionnez la spécialité et le niveau des étudiants à faire progresser.',
      enfant: Row(
        children: [
          FiltreDeroulant<String?>(
            etiquette: 'Spécialité',
            valeur: specialiteId,
            largeur: 260,
            onChange: onSpecialite,
            elements: [
              const DropdownMenuItem(
                  value: null, child: Text('Choisir…')),
              for (final s in m.specialites)
                DropdownMenuItem(value: s.id, child: Text(s.intitule)),
            ],
          ),
          const SizedBox(width: Espace.md),
          FiltreDeroulant<String?>(
            etiquette: 'Niveau actuel',
            valeur: niveauSourceId,
            largeur: 200,
            onChange: onNiveau,
            elements: [
              const DropdownMenuItem(
                  value: null, child: Text('Choisir…')),
              for (final n in m.niveauxTries)
                DropdownMenuItem(value: n.id, child: Text(n.intitule)),
            ],
          ),
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
    final m = Magasin.instance;
    final tousChoisis =
        etudiants.isNotEmpty && selection.length == etudiants.length;

    return _Bloc(
      numero: '2',
      titre: 'Sélectionner les étudiants',
      description: etudiants.isEmpty
          ? 'Aucun étudiant dans cette promotion.'
          : 'Décochez ceux qui redoublent ou ne sont pas admis.',
      enfant: etudiants.isEmpty
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: onTout,
                      icon: Icon(
                        tousChoisis
                            ? Icons.check_box_outlined
                            : Icons.check_box_outline_blank,
                        size: 18,
                      ),
                      label: Text(tousChoisis
                          ? 'Tout décocher'
                          : 'Tout sélectionner'),
                    ),
                    const Spacer(),
                    Text('${selection.length} / ${etudiants.length} retenu(s)',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: Espace.sm),
                Container(
                  constraints: const BoxConstraints(maxHeight: 260),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(rayonPetit),
                    border: Border.all(color: AppColors.bordure),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: etudiants.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
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
                                activeColor: AppColors.rouge,
                                visualDensity: VisualDensity.compact,
                              ),
                              const SizedBox(width: Espace.sm),
                              SizedBox(
                                width: 130,
                                child: Text(
                                  e.matricule,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.bleuSombre,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  e.nomComplet,
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      fontFamily: 'Inter',
                                      color: AppColors.texte),
                                ),
                              ),
                              Text(
                                m.nomSalle(e.salleId),
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.texteDoux,
                                    fontFamily: 'Inter'),
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

class _EtapeDestination extends StatelessWidget {
  final String niveauSourceId;
  final String? niveauCibleId;
  final String? salleCibleId;
  final int nbSelection;
  final ValueChanged<String?> onNiveauCible;
  final ValueChanged<String?> onSalleCible;
  final VoidCallback onMigrer;

  const _EtapeDestination({
    required this.niveauSourceId,
    required this.niveauCibleId,
    required this.salleCibleId,
    required this.nbSelection,
    required this.onNiveauCible,
    required this.onSalleCible,
    required this.onMigrer,
  });

  @override
  Widget build(BuildContext context) {
    final m = Magasin.instance;
    final suivant = m.niveauSuivant(niveauSourceId);
    final pret = niveauCibleId != null && nbSelection > 0;

    return _Bloc(
      numero: '3',
      titre: 'Définir la destination',
      description: suivant == null
          ? 'Ce niveau est le dernier du cursus : choisissez la destination manuellement.'
          : 'Le niveau suivant est proposé par défaut.',
      enfant: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FiltreDeroulant<String?>(
                etiquette: 'Niveau de destination',
                valeur: niveauCibleId,
                largeur: 220,
                onChange: onNiveauCible,
                elements: [
                  const DropdownMenuItem(
                      value: null, child: Text('Choisir…')),
                  for (final n in m.niveauxTries)
                    if (n.id != niveauSourceId)
                      DropdownMenuItem(value: n.id, child: Text(n.intitule)),
                ],
              ),
              const SizedBox(width: Espace.md),
              FiltreDeroulant<String?>(
                etiquette: 'Salle (facultatif)',
                valeur: salleCibleId,
                largeur: 200,
                onChange: onSalleCible,
                elements: [
                  const DropdownMenuItem(
                      value: null, child: Text('Inchangée')),
                  for (final s in m.salles)
                    DropdownMenuItem(value: s.id, child: Text(s.nom)),
                ],
              ),
            ],
          ),
          const SizedBox(height: Espace.xl),
          Row(
            children: [
              FilledButton.icon(
                onPressed: pret ? onMigrer : null,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: Text(nbSelection == 0
                    ? 'Migrer'
                    : 'Migrer $nbSelection étudiant(s)'),
              ),
              const SizedBox(width: Espace.md),
              if (!pret)
                Text(
                  nbSelection == 0
                      ? 'Sélectionnez au moins un étudiant.'
                      : 'Choisissez un niveau de destination.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

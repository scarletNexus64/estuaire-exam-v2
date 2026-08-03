import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/magasin.dart';
import '../data/modeles.dart';
import '../widgets/communs.dart';

class EcranSpecialites extends StatefulWidget {
  const EcranSpecialites({super.key});

  @override
  State<EcranSpecialites> createState() => _EcranSpecialitesState();
}

class _EcranSpecialitesState extends State<EcranSpecialites> {
  String _recherche = '';
  String? _filtreFiliere;

  @override
  Widget build(BuildContext context) {
    final m = Magasin.instance;
    return AnimatedBuilder(
      animation: m,
      builder: (context, _) {
        final liste = m.specialites.where((s) {
          final texte = '${s.code} ${s.intitule} ${s.responsable}'.toLowerCase();
          final okRecherche = texte.contains(_recherche.toLowerCase());
          final okFiliere =
              _filtreFiliere == null || s.filiereId == _filtreFiliere;
          return okRecherche && okFiliere;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EnTetePage(
              titre: 'Spécialités',
              sousTitre:
                  'Parcours de formation rattachés à une filière, avec leur responsable.',
              actions: [
                FilledButton.icon(
                  onPressed: m.filieres.isEmpty
                      ? null
                      : () => _ouvrirFormulaire(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nouvelle spécialité'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Espace.xxl, 0, Espace.xxl, Espace.lg),
              child: Row(
                children: [
                  ChampRecherche(
                    indice: 'Rechercher une spécialité…',
                    onChange: (v) => setState(() => _recherche = v),
                  ),
                  const SizedBox(width: Espace.md),
                  FiltreDeroulant<String?>(
                    etiquette: 'Filière',
                    valeur: _filtreFiliere,
                    onChange: (v) => setState(() => _filtreFiliere = v),
                    elements: [
                      const DropdownMenuItem(
                          value: null, child: Text('Toutes')),
                      for (final f in m.filieres)
                        DropdownMenuItem(
                            value: f.id, child: Text(f.intitule)),
                    ],
                  ),
                  const Spacer(),
                  Text('${liste.length} spécialité(s)',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    Espace.xxl, 0, Espace.xxl, Espace.xxl),
                child: m.filieres.isEmpty
                    ? _MessageAucuneFiliere()
                    : Tableau(
                        colonnes: const [
                          'Code',
                          'Intitulé',
                          'Filière',
                          'Responsable',
                          'Matières',
                          'Effectif',
                          ''
                        ],
                        flex: const [0.9, 2.6, 1.8, 1.8, 1, 1, 1],
                        messageVide: 'Aucune spécialité ne correspond.',
                        lignes: [
                          for (final s in liste)
                            LigneTableau(
                              flex: const [0.9, 2.6, 1.8, 1.8, 1, 1, 1],
                              cellules: [
                                Pastille.rouge(s.code),
                                cellule(s.intitule, gras: true),
                                cellule(m.nomFiliere(s.filiereId),
                                    couleur: AppColors.texteDoux),
                                cellule(s.responsable,
                                    couleur: AppColors.texteDoux),
                                cellule('${m.nbMatieresSpecialite(s.id)}'),
                                cellule('${m.effectifSpecialite(s.id)}'),
                                ActionsLigne(
                                  onModifier: () => _ouvrirFormulaire(context,
                                      specialite: s),
                                  onSupprimer: () => _supprimer(context, s),
                                ),
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

  Future<void> _supprimer(BuildContext context, Specialite s) async {
    final m = Magasin.instance;
    final nb = m.effectifSpecialite(s.id);
    final ok = await confirmerSuppression(
      context,
      titre: 'Supprimer la spécialité ?',
      message: nb > 0
          ? '« ${s.intitule} » compte $nb étudiant(s) inscrit(s).'
          : '« ${s.intitule} » sera définitivement supprimée.',
    );
    if (ok) m.supprimerSpecialite(s.id);
  }

  void _ouvrirFormulaire(BuildContext context, {Specialite? specialite}) {
    final m = Magasin.instance;
    final code = TextEditingController(text: specialite?.code ?? '');
    final intitule = TextEditingController(text: specialite?.intitule ?? '');
    final responsable =
        TextEditingController(text: specialite?.responsable ?? '');
    var filiereId = specialite?.filiereId ?? m.filieres.first.id;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, majEtat) => DialogueFormulaire(
          titre: specialite == null
              ? 'Nouvelle spécialité'
              : 'Modifier la spécialité',
          champs: [
            TextField(
              controller: code,
              decoration: const InputDecoration(
                  labelText: 'Code', hintText: 'GL'),
              textCapitalization: TextCapitalization.characters,
            ),
            TextField(
              controller: intitule,
              decoration: const InputDecoration(
                  labelText: 'Intitulé', hintText: 'Génie Logiciel'),
            ),
            DropdownButtonFormField<String>(
              initialValue: filiereId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Filière'),
              style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.texte,
                  fontFamily: 'Inter'),
              items: [
                for (final f in m.filieres)
                  DropdownMenuItem(value: f.id, child: Text(f.intitule)),
              ],
              onChanged: (v) => majEtat(() => filiereId = v!),
            ),
            TextField(
              controller: responsable,
              decoration: const InputDecoration(
                labelText: 'Responsable de la spécialité',
                hintText: 'M. KUIMO',
              ),
            ),
          ],
          onEnregistrer: () {
            if (code.text.trim().isEmpty || intitule.text.trim().isEmpty) {
              return;
            }
            if (specialite == null) {
              m.ajouterSpecialite(code.text.trim(), intitule.text.trim(),
                  filiereId, responsable.text.trim());
            } else {
              m.majSpecialite(specialite, code.text.trim(),
                  intitule.text.trim(), filiereId, responsable.text.trim());
            }
            Navigator.pop(c);
          },
        ),
      ),
    );
  }
}

class _MessageAucuneFiliere extends StatelessWidget {
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
            const Icon(Icons.account_tree_outlined,
                size: 32, color: AppColors.texteFaible),
            const SizedBox(height: Espace.md),
            Text('Créez d\'abord une filière',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Espace.xs),
            Text('Chaque spécialité doit être rattachée à une filière.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/magasin.dart';
import '../data/modeles.dart';
import '../widgets/communs.dart';

class EcranMatieres extends StatefulWidget {
  const EcranMatieres({super.key});

  @override
  State<EcranMatieres> createState() => _EcranMatieresState();
}

class _EcranMatieresState extends State<EcranMatieres> {
  static const _flex = <double>[1.2, 3, 2.4, 1.2, 1];

  String _recherche = '';
  String? _filtreNiveau;

  @override
  Widget build(BuildContext context) {
    final m = Magasin.instance;
    return AnimatedBuilder(
      animation: m,
      builder: (context, _) {
        // La promotion filtrée a pu être supprimée entre-temps.
        if (_filtreNiveau != null && m.niveau(_filtreNiveau!) == null) {
          _filtreNiveau = null;
        }

        final liste = m.matieres.where((mat) {
          final texte = '${mat.code} ${mat.intitule}'.toLowerCase();
          return texte.contains(_recherche.toLowerCase()) &&
              (_filtreNiveau == null || mat.niveauId == _filtreNiveau);
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EnTetePage(
              titre: 'Matières',
              sousTitre:
                  'Unités d\'enseignement rattachées à une spécialité et un niveau.',
              actions: [
                FilledButton.icon(
                  onPressed: m.niveaux.isEmpty
                      ? null
                      : () => _ouvrirFormulaire(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nouvelle matière'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Espace.xxl, 0, Espace.xxl, Espace.lg),
              child: Row(
                children: [
                  ChampRecherche(
                    indice: 'Rechercher une matière…',
                    onChange: (v) => setState(() => _recherche = v),
                  ),
                  const SizedBox(width: Espace.md),
                  SizedBox(
                    width: 300,
                    child: SelecteurCherchable<String>(
                      etiquette: 'Spécialité et niveau',
                      valeur: _filtreNiveau ?? '',
                      indice: 'Toutes',
                      options: [
                        const OptionSelecteur(valeur: '', libelle: 'Toutes'),
                        for (final n in m.niveauxTries)
                          OptionSelecteur(
                            valeur: n.id,
                            libelle: m.nomNiveau(n.id),
                            detail: n.palier.libelle,
                          ),
                      ],
                      onChange: (v) =>
                          setState(() => _filtreNiveau = v.isEmpty ? null : v),
                    ),
                  ),
                  const Spacer(),
                  Text('${liste.length} matière(s)',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    Espace.xxl, 0, Espace.xxl, Espace.xxl),
                child: m.niveaux.isEmpty
                    ? const _AucunNiveau()
                    : Tableau(
                        colonnes: const [
                          'Code',
                          'Intitulé',
                          'Spécialité',
                          'Niveau',
                          ''
                        ],
                        flex: _flex,
                        messageVide: 'Aucune matière ne correspond.',
                        lignes: [
                          for (final mat in liste)
                            LigneTableau(
                              flex: _flex,
                              cellules: [
                                cellule(mat.code,
                                    couleur: AppColors.bleuSombre, gras: true),
                                cellule(mat.intitule, gras: true),
                                cellule(
                                  m.nomSpecialite(
                                      m.niveau(mat.niveauId)?.specialiteId ??
                                          ''),
                                  couleur: AppColors.texteDoux,
                                ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child:
                                      Pastille.bleue(m.nomPalier(mat.niveauId)),
                                ),
                                ActionsLigne(
                                  onModifier: () =>
                                      _ouvrirFormulaire(context, matiere: mat),
                                  onSupprimer: () => _supprimer(context, mat),
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

  Future<void> _supprimer(BuildContext context, Matiere mat) async {
    final ok = await confirmerSuppression(
      context,
      titre: 'Supprimer la matière ?',
      message: '« ${mat.intitule} » sera définitivement supprimée.',
    );
    if (ok && context.mounted) {
      await executer(context, () => Magasin.instance.supprimerMatiere(mat.id));
    }
  }

  void _ouvrirFormulaire(BuildContext context, {Matiere? matiere}) {
    final m = Magasin.instance;
    final code = TextEditingController(text: matiere?.code ?? '');
    final intitule = TextEditingController(text: matiere?.intitule ?? '');
    var niveauId =
        matiere?.niveauId ?? _filtreNiveau ?? m.niveauxTries.first.id;
    var semestre = matiere?.semestre ?? 1;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, majEtat) => DialogueFormulaire(
          titre: matiere == null ? 'Nouvelle matière' : 'Modifier la matière',
          largeur: 560,
          champs: [
            TextField(
              controller: code,
              decoration: const InputDecoration(
                  labelText: 'Code', hintText: 'RO1234'),
              textCapitalization: TextCapitalization.characters,
            ),
            TextField(
              controller: intitule,
              decoration: const InputDecoration(
                labelText: 'Intitulé',
                hintText: 'Recherche Opérationnelle II',
              ),
            ),
            SelecteurCherchable<String>(
              etiquette: 'Spécialité et niveau',
              valeur: niveauId,
              options: [
                for (final n in m.niveauxTries)
                  OptionSelecteur(
                    valeur: n.id,
                    libelle: m.nomNiveau(n.id),
                    detail: n.palier.libelle,
                  ),
              ],
              onChange: (v) => majEtat(() => niveauId = v),
            ),
            DropdownButtonFormField<int>(
              initialValue: semestre,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Semestre'),
              style: const TextStyle(
                  fontSize: 13.5, color: AppColors.texte, fontFamily: 'Inter'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Semestre 1')),
                DropdownMenuItem(value: 2, child: Text('Semestre 2')),
              ],
              onChanged: (v) => majEtat(() => semestre = v!),
            ),
          ],
          onEnregistrer: () async {
            if (code.text.trim().isEmpty || intitule.text.trim().isEmpty) {
              return;
            }
            final ok = await executer(
              c,
              () => matiere == null
                  ? m.ajouterMatiere(
                      code.text.trim(), intitule.text.trim(), niveauId, semestre)
                  : m.majMatiere(matiere, code.text.trim(),
                      intitule.text.trim(), niveauId, semestre),
            );
            if (ok && c.mounted) Navigator.pop(c);
          },
        ),
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
            Text('Chaque matière est rattachée à une promotion.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

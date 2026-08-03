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
  String _recherche = '';
  String? _filtreSpecialite;
  String? _filtreNiveau;

  @override
  Widget build(BuildContext context) {
    final m = Magasin.instance;
    return AnimatedBuilder(
      animation: m,
      builder: (context, _) {
        final liste = m.matieres.where((mat) {
          final texte = '${mat.code} ${mat.intitule}'.toLowerCase();
          return texte.contains(_recherche.toLowerCase()) &&
              (_filtreSpecialite == null ||
                  mat.specialiteId == _filtreSpecialite) &&
              (_filtreNiveau == null || mat.niveauId == _filtreNiveau);
        }).toList();

        final pretACreer = m.specialites.isNotEmpty && m.niveaux.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EnTetePage(
              titre: 'Matières',
              sousTitre:
                  'Unités d\'enseignement rattachées à une spécialité et un niveau.',
              actions: [
                FilledButton.icon(
                  onPressed:
                      pretACreer ? () => _ouvrirFormulaire(context) : null,
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
                  FiltreDeroulant<String?>(
                    etiquette: 'Spécialité',
                    valeur: _filtreSpecialite,
                    onChange: (v) => setState(() => _filtreSpecialite = v),
                    elements: [
                      const DropdownMenuItem(
                          value: null, child: Text('Toutes')),
                      for (final s in m.specialites)
                        DropdownMenuItem(
                            value: s.id, child: Text(s.intitule)),
                    ],
                  ),
                  const SizedBox(width: Espace.md),
                  FiltreDeroulant<String?>(
                    etiquette: 'Niveau',
                    valeur: _filtreNiveau,
                    largeur: 150,
                    onChange: (v) => setState(() => _filtreNiveau = v),
                    elements: [
                      const DropdownMenuItem(
                          value: null, child: Text('Tous')),
                      for (final n in m.niveauxTries)
                        DropdownMenuItem(
                            value: n.id, child: Text(n.intitule)),
                    ],
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
                child: Tableau(
                  colonnes: const [
                    'Code UE',
                    'Intitulé du module',
                    'Spécialité',
                    'Niveau',
                    'Sem.',
                    'Crédits',
                    ''
                  ],
                  flex: const [1.2, 3, 2, 1.4, 0.8, 0.9, 1],
                  messageVide: 'Aucune matière ne correspond aux filtres.',
                  lignes: [
                    for (final mat in liste)
                      LigneTableau(
                        flex: const [1.2, 3, 2, 1.4, 0.8, 0.9, 1],
                        cellules: [
                          Pastille.bleue(mat.code),
                          cellule(mat.intitule, gras: true),
                          cellule(m.nomSpecialite(mat.specialiteId),
                              couleur: AppColors.texteDoux),
                          cellule(m.nomNiveau(mat.niveauId),
                              couleur: AppColors.texteDoux),
                          cellule('S${mat.semestre}'),
                          cellule('${mat.credits}'),
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
      message:
          '« ${mat.intitule} » (${mat.code}) sera définitivement supprimée.',
    );
    if (ok) Magasin.instance.supprimerMatiere(mat.id);
  }

  void _ouvrirFormulaire(BuildContext context, {Matiere? matiere}) {
    final m = Magasin.instance;
    final code = TextEditingController(text: matiere?.code ?? '');
    final intitule = TextEditingController(text: matiere?.intitule ?? '');
    final credits =
        TextEditingController(text: matiere == null ? '' : '${matiere.credits}');
    var specialiteId = matiere?.specialiteId ?? m.specialites.first.id;
    var niveauId = matiere?.niveauId ?? m.niveauxTries.first.id;
    var semestre = matiere?.semestre ?? 1;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, majEtat) => DialogueFormulaire(
          titre: matiere == null ? 'Nouvelle matière' : 'Modifier la matière',
          champs: [
            TextField(
              controller: code,
              decoration: const InputDecoration(
                  labelText: 'Code UE', hintText: 'RO1234'),
              textCapitalization: TextCapitalization.characters,
            ),
            TextField(
              controller: intitule,
              decoration: const InputDecoration(
                labelText: 'Intitulé du module',
                hintText: 'Recherche Opérationnelle II',
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: specialiteId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Spécialité'),
              style: const TextStyle(
                  fontSize: 13.5, color: AppColors.texte, fontFamily: 'Inter'),
              items: [
                for (final s in m.specialites)
                  DropdownMenuItem(value: s.id, child: Text(s.intitule)),
              ],
              onChanged: (v) => majEtat(() => specialiteId = v!),
            ),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: niveauId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Niveau'),
                    style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.texte,
                        fontFamily: 'Inter'),
                    items: [
                      for (final n in m.niveauxTries)
                        DropdownMenuItem(value: n.id, child: Text(n.intitule)),
                    ],
                    onChanged: (v) => majEtat(() => niveauId = v!),
                  ),
                ),
                const SizedBox(width: Espace.md),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: semestre,
                    decoration: const InputDecoration(labelText: 'Semestre'),
                    style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.texte,
                        fontFamily: 'Inter'),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Semestre 1')),
                      DropdownMenuItem(value: 2, child: Text('Semestre 2')),
                    ],
                    onChanged: (v) => majEtat(() => semestre = v!),
                  ),
                ),
              ],
            ),
            TextField(
              controller: credits,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Crédits', hintText: '4'),
            ),
          ],
          largeur: 540,
          onEnregistrer: () {
            final cr = int.tryParse(credits.text.trim()) ?? 0;
            if (code.text.trim().isEmpty || intitule.text.trim().isEmpty) {
              return;
            }
            if (matiere == null) {
              m.ajouterMatiere(code.text.trim(), intitule.text.trim(),
                  specialiteId, niveauId, semestre, cr);
            } else {
              m.majMatiere(matiere, code.text.trim(), intitule.text.trim(),
                  specialiteId, niveauId, semestre, cr);
            }
            Navigator.pop(c);
          },
        ),
      ),
    );
  }
}

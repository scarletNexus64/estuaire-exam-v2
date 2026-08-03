import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/magasin.dart';
import '../data/modeles.dart';
import '../widgets/communs.dart';

class EcranEtudiants extends StatefulWidget {
  const EcranEtudiants({super.key});

  @override
  State<EcranEtudiants> createState() => _EcranEtudiantsState();
}

class _EcranEtudiantsState extends State<EcranEtudiants> {
  String _recherche = '';
  String? _filtreSpecialite;
  String? _filtreNiveau;

  @override
  Widget build(BuildContext context) {
    final m = Magasin.instance;
    return AnimatedBuilder(
      animation: m,
      builder: (context, _) {
        final liste = m.etudiants.where((e) {
          final texte = '${e.matricule} ${e.nomComplet}'.toLowerCase();
          return texte.contains(_recherche.toLowerCase()) &&
              (_filtreSpecialite == null ||
                  e.specialiteId == _filtreSpecialite) &&
              (_filtreNiveau == null || e.niveauId == _filtreNiveau);
        }).toList()
          ..sort((a, b) => a.nomComplet.compareTo(b.nomComplet));

        final pretACreer = m.specialites.isNotEmpty && m.niveaux.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EnTetePage(
              titre: 'Étudiants',
              sousTitre:
                  'Registre des étudiants. Le matricule sert d\'identifiant lors des épreuves.',
              actions: [
                OutlinedButton.icon(
                  onPressed: () => _messageBientot(context),
                  icon: const Icon(Icons.file_upload_outlined, size: 18),
                  label: const Text('Importer'),
                ),
                FilledButton.icon(
                  onPressed:
                      pretACreer ? () => _ouvrirFormulaire(context) : null,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nouvel étudiant'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Espace.xxl, 0, Espace.xxl, Espace.lg),
              child: Row(
                children: [
                  ChampRecherche(
                    indice: 'Rechercher par nom ou matricule…',
                    largeur: 300,
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
                  Text('${liste.length} étudiant(s)',
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
                    'Matricule',
                    'Noms et prénoms',
                    'Sexe',
                    'Spécialité',
                    'Niveau',
                    'Salle',
                    'État',
                    ''
                  ],
                  flex: const [1.6, 2.6, 0.7, 2, 1.2, 1.4, 1, 1],
                  messageVide: 'Aucun étudiant ne correspond aux filtres.',
                  lignes: [
                    for (final e in liste)
                      LigneTableau(
                        flex: const [1.6, 2.6, 0.7, 2, 1.2, 1.4, 1, 1],
                        cellules: [
                          cellule(e.matricule,
                              couleur: AppColors.bleuSombre, gras: true),
                          cellule(e.nomComplet, gras: true),
                          cellule(e.sexe.code),
                          cellule(m.nomSpecialite(e.specialiteId),
                              couleur: AppColors.texteDoux),
                          cellule(m.nomNiveau(e.niveauId),
                              couleur: AppColors.texteDoux),
                          cellule(m.nomSalle(e.salleId),
                              couleur: AppColors.texteDoux),
                          e.actif
                              ? Pastille.succes('Inscrit')
                              : Pastille.neutre('Inactif'),
                          ActionsLigne(
                            onModifier: () =>
                                _ouvrirFormulaire(context, etudiant: e),
                            onSupprimer: () => _supprimer(context, e),
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

  void _messageBientot(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'L\'import de listes arrivera avec la base de données locale.'),
      ),
    );
  }

  Future<void> _supprimer(BuildContext context, Etudiant e) async {
    final ok = await confirmerSuppression(
      context,
      titre: 'Supprimer l\'étudiant ?',
      message:
          '${e.nomComplet} (${e.matricule}) sera retiré du registre.',
    );
    if (ok) Magasin.instance.supprimerEtudiant(e.id);
  }

  void _ouvrirFormulaire(BuildContext context, {Etudiant? etudiant}) {
    final m = Magasin.instance;
    final matricule = TextEditingController(text: etudiant?.matricule ?? '');
    final nom = TextEditingController(text: etudiant?.nomComplet ?? '');
    var sexe = etudiant?.sexe ?? Sexe.m;
    var specialiteId = etudiant?.specialiteId ?? m.specialites.first.id;
    var niveauId = etudiant?.niveauId ?? m.niveauxTries.first.id;
    String? salleId = etudiant?.salleId;
    var actif = etudiant?.actif ?? true;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, majEtat) => DialogueFormulaire(
          titre:
              etudiant == null ? 'Nouvel étudiant' : 'Modifier l\'étudiant',
          largeur: 560,
          champs: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: matricule,
                    decoration: const InputDecoration(
                      labelText: 'Matricule',
                      hintText: 'IUE26TEST92',
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: Espace.md),
                Expanded(
                  child: DropdownButtonFormField<Sexe>(
                    initialValue: sexe,
                    decoration: const InputDecoration(labelText: 'Sexe'),
                    style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.texte,
                        fontFamily: 'Inter'),
                    items: const [
                      DropdownMenuItem(value: Sexe.m, child: Text('Masculin')),
                      DropdownMenuItem(value: Sexe.f, child: Text('Féminin')),
                    ],
                    onChanged: (v) => majEtat(() => sexe = v!),
                  ),
                ),
              ],
            ),
            TextField(
              controller: nom,
              decoration: const InputDecoration(
                labelText: 'Noms et prénoms',
                hintText: 'Ange Tim',
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
                  child: DropdownButtonFormField<String?>(
                    initialValue: salleId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Salle'),
                    style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.texte,
                        fontFamily: 'Inter'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Non affectée')),
                      for (final s in m.salles)
                        DropdownMenuItem(value: s.id, child: Text(s.nom)),
                    ],
                    onChanged: (v) => majEtat(() => salleId = v),
                  ),
                ),
              ],
            ),
            if (etudiant != null)
              SwitchListTile(
                value: actif,
                onChanged: (v) => majEtat(() => actif = v),
                title: const Text('Étudiant inscrit',
                    style: TextStyle(fontSize: 13.5, fontFamily: 'Inter')),
                subtitle: Text(
                  actif
                      ? 'Peut composer les épreuves.'
                      : 'Exclu des listes d\'épreuve.',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.texteDoux,
                      fontFamily: 'Inter'),
                ),
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.succes,
              ),
          ],
          onEnregistrer: () {
            if (matricule.text.trim().isEmpty || nom.text.trim().isEmpty) {
              return;
            }
            if (etudiant == null) {
              m.ajouterEtudiant(matricule.text.trim(), nom.text.trim(), sexe,
                  specialiteId, niveauId, salleId);
            } else {
              m.majEtudiant(etudiant, matricule.text.trim(), nom.text.trim(),
                  sexe, specialiteId, niveauId, salleId, actif);
            }
            Navigator.pop(c);
          },
        ),
      ),
    );
  }
}

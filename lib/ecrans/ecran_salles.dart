import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/magasin.dart';
import '../data/modeles.dart';
import '../widgets/communs.dart';

class EcranSalles extends StatefulWidget {
  const EcranSalles({super.key});

  @override
  State<EcranSalles> createState() => _EcranSallesState();
}

class _EcranSallesState extends State<EcranSalles> {
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final m = Magasin.instance;
    return AnimatedBuilder(
      animation: m,
      builder: (context, _) {
        final liste = m.salles
            .where((s) =>
                s.nom.toLowerCase().contains(_recherche.toLowerCase()) ||
                s.batiment.toLowerCase().contains(_recherche.toLowerCase()))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EnTetePage(
              titre: 'Salles de classe',
              sousTitre:
                  'Locaux affectés aux groupes d\'étudiants pour les cours et les épreuves.',
              actions: [
                FilledButton.icon(
                  onPressed: () => _ouvrirFormulaire(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nouvelle salle'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Espace.xxl, 0, Espace.xxl, Espace.lg),
              child: Row(
                children: [
                  ChampRecherche(
                    indice: 'Rechercher une salle…',
                    onChange: (v) => setState(() => _recherche = v),
                  ),
                  const Spacer(),
                  Text('${liste.length} salle(s)',
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
                    'Salle',
                    'Bâtiment',
                    'Capacité',
                    'Occupation',
                    ''
                  ],
                  flex: const [2, 2, 1.2, 2, 1],
                  messageVide: 'Aucune salle enregistrée.',
                  lignes: [
                    for (final s in liste)
                      LigneTableau(
                        flex: const [2, 2, 1.2, 2, 1],
                        cellules: [
                          cellule(s.nom, gras: true),
                          cellule(s.batiment,
                              couleur: AppColors.texteDoux),
                          cellule('${s.capacite} places'),
                          _Occupation(
                            occupe: m.etudiants
                                .where((e) => e.salleId == s.id && e.actif)
                                .length,
                            capacite: s.capacite,
                          ),
                          ActionsLigne(
                            onModifier: () =>
                                _ouvrirFormulaire(context, salle: s),
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

  Future<void> _supprimer(BuildContext context, Salle s) async {
    final ok = await confirmerSuppression(
      context,
      titre: 'Supprimer la salle ?',
      message: '« ${s.nom} » sera définitivement supprimée.',
    );
    if (ok) Magasin.instance.supprimerSalle(s.id);
  }

  void _ouvrirFormulaire(BuildContext context, {Salle? salle}) {
    final nom = TextEditingController(text: salle?.nom ?? '');
    final batiment = TextEditingController(text: salle?.batiment ?? '');
    final capacite =
        TextEditingController(text: salle == null ? '' : '${salle.capacite}');

    showDialog(
      context: context,
      builder: (c) => DialogueFormulaire(
        titre: salle == null ? 'Nouvelle salle' : 'Modifier la salle',
        champs: [
          TextField(
            controller: nom,
            decoration: const InputDecoration(
                labelText: 'Nom de la salle', hintText: 'Salle A101'),
          ),
          TextField(
            controller: batiment,
            decoration: const InputDecoration(
                labelText: 'Bâtiment', hintText: 'Bâtiment A'),
          ),
          TextField(
            controller: capacite,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Capacité', hintText: '45'),
          ),
        ],
        onEnregistrer: () {
          final cap = int.tryParse(capacite.text.trim());
          if (nom.text.trim().isEmpty || cap == null) return;
          final m = Magasin.instance;
          if (salle == null) {
            m.ajouterSalle(nom.text.trim(), batiment.text.trim(), cap);
          } else {
            m.majSalle(salle, nom.text.trim(), batiment.text.trim(), cap);
          }
          Navigator.pop(c);
        },
      ),
    );
  }
}

class _Occupation extends StatelessWidget {
  final int occupe;
  final int capacite;

  const _Occupation({required this.occupe, required this.capacite});

  @override
  Widget build(BuildContext context) {
    final ratio = capacite == 0 ? 0.0 : (occupe / capacite).clamp(0.0, 1.0);
    final couleur = ratio > 0.9
        ? AppColors.danger
        : (ratio > 0.7 ? AppColors.alerte : AppColors.succes);

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppColors.bordureDouce,
              valueColor: AlwaysStoppedAnimation(couleur),
            ),
          ),
        ),
        const SizedBox(width: Espace.sm),
        Text('$occupe',
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
                color: AppColors.texteDoux)),
      ],
    );
  }
}

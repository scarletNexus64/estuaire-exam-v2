import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/magasin_campus.dart';
import '../data/parametres.dart';
import '../widgets/communs.dart';

/// Année académique en cours, reportée sur les documents officiels.
///
/// Le campus ne figure pas ici : il est choisi à la connexion.
class EcranEtablissement extends StatefulWidget {
  const EcranEtablissement({super.key});

  @override
  State<EcranEtablissement> createState() => _EcranEtablissementState();
}

class _EcranEtablissementState extends State<EcranEtablissement> {
  final _annee = TextEditingController();
  bool _charge = false;

  @override
  void dispose() {
    _annee.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Parametres.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([p, MagasinCampus.instance]),
      builder: (context, _) {
        // Amorçage unique : ne pas écraser la saisie en cours.
        if (!_charge) {
          _annee.text = p.annee;
          _charge = true;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EnTetePage(
              titre: 'Année académique',
              sousTitre:
                  'Elle apparaît sur les fiches de notes et les listes de présence.',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    Espace.xxl, 0, Espace.xxl, Espace.xxl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(Espace.xl),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(rayon),
                          border: Border.all(color: AppColors.bordure),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _annee,
                              decoration: const InputDecoration(
                                labelText: 'Année académique',
                                hintText: '2025-2026',
                                helperText:
                                    'Format : année de début - année de fin.',
                              ),
                            ),
                            const SizedBox(height: Espace.xl),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton(
                                onPressed: _enregistrer,
                                child: const Text('Enregistrer'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Espace.lg),
                      const _CampusCourant(),
                      const SizedBox(height: Espace.md),
                      const _Rappel(
                        icone: Icons.info_outline,
                        texte:
                            'L\'en-tête officiel (logo et intitulés de '
                            'l\'institut) est intégré aux documents et n\'a '
                            'pas à être saisi.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _enregistrer() async {
    if (_annee.text.trim().isEmpty) return;

    await executer(
      context,
      () => Parametres.instance.definir(Parametres.cleAnnee, _annee.text),
      succes: 'Année académique enregistrée.',
    );
  }
}

/// Campus de la session en cours, lu depuis la sélection faite à la
/// connexion — jamais saisi ni codé en dur.
class _CampusCourant extends StatelessWidget {
  const _CampusCourant();

  @override
  Widget build(BuildContext context) {
    final m = MagasinCampus.instance;
    final actif = m.actif;

    return Container(
      padding: const EdgeInsets.all(Espace.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(rayon),
        border: Border.all(color: AppColors.bordure),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.rouge.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(rayonPetit),
            ),
            child: const Icon(Icons.location_city_outlined,
                size: 19, color: AppColors.rouge),
          ),
          const SizedBox(width: Espace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Campus de travail',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  actif?.intitule ?? 'Aucun campus sélectionné',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (actif != null)
                  Text(m.nomAnnexeDe(actif.id),
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: Espace.md),
          Tooltip(
            message: 'Le campus se choisit à la connexion',
            child: Pastille.neutre('Session'),
          ),
        ],
      ),
    );
  }
}

class _Rappel extends StatelessWidget {
  final IconData icone;
  final String texte;

  const _Rappel({required this.icone, required this.texte});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Espace.lg),
      decoration: BoxDecoration(
        color: AppColors.bleuPale,
        borderRadius: BorderRadius.circular(rayonPetit),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 17, color: AppColors.bleuSombre),
          const SizedBox(width: Espace.md),
          Expanded(
            child:
                Text(texte, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

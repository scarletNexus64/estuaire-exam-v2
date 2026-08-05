import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/magasin.dart';
import '../widgets/communs.dart';

class EcranSynthese extends StatelessWidget {
  const EcranSynthese({super.key});

  @override
  Widget build(BuildContext context) {
    final m = Magasin.instance;
    return AnimatedBuilder(
      animation: m,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EnTetePage(
              titre: 'Synthèse',
              sousTitre:
                  'Vue d\'ensemble de la configuration académique du campus.',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    Espace.xxl, 0, Espace.xxl, Espace.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, contraintes) {
                        final colonnes =
                            contraintes.maxWidth < 720 ? 2 : 4;
                        return GridView.count(
                      crossAxisCount: colonnes,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: Espace.lg,
                      crossAxisSpacing: Espace.lg,
                      childAspectRatio: 2.9,
                      children: [
                        Statistique(
                          valeur: '${m.etudiants.where((e) => e.actif).length}',
                          libelle: 'Étudiants inscrits',
                          icone: Icons.groups_outlined,
                          couleur: AppColors.rouge,
                        ),
                        Statistique(
                          valeur: '${m.specialites.length}',
                          libelle: 'Spécialités',
                          icone: Icons.workspaces_outlined,
                          couleur: AppColors.bleu,
                        ),
                        Statistique(
                          valeur: '${m.matieres.length}',
                          libelle: 'Matières',
                          icone: Icons.menu_book_outlined,
                          couleur: AppColors.succes,
                        ),
                        Statistique(
                          valeur: '${m.niveaux.length}',
                          libelle: 'Niveaux ouverts',
                          icone: Icons.stairs_outlined,
                          couleur: AppColors.alerte,
                        ),
                      ],
                        );
                      },
                    ),
                    const SizedBox(height: Espace.xl),
                    LayoutBuilder(
                      builder: (context, contraintes) {
                        if (contraintes.maxWidth < 720) {
                          return Column(
                            children: [
                              _RepartitionNiveaux(),
                              const SizedBox(height: Espace.lg),
                              _RepartitionSpecialites(),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _RepartitionNiveaux()),
                            const SizedBox(width: Espace.lg),
                            Expanded(child: _RepartitionSpecialites()),
                          ],
                        );
                      },
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
}

class _RepartitionNiveaux extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final m = Magasin.instance;
    final niveaux = m.niveauxTries;
    final total = m.etudiants.where((e) => e.actif).length;

    return _Carte(
      titre: 'Effectifs par niveau',
      enfant: Column(
        children: [
          for (final n in niveaux) ...[
            _Barre(
              etiquette: m.nomNiveau(n.id),
              valeur: m.effectifNiveau(n.id),
              total: total,
              couleur: AppColors.bleu,
            ),
            if (n != niveaux.last) const SizedBox(height: Espace.md),
          ],
        ],
      ),
    );
  }
}

class _RepartitionSpecialites extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final m = Magasin.instance;
    final total = m.etudiants.where((e) => e.actif).length;

    return _Carte(
      titre: 'Effectifs par spécialité',
      enfant: Column(
        children: [
          for (final s in m.specialites) ...[
            _Barre(
              etiquette: s.intitule,
              valeur: m.effectifSpecialite(s.id),
              total: total,
              couleur: AppColors.rouge,
            ),
            if (s != m.specialites.last) const SizedBox(height: Espace.md),
          ],
        ],
      ),
    );
  }
}

class _Carte extends StatelessWidget {
  final String titre;
  final Widget enfant;
  const _Carte({required this.titre, required this.enfant});

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
          Text(titre, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Espace.lg),
          enfant,
        ],
      ),
    );
  }
}

class _Barre extends StatelessWidget {
  final String etiquette;
  final int valeur;
  final int total;
  final Color couleur;

  const _Barre({
    required this.etiquette,
    required this.valeur,
    required this.total,
    required this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : valeur / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(etiquette,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontFamily: 'Inter',
                      color: AppColors.texte)),
            ),
            Text('$valeur',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                  color: AppColors.texte,
                )),
          ],
        ),
        const SizedBox(height: Espace.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: AppColors.bordureDouce,
            valueColor: AlwaysStoppedAnimation(couleur),
          ),
        ),
      ],
    );
  }
}

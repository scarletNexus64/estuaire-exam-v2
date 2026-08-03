import 'package:flutter/material.dart';

import '../ecrans/ecran_etudiants.dart';
import '../ecrans/ecran_filieres.dart';
import '../ecrans/ecran_matieres.dart';
import '../ecrans/ecran_migration.dart';
import '../ecrans/ecran_niveaux.dart';
import '../ecrans/ecran_salles.dart';
import '../ecrans/ecran_specialites.dart';
import '../ecrans/ecran_synthese.dart';
import 'theme.dart';

class RubriqueNav {
  final String titre;
  final IconData icone;
  final Widget page;
  const RubriqueNav(this.titre, this.icone, this.page);
}

class CoquilleAdmin extends StatefulWidget {
  const CoquilleAdmin({super.key});

  @override
  State<CoquilleAdmin> createState() => _CoquilleAdminState();
}

class _CoquilleAdminState extends State<CoquilleAdmin> {
  int _index = 0;

  static const _rubriques = <RubriqueNav>[
    RubriqueNav('Synthèse', Icons.dashboard_outlined, EcranSynthese()),
    RubriqueNav('Étudiants', Icons.groups_outlined, EcranEtudiants()),
    RubriqueNav('Filières', Icons.account_tree_outlined, EcranFilieres()),
    RubriqueNav('Spécialités', Icons.workspaces_outlined, EcranSpecialites()),
    RubriqueNav('Niveaux', Icons.stairs_outlined, EcranNiveaux()),
    RubriqueNav('Salles de classe', Icons.meeting_room_outlined, EcranSalles()),
    RubriqueNav('Matières', Icons.menu_book_outlined, EcranMatieres()),
    RubriqueNav('Migration', Icons.upgrade_outlined, EcranMigration()),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _BarreLaterale(
            rubriques: _rubriques,
            index: _index,
            onChoisir: (i) => setState(() => _index = i),
          ),
          Expanded(
            child: Container(
              color: AppColors.fond,
              child: _rubriques[_index].page,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarreLaterale extends StatelessWidget {
  final List<RubriqueNav> rubriques;
  final int index;
  final ValueChanged<int> onChoisir;

  const _BarreLaterale({
    required this.rubriques,
    required this.index,
    required this.onChoisir,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 236,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.bordure)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Marque(),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Espace.lg, Espace.lg, Espace.lg, Espace.sm),
            child: Text('CONFIGURATION',
                style: Theme.of(context).textTheme.labelSmall),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: Espace.sm),
              itemCount: rubriques.length,
              itemBuilder: (_, i) => _Element(
                rubrique: rubriques[i],
                actif: i == index,
                onTap: () => onChoisir(i),
              ),
            ),
          ),
          const Divider(height: 1),
          const _PiedAdmin(),
        ],
      ),
    );
  }
}

class _Marque extends StatelessWidget {
  const _Marque();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Espace.lg),
      child: Row(
        children: [
          // Marque graphique : toque + livre, reprise du logo.
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.rouge,
              borderRadius: BorderRadius.circular(rayonPetit),
            ),
            child: const Icon(Icons.school, color: Colors.white, size: 20),
          ),
          const SizedBox(width: Espace.md),
          Expanded(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                overflow: TextOverflow.ellipsis,
                text: const TextSpan(
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  children: [
                    TextSpan(
                        text: 'ESTUAIRE ',
                        style: TextStyle(color: AppColors.rouge)),
                    TextSpan(
                        text: 'EXAMEN',
                        style: TextStyle(color: AppColors.bleu)),
                  ],
                ),
              ),
              const SizedBox(height: 1),
              const Text(
                'Administration',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.texteDoux,
                    fontFamily: 'Inter'),
              ),
            ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Element extends StatefulWidget {
  final RubriqueNav rubrique;
  final bool actif;
  final VoidCallback onTap;

  const _Element({
    required this.rubrique,
    required this.actif,
    required this.onTap,
  });

  @override
  State<_Element> createState() => _ElementState();
}

class _ElementState extends State<_Element> {
  bool _survol = false;

  @override
  Widget build(BuildContext context) {
    final actif = widget.actif;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _survol = true),
        onExit: (_) => setState(() => _survol = false),
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(rayonPetit),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(
                horizontal: Espace.md, vertical: Espace.md - 1),
            decoration: BoxDecoration(
              color: actif
                  ? AppColors.rougePale
                  : (_survol ? AppColors.survol : Colors.transparent),
              borderRadius: BorderRadius.circular(rayonPetit),
            ),
            child: Row(
              children: [
                Icon(
                  widget.rubrique.icone,
                  size: 18,
                  color: actif ? AppColors.rouge : AppColors.texteDoux,
                ),
                const SizedBox(width: Espace.md),
                Expanded(
                  child: Text(
                    widget.rubrique.titre,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5,
                      fontWeight: actif ? FontWeight.w600 : FontWeight.w500,
                      color: actif ? AppColors.rouge : AppColors.texte,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PiedAdmin extends StatelessWidget {
  const _PiedAdmin();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Espace.lg),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: AppColors.bleuPale,
            child: const Text(
              'AD',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.bleuSombre,
                fontFamily: 'Inter',
              ),
            ),
          ),
          const SizedBox(width: Espace.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Administrateur',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                    color: AppColors.texte,
                  ),
                ),
                Text(
                  'Campus de Bafoussam',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.texteDoux,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

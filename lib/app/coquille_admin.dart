import 'package:flutter/material.dart';

import '../data/magasin.dart';
import '../data/magasin_campus.dart';
import '../data/magasin_epreuves.dart';
import '../data/magasin_sessions.dart';
import '../data/modeles.dart';
import '../data/session.dart';
import '../ecrans/ecran_assignations.dart';
import '../ecrans/ecran_base.dart';
import '../ecrans/ecran_campus.dart';
import '../ecrans/ecran_comptes.dart';
import '../ecrans/ecran_etablissement.dart';
import '../ecrans/ecran_etudiants.dart';
import '../ecrans/ecran_matieres.dart';
import '../ecrans/ecran_mes_matieres.dart';
import '../ecrans/ecran_import_insam.dart';
import '../ecrans/ecran_migration.dart';
import '../ecrans/ecran_niveaux.dart';
import '../ecrans/ecran_notes.dart';
import '../ecrans/ecran_profil.dart';
import '../ecrans/ecran_specialites.dart';
import '../ecrans/ecran_synthese.dart';
import '../widgets/communs.dart';
import 'theme.dart';

/// Une commande du ruban : mène à un écran.
class RubriqueNav {
  final String titre;
  final IconData icone;
  final Widget page;
  const RubriqueNav(this.titre, this.icone, this.page);
}

/// Groupe de commandes, séparé par un trait dans le ruban.
class GroupeNav {
  final String titre;
  final List<RubriqueNav> rubriques;
  const GroupeNav(this.titre, this.rubriques);
}

/// Onglet du ruban : contient plusieurs groupes.
class OngletNav {
  final String titre;
  final List<GroupeNav> groupes;
  const OngletNav(this.titre, this.groupes);
}

/// Ruban du super administrateur.
const _ongletsAdmin = <OngletNav>[
  OngletNav('Accueil', [
    GroupeNav('Vue d\'ensemble', [
      RubriqueNav('Synthèse', Icons.dashboard_outlined, EcranSynthese()),
    ]),
    GroupeNav('Mon espace', [
      RubriqueNav('Mon compte', Icons.person_outline, EcranProfil()),
    ]),
  ]),
  OngletNav('Académique', [
    GroupeNav('Configuration', [
      RubriqueNav('Spécialités', Icons.workspaces_outlined, EcranSpecialites()),
      RubriqueNav('Niveaux', Icons.stairs_outlined, EcranNiveaux()),
      RubriqueNav('Matières', Icons.menu_book_outlined, EcranMatieres()),
    ]),
    GroupeNav('Scolarité', [
      RubriqueNav('Étudiants', Icons.groups_outlined, EcranEtudiants()),
      RubriqueNav('Migration', Icons.upgrade_outlined, EcranMigration()),
    ]),
    GroupeNav('Système central', [
      RubriqueNav('Import INSAM', Icons.cloud_download_outlined,
          EcranImportInsam()),
    ]),
  ]),
  // Les notes appartiennent à l'enseignant : l'administration se limite
  // à confier les matières.
  OngletNav('Évaluations', [
    GroupeNav('Enseignants', [
      RubriqueNav(
          'Assignations', Icons.assignment_ind_outlined, EcranAssignations()),
    ]),
  ]),
  OngletNav('Système', [
    GroupeNav('Accès', [
      RubriqueNav('Comptes', Icons.manage_accounts_outlined, EcranComptes()),
    ]),
    GroupeNav('Établissement', [
      RubriqueNav('Campus', Icons.location_city_outlined, EcranCampus()),
      RubriqueNav(
          'Année académique', Icons.event_outlined, EcranEtablissement()),
    ]),
    GroupeNav('Données', [
      RubriqueNav('Base de données', Icons.storage_outlined, EcranBase()),
    ]),
  ]),
];

/// Ruban de l'enseignant.
const _ongletsEnseignant = <OngletNav>[
  OngletNav('Accueil', [
    GroupeNav('Enseignement', [
      RubriqueNav('Mes matières', Icons.menu_book_outlined, EcranMesMatieres()),
      RubriqueNav('Notes', Icons.assignment_outlined, EcranNotes()),
    ]),
    GroupeNav('Mon espace', [
      RubriqueNav('Mon compte', Icons.person_outline, EcranProfil()),
    ]),
  ]),
];

class CoquilleAdmin extends StatefulWidget {
  const CoquilleAdmin({super.key});

  @override
  State<CoquilleAdmin> createState() => _CoquilleAdminState();
}

class _CoquilleAdminState extends State<CoquilleAdmin> {
  int _onglet = 0;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final session = Session.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([session, MagasinCampus.instance]),
      builder: (context, _) {
        final onglets =
            session.estSuperAdmin ? _ongletsAdmin : _ongletsEnseignant;

        // Le rôle peut changer entre deux sessions : on borne les index.
        final onglet = _onglet.clamp(0, onglets.length - 1);
        final pages = [
          for (final g in onglets[onglet].groupes) ...g.rubriques,
        ];
        final page = _page.clamp(0, pages.length - 1);

        return Scaffold(
          backgroundColor: AppColors.fond,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _BarreTitre(),
              _Ruban(
                onglets: onglets,
                ongletActif: onglet,
                pageActive: page,
                onOnglet: (i) => setState(() {
                  _onglet = i;
                  // Nouvel onglet : on ouvre sa première commande.
                  _page = 0;
                }),
                onPage: (i) => setState(() => _page = i),
              ),
              Expanded(child: pages[page].page),
            ],
          ),
        );
      },
    );
  }
}

// ---------- Barre de titre ----------

class _BarreTitre extends StatelessWidget {
  const _BarreTitre();

  @override
  Widget build(BuildContext context) {
    final campus = MagasinCampus.instance.actif;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: Espace.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.bordureDouce)),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/embleme.png',
            width: 28,
            height: 28,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(width: Espace.md),
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
              children: [
                TextSpan(
                    text: 'ESTUAIRE ',
                    style: TextStyle(color: AppColors.rouge)),
                TextSpan(text: 'EXAMEN', style: TextStyle(color: AppColors.bleu)),
              ],
            ),
          ),
          const Spacer(),
          if (campus != null) ...[
            const Icon(Icons.location_city_outlined,
                size: 15, color: AppColors.texteDoux),
            const SizedBox(width: Espace.xs + 2),
            Text(
              campus.intitule,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
                color: AppColors.texte,
              ),
            ),
            const SizedBox(width: Espace.lg),
            Container(width: 1, height: 20, color: AppColors.bordure),
            const SizedBox(width: Espace.lg),
          ],
          const _MenuCompte(),
        ],
      ),
    );
  }
}

/// Avatar et menu de l'utilisateur connecté.
class _MenuCompte extends StatelessWidget {
  const _MenuCompte();

  @override
  Widget build(BuildContext context) {
    final utilisateur = Session.instance.courant;
    final admin = utilisateur?.role == Role.superAdmin;

    return PopupMenuButton<String>(
      tooltip: 'Compte',
      position: PopupMenuPosition.under,
      onSelected: (choix) {
        if (choix == 'deconnexion') _deconnecter(context);
        if (choix == 'campus') _changerCampus(context);
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(utilisateur?.nomComplet ?? 'Invité',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                    color: AppColors.texte,
                  )),
              Text(utilisateur?.role.libelle ?? '—',
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontFamily: 'Inter',
                      color: AppColors.texteDoux)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'campus',
          child: Row(
            children: [
              Icon(Icons.swap_horiz, size: 17, color: AppColors.bleu),
              SizedBox(width: Espace.md),
              Text('Changer de campus'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'deconnexion',
          child: Row(
            children: [
              Icon(Icons.logout, size: 17, color: AppColors.danger),
              SizedBox(width: Espace.md),
              Text('Se déconnecter'),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: admin ? AppColors.rougePale : AppColors.bleuPale,
            child: Text(
              utilisateur?.initiales ?? '—',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
                color: admin ? AppColors.rouge : AppColors.bleuSombre,
              ),
            ),
          ),
          const SizedBox(width: Espace.sm),
          Text(
            utilisateur?.nomComplet ?? 'Invité',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter',
              color: AppColors.texte,
            ),
          ),
          const Icon(Icons.arrow_drop_down,
              size: 20, color: AppColors.texteDoux),
        ],
      ),
    );
  }

  /// Bascule vers un autre campus sans fermer la session.
  ///
  /// Tous les magasins sont rechargés : sans cela l'écran continuerait
  /// d'afficher les étudiants du campus précédent.
  Future<void> _changerCampus(BuildContext context) async {
    final m = MagasinCampus.instance;

    final choix = await showDialog<Campus>(
      context: context,
      builder: (c) => _DialogueCampus(actuel: m.actif),
    );
    if (choix == null || choix.id == m.actif?.id || !context.mounted) return;

    final messager = ScaffoldMessenger.of(context);
    try {
      m.choisir(choix);
      await Magasin.instance.charger();
      await MagasinEpreuves.instance.charger();
      await MagasinSessions.instance.charger();

      messager.showSnackBar(
        SnackBar(content: Text('Campus : ${choix.intitule}')),
      );
    } catch (e) {
      messager.showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        content: Text('Changement de campus impossible : $e'),
      ));
    }
  }

  Future<void> _deconnecter(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title:
            Text('Se déconnecter', style: Theme.of(c).textTheme.titleLarge),
        content: Text(
          'Vous allez revenir à l\'écran de connexion.',
          style: Theme.of(c).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      Session.instance.deconnecter();
      MagasinCampus.instance.choisir(null);
    }
  }
}

/// Choix du campus de travail, groupé par annexe.
class _DialogueCampus extends StatelessWidget {
  final Campus? actuel;
  const _DialogueCampus({required this.actuel});

  @override
  Widget build(BuildContext context) {
    final m = MagasinCampus.instance;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Espace.xl, Espace.xl, Espace.xl, Espace.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Changer de campus',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    'Les données affichées seront celles du campus choisi.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: Espace.sm),
                children: [
                  for (final a in m.annexes) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          Espace.xl, Espace.md, Espace.xl, Espace.xs),
                      child: Text(a.intitule.toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall),
                    ),
                    for (final c in m.campusDe(a.id))
                      _LigneChoix(campus: c, actif: c.id == actuel?.id),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(Espace.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LigneChoix extends StatelessWidget {
  final Campus campus;
  final bool actif;

  const _LigneChoix({required this.campus, required this.actif});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pop(context, campus),
      child: Container(
        color: actif ? AppColors.rougePale : Colors.transparent,
        padding: const EdgeInsets.symmetric(
            horizontal: Espace.xl, vertical: Espace.md),
        child: Row(
          children: [
            Icon(Icons.location_city_outlined,
                size: 17,
                color: actif ? AppColors.rouge : AppColors.texteDoux),
            const SizedBox(width: Espace.md),
            Expanded(
              child: Text(
                campus.intitule,
                style: TextStyle(
                  fontSize: 13.5,
                  fontFamily: 'Inter',
                  fontWeight: actif ? FontWeight.w600 : FontWeight.w400,
                  color: actif ? AppColors.rouge : AppColors.texte,
                ),
              ),
            ),
            if (actif) Pastille.succes('Campus courant'),
          ],
        ),
      ),
    );
  }
}

// ---------- Ruban ----------

class _Ruban extends StatelessWidget {
  final List<OngletNav> onglets;
  final int ongletActif;
  final int pageActive;
  final ValueChanged<int> onOnglet;
  final ValueChanged<int> onPage;

  const _Ruban({
    required this.onglets,
    required this.ongletActif,
    required this.pageActive,
    required this.onOnglet,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.bordure)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Rangée d'onglets.
          SizedBox(
            height: 34,
            child: Row(
              children: [
                const SizedBox(width: Espace.md),
                for (var i = 0; i < onglets.length; i++)
                  _Onglet(
                    titre: onglets[i].titre,
                    actif: i == ongletActif,
                    onTap: () => onOnglet(i),
                  ),
              ],
            ),
          ),
          // Commandes de l'onglet courant.
          _Commandes(
            groupes: onglets[ongletActif].groupes,
            pageActive: pageActive,
            onPage: onPage,
          ),
        ],
      ),
    );
  }
}

class _Onglet extends StatefulWidget {
  final String titre;
  final bool actif;
  final VoidCallback onTap;

  const _Onglet({
    required this.titre,
    required this.actif,
    required this.onTap,
  });

  @override
  State<_Onglet> createState() => _OngletState();
}

class _OngletState extends State<_Onglet> {
  bool _survol = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _survol = true),
      onExit: (_) => setState(() => _survol = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Espace.lg),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.actif
                ? AppColors.surface
                : (_survol ? AppColors.survol : Colors.transparent),
            // Le liseré rouge marque l'onglet courant, comme dans Word.
            border: Border(
              bottom: BorderSide(
                color: widget.actif ? AppColors.rouge : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Text(
            widget.titre,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Inter',
              fontWeight: widget.actif ? FontWeight.w700 : FontWeight.w500,
              color: widget.actif ? AppColors.rouge : AppColors.texteDoux,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bande de commandes, groupées et séparées par un trait vertical.
class _Commandes extends StatelessWidget {
  final List<GroupeNav> groupes;
  final int pageActive;
  final ValueChanged<int> onPage;

  const _Commandes({
    required this.groupes,
    required this.pageActive,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context) {
    // Index global de la première commande de chaque groupe.
    final departs = <int>[];
    var cumul = 0;
    for (final g in groupes) {
      departs.add(cumul);
      cumul += g.rubriques.length;
    }

    return Container(
      // Hauteur calée sur la commande la plus haute : icône (22) + libellé
      // sur deux lignes, plus l'intitulé du groupe en dessous.
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: Espace.md),
      decoration: const BoxDecoration(color: AppColors.fond),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var g = 0; g < groupes.length; g++) ...[
              if (g > 0)
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(
                      horizontal: Espace.sm, vertical: Espace.sm),
                  color: AppColors.bordure,
                ),
              _Groupe(
                groupe: groupes[g],
                depart: departs[g],
                pageActive: pageActive,
                onPage: onPage,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Groupe extends StatelessWidget {
  final GroupeNav groupe;
  final int depart;
  final int pageActive;
  final ValueChanged<int> onPage;

  const _Groupe({
    required this.groupe,
    required this.depart,
    required this.pageActive,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: Espace.sm),
        // Expanded : les commandes prennent la place restante après
        // l'intitulé, sans jamais déborder de la bande.
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < groupe.rubriques.length; i++)
                _Commande(
                  rubrique: groupe.rubriques[i],
                  actif: depart + i == pageActive,
                  onTap: () => onPage(depart + i),
                ),
            ],
          ),
        ),
        // Intitulé du groupe, sous ses commandes.
        Padding(
          padding: const EdgeInsets.only(
              top: Espace.xs, bottom: Espace.xs + 2),
          child: Text(
            groupe.titre,
            style: const TextStyle(
              fontSize: 10.5,
              fontFamily: 'Inter',
              color: AppColors.texteFaible,
            ),
          ),
        ),
      ],
    );
  }
}

class _Commande extends StatefulWidget {
  final RubriqueNav rubrique;
  final bool actif;
  final VoidCallback onTap;

  const _Commande({
    required this.rubrique,
    required this.actif,
    required this.onTap,
  });

  @override
  State<_Commande> createState() => _CommandeState();
}

class _CommandeState extends State<_Commande> {
  bool _survol = false;

  @override
  Widget build(BuildContext context) {
    final actif = widget.actif;

    return MouseRegion(
      onEnter: (_) => setState(() => _survol = true),
      onExit: (_) => setState(() => _survol = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          width: 84,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(
              horizontal: Espace.xs, vertical: Espace.xs),
          decoration: BoxDecoration(
            color: actif
                ? AppColors.rougePale
                : (_survol ? AppColors.survol : Colors.transparent),
            borderRadius: BorderRadius.circular(rayonPetit),
            border: Border.all(
              color: actif ? AppColors.rouge.withValues(alpha: 0.35)
                           : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.rubrique.icone,
                size: 22,
                color: actif ? AppColors.rouge : AppColors.texteDoux,
              ),
              const SizedBox(height: Espace.xs + 2),
              // Flexible : un libellé sur deux lignes ne pousse pas la
              // colonne au-delà de la hauteur allouée.
              Flexible(
                child: Text(
                  widget.rubrique.titre,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    fontFamily: 'Inter',
                    fontWeight: actif ? FontWeight.w600 : FontWeight.w500,
                    color: actif ? AppColors.rouge : AppColors.texte,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

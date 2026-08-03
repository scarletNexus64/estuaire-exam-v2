import 'package:flutter/material.dart';

import '../app/theme.dart';

/// En-tête de page : titre, sous-titre, actions à droite.
class EnTetePage extends StatelessWidget {
  final String titre;
  final String sousTitre;
  final List<Widget> actions;

  const EnTetePage({
    super.key,
    required this.titre,
    required this.sousTitre,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Espace.xxl, Espace.xl, Espace.xxl, Espace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: Espace.xs),
                Text(sousTitre, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: Espace.lg),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: Espace.sm),
                  actions[i],
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Carte statistique compacte.
class Statistique extends StatelessWidget {
  final String valeur;
  final String libelle;
  final IconData icone;
  final Color couleur;

  const Statistique({
    super.key,
    required this.valeur,
    required this.libelle,
    required this.icone,
    required this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Espace.lg),
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
              color: couleur.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(rayonPetit),
            ),
            child: Icon(icone, size: 19, color: couleur),
          ),
          const SizedBox(width: Espace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  valeur,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: AppColors.texte,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  libelle,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pastille d'état.
class Pastille extends StatelessWidget {
  final String texte;
  final Color couleur;
  final Color fond;

  const Pastille({
    super.key,
    required this.texte,
    required this.couleur,
    required this.fond,
  });

  factory Pastille.succes(String t) => Pastille(
      texte: t, couleur: AppColors.succes, fond: AppColors.succesPale);
  factory Pastille.neutre(String t) => Pastille(
      texte: t, couleur: AppColors.texteDoux, fond: AppColors.bordureDouce);
  factory Pastille.bleue(String t) =>
      Pastille(texte: t, couleur: AppColors.bleuSombre, fond: AppColors.bleuPale);
  factory Pastille.rouge(String t) =>
      Pastille(texte: t, couleur: AppColors.rouge, fond: AppColors.rougePale);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Espace.sm, vertical: 3),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texte,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: couleur,
        ),
      ),
    );
  }
}

/// Champ de recherche.
class ChampRecherche extends StatelessWidget {
  final String indice;
  final ValueChanged<String> onChange;
  final double largeur;

  const ChampRecherche({
    super.key,
    required this.indice,
    required this.onChange,
    this.largeur = 280,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: largeur,
      child: TextField(
        onChanged: onChange,
        decoration: InputDecoration(
          hintText: indice,
          prefixIcon: const Icon(Icons.search,
              size: 18, color: AppColors.texteFaible),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 38, minHeight: 38),
        ),
      ),
    );
  }
}

/// Menu déroulant de filtre.
class FiltreDeroulant<T> extends StatelessWidget {
  final String etiquette;
  final T? valeur;
  final List<DropdownMenuItem<T>> elements;
  final ValueChanged<T?> onChange;
  final double largeur;

  const FiltreDeroulant({
    super.key,
    required this.etiquette,
    required this.valeur,
    required this.elements,
    required this.onChange,
    this.largeur = 190,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: largeur,
      child: DropdownButtonFormField<T>(
        initialValue: valeur,
        isExpanded: true,
        decoration: InputDecoration(labelText: etiquette),
        style: const TextStyle(
            fontSize: 13.5, color: AppColors.texte, fontFamily: 'Inter'),
        items: elements,
        onChanged: onChange,
      ),
    );
  }
}

/// Conteneur de tableau avec en-tête stylé.
class Tableau extends StatelessWidget {
  final List<String> colonnes;
  final List<double> flex;
  final List<Widget> lignes;
  final String messageVide;

  const Tableau({
    super.key,
    required this.colonnes,
    required this.flex,
    required this.lignes,
    this.messageVide = 'Aucun élément à afficher.',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(rayon),
        border: Border.all(color: AppColors.bordure),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: Espace.lg, vertical: Espace.md),
            decoration: const BoxDecoration(
              color: AppColors.fond,
              border: Border(
                  bottom: BorderSide(color: AppColors.bordure)),
            ),
            child: Row(
              children: [
                for (var i = 0; i < colonnes.length; i++)
                  Expanded(
                    flex: (flex[i] * 10).round(),
                    child: Text(
                      colonnes[i].toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
          ),
          if (lignes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Espace.xxxl),
              child: Column(
                children: [
                  const Icon(Icons.inbox_outlined,
                      size: 32, color: AppColors.texteFaible),
                  const SizedBox(height: Espace.md),
                  Text(messageVide,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: lignes.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) => lignes[i],
              ),
            ),
        ],
      ),
    );
  }
}

/// Ligne de tableau avec survol et actions.
class LigneTableau extends StatefulWidget {
  final List<Widget> cellules;
  final List<double> flex;
  final VoidCallback? onModifier;
  final VoidCallback? onSupprimer;

  const LigneTableau({
    super.key,
    required this.cellules,
    required this.flex,
    this.onModifier,
    this.onSupprimer,
  });

  @override
  State<LigneTableau> createState() => _LigneTableauState();
}

class _LigneTableauState extends State<LigneTableau> {
  bool _survol = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _survol = true),
      onExit: (_) => setState(() => _survol = false),
      child: Container(
        color: _survol ? AppColors.survol : Colors.transparent,
        padding: const EdgeInsets.symmetric(
            horizontal: Espace.lg, vertical: Espace.md),
        child: Row(
          children: [
            for (var i = 0; i < widget.cellules.length; i++)
              Expanded(
                flex: (widget.flex[i] * 10).round(),
                child: widget.cellules[i],
              ),
          ],
        ),
      ),
    );
  }
}

/// Cellule texte standard.
Widget cellule(String texte, {bool gras = false, Color? couleur}) {
  return Text(
    texte,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: 13.5,
      fontWeight: gras ? FontWeight.w600 : FontWeight.w400,
      color: couleur ?? AppColors.texte,
    ),
  );
}

/// Boutons d'action de fin de ligne.
class ActionsLigne extends StatelessWidget {
  final VoidCallback onModifier;
  final VoidCallback onSupprimer;

  const ActionsLigne({
    super.key,
    required this.onModifier,
    required this.onSupprimer,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _bouton(Icons.edit_outlined, 'Modifier', AppColors.bleu, onModifier),
        const SizedBox(width: Espace.xs),
        _bouton(
            Icons.delete_outline, 'Supprimer', AppColors.danger, onSupprimer),
      ],
    );
  }

  Widget _bouton(
      IconData i, String info, Color c, VoidCallback onTap) {
    return Tooltip(
      message: info,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(rayonPetit),
        child: Padding(
          padding: const EdgeInsets.all(Espace.xs + 2),
          child: Icon(i, size: 17, color: c),
        ),
      ),
    );
  }
}

/// Boîte de dialogue de confirmation de suppression.
Future<bool> confirmerSuppression(
  BuildContext context, {
  required String titre,
  required String message,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(titre, style: Theme.of(c).textTheme.titleLarge),
      content: Text(message, style: Theme.of(c).textTheme.bodyMedium),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Squelette de formulaire en boîte de dialogue.
class DialogueFormulaire extends StatelessWidget {
  final String titre;
  final List<Widget> champs;
  final VoidCallback onEnregistrer;
  final double largeur;

  const DialogueFormulaire({
    super.key,
    required this.titre,
    required this.champs,
    required this.onEnregistrer,
    this.largeur = 460,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: largeur),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Espace.xl, Espace.xl, Espace.xl, Espace.lg),
              child: Text(titre,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Espace.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < champs.length; i++) ...[
                      if (i > 0) const SizedBox(height: Espace.lg),
                      champs[i],
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(Espace.xl),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: Espace.sm),
                  FilledButton(
                    onPressed: onEnregistrer,
                    child: const Text('Enregistrer'),
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

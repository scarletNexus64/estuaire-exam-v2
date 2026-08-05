import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'base_locale.dart';
import 'modeles.dart';

/// Annexes, campus, et campus de travail de la session en cours.
///
/// Le campus actif filtre tout ce que l'application affiche : se connecter
/// au Campus A ne doit jamais montrer les étudiants du Campus B.
class MagasinCampus extends ChangeNotifier {
  static final MagasinCampus instance = MagasinCampus._();
  MagasinCampus._();

  Database get _db => BaseLocale.instance.db;

  final List<Annexe> annexes = [];
  final List<Campus> campus = [];

  Campus? _actif;
  Campus? get actif => _actif;

  Future<void> charger() async {
    final lignesAnnexes = await _db.query('annexe', orderBy: 'ordre, intitule');
    final lignesCampus = await _db.query('campus', orderBy: 'ordre, intitule');

    annexes
      ..clear()
      ..addAll(lignesAnnexes.map((l) => Annexe(
            id: l['id'] as String,
            intitule: l['intitule'] as String,
            ordre: l['ordre'] as int,
          )));

    campus
      ..clear()
      ..addAll(lignesCampus.map((l) => Campus(
            id: l['id'] as String,
            annexeId: l['annexe_id'] as String,
            intitule: l['intitule'] as String,
            ordre: l['ordre'] as int,
            entete: l['entete'] as Uint8List?,
          )));

    // Le campus actif a pu être supprimé, ou la base remplacée par un import.
    final id = _actif?.id;
    _actif = id == null ? null : campus.where((c) => c.id == id).firstOrNull;
    notifyListeners();
  }

  // ---------- Lectures ----------

  Annexe? annexe(String id) => annexes.where((a) => a.id == id).firstOrNull;
  Campus? parId(String id) => campus.where((c) => c.id == id).firstOrNull;

  List<Campus> campusDe(String annexeId) =>
      campus.where((c) => c.annexeId == annexeId).toList();

  String nomCampus(String id) => parId(id)?.intitule ?? '—';

  String nomAnnexeDe(String campusId) {
    final c = parId(campusId);
    return c == null ? '—' : (annexe(c.annexeId)?.intitule ?? '—');
  }

  /// Intitulé complet, tel qu'il figure sur les documents officiels.
  String intituleComplet(String campusId) {
    final c = parId(campusId);
    if (c == null) return '—';
    return '${annexe(c.annexeId)?.intitule ?? '—'} — ${c.intitule}';
  }

  /// Campus actif, pour l'en-tête des fiches et listes de présence.
  String get intituleActif =>
      _actif == null ? '—' : intituleComplet(_actif!.id);

  /// Variante pour les PDF : Helvetica, la police par défaut du document,
  /// ne sait pas dessiner le tiret cadratin — il sortirait vide.
  String get intituleActifImprimable =>
      intituleActif.replaceAll('—', '-');

  // ---------- Session de travail ----------

  void choisir(Campus? c) {
    _actif = c;
    notifyListeners();
  }

  // ---------- Écritures ----------

  Future<String> _id(String prefixe, String table) async {
    final r = await _db.rawQuery(
      'SELECT id FROM $table WHERE id LIKE ? ORDER BY id DESC LIMIT 1',
      ['$prefixe%'],
    );
    var suivant = 1;
    if (r.isNotEmpty) {
      final dernier = r.first['id'] as String;
      suivant = (int.tryParse(dernier.substring(prefixe.length)) ?? 0) + 1;
    }
    return '$prefixe${suivant.toString().padLeft(3, '0')}';
  }

  Future<void> ajouterAnnexe(String intitule) async {
    final id = await _id('ANX', 'annexe');
    final ordre = annexes.length + 1;
    await _db.insert('annexe',
        {'id': id, 'intitule': intitule.trim(), 'ordre': ordre});
    annexes.add(Annexe(id: id, intitule: intitule.trim(), ordre: ordre));
    notifyListeners();
  }

  Future<void> majAnnexe(Annexe a, String intitule) async {
    await _db.update('annexe', {'intitule': intitule.trim()},
        where: 'id = ?', whereArgs: [a.id]);
    a.intitule = intitule.trim();
    notifyListeners();
  }

  /// Supprime l'annexe ; SQLite propage aux campus et à leurs données.
  Future<void> supprimerAnnexe(String id) async {
    await _db.delete('annexe', where: 'id = ?', whereArgs: [id]);
    campus.removeWhere((c) => c.annexeId == id);
    annexes.removeWhere((a) => a.id == id);
    if (_actif != null && parId(_actif!.id) == null) _actif = null;
    notifyListeners();
  }

  Future<void> ajouterCampus(String annexeId, String intitule) async {
    final id = await _id('CMP', 'campus');
    final ordre = campusDe(annexeId).length + 1;
    await _db.insert('campus', {
      'id': id,
      'annexe_id': annexeId,
      'intitule': intitule.trim(),
      'ordre': ordre,
    });
    campus.add(Campus(
      id: id,
      annexeId: annexeId,
      intitule: intitule.trim(),
      ordre: ordre,
    ));
    notifyListeners();
  }

  Future<void> majCampus(Campus c, String annexeId, String intitule) async {
    await _db.update(
      'campus',
      {'annexe_id': annexeId, 'intitule': intitule.trim()},
      where: 'id = ?',
      whereArgs: [c.id],
    );
    c.annexeId = annexeId;
    c.intitule = intitule.trim();
    notifyListeners();
  }

  /// Remplace l'en-tête du campus ; `null` revient à l'en-tête générique.
  Future<void> definirEntete(Campus c, Uint8List? image) async {
    await _db.update('campus', {'entete': image},
        where: 'id = ?', whereArgs: [c.id]);
    c.entete = image;
    notifyListeners();
  }

  /// En-tête à imprimer pour un campus : le sien, sinon celui de
  /// l'institut fourni par l'appelant.
  Uint8List? enteteDe(String? campusId) {
    if (campusId == null) return null;
    final c = parId(campusId);
    return c != null && c.aEntete ? c.entete : null;
  }

  /// En-tête du campus de travail.
  Uint8List? get enteteActif => enteteDe(_actif?.id);

  Future<void> supprimerCampus(String id) async {
    await _db.delete('campus', where: 'id = ?', whereArgs: [id]);
    campus.removeWhere((c) => c.id == id);
    if (_actif?.id == id) _actif = null;
    notifyListeners();
  }

  /// Nombre de spécialités rattachées : sert d'avertissement avant
  /// une suppression en cascade.
  Future<int> nbSpecialites(String campusId) async {
    final r = await _db.rawQuery(
        'SELECT COUNT(*) AS n FROM specialite WHERE campus_id = ?',
        [campusId]);
    return (r.first['n'] as int?) ?? 0;
  }
}

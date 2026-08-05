/// Page web servie aux étudiants.
///
/// Volontairement autonome : pas de CDN ni de police distante, le réseau du
/// campus est coupé d'Internet. Tout tient dans ce fichier.
library;

const String pageComposition = r'''
<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<title>Estuaire Examen</title>
<style>
  :root {
    --rouge:#D62027; --rouge-pale:#FDECEC; --bleu:#2E75B6; --bleu-sombre:#1F5A8D;
    --bleu-pale:#EAF2FA; --ardoise:#1C2430; --texte:#16202B; --doux:#5C6B7A;
    --faible:#8A97A5; --bordure:#DCE3EA; --fond:#F5F7FA; --surface:#FFF;
    --succes:#1E8E5A; --succes-pale:#E7F5EE; --alerte:#B7791F;
    --alerte-pale:#FDF4E3; --danger:#C0392B; --danger-pale:#FBEBE9;
  }
  * { box-sizing:border-box; margin:0; padding:0; }
  body {
    font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;
    background:var(--fond); color:var(--texte); font-size:15px; line-height:1.5;
    -webkit-font-smoothing:antialiased;
  }
  /* Empêche la sélection du texte de l'épreuve. */
  .verrou { user-select:none; -webkit-user-select:none; }
  .centre { min-height:100vh; display:flex; align-items:center; justify-content:center; padding:24px; }
  .carte {
    background:var(--surface); border:1px solid var(--bordure); border-radius:10px;
    padding:32px; width:100%; max-width:440px;
  }
  .marque { display:flex; align-items:center; gap:12px; margin-bottom:24px; }
  .entete-campus { width:100%; margin-bottom:16px; }
  .entete-campus img { width:100%; height:auto; display:block; }
  .campus-nom { text-align:center; font-size:12px; color:var(--doux); margin-bottom:18px; }
  .logo-app { display:block; margin:0 auto 18px; max-width:210px; width:60%; height:auto; }
  h1 { font-size:20px; font-weight:700; letter-spacing:-.3px; }
  h2 { font-size:17px; font-weight:600; margin-bottom:4px; }
  .sous { font-size:13px; color:var(--doux); }
  label { display:block; font-size:13px; font-weight:600; margin:16px 0 6px; }
  input[type=text] {
    width:100%; padding:12px; font-size:15px; font-family:inherit;
    border:1px solid var(--bordure); border-radius:6px; background:var(--surface);
  }
  input[type=text]:focus { outline:none; border-color:var(--bleu); border-width:1.6px; }
  .code { text-transform:uppercase; letter-spacing:3px; font-family:monospace; font-size:20px; text-align:center; }
  button {
    width:100%; padding:13px; font-size:15px; font-weight:600; font-family:inherit;
    color:#fff; background:var(--rouge); border:none; border-radius:6px; cursor:pointer;
    margin-top:20px;
  }
  button:disabled { background:var(--faible); cursor:not-allowed; }
  button.secondaire { background:var(--surface); color:var(--texte); border:1px solid var(--bordure); }
  .erreur {
    background:var(--danger-pale); color:var(--danger); padding:12px;
    border-radius:6px; font-size:13px; margin-top:16px; font-weight:500;
  }
  .info { background:var(--bleu-pale); padding:14px; border-radius:6px; font-size:13px; margin-top:16px; }
  .ligne { display:flex; justify-content:space-between; padding:6px 0; font-size:14px; }
  .ligne b { font-weight:600; }

  /* --- Barre de composition --- */
  .barre {
    position:fixed; top:0; left:0; right:0; height:60px; background:var(--surface);
    border-bottom:1px solid var(--bordure); display:flex; align-items:center;
    padding:0 20px; gap:16px; z-index:100;
  }
  .chrono { font-family:monospace; font-size:22px; font-weight:700; color:var(--bleu-sombre); }
  .chrono.urgent { color:var(--danger); }
  .avance { font-size:13px; color:var(--doux); }
  .barre-progression { flex:1; height:6px; background:var(--fond); border-radius:3px; overflow:hidden; max-width:260px; }
  .barre-progression div { height:100%; background:var(--succes); transition:width .3s; }

  main { padding:84px 20px 100px; max-width:780px; margin:0 auto; }
  .question {
    background:var(--surface); border:1px solid var(--bordure); border-radius:10px;
    padding:22px; margin-bottom:16px;
  }
  .question.repondue { border-color:var(--succes); }
  .qtete { display:flex; align-items:center; gap:10px; margin-bottom:14px; }
  .numero {
    width:26px; height:26px; border-radius:50%; background:var(--bleu-pale);
    color:var(--bleu-sombre); display:flex; align-items:center; justify-content:center;
    font-size:12px; font-weight:700; flex-shrink:0;
  }
  .pts { font-size:12px; color:var(--doux); margin-left:auto; white-space:nowrap; }
  .enonce { font-size:15.5px; line-height:1.55; margin-bottom:16px; white-space:pre-wrap; }
  .prop {
    display:flex; align-items:center; gap:12px; padding:12px 14px; margin-bottom:8px;
    border:1px solid var(--bordure); border-radius:8px; cursor:pointer;
    transition:background .12s,border-color .12s;
  }
  .prop:hover { background:var(--fond); }
  .prop.choisie { background:var(--bleu-pale); border-color:var(--bleu); }
  .prop input { width:18px; height:18px; accent-color:var(--bleu); cursor:pointer; flex-shrink:0; }
  select {
    width:100%; padding:12px; font-size:15px; font-family:inherit;
    border:1px solid var(--bordure); border-radius:6px; background:var(--surface);
  }
  .pied {
    position:fixed; bottom:0; left:0; right:0; background:var(--surface);
    border-top:1px solid var(--bordure); padding:14px 20px; display:flex;
    align-items:center; gap:16px; justify-content:center; z-index:100;
  }
  .pied button { width:auto; min-width:200px; margin:0; }
  .etat { font-size:13px; color:var(--doux); }
  .pastille { display:inline-block; padding:3px 10px; border-radius:20px; font-size:12px; font-weight:600; }
  .pastille.ok { background:var(--succes-pale); color:var(--succes); }
  .pastille.att { background:var(--alerte-pale); color:var(--alerte); }

  /* --- Navigation question par question --- */
  .nom-etudiant { margin-left:auto; }
  .grille-questions {
    display:flex; flex-wrap:wrap; gap:8px; justify-content:center;
    margin:22px auto 0; max-width:560px;
  }
  .pastille-q {
    width:38px; height:38px; padding:0; margin:0; border-radius:8px;
    font-size:13px; font-weight:600; font-family:inherit; cursor:pointer;
    background:var(--surface); color:var(--doux);
    border:1px solid var(--bordure); transition:all .12s;
  }
  .pastille-q:hover { border-color:var(--bleu); }
  .pastille-q.faite { background:var(--succes-pale); color:var(--succes);
                      border-color:var(--succes); }
  .pastille-q.courante { border-color:var(--bleu); border-width:2px;
                         color:var(--bleu-sombre); }
  .pastille-q.faite.courante { border-color:var(--bleu); }
  .rappel {
    max-width:560px; margin:18px auto 0; text-align:center;
    font-size:12.5px; color:var(--doux); line-height:1.5;
  }
  .pied button.nav { min-width:150px; }
  .pied button.nav:disabled { opacity:.45; }

  /* Compteur d'avertissements de fraude. */
  .avertissement {
    background:var(--danger-pale); color:var(--danger); padding:10px 14px;
    border-radius:8px; font-size:13px; font-weight:600; margin-top:14px;
  }

  /* --- Salle d'attente --- */
  .attente-carte { text-align:center; }
  .compte-rebours {
    font-family:monospace; font-size:38px; font-weight:700;
    color:var(--bleu-sombre); letter-spacing:2px; margin:14px 0 6px;
  }
  .detente {
    background:var(--bleu-pale); border-radius:8px; padding:20px 16px;
    margin-top:20px; min-height:104px; display:flex; flex-direction:column;
    align-items:center; justify-content:center;
  }
  .detente-texte {
    font-size:14.5px; line-height:1.6; color:var(--texte);
    transition:opacity .5s; font-style:italic;
  }
  .detente-source { font-size:12px; color:var(--doux); margin-top:8px; }
  .detente-genre {
    font-size:10.5px; font-weight:700; letter-spacing:1px;
    text-transform:uppercase; color:var(--bleu); margin-bottom:10px;
  }
  .points { display:flex; gap:6px; justify-content:center; margin-top:14px; }
  .points span {
    width:6px; height:6px; border-radius:50%; background:var(--bordure);
    transition:background .3s;
  }
  .points span.on { background:var(--bleu); }

  /* --- Téléphones : les étudiants composent souvent au mobile --- */
  @media (max-width:640px) {
    body { font-size:16px; }
    .centre { padding:14px; align-items:flex-start; }
    .carte { padding:22px 18px; border-radius:8px; }
    .logo-app { width:74%; max-width:250px; margin-bottom:14px; }
    h1 { font-size:18px; }
    .compte-rebours { font-size:32px; }

    /* Barre repliée en deux lignes : le chrono reste lisible. */
    .barre { height:auto; padding:8px 12px; flex-wrap:wrap; gap:8px 12px; }
    .chrono { font-size:19px; }
    .barre-progression { order:3; flex-basis:100%; max-width:none; }
    .avance { font-size:12px; }
    main { padding:96px 12px 92px; }
    .question { padding:16px 14px; border-radius:8px; }
    .enonce { font-size:15px; }
    /* Cibles tactiles : au moins 44 px de haut. */
    .prop { padding:14px 12px; }
    .prop input { width:22px; height:22px; }
    select, input[type=text] { font-size:16px; padding:14px; }
    .pied { padding:10px 12px; gap:8px; }
    .pied button.nav { min-width:0; flex:1; padding:14px 8px; font-size:14px; }
    .etat { display:none; }
    .pastille-q { width:34px; height:34px; font-size:12px; }
    .grille-questions { gap:6px; margin-top:18px; }
    .etat { font-size:11.5px; }
    .voile-carte { padding:26px 20px; }
  }

  /* Très petits écrans. */
  @media (max-width:380px) {
    .carte { padding:18px 14px; }
    .compte-rebours { font-size:28px; }
    .code { font-size:17px; letter-spacing:2px; }
  }

  /* --- Voile de surveillance --- */
  #voile {
    position:fixed; inset:0; background:rgba(28,36,48,.97); z-index:9999;
    display:none; align-items:center; justify-content:center; padding:24px;
  }
  #voile.actif { display:flex; }
  .voile-carte { background:var(--surface); border-radius:12px; padding:36px; max-width:460px; text-align:center; }
  .voile-carte h2 { color:var(--danger); font-size:19px; margin-bottom:10px; }
  .voile-carte p { font-size:14px; color:var(--doux); margin-bottom:8px; }
  .compteur-alertes { font-size:13px; color:var(--alerte); font-weight:600; margin-top:14px; }
</style>
</head>
<body>
<div id="app"></div>

<div id="voile">
  <div class="voile-carte">
    <h2 id="voile-titre">Épreuve suspendue</h2>
    <p id="voile-message">Vous avez quitté la page d'examen.</p>
    <p class="sous">Votre temps continue de s'écouler. Revenez immédiatement.</p>
    <div class="compteur-alertes" id="voile-compteur"></div>
    <button onclick="reprendre()">Reprendre l'épreuve</button>
  </div>
</div>

<script>
'use strict';

var etat = {
  matricule:null, etudiant:null, epreuve:null, session:null, campus:null,
  avantDebut:0, debutPrevu:null, index:0, seuil:3, jeton:null,
  reponses:{}, restant:0, alertes:0, fini:false, surveille:false
};

var app = document.getElementById('app');
var voile = document.getElementById('voile');

function h(s){ return String(s==null?'':s).replace(/[&<>"']/g, function(c){
  return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]; }); }

function poster(url, corps){
  return fetch(url, {
    method:'POST', headers:{'Content-Type':'application/json'},
    body:JSON.stringify(corps)
  }).then(function(r){ return r.json(); });
}

/* ---------- Écran 1 : identification ---------- */

/* En-tête du campus ; retiré du DOM si le serveur répond 404. */
function bandeauEntete(){
  return '<div class="entete-campus"><img src="/entete.png" alt="" ' +
         'onerror="this.parentNode.style.display=\'none\'"></div>';
}

function vueAccueil(erreur){
  app.innerHTML =
    '<div class="centre"><div class="carte">' +
      bandeauEntete() +
      '<img class="logo-app" src="/logo.png" alt="Estuaire Examen">' +
      '<div style="text-align:center;margin-bottom:20px">' +
        '<div class="sous">Composition en ligne</div></div>' +
      '<label for="code">Code d\'accès de l\'épreuve</label>' +
      '<input type="text" id="code" class="code" maxlength="6" placeholder="ABC123" autocomplete="off">' +
      '<label for="mat">Votre matricule</label>' +
      '<input type="text" id="mat" placeholder="IUE26XXXX" autocomplete="off">' +
      (erreur ? '<div class="erreur">' + h(erreur) + '</div>' : '') +
      '<button onclick="identifier()">Continuer</button>' +
    '</div></div>';
  document.getElementById('code').focus();
  document.getElementById('mat').addEventListener('keydown', function(e){
    if (e.key === 'Enter') identifier();
  });
}

function identifier(){
  var code = document.getElementById('code').value.trim().toUpperCase();
  var mat = document.getElementById('mat').value.trim();
  if (!code || !mat) { vueAccueil('Renseignez le code et votre matricule.'); return; }

  poster('/api/identifier', {code:code, matricule:mat}).then(function(r){
    if (!r.ok) { vueAccueil(r.erreur); return; }
    etat.matricule = mat;
    etat.etudiant = r.etudiant;
    etat.epreuve = r.epreuve;
    etat.campus = r.campus;
    vueConfirmation();
  }).catch(function(){ vueAccueil('Connexion au serveur impossible.'); });
}

/* ---------- Écran 2 : « est-ce bien vous ? » ---------- */

function vueConfirmation(){
  var e = etat.epreuve, et = etat.etudiant;
  app.innerHTML =
    '<div class="centre"><div class="carte">' +
      bandeauEntete() +
      (etat.campus ? '<div class="campus-nom">' + h(etat.campus) + '</div>' : '') +
      '<h2>Est-ce bien vous ?</h2>' +
      '<div class="sous">Vérifiez votre identité avant de commencer.</div>' +
      '<div class="info" style="margin-top:20px">' +
        '<div class="ligne"><span>Nom</span><b>' + h(et.nom) + '</b></div>' +
        '<div class="ligne"><span>Matricule</span><b>' + h(et.matricule) + '</b></div>' +
        '<div class="ligne"><span>Promotion</span><b>' + h(et.promotion) + '</b></div>' +
      '</div>' +
      '<div class="info">' +
        '<div class="ligne"><span>Épreuve</span><b>' + h(e.titre) + '</b></div>' +
        '<div class="ligne"><span>Matière</span><b>' + h(e.matiere) + '</b></div>' +
        '<div class="ligne"><span>Durée</span><b>' + e.duree + ' minutes</b></div>' +
        '<div class="ligne"><span>Questions</span><b>' + e.nbQuestions + '</b></div>' +
      '</div>' +
      (e.consignes ? '<div class="info"><b>Consignes</b><br>' + h(e.consignes) + '</div>' : '') +
      '<div class="info" style="background:var(--alerte-pale)">' +
        '<b>Épreuve surveillée</b><br>' +
        'La page passe en plein écran. Toute sortie, changement d\'onglet ou ' +
        'tentative de copie est enregistrée et transmise à l\'enseignant.' +
      '</div>' +
      '<button onclick="demarrer()">' +
        (e.avantDebut > 0 ? 'C\'est bien moi, patienter' : 'C\'est bien moi, commencer') +
      '</button>' +
      '<button class="secondaire" onclick="vueAccueil()">Ce n\'est pas moi</button>' +
    '</div></div>';
}

/* ---------- Salle d'attente ---------- */

/* Détente avant l'épreuve : de quoi faire baisser la tension. */
var DETENTE = [
  {g:'Citation', t:'L\'éducation est l\'arme la plus puissante que l\'on puisse utiliser pour changer le monde.', s:'Nelson Mandela'},
  {g:'Blague', t:'Pourquoi les étudiants en informatique confondent Halloween et Noël ? Parce que 31 OCT = 25 DEC.', s:''},
  {g:'Conseil', t:'Lisez chaque question deux fois avant de répondre. La précipitation coûte plus de points que l\'ignorance.', s:''},
  {g:'Citation', t:'Le succès, c\'est tomber sept fois et se relever huit.', s:'Proverbe'},
  {g:'Blague', t:'Le professeur : « Cette copie ressemble beaucoup à celle de ton voisin. » L\'étudiant : « Normal, on a le même manuel. »', s:''},
  {g:'Conseil', t:'Commencez par les questions que vous maîtrisez. Vous reviendrez aux autres avec plus de confiance.', s:''},
  {g:'Citation', t:'La chance sourit aux esprits préparés.', s:'Louis Pasteur'},
  {g:'Blague', t:'Un étudiant demande : « Est-ce qu\'on peut échouer à une question qu\'on n\'a pas lue ? » Le professeur : « Oui, et c\'est même la méthode la plus rapide. »', s:''},
  {g:'Conseil', t:'Respirez profondément. Votre cerveau travaille mieux quand il est oxygéné qu\'inquiet.', s:''},
  {g:'Citation', t:'Ce n\'est pas que je suis si intelligent, c\'est que je reste avec les problèmes plus longtemps.', s:'Albert Einstein'},
  {g:'Blague', t:'Pourquoi le livre de mathématiques était-il triste ? Parce qu\'il avait trop de problèmes.', s:''},
  {g:'Conseil', t:'Une réponse laissée vide rapporte zéro à coup sûr. Une réponse réfléchie a toujours une chance.', s:''},
  {g:'Citation', t:'L\'expert en toute chose a un jour été un débutant.', s:'Helen Hayes'},
  {g:'Blague', t:'Le savoir, c\'est comme la confiture : moins on en a, plus on l\'étale. Ce soir, étalez avec modération.', s:''},
  {g:'Conseil', t:'Vérifiez votre matricule avant de commencer : c\'est lui qui rattache votre copie à votre nom.', s:''},
];

var detenteIndex = 0;
var detenteMinuteur = null;
var attenteMinuteur = null;

function vueAttente(){
  app.innerHTML =
    '<div class="centre"><div class="carte attente-carte">' +
      bandeauEntete() +
      '<img class="logo-app" src="/logo.png" alt="Estuaire Examen">' +
      '<h2>' + h(etat.epreuve.titre) + '</h2>' +
      '<div class="sous">' + h(etat.epreuve.matiere) + '</div>' +
      '<div class="sous" style="margin-top:18px">L\'épreuve commence dans</div>' +
      '<div class="compte-rebours" id="rebours">--:--</div>' +
      '<div class="sous" id="debut-prevu"></div>' +
      '<div class="detente" id="detente"></div>' +
      '<div class="points" id="points"></div>' +
      '<button id="btn-commencer" disabled>En attente de l\'ouverture…</button>' +
      '<div class="sous" style="margin-top:14px">' +
        'Gardez cette page ouverte. Le bouton s\'activera automatiquement.' +
      '</div>' +
    '</div></div>';

  document.getElementById('btn-commencer').onclick = function(){
    if (etat.avantDebut <= 0) demarrer();
  };

  afficherDetente();
  majRebours();
  // Les citations défilent toutes les 8 secondes.
  if (detenteMinuteur) clearInterval(detenteMinuteur);
  detenteMinuteur = setInterval(function(){
    detenteIndex = (detenteIndex + 1) % DETENTE.length;
    afficherDetente();
  }, 8000);

  if (attenteMinuteur) clearInterval(attenteMinuteur);
  attenteMinuteur = setInterval(function(){
    etat.avantDebut--;
    majRebours();
  }, 1000);
}

function afficherDetente(){
  var bloc = document.getElementById('detente');
  if (!bloc) return;
  var d = DETENTE[detenteIndex];

  // Fondu : le changement brutal fatigue à la longue.
  bloc.style.opacity = '0';
  setTimeout(function(){
    bloc.innerHTML =
      '<div class="detente-genre">' + h(d.g) + '</div>' +
      '<div class="detente-texte">' + h(d.t) + '</div>' +
      (d.s ? '<div class="detente-source">— ' + h(d.s) + '</div>' : '');
    bloc.style.opacity = '1';
  }, 350);

  var points = document.getElementById('points');
  if (points) {
    var html = '';
    for (var i = 0; i < DETENTE.length; i++) {
      html += '<span class="' + (i === detenteIndex ? 'on' : '') + '"></span>';
    }
    points.innerHTML = html;
  }
}

function majRebours(){
  var el = document.getElementById('rebours');
  var bouton = document.getElementById('btn-commencer');
  if (!el) return;

  if (etat.avantDebut <= 0) {
    // L'heure est venue : le bouton s'active sans intervention.
    el.textContent = 'C\'est parti !';
    el.style.color = 'var(--succes)';
    if (bouton) {
      bouton.disabled = false;
      bouton.textContent = 'Commencer l\'épreuve';
    }
    if (attenteMinuteur) { clearInterval(attenteMinuteur); attenteMinuteur = null; }
    return;
  }

  var s = etat.avantDebut;
  var heures = Math.floor(s / 3600);
  var mm = Math.floor((s % 3600) / 60);
  var ss = s % 60;
  el.textContent = (heures > 0 ? heures + 'h ' : '') +
    (mm < 10 ? '0' : '') + mm + ':' + (ss < 10 ? '0' : '') + ss;

  var prevu = document.getElementById('debut-prevu');
  if (prevu && etat.debutPrevu) {
    var d = new Date(etat.debutPrevu);
    prevu.textContent = 'Ouverture à ' +
      ('0' + d.getHours()).slice(-2) + 'h' + ('0' + d.getMinutes()).slice(-2);
  }
}

function quitterAttente(){
  if (detenteMinuteur) { clearInterval(detenteMinuteur); detenteMinuteur = null; }
  if (attenteMinuteur) { clearInterval(attenteMinuteur); attenteMinuteur = null; }
}

/* ---------- Démarrage ---------- */

function demarrer(){
  poster('/api/demarrer', {code:etat.epreuve.code, matricule:etat.matricule})
    .then(function(r){
      if (!r.ok) { vueAccueil(r.erreur); return; }

      // Pas encore l'heure : salle d'attente plutôt qu'un message d'erreur.
      if (r.attente) {
        etat.avantDebut = r.avantDebut;
        etat.debutPrevu = r.debut;
        vueAttente();
        return;
      }
      quitterAttente();
      etat.session = r.sessionId;
      etat.jeton = r.jeton;
      etat.epreuve.questions = r.questions;
      etat.reponses = r.reponses || {};
      etat.restant = r.restant;
      if (r.soumise) { vueFin(r.note, r.bareme); return; }
      passerPleinEcran();
      activerSurveillance();
      vueComposition();
      lancerChrono();
      lancerBattement();
    });
}

function passerPleinEcran(){
  var el = document.documentElement;
  var demande = el.requestFullscreen || el.webkitRequestFullscreen || el.msRequestFullscreen;
  if (demande) { try { demande.call(el); } catch(e){} }
}

/* ---------- Surveillance ---------- */

function signaler(type, detail){
  if (!etat.surveille || etat.fini) return;
  etat.alertes++;
  poster('/api/incident', {
    sessionId:etat.session, jeton:etat.jeton, type:type, detail:detail||''
  }).then(function(r){
    if (!r) return;
    if (r.seuil) etat.seuil = r.seuil;
    if (r.alertes) etat.alertes = r.alertes;
    // Le serveur a tranché : la copie est annulée.
    if (r.annulee) vueAnnulee();
  }).catch(function(){});
}

/* Copie annulée pour fraude : écran terminal, aucun retour possible. */
function vueAnnulee(){
  etat.fini = true;
  quitterAttente();
  voile.classList.remove('actif');
  document.body.classList.remove('verrou');
  if (document.fullscreenElement && document.exitFullscreen) {
    try { document.exitFullscreen(); } catch(e){}
  }
  app.innerHTML =
    '<div class="centre"><div class="carte" style="text-align:center">' +
      '<div style="font-size:44px">&#9888;</div>' +
      '<h2 style="margin-top:12px;color:var(--danger)">Épreuve annulée</h2>' +
      '<div class="sous">' +
        'Le nombre maximum de tentatives de fraude a été atteint.' +
      '</div>' +
      '<div class="erreur" style="margin-top:20px">' +
        'Votre copie a été remise automatiquement avec la note de 0. ' +
        'L\'enseignant a reçu le détail des incidents.' +
      '</div>' +
      '<div class="sous" style="margin-top:20px">Vous pouvez fermer cette page.</div>' +
    '</div></div>';
}

function afficherVoile(titre, message){
  if (etat.fini) return;
  document.getElementById('voile-titre').textContent = titre;
  document.getElementById('voile-message').textContent = message;

  // L'étudiant doit savoir combien il lui reste avant l'annulation.
  var restantes = Math.max(0, etat.seuil - etat.alertes);
  document.getElementById('voile-compteur').textContent =
    restantes > 0
      ? 'Incident ' + etat.alertes + ' / ' + etat.seuil + ' — ' +
        'encore ' + restantes + ' avant annulation de votre copie'
      : 'Dernier avertissement : votre copie va être annulée';
  voile.classList.add('actif');
}

function reprendre(){
  voile.classList.remove('actif');
  passerPleinEcran();
}

function activerSurveillance(){
  etat.surveille = true;
  document.body.classList.add('verrou');

  // Onglet masqué ou fenêtre en arrière-plan.
  document.addEventListener('visibilitychange', function(){
    if (document.hidden) {
      signaler('onglet', 'page masquée');
      afficherVoile('Épreuve suspendue', 'Vous avez quitté la page d\'examen.');
    }
  });
  window.addEventListener('blur', function(){
    signaler('focus', 'fenêtre en arrière-plan');
    afficherVoile('Fenêtre inactive', 'La fenêtre d\'examen a perdu le focus.');
  });

  // Sortie du plein écran.
  document.addEventListener('fullscreenchange', function(){
    if (!document.fullscreenElement && !etat.fini) {
      signaler('pleinecran', 'sortie du plein écran');
      afficherVoile('Plein écran quitté', 'L\'épreuve doit rester en plein écran.');
    }
  });

  // Curseur hors de la page.
  document.addEventListener('mouseleave', function(){
    signaler('souris', 'curseur hors de la page');
  });

  // Copier / couper / coller et menu contextuel.
  ['copy','cut','paste','contextmenu','dragstart','selectstart'].forEach(function(ev){
    document.addEventListener(ev, function(e){
      e.preventDefault();
      if (ev !== 'selectstart' && ev !== 'dragstart') signaler('copie', ev);
      return false;
    });
  });

  // Raccourcis d'impression, de sauvegarde, d'outils de développement,
  // de changement d'onglet.
  document.addEventListener('keydown', function(e){
    var k = (e.key || '').toLowerCase();
    var meta = e.ctrlKey || e.metaKey;
    var bloque =
      (meta && ['c','v','x','p','s','u','a','f','t','n','w'].indexOf(k) >= 0) ||
      (meta && e.shiftKey && ['i','j','c'].indexOf(k) >= 0) ||
      k === 'f12' ||
      (e.altKey && k === 'tab');
    if (bloque) {
      e.preventDefault();
      signaler('raccourci', (meta ? 'Ctrl/Cmd+' : '') + k);
      return false;
    }
  });

  // Dernier avertissement du navigateur avant fermeture.
  window.addEventListener('beforeunload', function(e){
    if (etat.fini) return;
    signaler('fermeture', 'tentative de fermeture');
    e.preventDefault();
    e.returnValue = '';
    return '';
  });
}

/* ---------- Écran 3 : composition ---------- */

/* Une question à la fois : moins de défilement, surtout au téléphone,
   et l'étudiant se concentre sur une seule chose. */
function vueComposition(){
  app.innerHTML =
    '<div class="barre">' +
      '<span class="chrono" id="chrono">--:--</span>' +
      '<div class="barre-progression"><div id="progression" style="width:0%"></div></div>' +
      '<span class="avance" id="avance"></span>' +
      '<span class="avance nom-etudiant">' + h(etat.etudiant.nom) + '</span>' +
    '</div>' +
    '<main><div id="scene"></div>' + pastilles() + rappel() + '</main>' +
    '<div class="pied" id="pied"></div>';

  afficherQuestion();
}

/* Accès direct à n'importe quelle question : l'étudiant navigue librement. */
function pastilles(){
  return '<div class="grille-questions" id="grille"></div>';
}

function rappel(){
  return '<div class="rappel">' +
    'Vous pouvez revenir en arrière à tout moment. Vos réponses sont ' +
    'enregistrées dès que vous les cochez, même si vous changez de question.' +
    '</div>';
}

function afficherQuestion(){
  var qs = etat.epreuve.questions;
  if (etat.index < 0) etat.index = 0;
  if (etat.index >= qs.length) etat.index = qs.length - 1;

  var q = qs[etat.index];
  document.getElementById('scene').innerHTML =
    rendreQuestion(q, etat.index + 1);

  majPied();
  majGrille();
  majAvancement();
  // Nouvelle question : on remonte, sinon on reste au bas de la précédente.
  window.scrollTo(0, 0);
}

function majPied(){
  var qs = etat.epreuve.questions;
  var premiere = etat.index === 0;
  var derniere = etat.index === qs.length - 1;

  document.getElementById('pied').innerHTML =
    '<button class="secondaire nav" onclick="allerA(' + (etat.index - 1) + ')"' +
      (premiere ? ' disabled' : '') + '>&#8592; Précédente</button>' +
    '<span class="etat" id="etat-sauvegarde">Réponses enregistrées</span>' +
    (derniere
      ? '<button class="nav" onclick="soumettre(false)">Terminer et remettre</button>'
      : '<button class="nav" onclick="allerA(' + (etat.index + 1) + ')">Suivante &#8594;</button>');
}

/* Pastilles numérotées : vert = répondue, contour = question courante. */
function majGrille(){
  var qs = etat.epreuve.questions;
  var html = '';
  for (var i = 0; i < qs.length; i++) {
    var r = etat.reponses[qs[i].id];
    var classes = 'pastille-q';
    if (r && r.length) classes += ' faite';
    if (i === etat.index) classes += ' courante';
    html += '<button class="' + classes + '" onclick="allerA(' + i + ')">' +
            (i + 1) + '</button>';
  }
  document.getElementById('grille').innerHTML = html;
}

function allerA(i){
  etat.index = i;
  afficherQuestion();
}

function rendreQuestion(q, n){
  var choisies = etat.reponses[q.id] || [];
  var html =
    '<div class="question' + (choisies.length ? ' repondue' : '') + '" id="q-' + q.id + '">' +
      '<div class="qtete"><div class="numero">' + n + '</div>' +
      '<span class="sous">' + h(q.typeLibelle) + '</span>' +
      '<span class="pts">' + q.points + ' pt(s)</span></div>' +
      '<div class="enonce">' + h(q.enonce) + '</div>';

  if (q.type === 'listeDeroulante') {
    html += '<select onchange="repondreListe(\'' + q.id + '\', this.value)">' +
            '<option value="">— Choisir une réponse —</option>';
    for (var i = 0; i < q.propositions.length; i++) {
      var p = q.propositions[i];
      var sel = choisies.indexOf(p.id) >= 0 ? ' selected' : '';
      html += '<option value="' + p.id + '"' + sel + '>' + h(p.texte) + '</option>';
    }
    html += '</select>';
  } else {
    var multiple = q.type === 'choixMultiple';
    for (var j = 0; j < q.propositions.length; j++) {
      var pr = q.propositions[j];
      var actif = choisies.indexOf(pr.id) >= 0;
      html +=
        '<label class="prop' + (actif ? ' choisie' : '') + '" for="p-' + pr.id + '">' +
          '<input type="' + (multiple ? 'checkbox' : 'radio') + '"' +
            ' id="p-' + pr.id + '" name="q-' + q.id + '"' +
            (actif ? ' checked' : '') +
            ' onchange="repondreCase(\'' + q.id + '\',\'' + pr.id + '\',' + multiple + ',this.checked)">' +
          '<span>' + h(pr.texte) + '</span>' +
        '</label>';
    }
  }
  return html + '</div>';
}

function repondreCase(questionId, propId, multiple, coche){
  var actuelles = etat.reponses[questionId] || [];
  if (multiple) {
    var i = actuelles.indexOf(propId);
    if (coche && i < 0) actuelles.push(propId);
    if (!coche && i >= 0) actuelles.splice(i, 1);
  } else {
    actuelles = coche ? [propId] : [];
  }
  enregistrer(questionId, actuelles);
}

function repondreListe(questionId, propId){
  enregistrer(questionId, propId ? [propId] : []);
}

function enregistrer(questionId, propositions){
  etat.reponses[questionId] = propositions;

  var bloc = document.getElementById('q-' + questionId);
  if (bloc) bloc.className = 'question' + (propositions.length ? ' repondue' : '');
  // Reflète l'état des cases pour la question courante.
  if (bloc) {
    var entrees = bloc.querySelectorAll('.prop');
    for (var i = 0; i < entrees.length; i++) {
      var input = entrees[i].querySelector('input');
      entrees[i].className = 'prop' + (input && input.checked ? ' choisie' : '');
    }
  }
  majAvancement();
  // La pastille de navigation passe au vert dès la réponse cochée.
  majGrille();

  var etatTexte = document.getElementById('etat-sauvegarde');
  if (etatTexte) etatTexte.textContent = 'Enregistrement…';

  poster('/api/repondre', {
    sessionId:etat.session, jeton:etat.jeton,
    questionId:questionId, propositions:propositions
  }).then(function(){
    if (etatTexte) etatTexte.textContent = 'Réponses enregistrées';
  }).catch(function(){
    if (etatTexte) etatTexte.textContent = 'Hors ligne — nouvelle tentative…';
  });
}

function majAvancement(){
  var total = etat.epreuve.questions.length;
  var faites = 0;
  for (var i = 0; i < etat.epreuve.questions.length; i++) {
    var r = etat.reponses[etat.epreuve.questions[i].id];
    if (r && r.length) faites++;
  }
  var av = document.getElementById('avance');
  var pr = document.getElementById('progression');
  if (av) av.textContent = faites + ' / ' + total + ' répondues';
  if (pr) pr.style.width = (total ? (faites / total) * 100 : 0) + '%';
}

/* ---------- Chronomètre et battement ---------- */

function lancerChrono(){
  majChrono();
  setInterval(function(){
    if (etat.fini) return;
    etat.restant--;
    if (etat.restant <= 0) {
      etat.restant = 0;
      majChrono();
      soumettre(true);
      return;
    }
    majChrono();
  }, 1000);
}

function majChrono(){
  var el = document.getElementById('chrono');
  if (!el) return;
  var s = Math.max(0, etat.restant);
  var mm = Math.floor(s / 60), ss = s % 60;
  el.textContent = (mm < 10 ? '0' : '') + mm + ':' + (ss < 10 ? '0' : '') + ss;
  el.className = 'chrono' + (s <= 300 ? ' urgent' : '');
}

/* Le serveur reste la référence du temps : le battement resynchronise. */
function lancerBattement(){
  setInterval(function(){
    if (etat.fini) return;
    poster('/api/presence', {sessionId:etat.session, jeton:etat.jeton}).then(function(r){
      if (r && typeof r.restant === 'number') etat.restant = r.restant;
      if (r && r.terminee) soumettre(true);
    }).catch(function(){});
  }, 10000);
}

/* ---------- Remise ---------- */

function soumettre(automatique){
  if (etat.fini) return;
  if (!automatique) {
    var total = etat.epreuve.questions.length, faites = 0;
    for (var i = 0; i < etat.epreuve.questions.length; i++) {
      var r = etat.reponses[etat.epreuve.questions[i].id];
      if (r && r.length) faites++;
    }
    var reste = total - faites;
    var message = reste > 0
      ? 'Il reste ' + reste + ' question(s) sans réponse. Remettre quand même ?'
      : 'Remettre votre copie ? Vous ne pourrez plus la modifier.';
    if (!confirm(message)) return;
  }

  etat.fini = true;
  poster('/api/soumettre', {sessionId:etat.session, jeton:etat.jeton}).then(function(r){
    if (document.fullscreenElement && document.exitFullscreen) {
      try { document.exitFullscreen(); } catch(e){}
    }
    vueFin(r.note, r.bareme, automatique);
  });
}

function vueFin(note, bareme, automatique){
  etat.fini = true;
  voile.classList.remove('actif');
  document.body.classList.remove('verrou');
  app.innerHTML =
    '<div class="centre"><div class="carte" style="text-align:center">' +
      '<div style="font-size:44px">✓</div>' +
      '<h2 style="margin-top:12px">Copie remise</h2>' +
      '<div class="sous">' +
        (automatique ? 'Le temps imparti est écoulé.' : 'Votre copie a bien été enregistrée.') +
      '</div>' +
      (note != null
        ? '<div class="info" style="margin-top:20px"><div class="ligne">' +
          '<span>Votre note</span><b>' + note + ' / ' + bareme + '</b></div></div>'
        : '') +
      '<div class="sous" style="margin-top:20px">Vous pouvez fermer cette page.</div>' +
    '</div></div>';
}

vueAccueil();
</script>
</body>
</html>
''';

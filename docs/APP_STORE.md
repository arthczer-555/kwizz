# Fiche App Store - Kwizz

Tout le contenu prêt à coller dans App Store Connect. Langue principale : français.
Les compteurs de caractères respectent les limites Apple.

---

## Identité

- **Nom de l'app** (max 30) : `Kwizz`
  - Si « Kwizz » est déjà pris, replis possibles : `Kwizz - Quiz Culture G` / `Kwizz Quiz`.
- **Sous-titre** (max 30) : `Quiz, duels & défis du jour`
- **Bundle ID** : `com.kwizz.app`
- **Version / build** : `1.0` / `1`
- **Catégorie principale** : Jeux (sous-catégorie : Quiz / Trivia)
- **Catégorie secondaire** : Éducation
- **Copyright** : `© 2026 Arthur Czernichow`

---

## Texte promotionnel (max 170, modifiable sans review)

```
Affronte le monde en duel, grimpe au classement et relève le défi du jour.
Des milliers de questions de culture générale, 7 modes de jeu, zéro pub.
```

## Description (max 4000)

```
Kwizz, c'est la culture générale version arcade : nerveux, élégant, sans fioritures.
Réponds vite, enchaîne les bonnes réponses, fais grimper ton score.

7 MODES DE JEU
- Classique : 15 questions, vise le meilleur score.
- Contre-la-montre : un maximum de bonnes réponses en 60 secondes.
- Survie : une seule erreur et c'est fini.
- Marathon : 30 questions et plus pour les acharnés.
- Libre : sans chrono, pour réviser à ton rythme.
- Duel : affronte un autre joueur en temps réel.
- Défi du jour : la même grille pour tout le monde, une fois par jour.

JOUE EN LIGNE
- Duels en temps réel et mode classé : monte dans le classement.
- Classement mensuel et récompenses.
- Choisis ton pseudo, pas besoin de compte ni d'email.

PROGRESSE
- 20 niveaux à débloquer, une économie de pièces serrée.
- Personnalise ton avatar et la couleur de l'interface.
- Séries quotidiennes, coffres et succès à collectionner.

DES MILLIERS DE QUESTIONS
Cinéma, géographie, histoire, sciences, arts, gastronomie, actualité et bien plus,
en plusieurs niveaux de difficulté.

PROPRE ET RESPECTUEUX
Pas de publicité. Pas de pisteurs. Pas de revente de données.

Télécharge Kwizz et prouve que tu sais (vraiment) des trucs.
```

## Nouveautés de cette version (What's New)

```
Première version de Kwizz. Bon jeu !
```

---

## Mots-clés (champ unique, max 100 caractères, séparés par des virgules)

> Ne pas répéter les mots déjà présents dans le nom et le sous-titre (« quiz », « duel », « défi »).
> Pas d'espaces après les virgules pour économiser des caractères.

```
culture,trivia,questions,savoir,connaissance,classement,arcade,solo,multijoueur,jeu,révision,général
```

(99 caractères. Ajuste librement.)

---

## URLs (obligatoires)

- **URL de support** : `https://arthczer-555.github.io/kwizz-legal/support.html`
- **URL de confidentialité** : `https://arthczer-555.github.io/kwizz-legal/confidentialite.html`
- **URL marketing** (optionnelle) : `https://arthczer-555.github.io/kwizz-legal/`

> Code source : `arthczer-555/kwizz` (privé). Pages légales servies par le repo public
> `arthczer-555/kwizz-legal` via GitHub Pages (déjà en ligne). Les sources des pages
> existent aussi dans `web/` ici ; si tu les modifies, pense à pousser la même version
> dans kwizz-legal pour mettre à jour le site.
> Email de contact en place : `thequikstudio@gmail.com`.

---

## Confidentialité (section « App Privacy » d'App Store Connect)

Réponses à donner dans le questionnaire, cohérentes avec `Resources/PrivacyInfo.xcprivacy` :

**Collectez-vous des données ?** Oui.

**Données utilisées pour vous suivre (Tracking) :** AUCUNE.

**Données liées à l'utilisateur (Linked to You) :**
- **Identifiants → ID utilisateur** (identifiant de compte anonyme + pseudo).
  Finalité : Fonctionnalités de l'app. Suivi : Non.
- **Données d'utilisation → Interaction avec le produit** (scores, parties, classement).
  Finalité : Fonctionnalités de l'app. Suivi : Non.

**Données non liées à l'utilisateur :** aucune à déclarer.

**Note sur l'adresse IP :** collectée automatiquement par l'hébergeur (Supabase) pour le
fonctionnement et la sécurité, non utilisée pour du suivi publicitaire. Apple n'exige pas de la
déclarer si elle sert uniquement au fonctionnement/à la sécurité et n'est pas liée à l'identité.

---

## Classification d'âge (questionnaire)

À remplir honnêtement. Points d'attention pour Kwizz :
- La catégorie de questions « Vins & boissons » peut compter comme **référence à l'alcool**
  (fréquence : peu fréquente/légère).
- Les questions d'actualité/politique restent factuelles.

Résultat probable : **4+ à 13+** selon ce que tu déclares pour l'alcool. Aucune violence, nudité,
jeu d'argent réel, ni contenu généré par les utilisateurs non modéré (hors pseudo).

> Le pseudo est du contenu utilisateur visible publiquement : prévois de pouvoir filtrer/signaler
> les pseudos abusifs (voir checklist), Apple y est attentif.

---

## Conformité à l'export (chiffrement)

Déjà réglé dans le projet : `ITSAppUsesNonExemptEncryption = false` (l'app n'utilise que HTTPS/TLS
standard). Aucune déclaration annuelle de chiffrement requise.

---

## Captures d'écran (obligatoires)

- Taille requise : iPhone 6,9" (1320 x 2868) **ou** 6,5"/6,7". Une taille suffit, Apple adapte.
- Prévoir 3 à 6 visuels : Accueil, une partie en cours, Défi du jour / Duel, Classement, Boutique.
- Générables depuis le simulateur (voir checklist).
- App preview (vidéo) : optionnelle.

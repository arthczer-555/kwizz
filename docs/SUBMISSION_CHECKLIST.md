# Checklist de soumission App Store - Kwizz

Ordre conseillé. Coche au fur et à mesure.

## 0. Bloqueurs techniques (FAITS)
- [x] Icône 1024 sans canal alpha
- [x] `ITSAppUsesNonExemptEncryption = false` dans `Kwizz-Info.plist`
- [x] `Resources/PrivacyInfo.xcprivacy` présent et exact (User ID + interactions)
- [x] L'app compile (BUILD SUCCEEDED) et se lance dans le simulateur

## 1. Compte & identifiants (à confirmer côté Apple)
- [ ] Apple Developer Program payant (99 €/an) actif
- [ ] Bundle ID `com.kwizz.app` enregistré sur developer.apple.com (Identifiers)
- [ ] App créée dans App Store Connect (nom « Kwizz » disponible ?)

## 2. Pages web (URLs obligatoires)
- [x] Politique de confidentialité en ligne (email `thequikstudio@gmail.com` en place)
- [x] Page de support en ligne
- [ ] Renseigner les 2 URLs dans App Store Connect (voir `docs/APP_STORE.md`)

## 3. Décision produit
- [ ] Online (duels, classement, mode classé) activé en v1 ? Si oui :
  - [ ] Politiques RLS Supabase vérifiées (un joueur ne lit/écrit que ses données)
  - [ ] Modération minimale des pseudos (filtre gros mots OU bouton signaler) -> Apple regarde le contenu utilisateur
- [ ] Idéalement : bouton « effacer mes données en ligne » dans Réglages (sinon, suppression par email, déjà documentée)

## 4. Fiche App Store (contenu prêt dans docs/APP_STORE.md)
- [ ] Nom, sous-titre, description, texte promo, mots-clés
- [ ] Catégories (Jeux/Quiz + Éducation)
- [ ] Captures d'écran (3 à 6, format 6,9" ou 6,7")
- [ ] Questionnaire de classification d'âge
- [ ] Section « App Privacy » remplie (cohérente avec le manifest)
- [ ] Copyright, coordonnées

## 5. Build & upload
- [ ] Dans Xcode : sélectionner « Any iOS Device (arm64) »
- [ ] `App/Secrets.xcconfig` présent (il est versionné) pour que l'app online fonctionne en Release
- [ ] `MARKETING_VERSION` supérieur à la dernière version approuvée sur l'App Store
      (sinon : « Invalid Pre-Release Train », le train d'une version publiée est fermé)
- [ ] Product > Archive
- [ ] Organizer > Validate App (c'est ici qu'Apple confirme l'icône, le manifest, etc.)
- [ ] Distribute App > App Store Connect > Upload

## 6. TestFlight (recommandé avant la review)
- [ ] Tester le build sur un vrai iPhone (au moins soi-même en test interne)
- [ ] Vérifier que l'online fonctionne en Release (pas seulement en mock)

## 7. Soumission
- [ ] Associer le build à la version 1.0
- [ ] Répondre aux questions de conformité à l'export (chiffrement : déjà NO)
- [ ] Soumettre pour examen
- [ ] Choisir la mise en vente (automatique ou manuelle après validation)

---

### Commandes utiles

Build de vérif (simulateur) :
```bash
xcodebuild -project Kwizz.xcodeproj -scheme Kwizz \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build
```

Captures d'écran depuis un simulateur booté :
```bash
xcrun simctl boot "iPhone 17 Pro Max"
xcrun simctl install booted /chemin/vers/Kwizz.app
xcrun simctl launch booted com.kwizz.app
xcrun simctl io booted screenshot ~/Desktop/kwizz-01.png
```

# Lecteur vidéo + sous-titres SRT

Lecteur pour s'entraîner à répéter des phrases : il lit une vidéo (.mp4) avec son fichier de sous-titres (.srt) directement dans le navigateur. Les fichiers restent sur l'appareil : rien n'est envoyé sur Internet.

## Fonctions

- **Pause après chaque phrase** : la vidéo s'arrête de 1 à 5 s à la fin de chaque sous-titre, le temps de répéter, puis rejoue la phrase (0 à 5 fois, ou en boucle) ou passe à la suivante.
- **Séquence A-B** : marqueurs de début et de fin sur la barre de temps (boutons, glisser, ou A / B dans la transcription), lecture en boucle, avec une pause avant de reboucler si on le souhaite.
- Lecture / pause, retour au début, phrase précédente / suivante, rejouer la phrase, vitesse de 0,5× à 1,25×.
- Réglages dans un panneau qui s'ouvre avec le bouton ⚙, avec la phrase en cours (transcription) et ses boutons A / B.
- Sous-titres affichés tout en bas de l'image ; option **Masquer le texte anglais incrusté** : un bandeau sombre, réglable en hauteur, cache le texte déjà présent dans l'image.
- **Chargement** : bouton **Vidéo** pour la vidéo, bouton **Sous-titres** pour le fichier .srt, dans l'ordre que vous voulez. Sur ordinateur, on peut aussi glisser les deux fichiers sur la page : le .srt dont le nom commence par celui de la vidéo lui est alors associé (les caractères en plus à la fin, comme `.fr`, sont ignorés).

## Bibliothèque (vidéos publiées avec le site)

Les vidéos rangées dans `media-library/` apparaissent dès le démarrage dans la liste **📚 Bibliothèque** (la dernière regardée, sinon la première, est ouverte) : un choix charge la vidéo et ses sous-titres d'un coup, sur ordinateur (même en ouvrant `index.html` par double-clic) comme sur iPad / iPhone.

Pour la gérer, lancer `ajouter-enlever-videos\gerer-bibliotheque.cmd` :

1. Ouvrir la bibliothèque dans l'Explorateur
2. Ajouter plusieurs vidéos : sélectionner les .mp4, le .srt dont le nom commence par celui de la vidéo (même dossier) est ajouté automatiquement
3. Ajouter une vidéo et choisir son .srt
4. Enlever des vidéos
5. Publier sur GitHub (pour que l'iPad et l'iPhone voient la nouvelle liste)

Chaque vidéo est copiée dans `media-library/pieces/<id>/` avec son .srt et décrite dans `media-library/catalog.json`. GitHub refuse les fichiers de plus de 100 Mo : le script les signale et ne les ajoute pas.

## Utilisation sur iPad / iPhone

1. Ouvrir l'adresse GitHub Pages dans Safari.
2. Bouton Partager → **Sur l'écran d'accueil** : le lecteur s'ouvre ensuite comme une app, en plein écran, et fonctionne même hors ligne.
3. Mettre les vidéos et leurs .srt dans l'app **Fichiers** (iCloud Drive ou « Sur mon iPad »), puis les ouvrir avec les boutons **Vidéo** et **Sous-titres**.

Le volume se règle avec les boutons de l'appareil (iOS ne permet pas de le régler depuis une page web).

## Raccourcis clavier (ordinateur, ou iPad avec clavier)

| Touche | Action |
|---|---|
| Espace | Lecture / pause |
| Début | Retour au début (ou au marqueur A) |
| ← / → | Phrase précédente / suivante |
| R | Rejouer la phrase |
| [ / ] | Placer A / B |
| L | Boucle A-B |
| P | Pause après chaque phrase |
| 1 à 5 | Délai en secondes |
| S | Ouvrir / fermer les réglages |

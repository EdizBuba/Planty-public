# Planty — prototype matériel

Sketch Arduino/ESP32 du projet universitaire Planty. L'application Flutter et
les règles Firebase sont à la racine de ce même dépôt.

Copier `secrets.h.example` en `secrets.h`, puis renseigner exclusivement votre
réseau et vos ressources de test. Le fichier local est ignoré par Git.
Aucune configuration du backend d'origine n'est fournie.

Le firmware utilise notamment WiFi, Firebase ESP Client et AM2302-Sensor.
Il est fourni comme archive pédagogique, sans validation matérielle actuelle.
L'authentification anonyme n'établit pas à elle seule le droit d'accéder à une
plante : prévoir une identité et des autorisations adaptées par appareil.

Les règles Firestore fournies refusent tous les accès clients. Ne les ouvrez
pas globalement pour faire fonctionner ce prototype. Tester dans un environnement
isolé, avec des données fictives, et revoir les sécurités avant de piloter une
pompe réelle. Ne pas connecter le matériel à un ancien service existant.

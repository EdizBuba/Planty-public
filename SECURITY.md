# Sécurité de cette archive

- Utiliser exclusivement ses propres ressources de test et des données fictives.
- Ne jamais versionner de mot de passe, clé privée, configuration personnelle,
  fichier de compte de service ou base issue d'un appareil.
- Les règles Firestore et Realtime Database refusent tous les accès clients.
  Cela ne remplace pas les permissions IAM des SDK administrateur ni la
  sécurisation séparée d'Authentication, Storage et des autres services.
- Les notifications sont désactivées par défaut. Aucun déploiement n'a été fait
  pour publier le code. Un déploiement manuel peut néanmoins créer des ressources
  facturables ; l'activation doit faire l'objet de tests et d'un examen dédié.
- Les audits de dépendances doivent être relancés avant toute utilisation.
  Les tests fournis ne certifient ni la sécurité de production ni celle du matériel.
- Ce dépôt possède son propre historique initial : ne pas y pousser d'ancien
  clone, de branche historique ou de sauvegarde.

En cas de découverte d'un secret, ne pas le recopier dans une issue publique.

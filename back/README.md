# Doctors App Backend - API REST

Backend Node.js pour l'application de prise de rendez-vous médical au Sénégal.

## 🚀 Fonctionnalités

### Authentification
- ✅ Inscription avec numéro de téléphone sénégalais
- ✅ Vérification par SMS (OTP)
- ✅ Connexion sécurisée avec JWT
- ✅ Récupération de mot de passe par SMS
- ✅ Gestion des rôles (Patient, Médecin, Admin)

### Gestion des Utilisateurs
- ✅ Profils patients complets
- ✅ Upgrade Patient → Médecin avec validation
- ✅ Géolocalisation des utilisateurs
- ✅ Préférences de notification

### Médecins
- ✅ Profils médecins détaillés
- ✅ Spécialités et certifications
- ✅ Informations du cabinet médical
- ✅ Horaires de travail
- ✅ Système de validation admin
- ✅ Recherche géographique et par spécialité

### Rendez-vous
- ✅ Création de rendez-vous
- ✅ Gestion des créneaux
- ✅ Notifications SMS automatiques
- ✅ Annulation avec règles métier
- ✅ Système d'évaluation
- ✅ Historique complet

### Administration
- ✅ Dashboard avec statistiques
- ✅ Validation des médecins
- ✅ Gestion des utilisateurs
- ✅ Rapports mensuels
- ✅ Monitoring des rendez-vous

## 🛠️ Stack Technique

- **Runtime**: Node.js
- **Framework**: Express.js
- **Base de données**: MongoDB avec Mongoose
- **Authentification**: JWT + bcrypt
- **SMS**: Twilio (ou service local sénégalais)
- **Validation**: express-validator
- **Sécurité**: helmet, cors, rate-limiting

## 📦 Installation

1. **Cloner le projet**
```bash
cd back
```

2. **Installer les dépendances**
```bash
npm install
```

3. **Configuration**
```bash
cp .env.example .env
# Éditer le fichier .env avec vos configurations
```

4. **Démarrer MongoDB**
```bash
# Assurez-vous que MongoDB est installé et en cours d'exécution
mongod
```

5. **Démarrer le serveur**
```bash
# Mode développement
npm run dev

# Mode production
npm start
```

## 🔧 Configuration

### Variables d'environnement (.env)

```env
# Serveur
PORT=3000
NODE_ENV=development

# Base de données
MONGODB_URI=mongodb://localhost:27017/doctors_app

# JWT
JWT_SECRET=your_super_secret_key
JWT_EXPIRE=7d

# SMS (Twilio)
SMS_SERVICE_SID=your_twilio_sid
SMS_AUTH_TOKEN=your_twilio_token
SMS_FROM_NUMBER=+221xxxxxxxxx

# Admin
ADMIN_EMAIL=admin@doctorsapp.sn
ADMIN_PASSWORD=secure_password
```

### Configuration SMS pour le Sénégal

Pour la production, remplacez Twilio par un service SMS local sénégalais :
- **Orange SMS API**
- **Tigo SMS API**
- **Expresso SMS API**

## 📚 API Documentation

### Authentification
```
POST /api/auth/register        - Inscription
POST /api/auth/verify-phone    - Vérification SMS
POST /api/auth/login           - Connexion
POST /api/auth/forgot-password - Mot de passe oublié
POST /api/auth/reset-password  - Réinitialisation
GET  /api/auth/me             - Profil utilisateur
```

### Médecins
```
POST /api/doctors/upgrade      - Upgrade vers médecin
GET  /api/doctors/search       - Recherche médecins
GET  /api/doctors/:id          - Détails médecin
GET  /api/doctors/:id/availability - Disponibilités
PUT  /api/doctors/profile      - Mise à jour profil
```

### Rendez-vous
```
POST /api/appointments         - Créer rendez-vous
GET  /api/appointments/:id     - Détails rendez-vous
PUT  /api/appointments/:id/cancel - Annuler
PUT  /api/appointments/:id/confirm - Confirmer (médecin)
PUT  /api/appointments/:id/complete - Terminer (médecin)
POST /api/appointments/:id/review - Évaluer (patient)
```

### Administration
```
GET  /api/admin/dashboard      - Statistiques
GET  /api/admin/doctors/pending - Médecins en attente
PUT  /api/admin/doctors/:id/verify - Valider médecin
GET  /api/admin/users          - Liste utilisateurs
GET  /api/admin/appointments   - Liste rendez-vous
```

## 🔐 Sécurité

- **Authentification JWT** avec expiration
- **Hachage bcrypt** des mots de passe
- **Rate limiting** anti-spam
- **Validation** stricte des données
- **CORS** configuré
- **Helmet** pour les headers de sécurité

## 🌍 Spécificités Sénégal

- **Format téléphone**: +221XXXXXXXX
- **Monnaie**: Franc CFA (XOF)
- **Langues**: Français, Wolof, Arabe
- **Géolocalisation**: Optimisée pour Dakar
- **SMS**: Intégration services locaux

## 🚦 Statuts des Rendez-vous

- `pending` - En attente de confirmation
- `confirmed` - Confirmé par le médecin
- `completed` - Consultation terminée
- `cancelled` - Annulé
- `no_show` - Patient absent

## 📱 Notifications SMS

- **Inscription**: Code de vérification
- **RDV créé**: Confirmation automatique
- **RDV confirmé**: Notification patient
- **Rappel**: 24h avant le RDV
- **Annulation**: Notification immédiate

## 🔄 Workflow Médecin

1. **Inscription** comme patient
2. **Upgrade** vers médecin (formulaire complet)
3. **Validation** par l'admin
4. **Activation** du profil médecin
5. **Gestion** des rendez-vous

## 📊 Monitoring

- **Logs** détaillés des erreurs
- **Statistiques** temps réel
- **Métriques** de performance
- **Alertes** automatiques

## 🧪 Tests

```bash
# Lancer les tests
npm test

# Tests avec couverture
npm run test:coverage
```

## 🚀 Déploiement

### Alwaysdata (Production)

1. **Upload** des fichiers
2. **Configuration** des variables d'environnement
3. **Installation** des dépendances
4. **Démarrage** du service

```bash
# Sur Alwaysdata
npm install --production
npm start
```

## 📞 Support

Pour toute question technique :
- **Email**: dev@doctorsapp.sn
- **Documentation**: [API Docs](https://api.doctorsapp.sn/docs)

## 📄 Licence

MIT License - Voir le fichier LICENSE pour plus de détails.

---

**Développé avec ❤️ pour le Sénégal** 🇸🇳

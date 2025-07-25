# 🧪 Guide de Test API - Insomnia/Postman

Guide complet pour tester l'API Doctors App avec Insomnia ou Postman.

## 🚀 Configuration de base

**Base URL**: `http://localhost:3000/api`

### Headers communs
```json
{
  "Content-Type": "application/json",
  "Authorization": "Bearer YOUR_JWT_TOKEN"
}
```

---

## 📋 Workflow de test complet

### 1️⃣ **SANTÉ DE L'API**

#### Health Check
```http
GET http://localhost:3000/api/health
```
**Réponse attendue**: Status 200 avec message "OK"

---

## 🔐 **AUTHENTIFICATION**

### 1. Inscription Patient
```http
POST http://localhost:3000/api/auth/register
Content-Type: application/json

{
  "firstName": "Amadou",
  "lastName": "Diallo",
  "phone": "+221771234567",
  "email": "amadou@example.com",
  "password": "motdepasse123"
}
```

**Réponse**: Token JWT + code de vérification (en mode dev)

### 2. Vérification Téléphone
```http
POST http://localhost:3000/api/auth/verify-phone
Content-Type: application/json
Authorization: Bearer YOUR_TOKEN

{
  "code": "123456"
}
```

### 3. Connexion
```http
POST http://localhost:3000/api/auth/login
Content-Type: application/json

{
  "phone": "+221771234567",
  "password": "motdepasse123"
}
```

### 4. Profil Utilisateur
```http
GET http://localhost:3000/api/auth/me
Authorization: Bearer YOUR_TOKEN
```

### 5. Mot de passe oublié
```http
POST http://localhost:3000/api/auth/forgot-password
Content-Type: application/json

{
  "phone": "+221771234567"
}


### 6. Réinitialiser mot de passe
```http
POST http://localhost:3000/api/auth/reset-password
Content-Type: application/json

{
  "phone": "+221771234567",
  "code": "123456",
  "newPassword": "nouveaumotdepasse123"
}
```

---

## 👨‍⚕️ **MÉDECINS**

### 1. Upgrade Patient → Médecin
```http
POST http://localhost:3000/api/doctors/upgrade
Content-Type: application/json
Authorization: Bearer YOUR_TOKEN

{
  "medicalLicenseNumber": "SN12345678",
  "specialties": ["Médecine générale", "Cardiologie"],
  "yearsOfExperience": 5,
  "clinic": {
    "name": "Cabinet Dr Diallo",
    "address": {
      "street": "Rue 10 x Rue 15, Médina",
      "city": "Dakar",
      "region": "Dakar",
      "coordinates": {
        "latitude": 14.6937,
        "longitude": -17.4441
      }
    },
    "phone": "+221338901234",
    "description": "Cabinet médical moderne au cœur de Médina"
  },
  "consultationFee": 15000,
  "languages": ["Français", "Wolof"],
  "education": [
    {
      "degree": "Doctorat en Médecine",
      "institution": "Université Cheikh Anta Diop",
      "year": 2018,
      "country": "Sénégal"
    }
  ],
  "workingHours": {
    "monday": {
      "isWorking": true,
      "morning": { "start": "08:00", "end": "12:00" },
      "afternoon": { "start": "15:00", "end": "18:00" }
    },
    "tuesday": {
      "isWorking": true,
      "morning": { "start": "08:00", "end": "12:00" },
      "afternoon": { "start": "15:00", "end": "18:00" }
    }
  }
}
```

### 2. Recherche Médecins (Géolocalisée)
```http
GET http://localhost:3000/api/doctors/search?latitude=14.6937&longitude=-17.4441&radius=10&specialty=Cardiologie&page=1&limit=10
```

### 3. Recherche Médecins (Sans géolocalisation)
```http
GET http://localhost:3000/api/doctors/search?specialty=Médecine générale&page=1&limit=10
```

### 4. Détails d'un Médecin
```http
GET http://localhost:3000/api/doctors/DOCTOR_ID
```

### 5. Disponibilités Médecin
```http
GET http://localhost:3000/api/doctors/DOCTOR_ID/availability?date=2024-01-15&days=7
```

### 6. Mettre à jour Profil Médecin
```http
PUT http://localhost:3000/api/doctors/profile
Content-Type: application/json
Authorization: Bearer DOCTOR_TOKEN

{
  "consultationFee": 20000,
  "isAvailable": true,
  "workingHours": {
    "wednesday": {
      "isWorking": true,
      "morning": { "start": "09:00", "end": "13:00" }
    }
  }
}
```

---

## 📅 **RENDEZ-VOUS**

### 1. Créer un Rendez-vous
```http
POST http://localhost:3000/api/appointments
Content-Type: application/json
Authorization: Bearer PATIENT_TOKEN

{
  "doctorId": "DOCTOR_OBJECT_ID",
  "appointmentDate": "2024-01-20",
  "appointmentTime": "10:30",
  "reason": "Consultation pour douleurs thoraciques récurrentes depuis une semaine",
  "consultationType": "first_visit",
  "symptoms": ["Douleur thoracique", "Essoufflement"],
  "patientNotes": "Les douleurs surviennent surtout le matin"
}
```

### 2. Détails d'un Rendez-vous
```http
GET http://localhost:3000/api/appointments/APPOINTMENT_ID
Authorization: Bearer YOUR_TOKEN
```

### 3. Annuler un Rendez-vous
```http
PUT http://localhost:3000/api/appointments/APPOINTMENT_ID/cancel
Content-Type: application/json
Authorization: Bearer YOUR_TOKEN

{
  "reason": "Empêchement de dernière minute"
}
```

### 4. Confirmer un Rendez-vous (Médecin)
```http
PUT http://localhost:3000/api/appointments/APPOINTMENT_ID/confirm
Authorization: Bearer DOCTOR_TOKEN
```

### 5. Terminer un Rendez-vous (Médecin)
```http
PUT http://localhost:3000/api/appointments/APPOINTMENT_ID/complete
Content-Type: application/json
Authorization: Bearer DOCTOR_TOKEN

{
  "doctorNotes": "Patient présente des symptômes de stress. Recommandation de repos et suivi dans 2 semaines.",
  "diagnosis": "Syndrome de stress aigu",
  "prescription": [
    {
      "medication": "Paracétamol 500mg",
      "dosage": "1 comprimé",
      "frequency": "3 fois par jour",
      "duration": "5 jours",
      "instructions": "À prendre après les repas"
    }
  ],
  "followUp": {
    "required": true,
    "scheduledDate": "2024-02-03",
    "notes": "Contrôle de l'évolution des symptômes"
  }
}
```

### 6. Évaluer un Rendez-vous (Patient)
```http
POST http://localhost:3000/api/appointments/APPOINTMENT_ID/review
Content-Type: application/json
Authorization: Bearer PATIENT_TOKEN

{
  "rating": 5,
  "comment": "Excellent médecin, très à l'écoute et professionnel. Je recommande vivement."
}
```

### 7. Rendez-vous du Médecin
```http
GET http://localhost:3000/api/appointments/doctor/me?status=confirmed&date=2024-01-20&page=1&limit=10
Authorization: Bearer DOCTOR_TOKEN
```

---

## 👤 **GESTION UTILISATEUR**

### 1. Mettre à jour Profil
```http
PUT http://localhost:3000/api/users/profile
Content-Type: application/json
Authorization: Bearer YOUR_TOKEN

{
  "firstName": "Amadou",
  "lastName": "Diallo",
  "email": "amadou.diallo@example.com",
  "dateOfBirth": "1990-05-15",
  "gender": "male",
  "address": {
    "street": "Cité Keur Gorgui, Villa 123",
    "city": "Dakar",
    "region": "Dakar",
    "coordinates": {
      "latitude": 14.7167,
      "longitude": -17.4677
    }
  },
  "language": "fr"
}
```

### 2. Changer Mot de Passe
```http
PUT http://localhost:3000/api/users/change-password
Content-Type: application/json
Authorization: Bearer YOUR_TOKEN

{
  "currentPassword": "ancienpassword",
  "newPassword": "nouveaupassword123",
  "confirmPassword": "nouveaupassword123"
}
```

### 3. Mettre à jour Localisation
```http
PUT http://localhost:3000/api/users/location
Content-Type: application/json
Authorization: Bearer YOUR_TOKEN

{
  "address": {
    "street": "Nouvelle adresse",
    "city": "Dakar",
    "coordinates": {
      "latitude": 14.7167,
      "longitude": -17.4677
    }
  }
}
```

### 4. Préférences Notifications
```http
PUT http://localhost:3000/api/users/notifications
Content-Type: application/json
Authorization: Bearer YOUR_TOKEN

{
  "notifications": {
    "sms": true,
    "email": false,
    "push": true
  }
}
```

### 5. Mes Rendez-vous
```http
GET http://localhost:3000/api/users/me/appointments?status=confirmed&page=1&limit=10
Authorization: Bearer YOUR_TOKEN
```

---

## 🔧 **ADMINISTRATION**

### 1. Créer Admin (Script)
```bash
node scripts/createAdmin.js
```

### 2. Dashboard Admin
```http
GET http://localhost:3000/api/admin/dashboard
Authorization: Bearer ADMIN_TOKEN
```

### 3. Médecins en Attente
```http
GET http://localhost:3000/api/admin/doctors/pending?page=1&limit=10
Authorization: Bearer ADMIN_TOKEN
```

### 4. Valider un Médecin
```http
PUT http://localhost:3000/api/admin/doctors/DOCTOR_ID/verify
Content-Type: application/json
Authorization: Bearer ADMIN_TOKEN

{
  "action": "approve",
  "notes": "Diplômes vérifiés, profil complet et conforme"
}
```

### 5. Rejeter un Médecin
```http
PUT http://localhost:3000/api/admin/doctors/DOCTOR_ID/verify
Content-Type: application/json
Authorization: Bearer ADMIN_TOKEN

{
  "action": "reject",
  "notes": "Documents manquants ou non conformes"
}
```

### 6. Liste Utilisateurs
```http
GET http://localhost:3000/api/admin/users?role=patient&isActive=true&search=amadou&page=1&limit=20
Authorization: Bearer ADMIN_TOKEN
```

### 7. Activer/Désactiver Utilisateur
```http
PUT http://localhost:3000/api/admin/users/USER_ID/status
Content-Type: application/json
Authorization: Bearer ADMIN_TOKEN

{
  "isActive": false,
  "reason": "Violation des conditions d'utilisation"
}
```

### 8. Rapport Mensuel
```http
GET http://localhost:3000/api/admin/reports/monthly?year=2024&month=1
Authorization: Bearer ADMIN_TOKEN
```

---

## 🔄 **WORKFLOW COMPLET DE TEST**

### Scénario 1: Patient complet
1. **Inscription** patient
2. **Vérification** téléphone
3. **Recherche** médecins
4. **Création** rendez-vous
5. **Évaluation** après consultation

### Scénario 2: Médecin complet
1. **Inscription** comme patient
2. **Upgrade** vers médecin
3. **Attente** validation admin
4. **Gestion** des rendez-vous
5. **Finalisation** consultations

### Scénario 3: Admin complet
1. **Connexion** admin
2. **Validation** médecins
3. **Monitoring** utilisateurs
4. **Génération** rapports

---

## 🐛 **CODES D'ERREUR COURANTS**

- **400**: Données invalides
- **401**: Non authentifié
- **403**: Accès refusé
- **404**: Ressource non trouvée
- **429**: Trop de requêtes
- **500**: Erreur serveur

---

## 📱 **SIMULATION SMS (Mode Dev)**

En mode développement, les codes SMS apparaissent dans :
- **Console serveur**
- **Réponse API** (champ `devCode`)

Codes par défaut pour les tests :
- **Vérification**: 6 chiffres aléatoires
- **Reset password**: 6 chiffres aléatoires

---

## 🎯 **CONSEILS DE TEST**

1. **Commencez** par le health check
2. **Créez** un admin avec le script
3. **Testez** l'authentification en premier
4. **Gardez** les tokens JWT pour les autres requêtes
5. **Utilisez** des numéros sénégalais valides (+221XXXXXXXX)
6. **Vérifiez** les logs serveur pour les SMS simulés

---

**🚀 Bon testing ! L'API est prête pour tous les scénarios du MVP 1.**

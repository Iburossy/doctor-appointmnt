const mongoose = require('mongoose');
const request = require('supertest');
const bcrypt = require('bcryptjs');
const app = require('../app'); // Assurez-vous que ce fichier exporte votre application Express
const User = require('../models/User');
const Patient = require('../models/Patient');
const Doctor = require('../models/Doctor');
const Appointment = require('../models/Appointment');
const MedicalRecord = require('../models/MedicalRecord');
const Notification = require('../models/Notification');
const RefreshToken = require('../models/RefreshToken');
const PasswordResetToken = require('../models/PasswordResetToken');
const AuditLog = require('../models/AuditLog');

describe('Test de la suppression permanente d\'utilisateurs', () => {
  let adminToken;
  let adminId;
  let testUserId;
  let patientId;

  // Configuration avant les tests
  beforeAll(async () => {
    // Connexion à la base de données de test
    await mongoose.connect(process.env.MONGODB_URI_TEST || 'mongodb://localhost:27017/doctors_test', {
      useNewUrlParser: true,
      useUnifiedTopology: true
    });

    // Nettoyage initial de la base de données de test
    await User.deleteMany({});
    await Patient.deleteMany({});
    await Doctor.deleteMany({});
    await Appointment.deleteMany({});
    await MedicalRecord.deleteMany({});
    await Notification.deleteMany({});
    await RefreshToken.deleteMany({});
    await PasswordResetToken.deleteMany({});
    await AuditLog.deleteMany({});

    // Création d'un administrateur de test
    const hashedPassword = await bcrypt.hash('Admin123!', 10);
    const admin = await User.create({
      firstName: 'Admin',
      lastName: 'Test',
      email: 'admin@test.com',
      password: hashedPassword,
      role: 'admin',
      isActive: true,
      isVerified: true
    });
    adminId = admin._id;

    // Création d'un utilisateur de test (patient)
    const user = await User.create({
      firstName: 'Jean',
      lastName: 'Dupont',
      email: 'jean.dupont@example.com',
      password: await bcrypt.hash('User123!', 10),
      role: 'patient',
      isActive: true,
      isVerified: true
    });
    testUserId = user._id;

    // Création d'un profil patient associé
    const patient = await Patient.create({
      userId: testUserId,
      firstName: 'Jean',
      lastName: 'Dupont',
      email: 'jean.dupont@example.com',
      phoneNumber: '0612345678',
      gender: 'male'
    });
    patientId = patient._id;

    // Création de quelques rendez-vous pour ce patient
    const futureDate = new Date();
    futureDate.setDate(futureDate.getDate() + 7);
    
    const pastDate = new Date();
    pastDate.setDate(pastDate.getDate() - 7);
    
    await Appointment.create({
      patient: patientId,
      patientName: 'Jean Dupont',
      doctor: mongoose.Types.ObjectId(),
      doctorName: 'Dr. Test',
      appointmentDate: futureDate,
      status: 'confirmed'
    });
    
    await Appointment.create({
      patient: patientId,
      patientName: 'Jean Dupont',
      doctor: mongoose.Types.ObjectId(),
      doctorName: 'Dr. Test',
      appointmentDate: pastDate,
      status: 'completed'
    });

    // Création d'un dossier médical
    await MedicalRecord.create({
      patientId: patientId,
      doctorId: mongoose.Types.ObjectId(),
      patientName: 'Jean Dupont',
      doctorName: 'Dr. Test',
      diagnosis: 'Test Diagnosis',
      symptoms: ['Fever', 'Headache']
    });

    // Connexion en tant qu'administrateur pour obtenir un token
    const loginResponse = await request(app)
      .post('/api/auth/login')
      .send({
        email: 'admin@test.com',
        password: 'Admin123!'
      });
    
    adminToken = loginResponse.body.token;
  });

  // Nettoyage après les tests
  afterAll(async () => {
    await mongoose.connection.close();
  });

  // Test de suppression soft (désactivation)
  test('Désactivation d\'un utilisateur (soft delete)', async () => {
    const response = await request(app)
      .delete(`/api/admin/users/${testUserId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        reason: 'Test de désactivation'
      });
    
    expect(response.status).toBe(200);
    expect(response.body.success).toBe(true);
    
    // Vérifier que l'utilisateur est marqué comme supprimé mais existe toujours
    const user = await User.findById(testUserId);
    expect(user).toBeTruthy();
    expect(user.isDeleted).toBe(true);
    expect(user.isActive).toBe(false);
  });

  // Test de suppression permanente
  test('Suppression permanente d\'un utilisateur', async () => {
    const response = await request(app)
      .delete(`/api/admin/users/${testUserId}/permanent`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        confirmation: 'SUPPRIMER DÉFINITIVEMENT',
        password: 'Admin123!',
        reason: 'Test de suppression permanente'
      });
    
    expect(response.status).toBe(200);
    expect(response.body.success).toBe(true);
    
    // Vérifier que l'utilisateur a été complètement supprimé
    const user = await User.findById(testUserId);
    expect(user).toBeNull();
    
    // Vérifier que le patient a été anonymisé mais pas supprimé
    const patient = await Patient.findOne({ userId: testUserId });
    expect(patient.firstName).toBe('Anonymisé');
    expect(patient.lastName).toBe('Anonymisé');
    expect(patient.userId).toBeNull();
    expect(patient.isAnonymized).toBe(true);
    
    // Vérifier que les RDV passés sont anonymisés mais conservés
    const pastAppointment = await Appointment.findOne({ 
      patient: patientId,
      status: 'completed'
    });
    expect(pastAppointment).toBeTruthy();
    expect(pastAppointment.patientName).toBe('Patient anonymisé');
    expect(pastAppointment.patientId).toBeNull();
    expect(pastAppointment.isAnonymized).toBe(true);
    
    // Vérifier que les RDV futurs sont supprimés
    const futureAppointment = await Appointment.findOne({
      patient: patientId,
      status: 'confirmed'
    });
    expect(futureAppointment).toBeNull();
    
    // Vérifier que les dossiers médicaux sont anonymisés
    const medicalRecord = await MedicalRecord.findOne({ patientId });
    expect(medicalRecord).toBeTruthy();
    expect(medicalRecord.patientName).toBe('Patient anonymisé');
    expect(medicalRecord.isAnonymized).toBe(true);
    
    // Vérifier qu'un log d'audit a été créé
    const auditLog = await AuditLog.findOne({ 
      action: 'PERMANENT_DELETE_USER',
      entityId: testUserId
    });
    expect(auditLog).toBeTruthy();
    expect(auditLog.performedBy.toString()).toBe(adminId.toString());
  });
  
  // Test de tentative de suppression permanente avec mot de passe incorrect
  test('Échec de suppression permanente avec mot de passe incorrect', async () => {
    // Créer d'abord un nouvel utilisateur de test
    const newUser = await User.create({
      firstName: 'Test',
      lastName: 'User',
      email: 'test.user@example.com',
      password: await bcrypt.hash('Password123!', 10),
      role: 'patient',
      isActive: true,
      isVerified: true
    });
    
    const response = await request(app)
      .delete(`/api/admin/users/${newUser._id}/permanent`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        confirmation: 'SUPPRIMER DÉFINITIVEMENT',
        password: 'WrongPassword123!',
        reason: 'Test avec mauvais mot de passe'
      });
    
    expect(response.status).toBe(403);
    expect(response.body.success).toBe(false);
    expect(response.body.error).toBe('Mot de passe administrateur incorrect');
    
    // Vérifier que l'utilisateur existe toujours
    const user = await User.findById(newUser._id);
    expect(user).toBeTruthy();
  });
  
  // Test de tentative de suppression permanente avec texte de confirmation incorrect
  test('Échec de suppression permanente avec texte de confirmation incorrect', async () => {
    // Créer d'abord un nouvel utilisateur de test
    const newUser = await User.create({
      firstName: 'Another',
      lastName: 'User',
      email: 'another.user@example.com',
      password: await bcrypt.hash('Password123!', 10),
      role: 'patient',
      isActive: true,
      isVerified: true
    });
    
    const response = await request(app)
      .delete(`/api/admin/users/${newUser._id}/permanent`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        confirmation: 'SUPPRIMER',  // Texte incorrect
        password: 'Admin123!',
        reason: 'Test avec mauvaise confirmation'
      });
    
    expect(response.status).toBe(400);
    expect(response.body.success).toBe(false);
    expect(response.body.error).toBe('Texte de confirmation incorrect');
    
    // Vérifier que l'utilisateur existe toujours
    const user = await User.findById(newUser._id);
    expect(user).toBeTruthy();
  });
});

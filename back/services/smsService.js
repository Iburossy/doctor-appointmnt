const twilio = require('twilio');

class SMSService {
  constructor() {
    // Configuration Twilio (ou service SMS local sénégalais)
    this.client = null;
    this.fromNumber = process.env.SMS_FROM_NUMBER;
    
    // Vérifier que les credentials Twilio sont valides avant d'initialiser
    if (process.env.SMS_SERVICE_SID && 
        process.env.SMS_AUTH_TOKEN && 
        process.env.SMS_SERVICE_SID.startsWith('AC') &&
        process.env.SMS_SERVICE_SID !== 'your_twilio_service_sid') {
      try {
        this.client = twilio(process.env.SMS_SERVICE_SID, process.env.SMS_AUTH_TOKEN);
        console.log('✅ Service SMS Twilio initialisé');
      } catch (error) {
        console.warn('⚠️  Erreur initialisation Twilio:', error.message);
        console.log('📱 Fonctionnement en mode développement (SMS simulés)');
      }
    } else {
      console.log('📱 Mode développement: SMS simulés dans les logs');
    }
  }

  // Envoyer un SMS de vérification
  async sendVerificationCode(phoneNumber, code) {
    try {
      const message = `Votre code de vérification Doctors App: ${code}. Ce code expire dans 10 minutes.`;
      
      if (this.client) {
        const result = await this.client.messages.create({
          body: message,
          from: this.fromNumber,
          to: phoneNumber
        });
        
        console.log(`✅ SMS envoyé à ${phoneNumber}: ${result.sid}`);
        return { success: true, messageId: result.sid };
      } else {
        // Mode développement - afficher le code dans les logs
        console.log(`📱 [DEV MODE] SMS pour ${phoneNumber}: ${message}`);
        return { success: true, messageId: 'dev_mode', devCode: code };
      }
    } catch (error) {
      console.error('❌ Erreur envoi SMS:', error);
      throw new Error('Impossible d\'envoyer le SMS de vérification');
    }
  }

  // Envoyer un SMS de rappel de rendez-vous
  async sendAppointmentReminder(phoneNumber, appointmentDetails) {
    try {
      const { doctorName, date, time, clinicName } = appointmentDetails;
      const message = `Rappel: RDV avec Dr ${doctorName} le ${date} à ${time} - ${clinicName}. Pour annuler, contactez le cabinet.`;
      
      if (this.client) {
        const result = await this.client.messages.create({
          body: message,
          from: this.fromNumber,
          to: phoneNumber
        });
        
        console.log(`✅ Rappel SMS envoyé à ${phoneNumber}: ${result.sid}`);
        return { success: true, messageId: result.sid };
      } else {
        console.log(`📱 [DEV MODE] Rappel SMS pour ${phoneNumber}: ${message}`);
        return { success: true, messageId: 'dev_mode' };
      }
    } catch (error) {
      console.error('❌ Erreur envoi rappel SMS:', error);
      throw new Error('Impossible d\'envoyer le rappel SMS');
    }
  }

  // Envoyer un SMS de confirmation de rendez-vous
  async sendAppointmentConfirmation(phoneNumber, appointmentDetails) {
    try {
      const { doctorName, date, time, clinicName, clinicAddress } = appointmentDetails;
      const message = `RDV confirmé avec Dr ${doctorName} le ${date} à ${time}. Lieu: ${clinicName}, ${clinicAddress}. Merci!`;
      
      if (this.client) {
        const result = await this.client.messages.create({
          body: message,
          from: this.fromNumber,
          to: phoneNumber
        });
        
        console.log(`✅ Confirmation SMS envoyée à ${phoneNumber}: ${result.sid}`);
        return { success: true, messageId: result.sid };
      } else {
        console.log(`📱 [DEV MODE] Confirmation SMS pour ${phoneNumber}: ${message}`);
        return { success: true, messageId: 'dev_mode' };
      }
    } catch (error) {
      console.error('❌ Erreur envoi confirmation SMS:', error);
      throw new Error('Impossible d\'envoyer la confirmation SMS');
    }
  }

  // Envoyer un SMS d'annulation
  async sendAppointmentCancellation(phoneNumber, appointmentDetails) {
    try {
      const { doctorName, date, time, reason } = appointmentDetails;
      const message = `RDV annulé: Dr ${doctorName} le ${date} à ${time}. ${reason ? `Motif: ${reason}` : ''}`;
      
      if (this.client) {
        const result = await this.client.messages.create({
          body: message,
          from: this.fromNumber,
          to: phoneNumber
        });
        
        console.log(`✅ Annulation SMS envoyée à ${phoneNumber}: ${result.sid}`);
        return { success: true, messageId: result.sid };
      } else {
        console.log(`📱 [DEV MODE] Annulation SMS pour ${phoneNumber}: ${message}`);
        return { success: true, messageId: 'dev_mode' };
      }
    } catch (error) {
      console.error('❌ Erreur envoi annulation SMS:', error);
      throw new Error('Impossible d\'envoyer l\'annulation SMS');
    }
  }

  // Valider le format du numéro de téléphone sénégalais
  validateSenegalPhoneNumber(phoneNumber) {
    const senegalPhoneRegex = /^\+221[0-9]{8,9}$/;
    return senegalPhoneRegex.test(phoneNumber);
  }

  // Formater le numéro de téléphone
  formatPhoneNumber(phoneNumber) {
    // Supprimer tous les espaces et caractères spéciaux
    let cleaned = phoneNumber.replace(/\D/g, '');
    
    // Si le numéro commence par 221, ajouter le +
    if (cleaned.startsWith('221')) {
      return '+' + cleaned;
    }
    
    // Si le numéro commence par 7 ou 3 (numéros sénégalais), ajouter +221
    if (cleaned.startsWith('7') || cleaned.startsWith('3')) {
      return '+221' + cleaned;
    }
    
    return phoneNumber; // Retourner tel quel si format non reconnu
  }
}

module.exports = new SMSService();

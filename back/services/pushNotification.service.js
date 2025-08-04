const admin = require('firebase-admin');
const path = require('path');

// Path to your service account key file - configurable via env vars
const serviceAccountPath = path.join(__dirname, '..', process.env.FIREBASE_SERVICE_ACCOUNT_PATH || 'firebase-service-account-key.json');
console.log(`🔑 Utilisation du fichier de service account Firebase: ${serviceAccountPath}`);

let firebaseInitialized = false;

try {
  const serviceAccount = require(serviceAccountPath);

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });

  firebaseInitialized = true;
  console.log('✅ Firebase Admin SDK initialized successfully.');

} catch (error) {
  console.error('❌ Error initializing Firebase Admin SDK:', error.message);
  console.error('Ensure firebase-service-account-key.json is in the /back directory.');
}

/**
 * Sends a push notification to a user's devices.
 * @param {string[]} tokens - An array of FCM registration tokens.
 * @param {string} title - The title of the notification.
 * @param {string} body - The body of the notification.
 * @param {object} [data] - Optional data payload to send with the notification.
 */
const sendPushNotification = async (tokens, title, body, data) => {
  if (!firebaseInitialized) {
    console.error('Firebase Admin SDK not initialized. Cannot send notification.');
    return;
  }

  if (!tokens || tokens.length === 0) {
    console.log('No FCM tokens provided. Skipping notification.');
    return;
  }

  const message = {
    notification: {
      title,
      body,
    },
    tokens: tokens,
    data: data || {},
    android: {
        priority: 'high',
    },
    apns: {
        headers: {
            'apns-priority': '10',
        },
    },
  };

  try {
    const response = await admin.messaging().sendMulticast(message);
    console.log('Successfully sent notification:', response.successCount, 'messages');
    if (response.failureCount > 0) {
        const failedTokens = [];
        response.responses.forEach((resp, idx) => {
            if (!resp.success) {
                failedTokens.push(tokens[idx]);
            }
        });
        console.log('List of failed tokens:', failedTokens);
        // TODO: Add logic to remove these failed tokens from the database
    }
  } catch (error) {
    console.error('Error sending notification:', error);
  }
};

module.exports = { sendPushNotification };

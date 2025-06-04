// NOTE: This script requires a valid Firebase Admin SDK key file.
// Current key had issues with "Invalid JWT Signature" - needs to be regenerated before use.
// To generate a new key: 
// 1. Go to Firebase Console > Project Settings > Service Accounts
// 2. Click "Generate New Private Key"
// 3. Save the key as firebase-admin-key.json in this directory

const admin = require('firebase-admin');
const serviceAccount = require('./firebase-admin-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function createTestUser() {
  try {
    const userRecord = await admin.auth().createUser({
      email: 'test@example.com',
      password: 'Test123!',
      displayName: 'Test User',
    });
    console.log('Successfully created test user:', userRecord.uid);
    
    // Update user custom claims to mark as test user
    await admin.auth().setCustomUserClaims(userRecord.uid, { isTestUser: true });
    console.log('Added test user claims');
    
    // Create user document in Firestore
    await admin.firestore().collection('users').doc(userRecord.uid).set({
      uid: userRecord.uid,
      email: 'test@example.com',
      displayName: 'Test User',
      photoURL: null,
      isAnonymous: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
      videoCount: 0,
      followerCount: 0,
      followingCount: 0,
      likeCount: 0,
      bio: 'This is a test account',
      website: '',
      location: 'Test Location',
      deviceToken: '',
      settings: {
        notifications: true,
        darkMode: false,
        privateAccount: false,
      },
      accountType: 'test',
      joinDate: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log('Created user document in Firestore');
    
    console.log('Test user setup complete');
  } catch (error) {
    console.error('Error creating test user:', error);
  }
}

createTestUser().then(() => process.exit(0));

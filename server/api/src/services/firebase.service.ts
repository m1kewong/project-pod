import admin from 'firebase-admin';
import { config } from '../config';
import { logger } from '../utils/logger';

// Export commonly used Firebase utilities
export const FieldValue = admin.firestore.FieldValue;
export const FieldPath = admin.firestore.FieldPath;

class FirebaseService {
  private static instance: FirebaseService;
  private initialized = false;

  private constructor() {}

  public static getInstance(): FirebaseService {
    if (!FirebaseService.instance) {
      FirebaseService.instance = new FirebaseService();
    }
    return FirebaseService.instance;
  }
  public async initialize(): Promise<void> {
    if (this.initialized) {
      return;
    }

    try {
      // Check if we're using mock credentials for local development
      if (config.firebase.serviceAccountPath && config.firebase.serviceAccountPath.includes('service-account-key.json')) {
        // For local development with mock credentials, skip Firebase initialization
        logger.warn('Using mock Firebase credentials - Firebase features disabled for local development');
        this.initialized = true;
        return;
      }

      // Initialize Firebase Admin SDK
      if (config.firebase.serviceAccountPath) {
        admin.initializeApp({
          credential: admin.credential.cert(config.firebase.serviceAccountPath),
          projectId: config.firebase.projectId,
        });
      } else {
        // Use default credentials (for Cloud Run deployment)
        admin.initializeApp({
          projectId: config.firebase.projectId,
        });
      }

      this.initialized = true;
      logger.info('Firebase Admin SDK initialized successfully');
    } catch (error) {
      logger.error('Failed to initialize Firebase Admin SDK', error);
      throw error;
    }
  }
  public getAuth() {
    if (!this.initialized) {
      throw new Error('Firebase not initialized');
    }
    
    // Check if we're in mock mode
    if (config.firebase.serviceAccountPath && config.firebase.serviceAccountPath.includes('service-account-key.json')) {
      throw new Error('Firebase Auth not available in mock mode');
    }
    
    return admin.auth();
  }

  public getFirestore() {
    if (!this.initialized) {
      throw new Error('Firebase not initialized');
    }
    
    // Check if we're in mock mode
    if (config.firebase.serviceAccountPath && config.firebase.serviceAccountPath.includes('service-account-key.json')) {
      throw new Error('Firestore not available in mock mode');
    }
    
    return admin.firestore();
  }

  public getStorage() {
    if (!this.initialized) {
      throw new Error('Firebase not initialized');
    }
    
    // Check if we're in mock mode
    if (config.firebase.serviceAccountPath && config.firebase.serviceAccountPath.includes('service-account-key.json')) {
      throw new Error('Firebase Storage not available in mock mode');
    }
    
    return admin.storage();
  }

  public async verifyIdToken(idToken: string) {
    try {
      const decodedToken = await this.getAuth().verifyIdToken(idToken);
      return decodedToken;
    } catch (error) {
      logger.error('Failed to verify Firebase ID token', error);
      throw error;
    }
  }

  public async getUserByUid(uid: string) {
    try {
      const userRecord = await this.getAuth().getUser(uid);
      return userRecord;
    } catch (error) {
      logger.error(`Failed to get user by UID: ${uid}`, error);
      throw error;
    }
  }

  public async createCustomToken(uid: string, additionalClaims?: Record<string, any>) {
    try {
      const customToken = await this.getAuth().createCustomToken(uid, additionalClaims);
      return customToken;
    } catch (error) {
      logger.error(`Failed to create custom token for UID: ${uid}`, error);
      throw error;
    }
  }
}

export const firebaseService = FirebaseService.getInstance();

// Main services exports
export { firebaseService, FieldValue, FieldPath } from './firebase.service';
export { cacheService } from './cache.service';

// Initialize Firebase on import
import { firebaseService } from './firebase.service';

// Auto-initialize Firebase
firebaseService.initialize().catch(error => {
  console.error('Failed to initialize Firebase:', error);
  process.exit(1);
});

// Export firestore and auth instances for convenience
export const firestore = firebaseService.getFirestore();
export const auth = firebaseService.getAuth();

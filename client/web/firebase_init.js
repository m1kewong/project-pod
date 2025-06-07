// Initialize Firebase
window.firebaseConfig = {
  apiKey: "AIzaSyBLkaaslwRrvwr5W2p2-sEpoPx1TRHdRZI",
  authDomain: "project-pod-dev.firebaseapp.com",
  projectId: "project-pod-dev",
  storageBucket: "project-pod-dev.firebasestorage.app",
  messagingSenderId: "56249782826",
  appId: "1:56249782826:web:d4a70d544ad8e2abc92953"
};

// Track initialization status to avoid multiple initializations
window.firebaseInitialized = false;

// Initialize Firebase if it's not already initialized
try {
  if (typeof firebase !== 'undefined') {
    // Check if Firebase is already initialized
    if (!firebase.apps.length && !window.firebaseInitialized) {
      console.log("Initializing Firebase Web SDK");
      firebase.initializeApp(window.firebaseConfig);
      window.firebaseInitialized = true;
      
      // Enable Firebase Auth persistence with stronger settings
      firebase.auth().setPersistence(firebase.auth.Auth.Persistence.LOCAL)
        .then(() => {
          console.log("Firebase Auth persistence set to LOCAL");
          
          // Once persistence is set, attempt to restore the session
          return firebase.auth().onAuthStateChanged(function(user) {
            if (user) {
              console.log("Firebase Auth: User session restored", 
                user.isAnonymous ? "(anonymously)" : "",
                user.emailVerified ? "(email verified)" : "(email not verified)");
                
              // Periodically refresh token to ensure session validity
              setInterval(() => {
                if (firebase.auth().currentUser) {
                  firebase.auth().currentUser.getIdToken(true)
                    .then(() => console.debug("Auth token refreshed"))
                    .catch(error => console.error("Error refreshing token:", error));
                }
              }, 10 * 60 * 1000); // Refresh every 10 minutes
            } else {
              console.log("Firebase Auth: No user session to restore");
            }
          });
        })
        .catch(function(error) {
          console.error("Error setting auth persistence:", error);
        });
    } else {
      console.log("Firebase already initialized");
    }
    
    // Enhanced auth state monitoring
    firebase.auth().onAuthStateChanged(function(user) {
      if (user) {
        console.log("Firebase Auth: User state change", 
          user.isAnonymous ? "(anonymously)" : "",
          user.emailVerified ? "(email verified)" : "(email not verified)");
          
        // Add event listeners for session expiration
        window.addEventListener('focus', function() {
          // When the window gains focus, check if the token is still valid
          if (firebase.auth().currentUser) {
            firebase.auth().currentUser.getIdToken(true)
              .catch(error => {
                console.error("Session expired on window focus:", error);
                // Dispatch an event that Flutter can listen for
                window.dispatchEvent(new CustomEvent('firebaseAuthSessionExpired'));
              });
          }
        });
      } else {
        console.log("Firebase Auth: User signed out");
      }
    });
  } else {
    console.error("Firebase SDK not loaded. Authentication features may not work correctly.");
  }
} catch (e) {
  console.error("Error initializing Firebase:", e);
}

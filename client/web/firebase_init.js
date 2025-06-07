// Initialize Firebase
window.firebaseConfig = {
  apiKey: "AIzaSyBLkaaslwRrvwr5W2p2-sEpoPx1TRHdRZI",
  authDomain: "project-pod-dev.firebaseapp.com",
  projectId: "project-pod-dev",
  storageBucket: "project-pod-dev.firebasestorage.app",
  messagingSenderId: "56249782826",
  appId: "1:56249782826:web:d4a70d544ad8e2abc92953"
};

// Initialize Firebase if it's not already initialized
try {
  if (typeof firebase !== 'undefined') {
    // Check if Firebase is already initialized
    if (!firebase.apps.length) {
      console.log("Initializing Firebase Web SDK");
      firebase.initializeApp(window.firebaseConfig);
      
      // Enable Firebase Auth persistence
      firebase.auth().setPersistence(firebase.auth.Auth.Persistence.LOCAL)
        .then(() => {
          console.log("Firebase Auth persistence set to LOCAL");
        })
        .catch(function(error) {
          console.error("Error setting auth persistence:", error);
        });
    } else {
      console.log("Firebase already initialized");
    }
    
    // Set up auth state changed listener for debugging
    firebase.auth().onAuthStateChanged(function(user) {
      if (user) {
        console.log("Firebase Auth: User is signed in", user.isAnonymous ? "(anonymously)" : "");
      } else {
        console.log("Firebase Auth: No user is signed in");
      }
    });
  } else {
    console.error("Firebase SDK not loaded. Authentication features may not work correctly.");
  }
} catch (e) {
  console.error("Error initializing Firebase:", e);
}

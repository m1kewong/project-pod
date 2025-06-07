# Firebase Authentication Configuration

## Anonymous Authentication Setup

1. Go to the Firebase Console: https://console.firebase.google.com/project/project-pod-dev/authentication/providers

2. Enable Anonymous Authentication:
   - Navigate to the "Sign-in method" tab
   - Find "Anonymous" in the list of providers
   - Click the edit icon (pencil)
   - Toggle the "Enable" switch to ON
   - Click "Save"

## Email/Password Authentication Setup

1. Go to the Firebase Console: https://console.firebase.google.com/project/project-pod-dev/authentication/providers

2. Enable Email/Password Authentication:
   - Navigate to the "Sign-in method" tab
   - Find "Email/Password" in the list of providers
   - Click the edit icon (pencil)
   - Toggle the "Enable" switch to ON
   - Enable "Email link (passwordless sign-in)" if you want to support magic links
   - Click "Save"

3. Configure Email Templates:
   - Navigate to the "Templates" tab
   - Customize the following templates:
     - Email verification
     - Password reset
     - Email link for sign-in (if enabled)
   - Update the sender name, reply-to email, subject, and message content
   - Add your app's logo and customize colors
   - Click "Save" for each template

## Google Authentication Setup

1. Go to the Firebase Console: https://console.firebase.google.com/project/project-pod-dev/authentication/providers

2. Enable Google Authentication:
   - Navigate to the "Sign-in method" tab
   - Find "Google" in the list of providers
   - Click the edit icon (pencil)
   - Toggle the "Enable" switch to ON
   - Add your support email
   - Configure the OAuth Client ID (should be auto-created)
   - Click "Save"

3. Configure OAuth Consent Screen:
   - Go to Google Cloud Console: https://console.cloud.google.com/apis/credentials/consent
   - Set up the consent screen with your app information
   - Add necessary scopes (email, profile)
   - Add test users if in testing mode

## Apple Authentication Setup

1. Go to the Firebase Console: https://console.firebase.google.com/project/project-pod-dev/authentication/providers

2. Enable Apple Authentication:
   - Navigate to the "Sign-in method" tab
   - Find "Apple" in the list of providers
   - Click the edit icon (pencil)
   - Toggle the "Enable" switch to ON
   - Follow the instructions to set up Apple Sign-In
   - You'll need to configure your Apple Developer account
   - Click "Save"

3. Configure Apple Developer Account:
   - Go to https://developer.apple.com/account/
   - Register an App ID with Sign In with Apple capability
   - Create a Services ID for web authentication
   - Create a private key for client-side authentication
   - Configure the domain association file for web authentication

## Web Configuration

1. Add Firebase SDK to web/index.html:
   ```html
   <!-- Firebase SDK -->
   <script src="https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js"></script>
   <script src="https://www.gstatic.com/firebasejs/9.22.0/firebase-auth-compat.js"></script>
   <script src="https://www.gstatic.com/firebasejs/9.22.0/firebase-firestore-compat.js"></script>
   <script src="https://www.gstatic.com/firebasejs/9.22.0/firebase-storage-compat.js"></script>
   
   <!-- Initialize Firebase -->
   <script src="firebase_init.js"></script>
   ```

2. Create web/firebase_init.js:
   ```javascript
   // Initialize Firebase
   window.firebaseConfig = {
     apiKey: "YOUR_API_KEY",
     authDomain: "project-pod-dev.firebaseapp.com",
     projectId: "project-pod-dev",
     storageBucket: "project-pod-dev.firebasestorage.app",
     messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
     appId: "YOUR_APP_ID"
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
       }
     }
   } catch (e) {
     console.error("Error initializing Firebase:", e);
   }
   ```

3. Configure Authorized Domains:
   - Go to Firebase Console > Authentication > Settings
   - Add your domains to the "Authorized domains" list:
     - localhost (for development)
     - project-pod-dev.web.app (for Firebase Hosting)
     - Any custom domains you're using

## Session Management

The app has been configured with robust session management:

1. **Persistent Login**: Firebase Auth is configured with `Auth.Persistence.LOCAL` for web to keep users logged in across browser sessions.

2. **Token Auto-Refresh**: The web app automatically refreshes the authentication token before it expires.

3. **Session Validation**: On app startup, the system validates the existing session to ensure it's still valid.

4. **Graceful Error Handling**: If a session becomes invalid, the user is gracefully redirected to the login screen.

## Email Verification

Email verification is implemented with the following features:

1. **Automatic Verification Email**: When a user registers, a verification email is automatically sent.

2. **Verification Status Checking**: The app periodically checks if the email has been verified.

3. **Resend Verification**: Users can request a new verification email if needed.

4. **Verification UI**: A dedicated UI guides users through the verification process.

## Password Reset

Password reset functionality is implemented with these features:

1. **Password Reset Flow**: Users can request a password reset email from the login screen.

2. **Customizable Email**: The password reset email template can be customized in the Firebase Console.

3. **User-Friendly Messages**: Clear feedback is provided throughout the password reset process.

## Testing Authentication

1. After enabling the authentication methods, test them using the app
2. For guest mode, ensure anonymous authentication is enabled
3. For more complete testing, use the Firebase Authentication Emulator
4. Test the following flows:
   - Sign up with email/password
   - Email verification
   - Password reset
   - Sign in with email/password
   - Sign in with Google
   - Sign in with Apple (on supported platforms)
   - Anonymous browsing
   - Session persistence after browser refresh
   - Sign out

## Troubleshooting

If authentication methods fail:

1. **Console Errors**: Check browser console for specific error messages.

2. **Firebase Configuration**:
   - Verify the correct Firebase config is being used
   - Ensure all required Firebase SDKs are loaded

3. **Domain Configuration**:
   - Make sure your domain is whitelisted in Firebase Auth settings
   - For OAuth providers, verify redirect domains are correctly configured

4. **Web-Specific Issues**:
   - Check for cross-origin (CORS) issues
   - Verify that third-party cookies are enabled in the browser
   - Test in incognito/private browsing mode to identify cookie issues

5. **OAuth Providers**:
   - Verify OAuth consent screen configuration
   - Check that required scopes are enabled
   - Ensure redirect URIs are correctly configured

6. **Email Configuration**:
   - Check spam folder for verification/reset emails
   - Verify email templates are correctly configured

7. **Anonymous Auth**:
   - Ensure anonymous auth is enabled in Firebase Console
   - Check if IP restrictions are blocking anonymous auth

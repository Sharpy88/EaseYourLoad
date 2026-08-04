// Cloud Functions are provided in the functions/ directory. This file contains Firestore security rules and deployment instructions.

# Firebase setup & deployment

This branch adds email/password authentication, a secure invite flow (server-side Cloud Functions), and per-user PIN protected private gifts.

Quick steps to finish setup:

1. Android: add your `google-services.json` to `android/app/` (not checked into this repo unless you add it).
2. iOS: `GoogleService-Info.plist` is already present in the repo.
3. In the Firebase Console:
   - Enable Authentication -> Sign-in method -> Email/Password
   - Create a Firestore database (native mode)
4. Deploy Firestore rules (file provided at firestore.rules):
   firebase deploy --only firestore:rules --project YOUR_PROJECT_ID

5. Deploy Cloud Functions (functions/):
   - cd functions
   - npm install
   - firebase deploy --only functions:createInvite,functions:joinWithCode --project YOUR_PROJECT_ID

6. In your project run:
   flutter pub get

Notes:
- Invite codes are generated server-side; only the hashed form is stored in Firestore and join logic runs in Cloud Functions for safety.
- PINs are handled server-side via a Cloud Function in this scaffold; do not store plain-text PINs.


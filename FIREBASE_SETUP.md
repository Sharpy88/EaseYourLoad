# Firebase setup for household sharing

Sharing lets two (up to four) people use Ease Your Mind on their own phones and
see each other's shopping list, household tasks, calendar, ideas and budget
update live. It needs a Firebase project. Until one is configured the app runs
exactly as before, fully offline, with the sharing screen showing
"Sharing unavailable".

## Current state

- **iOS is configured** for the `easeyourminddatabase-ca0de` project:
  `ios/Runner/GoogleService-Info.plist` is committed and bundled with the Runner
  target, and `lib/firebase_options.dart` holds the matching iOS values.
- **Android and web are not configured yet** — they stay local-only until their
  sections of `lib/firebase_options.dart` are filled in (step 2).
- **The Firestore rules still need publishing** (step 3). A database left in Test
  mode lets anyone read and write your household data and stops working after
  about 30 days.

Steps 1 and 2 are only needed for a new project or when adding Android.

## 1. Create the Firebase project

1. Go to https://console.firebase.google.com and click **Add project**
   (the free Spark plan is enough).
2. In **Build → Authentication → Sign-in method**, enable **Anonymous**.
   Each phone signs in silently; nobody has to create an account.
3. In **Build → Firestore Database**, click **Create database** and pick a
   region close to you. Start in production mode — the rules come from step 3.

## 2. Connect the app to the project

Install the CLIs once:

```bash
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
```

Then, from the repository root:

```bash
flutterfire configure
```

Select your project and the platforms you build for (at least Android). This
overwrites `lib/firebase_options.dart` with your real keys, writes
`android/app/google-services.json`, and adds the
`com.google.gms.google-services` Gradle plugin. Those values are not secret —
they identify the project; access is controlled by the Firestore rules below.

## 3. Publish the security rules

`firestore.rules` in this repository restricts every household document to its
members, allows someone holding an invite code to join while there is room, and
lets a member remove only themselves. Publish it with:

```bash
firebase deploy --only firestore:rules
```

or paste the file's contents into **Firestore Database → Rules → Publish**.

## 4. Use it

1. Build and run the app: `flutter run`.
2. Open **More → Share with someone → Invite someone**. A six-character invite
   code appears (for example `K4M7QP`).
3. On the second phone, open **More → Share with someone → Join with an invite
   code** and enter it.

From then on both phones write to the same household document, so ticking off
"Milk" on one phone removes it on the other within a second.

## How it works

- `lib/household_sync.dart` signs in anonymously, keeps
  `households/{inviteCode}` in sync, and stores the joined household id in
  `SharedPreferences` so sharing survives a restart.
- The whole shared payload (`lib/shared_data.dart`) lives in one document, so any
  edit is a single write and a single snapshot for everyone else. Writes are
  debounced by 400 ms, and the local device ignores the echo of its own writes.
- Firestore's offline cache means edits made without signal are queued and sent
  when the phone reconnects. Simultaneous edits resolve last-write-wins.
- Notification preferences are deliberately **not** shared: reminders stay
  per-device.

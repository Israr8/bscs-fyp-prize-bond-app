# Pakbond — Prize Bond Checker & Management App

**Pakbond** is a Flutter mobile application for Pakistani prize bond holders. Users can register, save bonds, scan bond numbers with OCR, check results against official draws, buy/sell on a marketplace, and receive win/draw notifications. Admins approve users and upload draw results.

> Final Year Project (FYP) — Flutter + Firebase

---

## Features

### User
- Email/password **registration** & **login** (Firebase Auth)
- **Admin approval** before full access
- **4-digit PIN** lock after login (SHA-256 hashed in Firestore)
- **Guest mode** (limited browsing)
- **My Bonds** — add manually (denomination + date of issue), filter winning/non-winning, auto-check against draws
- **Scan** — camera/gallery + Google ML Kit OCR → extract bond number → check/save
- **Draw Results / Draw Lists** — filter by denomination & date, search bonds
- **Marketplace** — post listings, contact seller, complete sale (bond added to buyer’s My Bonds)
- **Notifications** — draw announcements, winning alerts, marketplace updates (FCM + local)
- **Profile** — view/update account details

### Admin
- Approve / manage pending users
- Upload draw results from text files (`DrawTextParser`)
- View uploaded draws list

---

## Tech Stack

| Layer | Technology |
|--------|------------|
| Framework | Flutter (Dart 3) |
| Auth | Firebase Authentication |
| Database | Cloud Firestore |
| Push | Firebase Cloud Messaging + `flutter_local_notifications` |
| Storage | Firebase Storage (profile images) |
| State | Provider (`AuthService`) |
| OCR | Google ML Kit Text Recognition |
| Other | Camera, image_picker, file_picker, confetti, SharedPreferences |

**No custom backend server** — the app talks to Firebase SDKs directly.

---

## Architecture (high level)

```
┌─────────────────────────────────────────┐
│           Flutter App (UI)              │
│  Screens · AuthService · Notifications  │
└────────────┬───────────────┬────────────┘
             │               │
     Firebase Auth    Cloud Firestore
             │               │
             └───────┬───────┘
                     ▼
              FCM / Storage
```

**Auth routing (`AuthWrapper` in `main.dart`):**

1. Not logged in → Login / Register  
2. Logged in + Admin → Admin Panel  
3. Logged in + pending approval → Pending screen  
4. Approved + PIN locked → PIN screen  
5. Approved + PIN unlocked → Home  

---

## Project structure

```
lib/
├── main.dart                 # Firebase init, Provider, AuthWrapper
├── models/
│   ├── user_model.dart
│   └── market_item.dart
├── services/
│   ├── auth_service.dart     # Login, register, PIN, profile
│   ├── notification_service.dart
│   └── email_service.dart
├── screens/
│   ├── home_screen.dart
│   ├── my_bonds_screen.dart
│   ├── scan_screen.dart
│   ├── draw_results_screen.dart
│   ├── draw_lists_screen.dart
│   ├── marketplace_screen.dart
│   ├── notifications_screen.dart
│   ├── profile_screen.dart
│   ├── guest_home_screen.dart
│   ├── auth/
│   │   ├── login_screen.dart
│   │   ├── register_screen.dart
│   │   └── pin_authentication_screen.dart
│   └── admin/
│       ├── admin_panel_screen.dart
│       ├── upload_draw_screen.dart
│       └── admin_draws_list_screen.dart
├── widgets/
│   ├── bond_item.dart
│   ├── bond_result_card.dart
│   ├── post_item_sheet.dart
│   └── custom_card.dart
└── utils/
    ├── theme.dart
    ├── constants.dart
    └── draw_text_parser.dart
```

Android package / application id: `app.com`

---

## Firestore collections (overview)

| Collection / path | Purpose |
|-------------------|--------|
| `users/{uid}` | Profile, PIN hash, approval, FCM token |
| `users/{uid}/my_bonds/{bondNumber}` | Saved bonds (number, denomination, `issueDate`, winner flags) |
| `draws` | Official draw results (1st / 2nd / 3rd prizes) |
| `draw_announcements` | New-draw announcements for notifications |
| `prize_bonds` | Winning bond lookup (optional matching) |
| `marketplace` | Buy/sell listings |
| `transactions` | Sale records |
| `notifications/{uid}/user_notifications` | In-app notification history |
| `winner_notifications` | Win-related alerts |

Configure **Firestore Security Rules** in the Firebase Console before production use.

---

## Getting started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x)
- Android Studio / VS Code
- A [Firebase](https://console.firebase.google.com/) project
- Android device or emulator **with Google Play**

### 1. Clone the repo

```bash
git clone https://github.com/Israr8/bscs-fyp-prize-bond-app.git
cd bscs-fyp-prize-bond-app
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Firebase setup

1. Create a Firebase project.
2. Add an **Android** app with package name: `app.com`
3. Download `google-services.json` and place it at:

   ```
   android/app/google-services.json
   ```

4. Enable in Firebase Console:
   - **Authentication** → Email/Password  
   - **Cloud Firestore**  
   - **Cloud Messaging**  
   - **Storage** (if using profile images)

5. Create an admin user document under `users/{uid}` with:

   ```json
   {
     "userType": "admin",
     "isApproved": true,
     "status": "approved"
   }
   ```

> **Security tip:** Do not commit real API keys or production `google-services.json` if the repo is public and you want to keep credentials private. Use your own Firebase project for local runs. Rotate keys if they were ever pushed publicly.

### 4. Run the app

```bash
flutter run
```

On some devices (e.g. certain Infinix builds), if you see a blank/white screen with Impeller/Vulkan issues:

```bash
flutter run --no-enable-impeller
```

### 5. App icon (optional)

```bash
dart run flutter_launcher_icons
```

---

## Main user flows

### Register → Approve → Login → PIN → Home
1. User registers → Firestore profile with `status: pending`
2. Admin approves → `isApproved: true`, `status: approved`
3. User logs in → enters PIN → Home

### My Bonds
1. Add bond (manual / scan / marketplace purchase)
2. App listens to `draws` and matches bond numbers by denomination
3. On win → update bond, show notification

### Admin upload draw
1. Pick/upload text file
2. `DrawTextParser` extracts draw data
3. Saved to `draws` (+ announcements / related notifications)

## Dependencies (main)

See `pubspec.yaml` for full versions. Key packages:

- `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_messaging`
- `provider`, `google_mlkit_text_recognition`, `camera`, `image_picker`
- `flutter_local_notifications`, `google_fonts`, `intl`, `file_picker`

---

## Known limitations / future work

- Forgot-password flow may be incomplete
- Production-hardening of Firestore/Storage security rules
- Broader offline UX and error handling
- iOS build/config (project is primarily Android-focused)

---

## Disclaimer

Pakbond is an academic / portfolio project. Prize bond results should be verified against **official National Savings / SBP** sources. This app is not affiliated with the Government of Pakistan.

---

## Author

Built as a Final Year Project with Flutter & Firebase.

---

## License

This project is provided for educational and portfolio use.  
Add a license file (e.g. MIT) if you want others to reuse the code under clear terms.

# 🏍️ Trackie — Real-Time Group Touring & Convoy Location Tracker

**Trackie** is a cross-platform mobile application built with **Flutter**, specifically designed to facilitate coordination, real-time location tracking, and safety for road trip groups (*group touring*, *Sunmori* / Sunday morning rides, car convoys, and cycling clubs).

Powered by **Google Maps**, **Firebase Realtime Database**, and a **Background Foreground Service**, Trackie enables every group member to monitor each other's live positions, connection statuses, and inter-rider distances in real time—even when the phone screen is locked or the app is running in the background.

---

## ✨ Key Value Propositions & Problems Solved

1. **Preventing Riders from Getting Separated**  
   Displays the live locations of all group members along with their actual distance (in meters or kilometers) from the user's position using the Haversine formula.
2. **Uninterrupted Tracking When the Screen is Locked**  
   Utilizes a native *Foreground Service* (`flutter_background_service`) so GPS coordinates continue broadcasting every 5 seconds throughout the trip without being terminated by the operating system.
3. **Instant Emergency Response (SOS Feature)**  
   Provides a one-tap floating emergency button to broadcast an **SOS** distress signal to all group members in the event of an accident, flat tire, or mechanical breakdown.
4. **Effortless Group Coordination**  
   Instant trip group creation with a unique, cryptographically generated 6-character invitation code (`TRG-XXXXXX`)—no need to manually add contacts one by one.
5. **Trip Recap & Documentation**  
   Records trip route histories, distance metrics, average/top speeds, durations, and travel journals, complete with multi-format social sharing (formatted text or high-resolution route card images).

---

## 🧩 Application Modules Breakdown

**Trackie** is organized into **5 core functional modules**:

### 1. Onboarding & User Authentication Module
Handles first-time user introduction, automatic session management, account registration, social sign-in, and password recovery.
- **Interactive Onboarding (`OnboardingPage`)**: Displays 3 introductory slides with image pre-caching and persists completion state in `SharedPreferences` so it only appears on first launch.
- **Session & Auth Guard (`AuthWrapper`)**: Automatically checks authentication state and onboarding history at startup to route users to the appropriate screen.
- **Multi-Method Login (`LoginPage`)**: Supports sign-in via Email & Password, Google Sign-In, and Facebook Login, plus email-based password recovery (*Forgot Password*).
- **User Registration (`SignupPage`)**: Account creation form with validation for full name, email, birth date (*date picker*), international phone number (`CountryCodePicker`), and password.
- **Technical Components**: `AuthProvider`, `AuthService`, `UserModel`.

### 2. Home & Group/Trip Management Module
Acts as the central trip hub for creating new touring sessions as a *Host*, joining active convoys as a *Member*, and viewing upcoming trip schedules.
- **Create Trip (`HomeTab`)**: Creates a new trip group by specifying the group name, destination, and vehicle type (`Motorcycle`, `Car`, `Bicycle`). Automatically generates a unique invitation code (`TRG-XXXXXX`) using a cryptographically secure random generator.
- **Join Trip (`HomeTab`)**: Joins an active trip session using an invitation code shared by the *Host*.
- **Active Trip Banner (`HomeTab`)**: Displays a quick-access banner on the home screen whenever the user is part of an ongoing trip session.
- **Upcoming Trips (`HomeTab`)**: Lists scheduled future trips complete with meeting points, departure times, participant counts, and user roles (`Host` / `Member`).
- **Automated Group Lifecycle Management (`GroupService`)**: Automatically transfers *Host* ownership to the next remaining member if the original host leaves early, and automatically closes the group (`status: 'ended'`) while cleaning up Realtime Database location nodes when the last member leaves.
- **Technical Components**: `MainPage`, `HomeTab`, `GroupProvider`, `GroupService`, `GroupModel`.

### 3. Real-Time Location Tracking, Interactive Map & SOS Module
The core module responsible for visualizing group member positions on the map, broadcasting background GPS updates, calculating distances, and handling emergency alerts.
- **Real-Time Map & Dynamic Status Markers (`MapPage`)**: Renders all group members on Google Maps with color-coded markers reflecting each rider's live state:
  - 🟢 **Green**: Member is *Online* / Connected
  - 🟠 **Orange (Dimmed)**: Member is *Offline* / Signal Lost
  - 🔴 **Red**: Member is in an emergency state (**SOS**)
- **Inter-Member Distance Calculation (`HaversineUtils`)**: Computes the real-time great-circle distance between the user and every other group member in meters (`m`) or kilometers (`km`).
- **Interactive Member Sheet (`DraggableScrollableSheet`)**: Displays a scrollable bottom sheet of all group members with their connection status and distance. Tapping a member smoothly animates the map camera to focus on their position.
- **Emergency Signal / SOS Button (`MapPage` & `LocationProvider`)**: A floating emergency action button with a confirmation dialog that updates the user's status to `sos` in both Firebase RTDB and the background service isolate, triggering high-visibility alerts across all members' screens.
- **Background Location Service (`BackgroundLocationService`)**: Runs in an isolated background thread with a persistent foreground notification to broadcast high-accuracy GPS coordinates every 5 seconds to Firebase RTDB (`active_locations/{groupId}/{uid}`) even when the device is locked.
- **Progressive Permission Management (`PermissionService`)**: Handles step-by-step permission requests for *Foreground Location* (*While Using*), *Background Location* (*Always Allow*), and *Notifications* in compliance with Android 12+/13+ and iOS policies.
- **Technical Components**: `MapPage`, `LocationProvider`, `LocationService`, `BackgroundLocationService`, `PermissionService`, `HaversineUtils`, `MemberLocation`.

### 4. Trip History, Route Details & Social Sharing Module
A trip documentation module for reviewing completed touring sessions and sharing route summaries with friends or social media.
- **Trip History List (`HistoryTab`)**: Displays past trip cards detailing group name, destination, date & time, user role (`Host`/`Member`), total distance (`km`), duration, average speed (`km/h`), and participant count.
- **Route Visualization & Travel Journal (`TripDetailPage`)**: Renders a static map with a route `Polyline` from the start point (green marker) to the end point (red marker) with automatic camera bounds fitting, alongside a travel journal note and star rating.
- **Multi-Format Social Sharing (`TripDetailPage`)**: Shares trip results via an interactive bottom sheet as **Formatted Text**, a **Captured Route Card Image** (converting a `RepaintBoundary` widget into a high-resolution PNG), direct **WhatsApp** share, or clipboard copy.
- **Technical Components**: `HistoryTab`, `TripHistory`, `TripDetailPage`.

### 5. Profile, Account Settings, Privacy & Preferences Module
A personalization module for managing rider identity, location privacy visibility, account security settings, and app appearance/language.
- **Rider Profile & Statistics (`ProfileTab`)**: Displays the user's avatar/initials, full name, vehicle info, join date, summary statistics (*Routes*, *Tracked*, *Places*), and a *Tracking Streak Banner*.
- **Profile Picture Upload & Validation (`AuthService.uploadProfilePicture`)**: Picks an image from the gallery with quality compression, validates file size (max 5 MB), and sanitizes file extensions (`JPG`, `PNG`, `WEBP`) before uploading to Firebase Storage.
- **Ghost Mode (`ProfileTab`)**: A quick privacy toggle on the profile tab to hide the user's location visibility from the group map.
- **Account Management & Security (`AccountPage`)**: Allows editing display name and vehicle details, requesting a password reset link via email, and permanently deleting the account (*Danger Zone*) along with its Firestore data.
- **Language & Theme Preferences (`PreferencesPage`)**: Enables real-time language switching between **Indonesian (`id`)** and **English (`en`)**, as well as theme mode selection (**Light Mode**, **Dark Mode**, or **System Default**).
- **Privacy Policy (`PrivacyPolicyPage`)**: Provides transparent documentation on account data collection, GPS usage, Firebase storage security, and user privacy rights.
- **Technical Components**: `ProfileTab`, `AccountPage`, `PreferencesPage`, `PrivacyPolicyPage`, `LocaleProvider`, `AppTheme`.

---

## 📊 Module Summary Table

| No | Module Name | Key Screens / Components | Primary Function |
| :-: | :--- | :--- | :--- |
| **1** | **Onboarding & Authentication** | `OnboardingPage`, `LoginPage`, `SignupPage`, `AuthWrapper` | App introduction, sign-up, login (Email, Google, Facebook), & password reset. |
| **2** | **Home & Group Management** | `MainPage`, `HomeTab`, `GroupProvider`, `GroupService` | Create trips, generate `TRG-XXXXXX` invite codes, join groups, & view trip schedules. |
| **3** | **Real-Time Tracking & SOS** | `MapPage`, `BackgroundLocationService`, `LocationService` | Live group map, 5-second background GPS broadcasts, Haversine distance, & SOS alarm. |
| **4** | **History & Route Sharing** | `HistoryTab`, `TripDetailPage` | Trip statistics recap, map route `Polyline` visualization, journal ratings, & image/text sharing. |
| **5** | **Profile, Account & Preferences** | `ProfileTab`, `AccountPage`, `PreferencesPage`, `PrivacyPolicyPage` | Edit profile & vehicle, upload avatar, *Ghost Mode*, delete account, language (`ID`/`EN`), & theme (`Light`/`Dark`). |

---

## 🛠️ Tech Stack & Dependencies

- **Framework & Language**: Flutter (Dart `^3.13.3`), Material Design 3
- **State Management**: `provider` (`ChangeNotifier`)
- **Backend & Cloud Services (Firebase)**:
  - `firebase_auth` (`google_sign_in`, `flutter_facebook_auth`) — Multi-provider authentication
  - `cloud_firestore` — Document storage for user profiles (`users`) and trip groups (`groups`)
  - `firebase_database` — Low-latency real-time GPS coordinate streaming (`active_locations`)
  - `firebase_storage` — Cloud storage for user profile avatars
- **Maps, Geolocation & Background Execution**:
  - `google_maps_flutter` — Interactive map rendering, dynamic markers, and route polylines
  - `geolocator` — High-accuracy device GPS positioning
  - `flutter_background_service` & `flutter_local_notifications` — Persistent foreground service for background tracking
  - `permission_handler` — Step-by-step location and notification permission handling
- **UI, Utilities & Localization**:
  - `google_fonts` (Urbanist), `cached_network_image`, `image_picker`, `share_plus`, `country_code_picker`, `shared_preferences`, `intl`, `flutter_localizations`

---

## 📂 Project Directory Structure (`lib/`)

```text
lib/
├── l10n/                          # Localization files (Indonesian & English)
├── models/                        # Data models
│   ├── group_model.dart           # Trip group data model (Firestore)
│   ├── location_model.dart        # Member GPS coordinate & status model (RTDB)
│   ├── onboarding_item.dart       # Onboarding slide content model
│   └── user_model.dart            # User profile data model (Firestore)
├── pages/                         # UI Screens & Tabs
│   ├── account_page.dart          # Account details, password reset, & account deletion
│   ├── history_tab.dart           # Completed trip history list tab
│   ├── home_tab.dart              # Home dashboard, create/join trip modals, & upcoming trips
│   ├── login_page.dart            # Sign-in screen (Email, Google, Facebook)
│   ├── main_page.dart             # Bottom navigation bar scaffold
│   ├── map_page.dart              # Real-time group map, member sheet, & SOS button
│   ├── onboarding_page.dart       # First-time onboarding carousel
│   ├── preferences_page.dart      # Language (ID/EN) & appearance (Light/Dark/System) settings
│   ├── privacy_policy_page.dart   # Privacy Policy screen
│   ├── profile_tab.dart           # Rider profile, stats, streak banner, & Ghost Mode
│   ├── signup_page.dart           # New user registration screen
│   └── trip_detail_page.dart      # Historical route map, travel journal, & share sheet
├── providers/                     # State management (Provider / ChangeNotifier)
│   ├── auth_provider.dart         # Authentication & user profile state
│   ├── group_provider.dart        # Active trip group state
│   ├── locale_provider.dart       # Active locale state (id / en)
│   └── location_provider.dart     # RTDB location stream & background tracking state
├── services/                      # Business logic & external integrations (Firebase / OS)
│   ├── auth_service.dart          # Firebase Auth, Firestore Users, & Storage integration
│   ├── background_location_service.dart # Background isolate & foreground notification service
│   ├── group_service.dart         # Group CRUD operations & unique invite code generator
│   ├── haversine_utils.dart       # Great-circle distance calculator between GPS coordinates
│   ├── location_service.dart      # Firebase RTDB location broadcasting & streaming
│   └── permission_service.dart    # Foreground/background location & notification permissions
├── theme/                         # App color palette, typography, & light/dark themes
├── widgets/                       # Reusable UI components (buttons, text fields, dialogs)
├── app.dart                       # AuthWrapper (initial route guard)
├── firebase_options.dart          # Platform-specific Firebase configuration
└── main.dart                      # Application entry point & service initialization
```

---

## 🚀 Getting Started

1. **Prerequisites**:
   - Flutter SDK (`^3.13.3`)
   - Android Studio / VS Code
   - Firebase configuration (`google-services.json` for Android / `GoogleService-Info.plist` for iOS) & Google Maps API Key.

2. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run the Application**:
   ```bash
   flutter run
   ```

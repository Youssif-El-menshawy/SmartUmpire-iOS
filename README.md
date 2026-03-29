# SmartUmpire 🎾

**SmartUmpire** is a professional iOS application designed to modernize tennis officiating and tournament operations.  
It provides **voice-controlled match scoring**, **tournament management**, **umpire assignment**, and **Excel-based tournament import** to streamline administrative and officiating workflows.

Built with **SwiftUI** and **Firebase**, SmartUmpire is designed for real-world tournament environments where efficiency, accuracy, and speed are critical.

---

## Overview

SmartUmpire supports two main user roles:

- **Admins** – Manage tournaments, matches, and umpire assignments (manually or via Excel import)
- **Umpires** – Officiate matches using live scoring, timers, and voice commands

The system combines tournament management tools with a live officiating interface in one unified platform.

---

## Key Features

### Voice-Controlled Officiating
Umpires can control match flow using voice commands, reducing the need for manual input during live matches.

Supported voice actions include:
- Start / pause timers
- Award points and games
- Handle deuce and advantage
- Set server
- Issue warnings and violations
- Update spoken score
- Undo last action

Voice commands are processed through a speech-to-intent pipeline and applied directly to the match scoring engine.

---

### Tennis Scoring Engine
The app includes a custom tennis scoring engine that supports:

- Point progression (0, 15, 30, 40)
- Deuce and Advantage
- Game and Set tracking
- Tiebreak scoring
- Server switching
- Match event logging

---

### Tournament Management (Admin)
Admins can manage tournaments in two ways:

#### Manual Setup
- Create tournaments
- Create matches
- Assign umpires
- Edit match and tournament details

#### Excel Import
Admins can import an Excel file containing:
- Tournament information
- Match schedule
- Player names
- Court assignments
- Umpire assignments

The system automatically creates tournaments, matches, and assignments from the file, significantly reducing setup time for large tournaments.

---

### Umpire Workflow
Umpires can:
- View assigned tournaments
- View assigned matches
- Start and manage live matches
- Use voice commands during officiating
- Track match score, sets, and timers
- View profile, certifications, and statistics

---

### Timers
Built-in officiating timers include:

| Timer | Duration |
|------|---------|
| Serve Timer | 25 seconds |
| Break Timer | 90 seconds |
| Medical Timeout | 3 minutes |
| Warmup | 5 minutes |

---

### Authentication & Security
- Firebase Authentication
- Face ID lock
- Password reset
- Notifications and reminders

---

## Architecture

The project follows a modular SwiftUI architecture:

```
App
 ├── AppState (Global state management)
 ├── Services (Notifications, AppDelegate)
 ├── Features
 │    ├── Admin
 │    ├── Auth
 │    ├── Umpires
 │    ├── Voice
 │    ├── Settings
 │    └── Onboarding
 ├── Models
 ├── Resources
 └── Config (Firebase)
```

### Voice System Architecture
```
Speech Recognition → Voice Engine → Intent Parser → Intent Dispatcher → Tennis Score Engine → UI Update
```

---

## Tech Stack

| Technology | Use |
|-----------|-----|
| SwiftUI | User Interface |
| Firebase Firestore | Database |
| Firebase Auth | Authentication |
| Firebase Storage | File & Image Storage |
| AVFoundation / Speech | Voice Recognition |
| Combine | Timers & State Updates |
| LocalAuthentication | Face ID |
| XLSX Processing | Excel Import / Reports |

---

## Project Structure

```
SmartUmpire
├── App
├── Services
├── Config
├── Features
│   ├── Admin
│   ├── Auth
│   ├── Onboarding
│   ├── Settings
│   ├── Umpires
│   └── Voice
├── Models
├── Resources
└── XLSX / Reports
```

---

## Getting Started

### 1. Clone the repository


### 2. Open in Xcode
Open the `.xcodeproj` file and build the project.

### 3. Firebase Setup

This project requires a Firebase configuration file to run.

Steps:
1. Create a Firebase project at https://firebase.google.com
2. Add an iOS app to the project
3. Download `GoogleService-Info.plist`
4. Add it to:
   SmartUmpire/Config/

The Firebase config file is not included in this repository for security reasons.

### 4. Permissions Required
Add the following permissions in `Info.plist`:
- Microphone Usage
- Speech Recognition Usage
- Face ID Usage
- Notifications

### 5. Run the App
Run on a simulator or physical device.  
Voice recognition works best on a real device.

---

## Future Improvements
- Match analytics and reporting dashboard
- Advanced Excel validation
- Offline match mode
- Apple Watch integration for umpires
- Expanded voice command recognition
- Tournament admin analytics

---


## License
This project is licensed under the MIT License.

---

## Authors
**Youssif El-menshawy, Youssef Ahmed & Radwan Arnous**

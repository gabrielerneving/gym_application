# 🏋️ Gym App - Comprehensive Workout Tracker

A modern, feature-rich Flutter application for tracking workouts, analyzing progress, and managing training programs with real-time synchronization across devices.

## ✨ Features

### 🎯 **Workout Management**
- Create custom workout programs with multiple exercises
- Track working sets and warm-up sets separately  
- Real-time timer during workout sessions
- Auto-fill previous session data with smart placeholders
- Visual indicators to distinguish warm-up from working sets

### 📊 **Advanced Statistics & Analytics**
- **Exercise Progression**: Interactive charts showing weight progression over time
- **Muscle Group Analysis**: Radar and bar charts for training distribution
- **Workout Statistics**: Monthly summaries, total hours, average duration
- **Popular Programs**: Track most frequently used workout routines

### 🎨 **Modern UI/UX**
- Dark theme optimized for gym environments
- Material Design 3 with subtle red accents
- Smooth animations and intuitive navigation

### 🔥 **Smart Features**
- **Warm-up Set Support**: Separate tracking for warm-up vs working sets
- **Auto-complete**: Smart suggestions based on previous workouts
- **Real-time Sync**: Data syncs instantly across all your devices
- **Offline Support**: Works without internet, syncs when reconnected
- **Exercise Library**: Organized by muscle groups (Chest, Back, Shoulders, Biceps, Triceps, Quads, Hamstrings, Glutes, Calf, Abs)

## 🛠️ Tech Stack

### **Frontend**
- **Flutter** - Cross-platform UI framework
- **Dart** - Programming language
- **Material Design 3** - Modern UI components

### **State Management**
- **Riverpod** - Type-safe, compile-time state management
- Immutable state patterns for reliability
- Reactive updates across the entire app

### **Backend & Database**
- **Firebase Firestore** - NoSQL database with real-time updates
- **Firebase Auth** - User authentication and management

### **Data Visualization**
- **fl_chart** - Interactive charts and graphs
- Custom color-coded muscle group visualization
- Progressive weight tracking with smooth animations

### **Additional Packages**
- `uuid` - Unique ID generation
- `intl` - Internationalization and date formatting
- `firebase_core` - Firebase initialization


## 🏗️ Project Architecture

```
lib/
├── main.dart                 # App entry point with Firebase & Riverpod setup
├── models/                   # Data models (Workout, Exercise, Session)
│   ├── exercise_model.dart
│   ├── master_exercise_model.dart
│   ├── workout_model.dart
│   └── workout_session_model.dart
├── pages/                    # UI screens
│   ├── main_screen.dart      # Bottom navigation
│   ├── home_screen.dart      # Dashboard
│   ├── active_workout_screen.dart
│   ├── statistics_screen.dart
│   ├── create_workout.dart
│   └── ...
├── providers/                # Riverpod state management
│   └── workout_provider.dart
├── services/                 # Business logic
│   ├── database_service.dart
│   └── auth_service.dart
└── widgets/                  # Reusable components
    ├── workout_widget.dart
    ├── stat_card.dart
    ├── progression_chart_widget.dart
    └── ...
```


## 🎯 Key Features Deep Dive

### **Workout Session Management**
- **Active Session Tracking**: Real-time timer with automatic state persistence
- **Smart Data Entry**: Previous session data auto-fills for quick entry
- **Flexible Set Structure**: Support for both warm-up and working sets
- **Progress Indicators**: Visual feedback showing workout completion status

### **Data Visualization**
- **Progressive Overload Tracking**: Line charts showing weight increases over time
- **Muscle Balance Analysis**: Radar charts revealing training imbalances
- **Volume Metrics**: Track total sets, reps, and training frequency
- **Time-based Filtering**: View statistics for different time periods


## 🔒 Security & Privacy

- **Firebase Security Rules**: Proper user data isolation
- **Authentication**: Secure login with Firebase Auth
- **Data Validation**: Client and server-side validation
- **Privacy First**: No tracking, no ads, user data stays private


## 📞 Contact

**Gabriel Erneving**
- GitHub: [@gabrielerneving](https://github.com/gabrielerneving)
- Website: https://gabrielerneving.se

---

*Built with ❤️ 

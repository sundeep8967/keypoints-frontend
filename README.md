# 📱 KeyPoints News App

A beautiful iOS-themed news aggregation app built with Flutter, featuring dynamic color extraction and clean architecture.

## ✨ Features

- **iOS-Native Design** - Cupertino widgets for authentic iOS experience
- **Dynamic Color Extraction** - Cards adapt colors from article images
- **Smart News Feed** - Swipe-based interface similar to popular news apps
- **Category Management** - Customizable news categories
- **Read Article Tracking** - Never see the same article twice
- **Offline Support** - Cached articles for offline reading
- **Clean Architecture** - Scalable, maintainable codebase

## 🚀 Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd keypoints
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

## 📚 Documentation

All project documentation is organized in the `/docs` folder:

- **[Setup Guide](./docs/SETUP.md)** - Complete installation and configuration
- **[Architecture Guide](./docs/ARCHITECTURE.md)** - Clean architecture implementation  
- **[TODO Part 1](./docs/TODO_PART1.md)** - Critical tasks and current priorities
- **[TODO Part 2](./docs/TODO_PART2.md)** - Detailed file audits and issues
- **[Integration Guide](./docs/INTEGRATION.md)** - Feature integration instructions

## 🏗️ Architecture

This project implements **Clean Architecture** with:

```
lib/
├── core/           # Core utilities and abstractions
├── domain/         # Business logic layer
├── data/           # Data layer (repositories, datasources)
├── presentation/   # UI layer (pages, widgets, BLoC)
├── services/       # Application services
└── screens/        # Legacy screens (being migrated)
```

## 🔧 Tech Stack

- **Flutter** - Cross-platform mobile framework
- **Dart** - Programming language
- **BLoC** - State management
- **Supabase** - Backend as a Service
- **Chaquopy** - Python integration for color extraction
- **Clean Architecture** - Scalable code organization

## 🎯 Current Status

- ✅ Core functionality complete
- ✅ iOS design implementation
- ✅ Color extraction feature
- 🔄 Clean architecture migration (50% complete)
- 🔄 BLoC state management implementation
- ⏳ Production optimization and testing

## 🤝 Contributing

1. Check [TODO Part 1](./docs/TODO_PART1.md) for current priorities
2. Read [Architecture Guide](./docs/ARCHITECTURE.md) for code standards
3. Follow clean architecture principles
4. Add tests for new features

## 📄 License

This project is licensed under the MIT License.

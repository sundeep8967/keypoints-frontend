# 📱 Key Points News App - Complete Developer Guide

> **⚠️ IMPORTANT DEVELOPMENT RULES**
> 
> 1. **NO NEW DART FILES** - Only update existing `.dart` files
> 2. **CONSOLIDATE, DON'T FRAGMENT** - Use this single guide instead of creating new `.md` files
> 3. **UPDATE THIS GUIDE** - Add new information here, don't create separate documentation






### Environment Setup
1. **Supabase Configuration**
   - Copy `.env.example` to `.env`
   - Add your Supabase URL and anon key
   - Configure database tables as per schema

2. **AdMob Setup**
   - Test ads work in debug mode automatically
   - Production ads require AdMob account setup
   - Native ads use: `ca-app-pub-1095663786072620/4749169720`
   - Banner ads use: `ca-app-pub-1095663786072620/3038197387`

---

## 🏗️ Architecture Overview

### Clean Architecture Structure
```
lib/
├── core/               # Core utilities and abstractions
│   ├── error/         # Error handling
│   ├── interfaces/    # Abstract interfaces
│   ├── network/       # Network utilities
│   └── usecases/      # Base use case classes
├── domain/            # Business logic layer
│   ├── entities/      # Business entities
│   ├── repositories/  # Repository interfaces
│   └── usecases/      # Business use cases
├── data/              # Data layer
│   ├── datasources/   # Local/Remote data sources
│   ├── models/        # Data models
│   └── repositories/  # Repository implementations
├── presentation/      # UI layer
│   ├── bloc/          # BLoC state management
│   └── widgets/       # Reusable UI components
├── services/          # Application services
│   ├── consolidated/  # Consolidated service layer
│   └── refactored/    # Refactored services
├── screens/           # Legacy screens (being migrated)
└── widgets/           # Legacy widgets (being migrated)
```

### Key Design Principles
- **Single Responsibility** - Each class has one reason to change
- **Dependency Inversion** - Depend on abstractions, not concretions
- **Clean Separation** - Clear boundaries between layers
- **Testability** - Easy to unit test each layer independently

---

## ⚠️ Development Rules

### 🚫 STRICT PROHIBITIONS

1. **NO NEW DART FILES**
   - Only modify existing `.dart` files
   - Consolidate functionality into existing services
   - Use dependency injection for new features

2. **NO NEW MARKDOWN FILES**
   - Update this `DEV_GUIDE.md` instead
   - Delete redundant `.md` files after consolidation
   - Keep documentation centralized

3. **NO CIRCULAR DEPENDENCIES**
   - Services should not import each other directly
   - Use interfaces and dependency injection
   - Follow the established service hierarchy

### ✅ ALLOWED MODIFICATIONS

1. **Update Existing Files**
   - Add methods to existing services
   - Enhance existing widgets
   - Improve existing implementations

2. **Refactor Within Files**
   - Extract methods within same file
   - Improve code organization
   - Optimize performance

3. **Configuration Changes**
   - Update `pubspec.yaml` for dependencies
   - Modify configuration files
   - Update environment variables

---

## 📋 Current Status & TODOs

### ✅ Current Status
- Core news feed with smooth scrolling
- Dynamic color extraction
- Category management
- AdMob integration (production ready)
- Reward points system
- Performance optimized (60fps)

### ⏳ High Priority TODOs

#### 1. **Service Layer Cleanup**
- Consolidate duplicate services in `/services/` folder
- Remove circular dependencies
- Implement proper dependency injection


#### 3. **Performance Optimization**
- Optimize image loading and caching
- Implement lazy loading for categories
- Reduce app startup time

#### 4. **Code Quality**
- Remove duplicate code across services

### 🐛 Known Issues
- Some circular dependencies in service layer
- Memory leaks in image caching
- Test ad references in production code

---

## 🔧 Feature Implementation

### Adding New Features (Within Existing Files)

1. **Identify Target Service**
   - Use existing services in `/services/` folder
   - Follow single responsibility principle
   - Check `/services/consolidated/` for main services

2. **Update Service Interface**
   - Add method to appropriate interface in `/core/interfaces/`
   - Maintain backward compatibility
   - Document new methods

3. **Implement in Service**
   - Add implementation to existing service file
   - Follow established patterns
   - Add proper error handling

4. **Update UI Layer**
   - Modify existing widgets in `/presentation/widgets/`
   - Use BLoC for state management
   - Maintain iOS design consistency

### Key Services Overview

- **`news_service.dart`** - Main news operations
- **`category_service.dart`** - Category management
- **`article_service.dart`** - Article operations
- **`admob_service.dart`** - Ad management
- **`supabase_service.dart`** - Backend operations
- **`local_storage_service.dart`** - Local data persistence




## ⚡ Optimization Guidelines

### Performance Best Practices

1. **Image Optimization**
   - Use optimized assets in `/assets/` folder
   - Implement progressive loading
   - Cache images efficiently

2. **Memory Management**
   - Dispose controllers properly
   - Use const constructors where possible
   - Implement proper widget lifecycle

3. **Network Optimization**
   - Cache API responses
   - Implement retry mechanisms
   - Use connection pooling

4. **Build Optimization**
   - Enable code splitting
   - Use tree shaking
   - Optimize asset bundling

### AdMob Optimization
- Use test ads during development
- Implement proper ad refresh rates
- Handle ad loading failures gracefully
- Monitor ad performance metrics

---

## 🔍 Troubleshooting

### Common Issues

#### 1. **Ad Loading Problems**
- **Symptom**: Ads not displaying
- **Solution**: Check `AdDebugService.printDebugInfo()`
- **Files**: `/services/ad_debug_service.dart`

#### 2. **Circular Dependencies**
- **Symptom**: Build failures, import errors
- **Solution**: Use dependency injection, check service imports
- **Files**: Check all files in `/services/` folder

#### 3. **State Management Issues**
- **Symptom**: UI not updating, inconsistent state
- **Solution**: Verify BLoC implementation, check event handling
- **Files**: `/presentation/bloc/` folder

#### 4. **Performance Issues**
- **Symptom**: Slow app startup, memory leaks
- **Solution**: Profile app, optimize image loading
- **Tools**: Flutter DevTools, memory profiler










```

### Performance Targets
- **App startup**: < 3 seconds
- **News feed load**: < 2 seconds
- **Memory usage**: < 150MB
- **APK size**: < 50MB

---


---



---


### External Resources
- [Flutter Documentation](https://flutter.dev/docs)
- [AdMob Flutter Plugin](https://pub.dev/packages/google_mobile_ads)
- [Supabase Flutter Guide](https://supabase.com/docs/guides/getting-started/tutorials/with-flutter)
- [BLoC Pattern Guide](https://bloclibrary.dev/)

---





---

## 🔧 Common Development Tasks

### Adding New Features (Within Existing Files)
1. **Identify Target Service** - Use existing services in `/services/` folder
2. **Update Service Interface** - Add method to appropriate interface
3. **Implement in Service** - Add implementation following established patterns
4. **Update UI Layer** - Modify existing widgets, use BLoC for state management

### Key Services Overview
- **`news_service.dart`** - Main news operations
- **`category_service.dart`** - Category management
- **`article_service.dart`** - Article operations
- **`admob_service.dart`** - Ad management
- **`supabase_service.dart`** - Backend operations

---

## 🔍 Troubleshooting

### Common Issues
1. **Ad Loading Problems**: Use `AdDebugService.printDebugInfo()` for diagnostics
2. **Performance Issues**: Check image loading and caching services
3. **Build Errors**: Verify dependencies in `pubspec.yaml`
4. **State Issues**: Check BLoC implementation in `/presentation/bloc/`




> ⚠️ IMPORTANT: This is the ONLY development guide. Do not create new .md files!
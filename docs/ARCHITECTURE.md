# Clean Architecture Implementation Guide

## 🏗️ Architecture Overview

This project now implements **Clean Architecture** with the following layers:

```
lib/
├── core/                    # Core utilities and abstractions
│   ├── error/              # Error handling
│   ├── usecases/           # Base use case classes
│   └── network/            # Network utilities
├── domain/                 # Business Logic Layer
│   ├── entities/           # Business entities
│   ├── repositories/       # Repository contracts
│   └── usecases/           # Business use cases
├── data/                   # Data Layer
│   ├── models/             # Data models
│   ├── datasources/        # Data sources (remote/local)
│   └── repositories/       # Repository implementations
├── presentation/           # Presentation Layer
│   ├── bloc/               # State management (BLoC)
│   ├── pages/              # UI pages
│   └── widgets/            # UI widgets
└── injection_container.dart # Dependency injection
```

## 🎯 Key Benefits

### 1. **Separation of Concerns**
- **Domain Layer**: Pure business logic, no dependencies on UI or data sources
- **Data Layer**: Handles data operations and caching
- **Presentation Layer**: UI and state management only

### 2. **Dependency Inversion**
- High-level modules don't depend on low-level modules
- Both depend on abstractions (interfaces)
- Easy to swap implementations (e.g., Supabase → Firebase)

### 3. **Testability**
- Each layer can be tested independently
- Mock implementations for testing
- Business logic is isolated and testable

### 4. **Maintainability**
- Clear structure and responsibilities
- Easy to add new features
- Minimal impact when changing implementations

## 🚀 How to Use

### 1. **Run the Clean Architecture Version**

```bash
# Install new dependencies
flutter pub get

# Run the clean architecture version
flutter run lib/main_clean.dart
```

### 2. **Key Components**

#### **Entities** (Domain Layer)
```dart
// Pure business objects with no dependencies
class NewsArticleEntity {
  final String id;
  final String title;
  final bool isRead;
  // ... business logic only
}
```

#### **Use Cases** (Domain Layer)
```dart
// Single responsibility business operations
class GetNews implements UseCase<List<NewsArticleEntity>, GetNewsParams> {
  final NewsRepository repository;
  
  Future<Either<Failure, List<NewsArticleEntity>>> call(GetNewsParams params);
}
```

#### **Repository Interface** (Domain Layer)
```dart
// Contract for data operations
abstract class NewsRepository {
  Future<Either<Failure, List<NewsArticleEntity>>> getNews({int limit});
  Future<Either<Failure, void>> markArticleAsRead(String articleId);
}
```

#### **Repository Implementation** (Data Layer)
```dart
// Concrete implementation with caching logic
class NewsRepositoryImpl implements NewsRepository {
  final NewsRemoteDataSource remoteDataSource;
  final NewsLocalDataSource localDataSource;
  final NetworkInfo networkInfo;
  
  // Smart caching and offline support
}
```

#### **BLoC State Management** (Presentation Layer)
```dart
// Clean state management with events and states
class NewsBloc extends Bloc<NewsEvent, NewsState> {
  final GetNews getNews;
  final MarkArticleAsRead markArticleAsRead;
  
  // Handles UI events and updates state
}
```

## 🔄 Data Flow

```
UI Widget → BLoC Event → Use Case → Repository → Data Source → API/Cache
                                                      ↓
UI Update ← BLoC State ← Use Case ← Repository ← Data Source ← Response
```

## 🧪 Testing Strategy

### 1. **Unit Tests** (Domain Layer)
```dart
// Test business logic in isolation
test('should return news articles when repository call is successful', () async {
  // Arrange
  when(mockRepository.getNews(any)).thenAnswer((_) async => Right(tNewsArticles));
  
  // Act
  final result = await usecase(GetNewsParams());
  
  // Assert
  expect(result, Right(tNewsArticles));
});
```

### 2. **Integration Tests** (Data Layer)
```dart
// Test data operations and caching
test('should cache news articles after successful remote fetch', () async {
  // Test caching behavior
});
```

### 3. **Widget Tests** (Presentation Layer)
```dart
// Test UI behavior with mocked BLoC
testWidgets('should display loading indicator when state is loading', (tester) async {
  // Test UI states
});
```

## 🔧 Dependency Injection

All dependencies are managed through `GetIt`:

```dart
// Register dependencies
sl.registerFactory(() => NewsBloc(getNews: sl(), markArticleAsRead: sl()));
sl.registerLazySingleton(() => GetNews(sl()));
sl.registerLazySingleton<NewsRepository>(() => NewsRepositoryImpl(
  remoteDataSource: sl(),
  localDataSource: sl(),
  networkInfo: sl(),
));
```

## 🎨 Features Implemented

### ✅ **Smart Caching**
- Automatic offline support
- Intelligent cache invalidation
- Seamless online/offline switching

### ✅ **Error Handling**
- Typed error handling with `Either<Failure, Success>`
- Graceful fallbacks
- User-friendly error messages

### ✅ **State Management**
- BLoC pattern for predictable state
- Event-driven architecture
- Optimistic updates

### ✅ **Performance**
- Lazy loading
- Image caching
- Efficient memory usage

## 🔄 Migration from Old Architecture

### Before (Tightly Coupled)
```dart
// UI directly calling services
class NewsFeedScreen extends StatefulWidget {
  void _loadNews() {
    SupabaseService.getNews().then((articles) {
      setState(() => _articles = articles);
    });
  }
}
```

### After (Clean Architecture)
```dart
// UI using BLoC with dependency injection
class NewsFeedPage extends StatefulWidget {
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<NewsBloc>()..add(LoadNewsEvent()),
      child: BlocBuilder<NewsBloc, NewsState>(
        builder: (context, state) => _buildUI(state),
      ),
    );
  }
}
```

## 🚀 Next Steps

1. **Run the clean version**: `flutter run lib/main_clean.dart`
2. **Compare with old version**: `flutter run lib/main.dart`
3. **Add tests**: Create test files for each layer
4. **Extend features**: Add new use cases following the pattern

## 📁 File Structure Comparison

### Old Structure (Mixed Responsibilities)
```
lib/
├── services/           # Everything mixed together
│   ├── supabase_service.dart
│   ├── local_storage_service.dart
│   ├── news_loading_service.dart
│   └── ... (12+ service files)
└── screens/           # UI with business logic
```

### New Structure (Clean Separation)
```
lib/
├── core/              # Shared utilities
├── domain/            # Business logic only
├── data/              # Data handling only
├── presentation/      # UI only
└── injection_container.dart
```

## 🎯 Benefits Achieved

1. **Testability**: Each layer can be tested independently
2. **Maintainability**: Clear separation of concerns
3. **Scalability**: Easy to add new features
4. **Flexibility**: Easy to swap implementations
5. **Reliability**: Better error handling and offline support

The clean architecture provides a solid foundation for scaling your news app while maintaining code quality and developer productivity.
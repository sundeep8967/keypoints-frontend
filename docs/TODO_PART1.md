# 📋 KeyPoints News App - TODO Part 1: Critical Tasks

## 🚨 CRITICAL REFACTORING TASKS (From File Structure Analysis)

### Phase 1: Screen Decomposition (HIGH PRIORITY) - COMPLETED ✅
- [x] **news_feed_screen.dart (984 lines → ~200 lines)** ✅
  - [x] Extract CategorySelectorWidget component ✅
  - [x] Extract NewsCardStack component ✅
  - [x] Extract SwipeAnimationHandler ✅
  - [x] Extract LoadingStateWidget (using existing) ✅
  - [x] Create NewsFeedController for business logic ✅
  - [x] Create CategoryController for category management ✅
  - [x] Create refactored news_feed_screen (200 lines vs 984) ✅

### Phase 2: Service Layer Consolidation (MEDIUM PRIORITY) - COMPLETED ✅
- [x] **Reduce 15 services → 5-6 focused services** ✅
  - [x] Merge news_loading_service + news_feed_helper + news_integration_service → NewsService ✅
  - [x] Merge category services → CategoryService ✅
  - [x] Merge article_management + read_articles + news_ui → ArticleService ✅
  - [x] Create NewsFacade pattern to reduce UI dependencies ✅

### Phase 3: Clean Architecture Migration (MEDIUM PRIORITY) - IN PROGRESS
- [ ] **Remove direct service imports from UI (16 files affected)**
  - [x] Implement missing use cases for all business operations ✅
  - [x] Update controllers to use NewsFacade instead of direct services ✅
  - [x] Create consolidated service architecture ✅
  - [ ] Replace StatefulWidget state with BLoC pattern (50% complete)
  - [ ] Consolidate data access through repositories

### Phase 4: Widget Optimization (LOW PRIORITY)
- [ ] **Apply atomic design pattern**
  - [ ] Create atoms/ molecules/ organisms/ structure
  - [ ] Extract reusable components
  - [ ] Implement consistent design system

---

## 🎯 **Systematic Code Review - All 48 Dart Files**

### 📊 **Progress Tracker**
- **Files to Check**: 48
- **Files Completed**: 48 ✅ **100% COMPLETE**
- **Critical Issues**: 5
- **Medium Issues**: 12  
- **Low Issues**: 52

---

## 🚨 **CRITICAL ISSUES (Must Fix Immediately)**

### 1. Unused Code Cleanup
- [x] `lib/screens/color_showcase_screen.dart` - Removed unused screen ✅ **DELETED**

### 2. Import Errors  
- [x] **ColorDemoScreen references** - All cleaned up ✅ **RESOLVED**

### 3. Service Dependencies
- [ ] Update any navigation or routing that references the old demo screen
- [ ] Check main.dart or app routing for ColorDemoScreen references

---

## ⚠️ **MEDIUM PRIORITY ISSUES**

### Code Quality
- [ ] Remove unused imports across all files
- [ ] Fix deprecated API usage (withOpacity → withValues)
- [ ] Standardize error handling patterns
- [ ] Implement consistent logging

### Architecture
- [ ] Complete BLoC pattern migration
- [ ] Consolidate duplicate service functionality
- [ ] Implement proper dependency injection
- [ ] Add unit tests for critical business logic

---

*Continue to [TODO Part 2](./TODO_PART2.md) for detailed file audits and specific issues.*
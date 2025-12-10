import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../data/services/local_storage_service.dart';
import '../../../data/services/streaks_service.dart';
import 'contact_us_screen.dart';

import '../../../core/utils/app_logger.dart';
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  String? _selectedLanguage;
  List<String> _selectedCategories = [];
  int _currentStreak = 0;
  int _longestStreak = 0;
  int _weeklyStreak = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh settings when app becomes active (user returns to app)
    if (state == AppLifecycleState.resumed) {
      _loadSettings();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh settings every time this screen becomes visible
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final language = await LocalStorageService.getLanguagePreference();
      final categories = await LocalStorageService.getCategoryPreferences();
      final streakStats = await StreaksService.instance.getStreakStats();
      
      AppLogger.debug(' SETTINGS: Loaded categories from storage: $categories');
      AppLogger.debug(' SETTINGS: Categories count: ${categories.length}');
      AppLogger.debug(' SETTINGS: Streak stats: $streakStats');
      
      if (mounted) {
        setState(() {
          _selectedLanguage = language ?? 'English';
          _selectedCategories = categories;
          _currentStreak = streakStats['currentStreak'] ?? 0;
          _longestStreak = streakStats['longestStreak'] ?? 0;
          _weeklyStreak = streakStats['weeklyStreak'] ?? 0;
        });
      }
    } catch (e) {
      AppLogger.error(' SETTINGS: Error loading settings: $e');
    }
  }

  /// Manual refresh method for pull-to-refresh or button tap
  Future<void> _refreshSettings() async {
    AppLogger.info(' SETTINGS: Manual refresh triggered');
    await _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black,
        border: null,
        middle: Text(
          'Settings',
          style: TextStyle(
            color: CupertinoColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: _refreshSettings,
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildSection(
                    'Preferences',
                    [
                      _buildSettingItem(
                        'Language',
                        _selectedLanguage ?? 'English',
                        CupertinoIcons.globe,
                        () => _showLanguageSelector(),
                      ),
                      _buildSettingItem(
                        'Categories',
                        _selectedCategories.isEmpty 
                          ? 'All categories' 
                          : '${_selectedCategories.length} selected',
                        CupertinoIcons.tag,
                        () => _showCategorySelector(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  _buildSection(
                    'Streaks',
                    [
                      _buildStreakCard(),
                    ],
                  ),
                  const SizedBox(height: 30),
                  _buildSection(
                    'About',
                    [
                      _buildSettingItem(
                        'Contact Us',
                        '',
                        CupertinoIcons.mail,
                        () => _navigateToContactUs(),
                      ),
                    ],
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: CupertinoColors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6.darkColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingItem(String title, String value, IconData icon, VoidCallback onTap) {
    return CupertinoListTile(
      leading: Icon(icon, color: CupertinoColors.systemBlue),
      title: Text(
        title,
        style: const TextStyle(color: CupertinoColors.white),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: CupertinoColors.systemGrey,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            CupertinoIcons.chevron_right,
            color: CupertinoColors.systemGrey,
            size: 16,
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildStreakCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Daily Streaks Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStreakStat(
                '🔥',
                _currentStreak.toString(),
                'Daily Streak',
                CupertinoColors.systemOrange,
              ),
              Container(
                width: 1,
                height: 60,
                color: CupertinoColors.systemGrey5,
              ),
              _buildStreakStat(
                '🏆',
                _longestStreak.toString(),
                'Best Daily',
                CupertinoColors.systemYellow,
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Weekly Streak (centered)
          Center(
            child: _buildStreakStat(
              '📅',
              '$_weeklyStreak',
              'This Week',
              CupertinoColors.systemPurple,
            ),
          ),
          const SizedBox(height: 16),
          
          // Info Message
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.info_circle_fill,
                  color: CupertinoColors.systemBlue,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _weeklyStreak == 0
                        ? 'Use the app for 7+ minutes daily to build your streak!'
                        : _weeklyStreak == 7 
                          ? '🎉 Sunday reached! Week completed, resets on Monday.'
                          : 'Current: ${_getDayName(_weeklyStreak)}. Use 7+ min daily to progress.',
                    style: const TextStyle(
                      color: CupertinoColors.systemBlue,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakStat(String emoji, String value, String label, Color color) {
    return Column(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 32),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: CupertinoColors.systemGrey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }



  void _navigateToContactUs() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => const ContactUsScreen(),
      ),
    );
  }

  void _showLanguageSelector() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Select Language'),
        message: const Text('Choose your preferred language for the app'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              _updateLanguage('Kannada');
              Navigator.pop(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🇮🇳 Kannada'),
                if (_selectedLanguage == 'Kannada') 
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(CupertinoIcons.check_mark, size: 16),
                  ),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              _updateLanguage('English');
              Navigator.pop(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🇺🇸 English'),
                if (_selectedLanguage == 'English') 
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(CupertinoIcons.check_mark, size: 16),
                  ),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              _updateLanguage('Hindi');
              Navigator.pop(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🇮🇳 Hindi'),
                if (_selectedLanguage == 'Hindi') 
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(CupertinoIcons.check_mark, size: 16),
                  ),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              _updateLanguage('Telugu');
              Navigator.pop(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🇮🇳 Telugu'),
                if (_selectedLanguage == 'Telugu') 
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(CupertinoIcons.check_mark, size: 16),
                  ),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              _updateLanguage('Tamil');
              Navigator.pop(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🇮🇳 Tamil'),
                if (_selectedLanguage == 'Tamil') 
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(CupertinoIcons.check_mark, size: 16),
                  ),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              _updateLanguage('Malayalam');
              Navigator.pop(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🇮🇳 Malayalam'),
                if (_selectedLanguage == 'Malayalam') 
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(CupertinoIcons.check_mark, size: 16),
                  ),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showCategorySelector() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => _CategorySelectionScreen(
          selectedCategories: _selectedCategories,
          onCategoriesChanged: (categories) {
            AppLogger.debug(' SETTINGS: Categories changed to: $categories');
            AppLogger.debug(' SETTINGS: New count: ${categories.length}');
            setState(() {
              _selectedCategories = categories;
            });
            LocalStorageService.setCategoryPreferences(categories);
          },
        ),
      ),
    ).then((_) {
      // Refresh settings when returning from category selection
      AppLogger.debug(' SETTINGS: Returned from category selection, reloading...');
      _loadSettings();
    });
  }

  void _updateLanguage(String language) async {
    await LocalStorageService.setLanguagePreference(language);
    setState(() {
      _selectedLanguage = language;
    });
    
    // Show confirmation
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Language Updated'),
        content: Text('Language has been set to $language. Some changes may require app restart.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  String _getDayName(int dayNumber) {
    switch (dayNumber) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return 'Unknown';
    }
  }
}

class _CategorySelectionScreen extends StatefulWidget {
  final List<String> selectedCategories;
  final Function(List<String>) onCategoriesChanged;

  const _CategorySelectionScreen({
    required this.selectedCategories,
    required this.onCategoriesChanged,
  });

  @override
  State<_CategorySelectionScreen> createState() => _CategorySelectionScreenState();
}

class _CategorySelectionScreenState extends State<_CategorySelectionScreen> {
  late Set<String> _selectedCategories;

  final List<Map<String, dynamic>> _availableCategories = [
    {'name': 'Technology', 'icon': CupertinoIcons.device_laptop, 'description': 'Tech news, gadgets, and innovations'},
    {'name': 'Business', 'icon': CupertinoIcons.briefcase, 'description': 'Market updates and business news'},
    {'name': 'Sports', 'icon': CupertinoIcons.sportscourt, 'description': 'Sports news and updates'},
    {'name': 'Health', 'icon': CupertinoIcons.heart, 'description': 'Health and wellness news'},
    {'name': 'Science', 'icon': CupertinoIcons.lab_flask, 'description': 'Scientific discoveries and research'},
    {'name': 'Entertainment', 'icon': CupertinoIcons.tv, 'description': 'Movies, music, and celebrity news'},
    {'name': 'World', 'icon': CupertinoIcons.globe, 'description': 'International news and events'},
    {'name': 'Politics', 'icon': CupertinoIcons.building_2_fill, 'description': 'Political news and updates'},
    {'name': 'Education', 'icon': CupertinoIcons.book, 'description': 'Education and learning news'},
    {'name': 'Travel', 'icon': CupertinoIcons.airplane, 'description': 'Travel news and destinations'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategories = Set.from(widget.selectedCategories);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black,
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        middle: const Text(
          'Select Categories',
          style: TextStyle(
            color: CupertinoColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('Save'),
          onPressed: () {
            widget.onCategoriesChanged(_selectedCategories.toList());
            Navigator.pop(context);
          },
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose Your Interests',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedCategories.isEmpty 
                      ? 'Select categories to personalize your news feed. Leave empty to see all categories.'
                      : '${_selectedCategories.length} categories selected',
                    style: const TextStyle(
                      color: CupertinoColors.systemGrey,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_selectedCategories.isNotEmpty)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setState(() {
                          _selectedCategories.clear();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: CupertinoColors.destructiveRed.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Clear All',
                          style: TextStyle(
                            color: CupertinoColors.destructiveRed,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _availableCategories.length,
                itemBuilder: (context, index) {
                  final category = _availableCategories[index];
                  final isSelected = _selectedCategories.contains(category['name']);
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isSelected 
                        ? CupertinoColors.systemBlue.withOpacity(0.2)
                        : CupertinoColors.systemGrey6.darkColor,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected 
                        ? Border.all(color: CupertinoColors.systemBlue, width: 2)
                        : null,
                    ),
                    child: CupertinoListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected 
                            ? CupertinoColors.systemBlue
                            : CupertinoColors.systemGrey,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          category['icon'],
                          color: CupertinoColors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        category['name'],
                        style: TextStyle(
                          color: isSelected 
                            ? CupertinoColors.systemBlue
                            : CupertinoColors.white,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        category['description'],
                        style: const TextStyle(
                          color: CupertinoColors.systemGrey,
                          fontSize: 14,
                        ),
                      ),
                      trailing: isSelected 
                        ? const Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            color: CupertinoColors.systemBlue,
                          )
                        : const Icon(
                            CupertinoIcons.circle,
                            color: CupertinoColors.systemGrey,
                          ),
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedCategories.remove(category['name']);
                          } else {
                            _selectedCategories.add(category['name']);
                          }
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
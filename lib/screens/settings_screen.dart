import 'package:flutter/cupertino.dart';
import '../services/local_storage_service.dart';
import '../services/read_articles_service.dart';
import '../services/reward_points_service.dart';
import '../widgets/points_display_widget.dart';
import 'contact_us_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _selectedLanguage;
  List<String> _selectedCategories = [];
  int _readArticlesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final language = await LocalStorageService.getLanguagePreference();
    final categories = await LocalStorageService.getCategoryPreferences();
    final readCount = await ReadArticlesService.getReadCount();
    
    print('DEBUG SETTINGS: Loaded categories from storage: $categories');
    print('DEBUG SETTINGS: Categories count: ${categories.length}');
    
    setState(() {
      _selectedLanguage = language ?? 'English';
      _selectedCategories = categories;
      _readArticlesCount = readCount;
    });
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
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
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
              'Reward Points',
              [
                _buildPointsSection(),
              ],
            ),
            const SizedBox(height: 30),
            _buildSection(
              'Statistics',
              [
                _buildInfoItem(
                  'Articles Read',
                  '$_readArticlesCount',
                  CupertinoIcons.book,
                ),
                _buildInfoItem(
                  'App Version',
                  '1.0.0',
                  CupertinoIcons.info,
                ),
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
            const SizedBox(height: 30),
            _buildSection(
              'Actions',
              [
                _buildActionItem(
                  'Clear Read History',
                  'Reset all read articles',
                  CupertinoIcons.clear,
                  () => _clearReadHistory(),
                  isDestructive: true,
                ),
                _buildActionItem(
                  'Reset App',
                  'Clear all data and restart setup',
                  CupertinoIcons.refresh,
                  () => _resetApp(),
                  isDestructive: true,
                ),
              ],
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

  Widget _buildInfoItem(String title, String value, IconData icon) {
    return CupertinoListTile(
      leading: Icon(icon, color: CupertinoColors.systemGrey),
      title: Text(
        title,
        style: const TextStyle(color: CupertinoColors.white),
      ),
      trailing: Text(
        value,
        style: const TextStyle(
          color: CupertinoColors.systemGrey,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildActionItem(String title, String subtitle, IconData icon, VoidCallback onTap, {bool isDestructive = false}) {
    return CupertinoListTile(
      leading: Icon(
        icon, 
        color: isDestructive ? CupertinoColors.destructiveRed : CupertinoColors.systemBlue,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? CupertinoColors.destructiveRed : CupertinoColors.white,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: CupertinoColors.systemGrey,
          fontSize: 14,
        ),
      ),
      onTap: onTap,
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
            print('DEBUG SETTINGS: Categories changed to: $categories');
            print('DEBUG SETTINGS: New count: ${categories.length}');
            setState(() {
              _selectedCategories = categories;
            });
            LocalStorageService.setCategoryPreferences(categories);
          },
        ),
      ),
    ).then((_) {
      // Refresh settings when returning from category selection
      print('DEBUG SETTINGS: Returned from category selection, reloading...');
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

  void _clearReadHistory() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Clear Read History'),
        content: const Text('This will mark all articles as unread. Are you sure?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Clear'),
            onPressed: () async {
              await ReadArticlesService.clearAllRead();
              await _loadSettings();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _resetApp() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Reset App'),
        content: const Text('This will clear all data and restart the app setup. Are you sure?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Reset'),
            onPressed: () async {
              await LocalStorageService.resetFirstTimeSetup();
              await ReadArticlesService.clearAllRead();
              Navigator.pop(context);
              // Would restart the app or navigate to language selection
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPointsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const PointsDisplayWidget(showDetailed: true),
    );
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
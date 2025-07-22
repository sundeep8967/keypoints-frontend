import 'package:flutter/cupertino.dart';
import '../services/local_storage_service.dart';
import '../services/read_articles_service.dart';

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
                  '${_selectedCategories.length} selected',
                  CupertinoIcons.tag,
                  () => _showCategorySelector(),
                ),
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

  void _showLanguageSelector() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Select Language'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              _updateLanguage('English');
              Navigator.pop(context);
            },
            child: const Text('English'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              _updateLanguage('Hindi');
              Navigator.pop(context);
            },
            child: const Text('Hindi'),
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
    // Navigate to category preferences screen
    // This would open the existing category preferences screen
  }

  void _updateLanguage(String language) async {
    await LocalStorageService.setLanguagePreference(language);
    setState(() {
      _selectedLanguage = language;
    });
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
}
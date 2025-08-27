import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/cupertino.dart';

import '../utils/app_logger.dart';
/// Service for handling URL launching functionality
class UrlLauncherService {
  /// Launch a URL directly in internal browser without confirmation
  static Future<bool> launchInternalBrowser(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      AppLogger.info(' Opening URL in internal browser: $url');
      
      // Open directly in internal browser
      return await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (e) {
      AppLogger.log('Error opening URL in internal browser: $e');
      return false;
    }
  }

  /// Launch a URL in the default browser
  static Future<bool> launchArticleUrl(String? url) async {
    if (url == null || url.isEmpty) {
      return false;
    }

    try {
      final Uri uri = Uri.parse(url);
      AppLogger.info(' Attempting to launch URL: $url');
      
      // Try different launch modes for better Android compatibility
      try {
        AppLogger.info(' Trying externalApplication mode...');
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e1) {
        AppLogger.error(' externalApplication failed: $e1');
        try {
          AppLogger.info(' Trying platformDefault mode...');
          return await launchUrl(uri, mode: LaunchMode.platformDefault);
        } catch (e2) {
          AppLogger.error(' platformDefault failed: $e2');
          try {
            AppLogger.info(' Trying inAppBrowserView mode...');
            return await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
          } catch (e3) {
            AppLogger.error(' All launch modes failed');
            return false;
          }
        }
      }
    } catch (e) {
      AppLogger.log('Error parsing or launching URL: $e');
      return false;
    }
  }

  /// Show a confirmation dialog before launching URL
  static Future<void> showLaunchConfirmation(
    BuildContext context, 
    String? url, 
    String articleTitle
  ) async {
    AppLogger.info(' showLaunchConfirmation called with URL: "$url"');
    
    if (url == null || url.isEmpty) {
      AppLogger.error(' URL is null or empty');
      _showErrorDialog(context, 'No source URL available for this article.');
      return;
    }
    
    AppLogger.success(' Showing confirmation dialog for URL: $url');

    final bool? shouldLaunch = await showCupertinoDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Open Article'),
          content: Text('Open the full article "${articleTitle}" in your browser?'),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Open'),
            ),
          ],
        );
      },
    );

    if (shouldLaunch == true) {
      final success = await launchArticleUrl(url);
      if (!success && context.mounted) {
        _showErrorDialog(context, 'Could not open the article. Please try again.');
      }
    }
  }

  /// Show error dialog when URL launch fails
  static void _showErrorDialog(BuildContext context, String message) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
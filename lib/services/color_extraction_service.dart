import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';

class ColorExtractionService {
  static const MethodChannel _channel = MethodChannel('color_extraction');

  /// Extract dominant color from image URL
  static Future<Color> extractDominantColorFromUrl(String imageUrl) async {
    try {
      // Download image to local storage
      final localPath = await _downloadImage(imageUrl);
      if (localPath == null) {
        return const Color(0xFF4B5563); // Fallback color
      }

      // Extract color using Python
      final colorHex = await _channel.invokeMethod('extractDominantColor', {
        'imagePath': localPath,
      });

      // Convert hex to Color
      return _hexToColor(colorHex ?? '#4B5563');
    } catch (e) {
      print('Error extracting color: $e');
      return const Color(0xFF4B5563); // Fallback color
    }
  }

  /// Extract color palette from image URL
  static Future<List<Color>> extractColorPaletteFromUrl(String imageUrl, {int colorCount = 5}) async {
    try {
      // Download image to local storage
      final localPath = await _downloadImage(imageUrl);
      if (localPath == null) {
        return _getFallbackPalette();
      }

      // Extract palette using Python
      final paletteHex = await _channel.invokeMethod('extractColorPalette', {
        'imagePath': localPath,
        'colorCount': colorCount,
      });

      if (paletteHex is List) {
        return paletteHex.map<Color>((hex) => _hexToColor(hex)).toList();
      }

      return _getFallbackPalette();
    } catch (e) {
      print('Error extracting palette: $e');
      return _getFallbackPalette();
    }
  }

  /// Download image from URL to local storage
  static Future<String?> _downloadImage(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final fileName = imageUrl.split('/').last.split('?').first;
        final file = File('${directory.path}/temp_$fileName');
        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      }
    } catch (e) {
      print('Error downloading image: $e');
    }
    return null;
  }

  /// Convert hex string to Color
  static Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex'; // Add alpha channel
    }
    return Color(int.parse(hex, radix: 16));
  }

  /// Get fallback color palette
  static List<Color> _getFallbackPalette() {
    return [
      const Color(0xFF4B5563),
      const Color(0xFF6B7280),
      const Color(0xFF9CA3AF),
      const Color(0xFFD1D5DB),
      const Color(0xFFF3F4F6),
    ];
  }

  /// Calculate if text should be light or dark based on background color
  static Color getContrastingTextColor(Color backgroundColor) {
    // Calculate luminance
    final luminance = (0.299 * backgroundColor.red + 
                     0.587 * backgroundColor.green + 
                     0.114 * backgroundColor.blue) / 255;
    
    // Return white text for dark backgrounds, black for light backgrounds
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  /// Get a slightly transparent version of the color for overlays
  static Color getOverlayColor(Color baseColor, {double opacity = 0.8}) {
    return baseColor.withOpacity(opacity);
  }
}
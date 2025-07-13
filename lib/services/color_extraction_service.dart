import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';

class ColorExtractionService {
  static final Map<String, ColorPalette> _cache = {};

  /// Extract a dynamic color palette from an image URL
  static Future<ColorPalette> extractColorsFromImage(String imageUrl) async {
    // Check cache first
    if (_cache.containsKey(imageUrl)) {
      return _cache[imageUrl]!;
    }

    try {
      // Try to extract colors from actual image
      final palette = await _extractColorsFromNetworkImage(imageUrl);
      _cache[imageUrl] = palette;
      return palette;
    } catch (e) {
      print('Failed to extract colors from image: $e');
      // Fallback to URL-based generation
      try {
        final palette = _generatePaletteFromUrl(imageUrl);
        _cache[imageUrl] = palette;
        return palette;
      } catch (e2) {
        // Final fallback to default palette
        final fallback = ColorPalette.defaultPalette();
        _cache[imageUrl] = fallback;
        return fallback;
      }
    }
  }

  /// Extract colors from actual network image
  static Future<ColorPalette> _extractColorsFromNetworkImage(String imageUrl) async {
    try {
      // Download image
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download image');
      }

      // Decode image
      final img.Image? image = img.decodeImage(response.bodyBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Extract colors using advanced algorithm
      final extractedColors = await _extractColorsFromImage(image);
      
      return ColorPalette(
        primary: extractedColors.primary,
        secondary: extractedColors.secondary,
        accent: extractedColors.accent,
        background: extractedColors.primary.withOpacity(0.1),
        surface: extractedColors.primary.withOpacity(0.05),
        onPrimary: extractedColors.textColor,
        onSecondary: extractedColors.textColor,
        onAccent: extractedColors.textColor,
      );
    } catch (e) {
      throw Exception('Color extraction failed: $e');
    }
  }

  /// Advanced color extraction from image using the sophisticated algorithm
  static Future<ExtractedColors> _extractColorsFromImage(img.Image image) async {
    // Resize image for faster processing
    final resized = img.copyResize(image, width: 100, height: 100);
    
    Map<String, int> colorCounts = {};
    
    // Sample pixels and count colors
    for (int y = 0; y < resized.height; y += 2) {
      for (int x = 0; x < resized.width; x += 2) {
        final pixel = resized.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        final a = pixel.a.toInt();
        
        if (a > 128) {
          // Round colors to reduce similar shades
          final roundedR = (r ~/ 20) * 20;
          final roundedG = (g ~/ 20) * 20;
          final roundedB = (b ~/ 20) * 20;
          
          final key = '$roundedR,$roundedG,$roundedB';
          colorCounts[key] = (colorCounts[key] ?? 0) + 1;
        }
      }
    }
    
    // Sort by frequency and filter
    final sortedColors = colorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final filteredColors = sortedColors.where((entry) {
      final parts = entry.key.split(',');
      final r = int.parse(parts[0]);
      final g = int.parse(parts[1]);
      final b = int.parse(parts[2]);
      
      final brightness = (r + g + b) / 3;
      final saturation = _getSaturation(r, g, b);
      
      return brightness > 40 && brightness < 200 && saturation > 0.3;
    }).take(10).toList();
    
    if (filteredColors.isEmpty) {
      return _getDefaultExtractedColors();
    }
    
    // Extract primary color
    final primaryParts = filteredColors.first.key.split(',');
    final primaryColor = Color.fromARGB(
      255,
      int.parse(primaryParts[0]),
      int.parse(primaryParts[1]),
      int.parse(primaryParts[2]),
    );
    
    // Find secondary color
    Color? secondaryColor;
    for (final entry in filteredColors.skip(1)) {
      final parts = entry.key.split(',');
      final r = int.parse(parts[0]);
      final g = int.parse(parts[1]);
      final b = int.parse(parts[2]);
      
      final distance = _colorDistance(
        primaryColor.red, primaryColor.green, primaryColor.blue,
        r, g, b,
      );
      
      if (distance > 100 && distance < 300) {
        secondaryColor = Color.fromARGB(255, r, g, b);
        break;
      }
    }
    
    secondaryColor ??= _adjustColor(primaryColor, 0.3);
    
    // Find accent color
    Color? accentColor;
    for (final entry in filteredColors.skip(2)) {
      final parts = entry.key.split(',');
      final r = int.parse(parts[0]);
      final g = int.parse(parts[1]);
      final b = int.parse(parts[2]);
      
      final primaryDistance = _colorDistance(
        primaryColor.red, primaryColor.green, primaryColor.blue,
        r, g, b,
      );
      final secondaryDistance = _colorDistance(
        secondaryColor.red, secondaryColor.green, secondaryColor.blue,
        r, g, b,
      );
      
      if (primaryDistance > 80 && secondaryDistance > 80) {
        accentColor = Color.fromARGB(255, r, g, b);
        break;
      }
    }
    
    accentColor ??= _adjustColor(primaryColor, -0.2);
    
    final textColor = _getTextColor(primaryColor);
    
    return ExtractedColors(
      primary: primaryColor,
      secondary: secondaryColor,
      accent: accentColor,
      textColor: textColor,
    );
  }

  static double _getSaturation(int r, int g, int b) {
    final max = [r, g, b].reduce((a, b) => a > b ? a : b);
    final min = [r, g, b].reduce((a, b) => a < b ? a : b);
    return max == 0 ? 0 : (max - min) / max;
  }

  static double _colorDistance(int r1, int g1, int b1, int r2, int g2, int b2) {
    return sqrt(pow(r1 - r2, 2) + pow(g1 - g2, 2) + pow(b1 - b2, 2));
  }

  static Color _adjustColor(Color color, double factor) {
    final r = (color.red + (color.red * factor)).clamp(0, 255).toInt();
    final g = (color.green + (color.green * factor)).clamp(0, 255).toInt();
    final b = (color.blue + (color.blue * factor)).clamp(0, 255).toInt();
    return Color.fromARGB(255, r, g, b);
  }

  static Color _getTextColor(Color backgroundColor) {
    final luminance = (0.299 * backgroundColor.red + 
                     0.587 * backgroundColor.green + 
                     0.114 * backgroundColor.blue) / 255;
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  static ExtractedColors _getDefaultExtractedColors() {
    return ExtractedColors(
      primary: const Color(0xFF667EEA),
      secondary: const Color(0xFF764BA2),
      accent: const Color(0xFF8B5FBF),
      textColor: Colors.white,
    );
  }

  /// Generate a beautiful color palette from URL hash (fallback method)
  static ColorPalette _generatePaletteFromUrl(String url) {
    // Create hash from URL
    final bytes = utf8.encode(url);
    final hash = bytes.fold(0, (prev, element) => prev + element);
    
    // Generate more vibrant and diverse colors
    final hue = (hash % 360).toDouble();
    final saturation = 0.75 + (hash % 25) / 100; // 0.75-1.0 for more vibrant colors
    final lightness = 0.45 + (hash % 30) / 100; // 0.45-0.75 for better contrast
    
    // Create primary color with higher saturation
    final primaryHSL = HSLColor.fromAHSL(1.0, hue, saturation, lightness);
    final primary = primaryHSL.toColor();
    
    // Generate more diverse complementary colors
    final secondary = HSLColor.fromAHSL(1.0, (hue + 60) % 360, saturation * 0.85, lightness * 1.15).toColor();
    final accent = HSLColor.fromAHSL(1.0, (hue + 120) % 360, saturation * 0.9, lightness * 0.8).toColor();
    
    // Create themed background colors
    final background = HSLColor.fromAHSL(1.0, hue, saturation * 0.15, 0.97).toColor();
    final surface = HSLColor.fromAHSL(1.0, hue, saturation * 0.08, 0.99).toColor();
    
    return ColorPalette(
      primary: primary,
      secondary: secondary,
      accent: accent,
      background: background,
      surface: surface,
      onPrimary: _getContrastColor(primary),
      onSecondary: _getContrastColor(secondary),
      onAccent: _getContrastColor(accent),
    );
  }

  /// Get contrasting color for text
  static Color _getContrastColor(Color color) {
    // Calculate luminance
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  /// Generate gradient colors for backgrounds
  static List<Color> generateGradientColors(ColorPalette palette) {
    return [
      palette.primary.withOpacity(0.1),
      palette.secondary.withOpacity(0.05),
      palette.surface,
    ];
  }

  /// Get themed colors for different UI elements
  static Color getThemedColor(ColorPalette palette, String element) {
    switch (element) {
      case 'like':
        return palette.accent;
      case 'bookmark':
        return palette.primary;
      case 'share':
        return palette.secondary;
      case 'category':
        return palette.primary;
      default:
        return palette.primary;
    }
  }
}

class ColorPalette {
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color onPrimary;
  final Color onSecondary;
  final Color onAccent;

  const ColorPalette({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.onPrimary,
    required this.onSecondary,
    required this.onAccent,
  });

  factory ColorPalette.defaultPalette() {
    return const ColorPalette(
      primary: CupertinoColors.systemBlue,
      secondary: CupertinoColors.systemIndigo,
      accent: CupertinoColors.systemPurple,
      background: CupertinoColors.systemBackground,
      surface: CupertinoColors.secondarySystemBackground,
      onPrimary: CupertinoColors.white,
      onSecondary: CupertinoColors.white,
      onAccent: CupertinoColors.white,
    );
  }

  /// Create a lighter version of the palette
  ColorPalette get light {
    return ColorPalette(
      primary: primary.withOpacity(0.8),
      secondary: secondary.withOpacity(0.8),
      accent: accent.withOpacity(0.8),
      background: background,
      surface: surface,
      onPrimary: onPrimary,
      onSecondary: onSecondary,
      onAccent: onAccent,
    );
  }

  /// Create a darker version of the palette
  ColorPalette get dark {
    return ColorPalette(
      primary: Color.lerp(primary, Colors.black, 0.2)!,
      secondary: Color.lerp(secondary, Colors.black, 0.2)!,
      accent: Color.lerp(accent, Colors.black, 0.2)!,
      background: background,
      surface: surface,
      onPrimary: onPrimary,
      onSecondary: onSecondary,
      onAccent: onAccent,
    );
  }
}

class ExtractedColors {
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color textColor;

  ExtractedColors({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.textColor,
  });
}
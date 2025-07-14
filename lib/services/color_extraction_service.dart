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
      
      // Create muted version of extracted colors
      final mutedPrimary = _createMutedBackground(extractedColors.primary);
      
      return ColorPalette(
        primary: mutedPrimary,
        secondary: _createMutedBackground(extractedColors.secondary),
        accent: _createMutedBackground(extractedColors.accent),
        background: mutedPrimary.withOpacity(0.1),
        surface: mutedPrimary.withOpacity(0.05),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onAccent: Colors.white,
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
      primary: const Color(0xFF4A5568), // Royal slate gray
      secondary: const Color(0xFF2D3748), // Deep charcoal
      accent: const Color(0xFF553C9A), // Royal purple
      textColor: Colors.white,
    );
  }

  /// Generate a beautiful color palette from URL hash (fallback method)
  static ColorPalette _generatePaletteFromUrl(String url) {
    // Create hash from URL
    final bytes = utf8.encode(url);
    final hash = bytes.fold(0, (prev, element) => prev + element);
    
    // Generate pleasant colors that keep their identity
    var hue = (hash % 360).toDouble();
    var saturation = 0.4 + (hash % 15) / 100; // 0.4-0.55 for recognizable colors
    var lightness = 0.2 + (hash % 10) / 100; // 0.2-0.3 for dark but visible backgrounds
    
    // Special handling for green hues to make them impressive
    if (hue >= 90 && hue <= 150) { // Green range
      // Use beautiful forest green, emerald, or sage tones
      final greenVariants = [
        HSLColor.fromAHSL(1.0, 140, 0.6, 0.35), // Deep forest green
        HSLColor.fromAHSL(1.0, 160, 0.7, 0.4),  // Emerald green
        HSLColor.fromAHSL(1.0, 120, 0.5, 0.45), // Rich sage green
        HSLColor.fromAHSL(1.0, 135, 0.65, 0.38), // Deep jade
        HSLColor.fromAHSL(1.0, 155, 0.6, 0.42),  // Teal green
      ];
      final selectedGreen = greenVariants[hash % greenVariants.length];
      hue = selectedGreen.hue;
      saturation = selectedGreen.saturation;
      lightness = selectedGreen.lightness;
    }
    
    // Create primary color with higher saturation
    final primaryHSL = HSLColor.fromAHSL(1.0, hue, saturation, lightness);
    final primary = primaryHSL.toColor();
    
    // Generate royal, complementary colors
    final secondary = HSLColor.fromAHSL(1.0, (hue + 40) % 360, saturation * 0.8, lightness * 1.1).toColor();
    final accent = HSLColor.fromAHSL(1.0, (hue + 80) % 360, saturation * 0.7, lightness * 0.9).toColor();
    
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

  /// Create a muted background color from any color (keeps color identity)
  static Color _createMutedBackground(Color originalColor) {
    final hsl = HSLColor.fromColor(originalColor);
    
    // Keep the color identity but make it pleasant
    final mutedSaturation = (hsl.saturation * 0.6).clamp(0.3, 0.7); // Keep more saturation
    final mutedLightness = 0.25; // Darker but not too dark
    
    return hsl.withSaturation(mutedSaturation).withLightness(mutedLightness).toColor();
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
      primary: Color(0xFF4A5568), // Royal slate gray
      secondary: Color(0xFF2D3748), // Deep charcoal  
      accent: Color(0xFF553C9A), // Royal purple
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
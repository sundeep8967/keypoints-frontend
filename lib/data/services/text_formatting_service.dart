import 'package:flutter/material.dart';

/// Service for formatting text with bold markdown-style formatting
class TextFormattingService {
  /// Converts text with **bold** markers to RichText with proper formatting
  static Widget formatTextWithBold(String text, TextStyle baseStyle, {int maxLines = 8}) {
    final List<TextSpan> spans = [];
    final RegExp boldPattern = RegExp(r'\*\*(.*?)\*\*');
    
    int lastEnd = 0;
    
    for (final Match match in boldPattern.allMatches(text)) {
      // Add text before the bold part
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }
      
      // Add the bold text
      spans.add(TextSpan(
        text: match.group(1), // The text inside **
        style: baseStyle.copyWith(fontWeight: FontWeight.bold),
      ));
      
      lastEnd = match.end;
    }
    
    // Add remaining text after the last bold part
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: baseStyle,
      ));
    }
    
    // If no bold formatting found, return simple text
    if (spans.isEmpty) {
      return Text(text, style: baseStyle, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    }
    
    return RichText(
      text: TextSpan(children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.left,
    );
  }
  
  /// Formats key points with bullet points and bold formatting
  static Widget formatKeyPoints(String keypoints, TextStyle baseStyle, {int maxLines = 8}) {
    final formattedText = keypoints
        .split('|')
        .map((point) {
          final trimmedPoint = point.trim();
          // Clean up the formatting - remove extra colons and fix spacing
          String cleanPoint = trimmedPoint;
          
          // Remove unwanted quotation marks around bold headers
          cleanPoint = cleanPoint.replaceAll('"**', '**');
          cleanPoint = cleanPoint.replaceAll('**"', '**');
          cleanPoint = cleanPoint.replaceAll("'**", '**');
          cleanPoint = cleanPoint.replaceAll("**'", '**');
          
          // Fix formatting to use single colon after bold text
          cleanPoint = cleanPoint.replaceAll('**:', '**:');
          cleanPoint = cleanPoint.replaceAll(': :', ':');
          
          // Ensure proper spacing - single colon after bold sections
          cleanPoint = cleanPoint.replaceAll('**:', '**: ');
          
          // Fix any remaining double colons to single
          cleanPoint = cleanPoint.replaceAll('::', ':');
          
          // Remove quotation marks after colons (**: "text" becomes **: text)
          cleanPoint = cleanPoint.replaceAll(': "', ': ');
          cleanPoint = cleanPoint.replaceAll(": '", ': ');
          cleanPoint = cleanPoint.replaceAll(':"', ':');
          cleanPoint = cleanPoint.replaceAll(":'", ':');
          
          // Remove extra quotation marks at the beginning of sentences
          cleanPoint = cleanPoint.replaceAll(RegExp(r'^"([A-Z])'), r'\1');
          cleanPoint = cleanPoint.replaceAll(RegExp(r"^'([A-Z])"), r'\1');
          
          // Remove trailing quotation marks at the end
          cleanPoint = cleanPoint.replaceAll(RegExp(r'"$'), '');
          cleanPoint = cleanPoint.replaceAll(RegExp(r"'$"), '');
          
          // Clean up extra spaces
          cleanPoint = cleanPoint.replaceAll(RegExp(r'\s+'), ' ');
          
          return '• $cleanPoint';
        })
        .join('\n'); // Single newline to save space and show more content
    
    // Use normal line height to fit more content
    final enhancedStyle = baseStyle.copyWith(
      height: 1.4, // Reduced line height to show more content
    );
    
    return formatTextWithBold(formattedText, enhancedStyle, maxLines: maxLines);
  }
}
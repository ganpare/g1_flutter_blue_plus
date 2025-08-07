import 'dart:convert';
import '../services/bluetooth_manager.dart';
import '../services/commands.dart';

/// Display utility functions for creating enhanced visual content for Even G1
class DisplayUtils {
  // ASCII box drawing characters
  static const String topLeft = '┌';
  static const String topRight = '┐';
  static const String bottomLeft = '└';
  static const String bottomRight = '┘';
  static const String horizontal = '─';
  static const String vertical = '│';
  static const String cross = '┼';
  static const String teeUp = '┴';
  static const String teeDown = '┬';
  static const String teeLeft = '┤';
  static const String teeRight = '├';

  // Simple ASCII alternatives
  static const String simpleTopLeft = '+';
  static const String simpleTopRight = '+';
  static const String simpleBottomLeft = '+';
  static const String simpleBottomRight = '+';
  static const String simpleHorizontal = '-';
  static const String simpleVertical = '|';

  /// Creates a bordered text display with frame
  static String createBorderedText(String content, {
    int width = 20,
    bool useUnicode = true,
    String title = '',
  }) {
    List<String> lines = _wrapText(content, width - 2); // Account for borders
    
    // Ensure we have exactly 3 content lines for Even G1 (5 total with borders)
    while (lines.length < 3) {
      lines.add('');
    }
    if (lines.length > 3) {
      lines = lines.take(3).toList();
    }

    String tl = useUnicode ? topLeft : simpleTopLeft;
    String tr = useUnicode ? topRight : simpleTopRight;
    String bl = useUnicode ? bottomLeft : simpleBottomLeft;
    String br = useUnicode ? bottomRight : simpleBottomRight;
    String h = useUnicode ? horizontal : simpleHorizontal;
    String v = useUnicode ? vertical : simpleVertical;

    List<String> result = [];
    
    // Top border
    if (title.isNotEmpty && title.length <= width - 4) {
      int padding = width - title.length - 2;
      int leftPad = padding ~/ 2;
      int rightPad = padding - leftPad;
      result.add('$tl${h * leftPad}$title${h * rightPad}$tr');
    } else {
      result.add('$tl${h * (width - 2)}$tr');
    }
    
    // Content lines
    for (String line in lines) {
      String paddedLine = line.padRight(width - 2);
      if (paddedLine.length > width - 2) {
        paddedLine = paddedLine.substring(0, width - 2);
      }
      result.add('$v$paddedLine$v');
    }
    
    // Bottom border
    result.add('$bl${h * (width - 2)}$br');
    
    return result.join('\n');
  }

  /// Creates a progress bar display
  static String createProgressBar(double progress, {
    int width = 18,
    String label = 'Progress',
    bool showPercentage = true,
  }) {
    progress = progress.clamp(0.0, 1.0);
    int fillWidth = (progress * width).round();
    int emptyWidth = width - fillWidth;
    
    String bar = '█' * fillWidth + '░' * emptyWidth;
    String percentage = showPercentage ? ' ${(progress * 100).toInt()}%' : '';
    
    return '''
$label$percentage
$bar
''';
  }

  /// Creates a menu-style display
  static String createMenu(List<String> items, {
    int selectedIndex = 0,
    String cursor = '→',
    int width = 20,
  }) {
    List<String> lines = [];
    
    for (int i = 0; i < items.length && i < 5; i++) {
      String prefix = i == selectedIndex ? cursor : ' ';
      String item = items[i];
      if (item.length > width - 2) {
        item = item.substring(0, width - 2);
      }
      lines.add('$prefix $item');
    }
    
    while (lines.length < 5) {
      lines.add('');
    }
    
    return lines.join('\n');
  }

  /// Creates a status display with icons
  static String createStatusDisplay({
    required String title,
    required String status,
    String icon = '●',
    bool isConnected = false,
  }) {
    String statusIcon = isConnected ? '✓' : '✗';
    String colorIndicator = isConnected ? '●' : '○';
    
    return '''
$title
${'-' * 20}
Status: $statusIcon $status
Connection: $colorIndicator
${'-' * 20}
''';
  }

  /// Creates a data visualization (simple chart)
  static String createSimpleChart(List<double> values, {
    String title = 'Data',
    int height = 3,
    int width = 20,
  }) {
    if (values.isEmpty) return title;
    
    double max = values.reduce((a, b) => a > b ? a : b);
    double min = values.reduce((a, b) => a < b ? a : b);
    double range = max - min;
    
    List<String> lines = [title];
    
    for (int row = height - 1; row >= 0; row--) {
      String line = '';
      for (int col = 0; col < values.length && col < width; col++) {
        double normalizedValue = range > 0 ? (values[col] - min) / range : 0;
        double threshold = (row + 1) / height;
        line += normalizedValue >= threshold ? '█' : ' ';
      }
      lines.add(line);
    }
    
    return lines.join('\n');
  }

  /// Creates an alert/warning display
  static String createAlert(String message, {
    AlertType type = AlertType.info,
    int width = 20,
  }) {
    String icon;
    String border;
    
    switch (type) {
      case AlertType.error:
        icon = '⚠';
        border = '!';
        break;
      case AlertType.warning:
        icon = '⚡';
        border = '!';
        break;
      case AlertType.success:
        icon = '✓';
        border = '+';
        break;
      case AlertType.info:
      default:
        icon = 'ℹ';
        border = '-';
        break;
    }
    
    List<String> lines = _wrapText(message, width - 4);
    List<String> result = [];
    
    // Top border
    result.add(border * width);
    
    // Icon and first line
    if (lines.isNotEmpty) {
      result.add('$border $icon ${lines[0].padRight(width - 4)} $border');
      lines = lines.skip(1).toList();
    }
    
    // Remaining lines
    for (String line in lines.take(2)) { // Max 2 more lines
      result.add('$border ${line.padRight(width - 3)} $border');
    }
    
    // Bottom border
    result.add(border * width);
    
    return result.join('\n');
  }

  /// Helper function to wrap text to specified width
  static List<String> _wrapText(String text, int width) {
    if (width <= 0) return [text];
    
    List<String> words = text.split(' ');
    List<String> lines = [];
    String currentLine = '';
    
    for (String word in words) {
      if ((currentLine + (currentLine.isEmpty ? '' : ' ') + word).length <= width) {
        currentLine += (currentLine.isEmpty ? '' : ' ') + word;
      } else {
        if (currentLine.isNotEmpty) {
          lines.add(currentLine);
        }
        currentLine = word.length <= width ? word : word.substring(0, width);
      }
    }
    
    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }
    
    return lines;
  }

  /// Send enhanced display content to Even G1
  static Future<String?> sendEnhancedDisplay({
    required String content,
    required BluetoothManager bluetoothManager,
    int pageNumber = 1,
    int maxPages = 1,
    int screenStatus = 0x31,
  }) async {
    return await sendTextPacket(
      textMessage: content,
      bluetoothManager: bluetoothManager,
      pageNumber: pageNumber,
      maxPages: maxPages,
      screenStatus: screenStatus,
    );
  }
}

enum AlertType {
  info,
  warning,
  error,
  success,
}

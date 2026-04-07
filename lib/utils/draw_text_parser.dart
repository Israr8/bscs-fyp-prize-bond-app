/// Parses draw result text (e.g. from SBP / National Savings style txt file)
/// into structured data for Firestore.
class ParsedDraw {
  final String denomination;
  final String drawNumber;
  final String firstPrize;
  final List<String> secondPrize;
  final List<String> thirdPrize;

  ParsedDraw({
    required this.denomination,
    required this.drawNumber,
    required this.firstPrize,
    required this.secondPrize,
    required this.thirdPrize,
  });
}

class DrawTextParser {
  /// Parse raw draw result text.
  /// Expects format like:
  /// DRAW RESULT OF RS. 750/- ... 105TH DRAW
  /// First Prize ... \n 809258
  /// Second Prize ... \n 488890 748328 746418
  /// Third Prize ... \n 000190 031570 ...
  static ParsedDraw? parse(String text) {
    if (text.trim().isEmpty) return null;

    final lines = text.split(RegExp(r'\r?\n'));
    String denomination = '';
    String drawNumber = '';
    String firstPrize = '';
    List<String> secondPrize = [];
    List<String> thirdPrize = [];

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.contains('draw') && RegExp(r'\d+').hasMatch(line)) {
        final match = RegExp(r'rs\.?\s*(\d+)', caseSensitive: false).firstMatch(line);
        if (match != null && denomination.isEmpty) denomination = match.group(1) ?? '';
        final nthMatch = RegExp(r'(\d+)\s*(?:st|nd|rd|th)\s*draw', caseSensitive: false).firstMatch(line);
        if (nthMatch != null && drawNumber.isEmpty) drawNumber = nthMatch.group(1) ?? '';
      }
    }

    int section = 0; // 0=none, 1=first, 2=second, 3=third
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase().trim();
      if (lower.contains('first prize') && !lower.contains('second') && !lower.contains('third')) {
        section = 1;
        continue;
      }
      if (lower.contains('second prize')) {
        section = 2;
        continue;
      }
      if (lower.contains('third prize')) {
        section = 3;
        continue;
      }

      if (section == 1) {
        final num = _extractFirstNumber(line);
        if (num.isNotEmpty) {
          firstPrize = num;
          section = 0;
        }
      } else if (section == 2) {
        final nums = _extractNumbers(line);
        if (nums.isNotEmpty) {
          secondPrize = nums;
          section = 0;
        }
      } else if (section == 3) {
        final nums = _extractSixDigitNumbers(line);
        thirdPrize.addAll(nums);
      }
    }

    if (denomination.isEmpty) denomination = '750';
    if (drawNumber.isEmpty) drawNumber = '105';
    if (firstPrize.isEmpty && secondPrize.isEmpty && thirdPrize.isEmpty) return null;

    return ParsedDraw(
      denomination: denomination,
      drawNumber: drawNumber,
      firstPrize: firstPrize,
      secondPrize: secondPrize,
      thirdPrize: thirdPrize,
    );
  }

  static String _extractFirstNumber(String line) {
    final match = RegExp(r'\b(\d{6})\b').firstMatch(line.trim());
    return match?.group(1) ?? '';
  }

  static List<String> _extractNumbers(String line) {
    return RegExp(r'\b\d{6}\b').allMatches(line).map((m) => m.group(0)!).toList();
  }

  static List<String> _extractSixDigitNumbers(String line) {
    return RegExp(r'\b(\d{6})\b').allMatches(line).map((m) => m.group(1)!).toList();
  }
}

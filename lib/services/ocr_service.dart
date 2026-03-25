import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  final String fullText;
  final String merchant;
  final double? amount;
  final DateTime? date;
  final String category;

  const OcrResult({
    required this.fullText,
    required this.merchant,
    required this.amount,
    required this.date,
    required this.category,
  });
}

class OcrService {
  final TextRecognizer _textRecognizer =
  TextRecognizer(script: TextRecognitionScript.latin);

  Future<OcrResult> scanReceipt(File imageFile) async {
    final InputImage inputImage = InputImage.fromFile(imageFile);
    final RecognizedText recognizedText =
    await _textRecognizer.processImage(inputImage);

    final String fullText = recognizedText.text.trim();
    final String merchant = _extractMerchant(recognizedText);
    final double? amount = _extractAmount(fullText);
    final DateTime? date = _extractDate(fullText);
    final String category = _categorizeMerchant(merchant);

    return OcrResult(
      fullText: fullText,
      merchant: merchant,
      amount: amount,
      date: date,
      category: category,
    );
  }

  String _extractMerchant(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) {
      return '';
    }

    // غالبًا أول بلوك في الفاتورة يكون اسم المتجر
    final String firstBlock = recognizedText.blocks.first.text.trim();
    if (firstBlock.isNotEmpty) {
      return firstBlock.split('\n').first.trim();
    }

    return '';
  }

  double? _extractAmount(String text) {
    final List<RegExp> patterns = [
      RegExp(
        r'(?:total|grand total|amount|subtotal|الإجمالي|المجموع|المبلغ)\s*[:\-]?\s*(\d+[.,]?\d{0,2})',
        caseSensitive: false,
      ),
      RegExp(
        r'(\d+[.,]?\d{0,2})\s*(?:SAR|ر\.س|ريال)',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final Match? match = pattern.firstMatch(text);
      if (match != null) {
        final String raw = (match.group(1) ?? '').replaceAll(',', '.').trim();
        final double? value = double.tryParse(raw);
        if (value != null && value > 0) {
          return value;
        }
      }
    }

    return null;
  }

  DateTime? _extractDate(String text) {
    final List<RegExp> patterns = [
      RegExp(r'(\d{4})[/-](\d{1,2})[/-](\d{1,2})'),
      RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{4})'),
    ];

    for (final pattern in patterns) {
      final Match? match = pattern.firstMatch(text);
      if (match == null) continue;

      try {
        if (pattern.pattern.startsWith(r'(\d{4})')) {
          final int year = int.parse(match.group(1)!);
          final int month = int.parse(match.group(2)!);
          final int day = int.parse(match.group(3)!);
          return DateTime(year, month, day);
        } else {
          final int day = int.parse(match.group(1)!);
          final int month = int.parse(match.group(2)!);
          final int year = int.parse(match.group(3)!);
          return DateTime(year, month, day);
        }
      } catch (_) {
        // نكمل لو هذا النمط لم يصلح
      }
    }

    return null;
  }

  String _categorizeMerchant(String merchant) {
    final String value = merchant.toLowerCase();

    if (value.contains('danube') ||
        value.contains('carrefour') ||
        value.contains('panda') ||
        value.contains('أسواق') ||
        value.contains('بنده') ||
        value.contains('كارفور')) {
      return 'Groceries';
    }

    if (value.contains('jarir') || value.contains('جرير')) {
      return 'Electronics';
    }

    if (value.contains('sephora') || value.contains('سيفورا')) {
      return 'Beauty';
    }

    if (value.contains('pharmacy') ||
        value.contains('صيدلية') ||
        value.contains('nahdi')) {
      return 'Health';
    }

    return 'Other';
  }

  Future<void> dispose() async {
    await _textRecognizer.close();
  }
}
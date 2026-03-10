import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

/// MemoryTriggerEngine v2 — improved keyword matching, lower thresholds,
/// runs across all OCR'd items not just screenshots.
class MemoryTriggerEngine {
  final DatabaseService _db = DatabaseService();

  /// Runs after each OCR task completes. If the item has enough text,
  /// scan it for actionable memory trigger patterns.
  Future<void> processItem(String itemId) async {
    try {
      final db = await _db.database;
      final results = await db.query('memory_items', where: 'id = ?', whereArgs: [itemId]);
      if (results.isEmpty) return;

      final item = results.first;
      final bucket = (item['source_bucket'] ?? '').toString().toUpperCase();

      // Build full text: title + FTS OCR content
      final titleText = (item['title'] ?? '').toString();
      final ftsResults = await db.query(
        'memory_items_fts',
        where: 'memory_item_id = ?',
        whereArgs: [itemId],
      );

      final ftsContent = ftsResults.isNotEmpty
          ? (ftsResults.first['content'] as String? ?? '')
          : '';

      // Only process if we actually have OCR text
      final fullText = '$titleText $ftsContent'.toLowerCase().trim();
      if (fullText.length < 10) return;

      debugPrint('[Triggers] Processing $itemId (${fullText.length} chars, bucket=$bucket)');

      final prefs = await SharedPreferences.getInstance();

      if (prefs.getBool('trigger_flight') ?? true) {
        await _detectFlight(itemId, fullText, bucket, db);
      }
      if (prefs.getBool('trigger_parking') ?? true) {
        await _detectParking(itemId, fullText, bucket, db);
      }
      if (prefs.getBool('trigger_package') ?? true) {
        await _detectPackage(itemId, fullText, bucket, db);
      }
      if (prefs.getBool('trigger_receipt') ?? true) {
        await _detectReceipt(itemId, fullText, bucket, db);
      }
      if (prefs.getBool('trigger_otp') ?? true) {
        await _detectOTP(itemId, fullText, bucket, db);
      }
      if (prefs.getBool('trigger_address') ?? true) {
        await _detectAddress(itemId, fullText, bucket, db);
      }
      if (prefs.getBool('trigger_contact') ?? true) {
        await _detectContact(itemId, fullText, bucket, db);
      }
      if (prefs.getBool('trigger_wifi') ?? true) {
        await _detectWifi(itemId, fullText, bucket, db);
      }

    } catch (e) {
      debugPrint('[Triggers] processItem error for $itemId: $e');
    }
  }

  /// Re-run triggers across ALL already-OCR'd items (useful after a fresh index).
  Future<int> reprocessAllItems() async {
    int count = 0;
    try {
      final db = await _db.database;
      final items = await db.query(
        'memory_items',
        where: 'is_ocr_complete = 1',
        columns: ['id'],
      );
      for (final item in items) {
        await processItem(item['id'] as String);
        count++;
        // Yield to allow UI frames to render between items
        if (count % 5 == 0) {
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }
    } catch (e) {
      debugPrint('[Triggers] reprocessAllItems error: $e');
    }
    return count;
  }

  // ─── Individual Detectors ─────────────────────────────────────────────────

  Future<void> _detectFlight(String itemId, String text, String bucket, dynamic db) async {
    // Lowered threshold: 1 strong keyword OR 2 weaker ones
    final strongKeywords = ['boarding pass', 'flight number', 'pnr', 'e-ticket', 'eticket'];
    final weakKeywords   = ['flight', 'boarding', 'gate', 'departure', 'arrival', 'terminal', 'seat', 'airline'];

    final strongHit = strongKeywords.any((k) => text.contains(k));
    final weakCount = weakKeywords.where((k) => text.contains(k)).length;

    if (strongHit || weakCount >= 2) {
      await _upsertTrigger(itemId, 'FLIGHT', strongHit ? 0.92 : 0.78, {
        'detected_via': strongHit ? 'strong_keyword' : 'weak_keywords',
        'weak_count': weakCount,
      });
    }
  }

  Future<void> _detectParking(String itemId, String text, String bucket, dynamic db) async {
    // Parking works on PHOTOS, SCREENSHOTS, and even Documents
    final keywords = ['parking', 'parked', 'garage', 'level', 'floor', 'spot', 'zone', 'bay', 'lot'];
    final count = keywords.where((k) => text.contains(k)).length;
    if (count >= 1) {  // Single keyword is enough for parking — very actionable
      await _upsertTrigger(itemId, 'PARKING', count >= 2 ? 0.90 : 0.72, {
        'matched_keywords': keywords.where((k) => text.contains(k)).toList(),
      });
    }
  }

  Future<void> _detectPackage(String itemId, String text, String bucket, dynamic db) async {
    // Tracking number patterns (case-insensitive)
    final upsPattern  = RegExp(r'1z[a-z0-9]{16}', caseSensitive: false);
    final uspsPattern = RegExp(r'\b94[0-9]{18,22}\b');
    final fedExPattern = RegExp(r'\b[0-9]{12,15}\b');
    final keywords = ['tracking number', 'tracking #', 'shipment', 'delivery', 'shipped', 'out for delivery', 'package'];

    final hasPattern = upsPattern.hasMatch(text) || uspsPattern.hasMatch(text);
    final hasKeyword = keywords.any((k) => text.contains(k));

    if (hasPattern || hasKeyword) {
      String provider = 'Unknown';
      if (upsPattern.hasMatch(text)) { provider = 'UPS'; }
      else if (uspsPattern.hasMatch(text)) { provider = 'USPS'; }
      else if (fedExPattern.hasMatch(text) && text.contains('fedex')) { provider = 'FedEx'; }

      await _upsertTrigger(itemId, 'PACKAGE', hasPattern ? 0.95 : 0.78, {
        'provider': provider,
        'detected_via': hasPattern ? 'tracking_number' : 'keyword',
      });
    }
  }

  Future<void> _detectReceipt(String itemId, String text, String bucket, dynamic db) async {
    final strongKeywords = ['receipt', 'order confirmation', 'invoice', 'payment confirmed'];
    final amountPattern  = RegExp(r'\$\s*\d+\.\d{2}');
    final weakKeywords   = ['total', 'subtotal', 'tax', 'paid', 'charged', 'amount due', 'order #'];

    final strongHit  = strongKeywords.any((k) => text.contains(k));
    final hasAmount  = amountPattern.hasMatch(text);
    final weakCount  = weakKeywords.where((k) => text.contains(k)).length;

    // Receipt: either 1 strong, or amount + 2 weak words
    if (strongHit || (hasAmount && weakCount >= 1) || weakCount >= 3) {
      await _upsertTrigger(itemId, 'RECEIPT', strongHit ? 0.92 : 0.81, {
        'has_amount': hasAmount,
        'strong': strongHit,
      });
    }
  }

  Future<void> _detectOTP(String itemId, String text, String bucket, dynamic db) async {
    final keywords = [
      'verification code', 'security code', 'otp', 'one-time', 'one time password',
      'confirm your', 'passcode', 'expir', 'authenticate',
    ];
    // OTP pattern: 4-8 digit standalone number often on its own line
    final otpPattern = RegExp(r'\b\d{4,8}\b');

    final hasKeyword = keywords.any((k) => text.contains(k));
    final hasPattern = otpPattern.hasMatch(text);

    if (hasKeyword && hasPattern) {
      await _upsertTrigger(itemId, 'OTP', 0.88, {
        'potential_code': otpPattern.firstMatch(text)?.group(0),
      });
    } else if (hasKeyword) {
      await _upsertTrigger(itemId, 'OTP', 0.72, {});
    }
  }

  Future<void> _detectAddress(String itemId, String text, String bucket, dynamic db) async {
    final streetPattern = RegExp(r'\d+\s+\w+\s+(st|street|ave|avenue|blvd|boulevard|rd|road|dr|drive|ln|lane|ct|court|pl|place|way)\b', caseSensitive: false);
    final cityStateZip  = RegExp(r'\b[A-Z][a-z]+,\s+[A-Z]{2}\s+\d{5}\b');
    final keywords = ['address', 'location', 'directions', 'deliver to', 'ship to'];

    final hasStreet = streetPattern.hasMatch(text);
    final hasCityState = cityStateZip.hasMatch(text);
    final hasKeyword = keywords.any((k) => text.contains(k));

    if (hasStreet || hasCityState || (hasKeyword && (hasStreet || hasCityState))) {
      await _upsertTrigger(itemId, 'ADDRESS', hasStreet && hasCityState ? 0.92 : 0.75, {
        'has_street': hasStreet,
        'has_city_state': hasCityState,
      });
    }
  }

  Future<void> _detectContact(String itemId, String text, String bucket, dynamic db) async {
    // Phone pattern
    final phonePattern = RegExp(r'\b(\+?1?\s?)?(\(?\d{3}\)?[\s\-.]?\d{3}[\s\-.]?\d{4})\b');
    // Email pattern
    final emailPattern = RegExp(r'\b[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}\b');

    final hasPhone = phonePattern.hasMatch(text);
    final hasEmail = emailPattern.hasMatch(text);

    if (hasPhone && hasEmail) {
      await _upsertTrigger(itemId, 'CONTACT', 0.88, {
        'has_phone': true,
        'has_email': true,
      });
    } else if (hasPhone || hasEmail) {
      await _upsertTrigger(itemId, 'CONTACT', 0.72, {
        'has_phone': hasPhone,
        'has_email': hasEmail,
      });
    }
  }

  Future<void> _detectWifi(String itemId, String text, String bucket, dynamic db) async {
    // Only on screenshots — wifi passwords are usually texted or screenshotted
    if (bucket != 'SCREENSHOTS') return;

    final keywords = ['password', 'wifi', 'wi-fi', 'network name', 'ssid', 'wpa', 'wep'];
    final count = keywords.where((k) => text.contains(k)).length;
    if (count >= 2) {
      await _upsertTrigger(itemId, 'WIFI_PASSWORD', 0.85, {
        'matched': keywords.where((k) => text.contains(k)).toList(),
      });
    }
  }

  // ─── Shared Helper ─────────────────────────────────────────────────────────

  Future<void> _upsertTrigger(
    String itemId,
    String type,
    double confidence,
    Map<String, dynamic> data,
  ) async {
    try {
      final triggerId = 'trigger_${type.toLowerCase()}_$itemId';
      await _db.insertTrigger({
        'id': triggerId,
        'memory_item_id': itemId,
        'trigger_type': type,
        'confidence_score': confidence,
        'trigger_data_json': jsonEncode(data),
        'is_dismissed': 0,
        'is_accepted': 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      debugPrint('[Triggers] ✅ Created $type trigger for $itemId (confidence=$confidence)');
    } catch (e) {
      // Trigger may already exist — that's fine
      debugPrint('[Triggers] Skip duplicate trigger $type for $itemId');
    }
  }
}

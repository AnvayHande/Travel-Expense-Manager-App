import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DraftExpenseService {
  static const String _prefix = 'draft_expense_';

  String _key(String tripId) => '$_prefix$tripId';

  Future<void> saveDraft({
    required String tripId,
    required String? expenseName,
    required String? amount,
    required String? category,
    required String? paidBy,
    required String? splitType,
    required List<String>? splitBetween,
    required Map<String, String>? splitValues,
    required String? notes,
    required int? dateMillis,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{
      'tripId': tripId,
      'expenseName': expenseName,
      'amount': amount,
      'category': category,
      'paidBy': paidBy,
      'splitType': splitType,
      'splitBetween': splitBetween,
      'splitValues': splitValues,
      'notes': notes,
      'dateMillis': dateMillis,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    await prefs.setString(_key(tripId), jsonEncode(data));
  }

  Future<Map<String, dynamic>?> loadDraft(String tripId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(tripId));
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteDraft(String tripId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(tripId));
  }

  Future<bool> hasDraft(String tripId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_key(tripId));
  }
}

// ignore_for_file: use_null_aware_elements
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TranslateService {
  TranslateService._();
  static final instance = TranslateService._();

  static const _boxName = 'translate_cache';
  Box<String>? _box;

  Future<void> init() async {
    if (_box != null) return;
    _box = await Hive.openBox<String>(_boxName);
  }

  String _key(String text, String lang) => '${text.hashCode}_$lang';

  /// Перевести текст, кэш в Hive по hash+lang, прокси через Edge Function `translate`
  Future<String> translate(String text, {String targetLang = 'en', String? sourceLang}) async {
    await init();
    final k = _key(text, targetLang);
    final cached = _box!.get(k);
    if (cached != null) return cached;
    try {
      final res = await Supabase.instance.client.functions.invoke('translate', body: {'text': text, 'target_lang': targetLang, if (sourceLang != null) 'source_lang': sourceLang});
      final data = res.data as Map<String, dynamic>?;
      final translated = data?['translated'] as String? ?? data?['translatedText'] as String? ?? text;
      await _box!.put(k, translated);
      return translated;
    } catch (_) {
      // fallback — мок без сети
      final mock = '[$targetLang] $text';
      await _box!.put(k, mock);
      return mock;
    }
  }
}

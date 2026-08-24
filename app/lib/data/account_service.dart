import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend.dart';

/// Один сохранённый аккаунт (как в Telegram: до 3).
class VibeAccount {
  const VibeAccount({
    required this.phone,
    required this.displayName,
    required this.userId,
    this.emoji,
    this.avatarUrl,
  });

  final String phone;
  final String displayName;
  final String userId;
  final String? emoji;
  final String? avatarUrl;

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'displayName': displayName,
        'userId': userId,
        'emoji': emoji,
        'avatarUrl': avatarUrl,
      };

  factory VibeAccount.fromJson(Map<String, dynamic> j) => VibeAccount(
        phone: j['phone'] as String,
        displayName: j['displayName'] as String? ?? '',
        userId: j['userId'] as String,
        emoji: j['emoji'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
      );
}

/// Мультиаккаунт: хранение до 3 аккаунтов + переключение Supabase-сессии.
///
/// Пароли хранятся в `FlutterSecureStorage` (шифруется OS keystore),
/// мета аккаунтов — в том же сторе как JSON.
/// Текущий индекс — в `currentAccountIndex` (0..n-1).
class AccountService {
  AccountService._();
  static final instance = AccountService._();

  static const _storage = FlutterSecureStorage();
  static const _keyAccounts = 'vibe_accounts_data';
  static const _keyCurrentIdx = 'vibe_current_account_idx';
  static const _keyPasswords = 'vibe_account_passwords';

  final ValueNotifier<int> version = ValueNotifier(0);

  List<VibeAccount> _accounts = [];
  int _currentIdx = 0;
  Map<String, String> _passwords = {}; // phone -> password

  List<VibeAccount> get accounts => List.unmodifiable(_accounts);
  int get currentIndex => _currentIdx;
  VibeAccount? get currentAccount =>
      _accounts.isEmpty ? null : _accounts[_currentIdx.clamp(0, _accounts.length - 1)];

  bool get canAddMore => _accounts.length < 3;

  Future<void> init() async {
    try {
      final raw = await _storage.read(key: _keyAccounts);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        _accounts = list.map((e) => VibeAccount.fromJson(e as Map<String, dynamic>)).toList();
      }
      final idxRaw = await _storage.read(key: _keyCurrentIdx);
      if (idxRaw != null) _currentIdx = int.tryParse(idxRaw) ?? 0;
      final pwRaw = await _storage.read(key: _keyPasswords);
      if (pwRaw != null && pwRaw.isNotEmpty) {
        _passwords = Map<String, String>.from(jsonDecode(pwRaw) as Map);
      }
      // Clamp index
      if (_accounts.isNotEmpty) {
        _currentIdx = _currentIdx.clamp(0, _accounts.length - 1);
      }
    } catch (_) {
      // Повреждённые данные — сброс
      _accounts = [];
      _currentIdx = 0;
      _passwords = {};
    }
  }

  Future<void> _persist() async {
    await _storage.write(
      key: _keyAccounts,
      value: jsonEncode(_accounts.map((a) => a.toJson()).toList()),
    );
    await _storage.write(key: _keyCurrentIdx, value: '$_currentIdx');
    await _storage.write(key: _keyPasswords, value: jsonEncode(_passwords));
    version.value++;
  }

  String _emailForPhone(String phone) =>
      '${phone.replaceAll(RegExp(r'[^\d]'), '')}@vibe.local';

  /// Сохранить аккаунт после успешной auth (вызывать из AuthScreen).
  /// Если phone уже есть — обновляет.
  Future<void> saveAccount({
    required String phone,
    required String password,
    required String userId,
    String displayName = '',
    String? emoji,
    String? avatarUrl,
  }) async {
    final existingIdx = _accounts.indexWhere((a) => a.phone == phone);
    final acc = VibeAccount(
      phone: phone,
      displayName: displayName,
      userId: userId,
      emoji: emoji,
      avatarUrl: avatarUrl,
    );
    if (existingIdx >= 0) {
      _accounts[existingIdx] = acc;
      _currentIdx = existingIdx;
    } else {
      if (_accounts.length >= 3) return; // лимит как в ТГ
      _accounts.add(acc);
      _currentIdx = _accounts.length - 1;
    }
    _passwords[phone] = password;
    await _persist();
  }

  /// Переключить активный аккаунт по индексу.
  /// Делает signOut → signIn → re-init VibeBackend.
  Future<bool> switchToAccount(int index) async {
    if (index < 0 || index >= _accounts.length) return false;
    if (index == _currentIdx) return true;

    final target = _accounts[index];
    final password = _passwords[target.phone];
    if (password == null || password.isEmpty) return false;

    final client = Supabase.instance.client;
    try {
      await client.auth.signOut();
    } catch (_) {}

    try {
      final email = _emailForPhone(target.phone);
      await client.auth.signInWithPassword(email: email, password: password);
    } catch (e) {
      debugPrint('AccountService switch failed: $e');
      return false;
    }

    _currentIdx = index;
    await _persist();

    // Переинициализировать бекенд под новую сессию
    try {
      await VibeBackend.init();
    } catch (e) {
      debugPrint('VibeBackend re-init after switch failed: $e');
    }

    return true;
  }

  /// Удалить аккаунт по индексу. Если это был активный — переключаем на 0.
  Future<void> removeAccount(int index) async {
    if (index < 0 || index >= _accounts.length) return;
    final removed = _accounts[index];
    _accounts.removeAt(index);
    _passwords.remove(removed.phone);
    if (_currentIdx >= _accounts.length) {
      _currentIdx = _accounts.isEmpty ? 0 : _accounts.length - 1;
    } else if (index < _currentIdx) {
      _currentIdx--;
    } else if (index == _currentIdx && _accounts.isNotEmpty) {
      // Активный удалили — надо перелогинить на новый текущий
      final next = _accounts[_currentIdx.clamp(0, _accounts.length - 1)];
      final pw = _passwords[next.phone];
      if (pw != null) {
        try {
          await Supabase.instance.client.auth.signOut();
          await Supabase.instance.client.auth.signInWithPassword(
            email: _emailForPhone(next.phone),
            password: pw,
          );
          await VibeBackend.init();
        } catch (_) {}
      }
    }
    await _persist();
  }

  /// Обновить displayName/emoji текущего профиля (после смены в настройках).
  Future<void> updateCurrentMeta({String? displayName, String? emoji, String? avatarUrl}) async {
    if (_accounts.isEmpty) return;
    final idx = _currentIdx.clamp(0, _accounts.length - 1);
    final cur = _accounts[idx];
    _accounts[idx] = VibeAccount(
      phone: cur.phone,
      displayName: displayName ?? cur.displayName,
      userId: cur.userId,
      emoji: emoji ?? cur.emoji,
      avatarUrl: avatarUrl ?? cur.avatarUrl,
    );
    await _persist();
  }
}

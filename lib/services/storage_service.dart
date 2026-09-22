import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import '../models/user_profile.dart';
import '../models/attendance_day.dart';
import '../models/session.dart';
import '../models/skill.dart';
import 'sync_service.dart';
import 'notification_service.dart';

class StorageService extends ChangeNotifier {
  static const _nameKey = 'user_name';
  static const _birthdayKey = 'user_birthday';
  static const _darkModeKey = 'dark_mode';
  static const _dailyTargetKey = 'daily_target_hours';
  static const _notificationsKey = 'notifications_enabled';
  static const _backendUrlKey = 'backend_url';
  static const _autoSyncKey = 'auto_sync_enabled';
  static const _lastSyncTimeKey = 'last_sync_time';
  static const _appLockEnabledKey = 'app_lock_enabled';
  static const _appLockPinHashKey = 'app_lock_pin_hash';
  static const _appLockBiometricKey = 'app_lock_biometric_enabled';
  static const _attendanceFile = 'attendance_data.json';
  static const _skillsFile = 'skills_data.json';
  static const _widgetChannel = MethodChannel('com.example.lnote/widgets');

  SharedPreferences? _prefs;
  UserProfile? _profile;
  List<AttendanceDay> _attendanceDays = [];
  List<Skill> _skills = [];
  bool _isDarkMode = true;
  double _dailyTargetHours = 8.0;
  bool _notificationsEnabled = true;

  // ─── App Lock & Biometrics ───
  bool _isAppLockEnabled = false;
  String? _pinHash;
  bool _isBiometricEnabled = false;

  // ─── Backend & Sync State ───
  String? _backendUrl;
  bool _autoSyncEnabled = true;
  DateTime? _lastSyncTime;
  SyncStatus _syncStatus = SyncStatus.idle;
  String? _lastSyncError;

  UserProfile? get profile => _profile;
  List<AttendanceDay> get attendanceDays => List.unmodifiable(_attendanceDays);
  List<Skill> get skills => List.unmodifiable(_skills);
  bool get isDarkMode => _isDarkMode;
  double get dailyTargetHours => _dailyTargetHours;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get hasProfile => _profile != null;

  bool get isAppLockEnabled => _isAppLockEnabled && _pinHash != null;
  bool get isBiometricEnabled => _isBiometricEnabled;

  String? get backendUrl => _backendUrl;
  bool get autoSyncEnabled => _autoSyncEnabled;
  DateTime? get lastSyncTime => _lastSyncTime;
  SyncStatus get syncStatus => _syncStatus;
  String? get lastSyncError => _lastSyncError;
  bool get isBackendConfigured => _backendUrl != null && _backendUrl!.trim().isNotEmpty;

  /// Initialize storage and load all data
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadProfile();
    _loadSettings();
    _loadSyncSettings();
    await _loadAttendance();
    await _loadSkills();

    // Auto-sync on startup if backend is configured
    if (isBackendConfigured && _autoSyncEnabled) {
      triggerSync();
    }
  }

  // ─── Profile ───────────────────────────────────────────────

  void _loadProfile() {
    final name = _prefs?.getString(_nameKey);
    final birthdayStr = _prefs?.getString(_birthdayKey);
    if (name != null && birthdayStr != null) {
      _profile = UserProfile(
        name: name,
        birthday: DateTime.parse(birthdayStr),
      );
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _prefs?.setString(_nameKey, profile.name);
    await _prefs?.setString(_birthdayKey, profile.birthday.toIso8601String());
    _profile = profile;
    notifyListeners();
    if (isBackendConfigured && _autoSyncEnabled) {
      triggerSync();
    }
  }

  // ─── Settings ──────────────────────────────────────────────

  void _loadSettings() {
    _isDarkMode = _prefs?.getBool(_darkModeKey) ?? true;
    _dailyTargetHours = _prefs?.getDouble(_dailyTargetKey) ?? 8.0;
    _notificationsEnabled = _prefs?.getBool(_notificationsKey) ?? true;
    _isAppLockEnabled = _prefs?.getBool(_appLockEnabledKey) ?? false;
    _pinHash = _prefs?.getString(_appLockPinHashKey);
    _isBiometricEnabled = _prefs?.getBool(_appLockBiometricKey) ?? false;
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    await _prefs?.setBool(_darkModeKey, value);
    notifyListeners();
  }

  Future<void> setDailyTargetHours(double hours) async {
    _dailyTargetHours = hours;
    await _prefs?.setDouble(_dailyTargetKey, hours);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    await _prefs?.setBool(_notificationsKey, value);
    notifyListeners();
  }

  // ─── App Lock & PIN Methods ────────────────────────────────

  static String _hashPin(String pin) {
    const salt = 'lnote_secure_salt_2026_';
    final bytes = utf8.encode('$salt$pin');
    return sha256.convert(bytes).toString();
  }

  /// Sets or updates the 4-digit PIN
  Future<bool> setAppPin(String pin, {bool enableBiometric = false}) async {
    if (pin.length != 4) return false;
    _pinHash = _hashPin(pin);
    _isAppLockEnabled = true;
    _isBiometricEnabled = enableBiometric;
    await _prefs?.setString(_appLockPinHashKey, _pinHash!);
    await _prefs?.setBool(_appLockEnabledKey, true);
    await _prefs?.setBool(_appLockBiometricKey, enableBiometric);
    notifyListeners();
    return true;
  }

  /// Verifies entered PIN against stored hash
  bool verifyPin(String pin) {
    if (_pinHash == null) return false;
    return _pinHash == _hashPin(pin);
  }

  /// Change existing PIN
  Future<bool> changePin({required String currentPin, required String newPin}) async {
    if (!verifyPin(currentPin)) return false;
    if (newPin.length != 4) return false;
    return setAppPin(newPin, enableBiometric: _isBiometricEnabled);
  }

  /// Disables App Lock after verifying current PIN
  Future<bool> disableAppLock({required String currentPin}) async {
    if (!verifyPin(currentPin)) return false;
    _isAppLockEnabled = false;
    _pinHash = null;
    _isBiometricEnabled = false;
    await _prefs?.remove(_appLockPinHashKey);
    await _prefs?.setBool(_appLockEnabledKey, false);
    await _prefs?.setBool(_appLockBiometricKey, false);
    notifyListeners();
    return true;
  }

  /// Toggles biometric unlock
  Future<void> setBiometricEnabled(bool value) async {
    _isBiometricEnabled = value;
    await _prefs?.setBool(_appLockBiometricKey, value);
    notifyListeners();
  }

  // ─── Attendance ────────────────────────────────────────────

  Future<File> get _attendanceFilePath async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_attendanceFile');
  }

  Future<void> _loadAttendance() async {
    try {
      final file = await _attendanceFilePath;
      if (await file.exists()) {
        final jsonStr = await file.readAsString();
        final List<dynamic> jsonList = json.decode(jsonStr);
        _attendanceDays = jsonList
            .map((j) => AttendanceDay.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading attendance: $e');
      _attendanceDays = [];
    }
  }

  Future<void> _saveAttendance() async {
    try {
      final file = await _attendanceFilePath;
      final jsonStr = json.encode(
        _attendanceDays.map((d) => d.toJson()).toList(),
      );
      await file.writeAsString(jsonStr);
      _notifyNativeWidgets();
    } catch (e) {
      debugPrint('Error saving attendance: $e');
    }
  }

  Future<void> _notifyNativeWidgets() async {
    try {
      if (Platform.isAndroid) {
        await _widgetChannel.invokeMethod('updateWidgets');
      }
    } catch (_) {
      // Not on Android or platform channel error
    }
  }

  /// Reload attendance from disk (e.g. after home screen widget modified attendance_data.json)
  Future<void> reloadAttendance() async {
    await _loadAttendance();
    notifyListeners();
  }

  /// Get today's attendance or create a new one
  AttendanceDay _getOrCreateToday() {
    final todayStr = _todayString();
    final idx = _attendanceDays.indexWhere((d) => d.date == todayStr);
    if (idx >= 0) return _attendanceDays[idx];
    final today = AttendanceDay(date: todayStr);
    _attendanceDays.add(today);
    return today;
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Check if there's an active session right now
  bool get hasActiveSession {
    final todayStr = _todayString();
    final idx = _attendanceDays.indexWhere((d) => d.date == todayStr);
    if (idx < 0) return false;
    return _attendanceDays[idx].hasActiveSession;
  }

  /// Get today's attendance day (may be null)
  AttendanceDay? get today {
    final todayStr = _todayString();
    final idx = _attendanceDays.indexWhere((d) => d.date == todayStr);
    if (idx < 0) return null;
    return _attendanceDays[idx];
  }

  /// Clock IN — start a new session
  Future<DateTime> clockIn() async {
    final now = DateTime.now();
    final day = _getOrCreateToday();
    day.sessions.add(Session(inTime: now));
    await _saveAttendance();
    notifyListeners();
    if (isBackendConfigured && _autoSyncEnabled) {
      triggerSync();
    }
    return now;
  }

  /// Clock OUT — end the current active session
  Future<DateTime> clockOut() async {
    final now = DateTime.now();
    final day = _getOrCreateToday();
    if (day.sessions.isNotEmpty && day.sessions.last.isActive) {
      final lastSession = day.sessions.last;
      day.sessions[day.sessions.length - 1] = lastSession.copyWith(outTime: now);
    }
    await _saveAttendance();
    notifyListeners();
    if (isBackendConfigured && _autoSyncEnabled) {
      triggerSync();
    }
    return now;
  }

  /// Get attendance for a specific date
  AttendanceDay? getAttendanceForDate(String dateStr) {
    final idx = _attendanceDays.indexWhere((d) => d.date == dateStr);
    if (idx < 0) return null;
    return _attendanceDays[idx];
  }

  /// Get all days sorted by date descending
  List<AttendanceDay> get sortedDays {
    final sorted = List<AttendanceDay>.from(_attendanceDays);
    sorted.sort((a, b) => b.date.compareTo(a.date));
    return sorted;
  }

  // ─── Skills ────────────────────────────────────────────────

  Future<File> get _skillsFilePath async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_skillsFile');
  }

  Future<void> _loadSkills() async {
    try {
      final file = await _skillsFilePath;
      if (await file.exists()) {
        final jsonStr = await file.readAsString();
        final List<dynamic> jsonList = json.decode(jsonStr);
        _skills = jsonList
            .map((j) => Skill.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading skills: $e');
      _skills = [];
    }
  }

  Future<void> _saveSkills() async {
    try {
      final file = await _skillsFilePath;
      final jsonStr = json.encode(
        _skills.map((s) => s.toJson()).toList(),
      );
      await file.writeAsString(jsonStr);
    } catch (e) {
      debugPrint('Error saving skills: $e');
    }
  }

  List<Skill> getSkills() => List.unmodifiable(_skills);

  Future<void> addSkill(String name) async {
    final skill = Skill.create(name: name);
    _skills.add(skill);
    await _saveSkills();
    notifyListeners();
    if (isBackendConfigured && _autoSyncEnabled) {
      triggerSync();
    }
  }

  Future<void> removeSkill(String id) async {
    _skills.removeWhere((s) => s.id == id);
    await _saveSkills();
    notifyListeners();
    if (isBackendConfigured && _autoSyncEnabled) {
      triggerSync();
    }
  }

  /// Tag a session with a skill name or custom tag
  Future<void> tagSession(String dateStr, int sessionIndex, String? tag) async {
    final dayIdx = _attendanceDays.indexWhere((d) => d.date == dateStr);
    if (dayIdx < 0) return;
    final day = _attendanceDays[dayIdx];
    if (sessionIndex < 0 || sessionIndex >= day.sessions.length) return;

    final session = day.sessions[sessionIndex];
    day.sessions[sessionIndex] = session.copyWith(
      tag: tag,
      clearTag: tag == null,
    );
    await _saveAttendance();
    notifyListeners();
    if (isBackendConfigured && _autoSyncEnabled) {
      triggerSync();
    }
  }

  /// Sum duration of all sessions tagged with a given skill name across all days
  Duration getHoursForSkill(String skillName) {
    Duration total = Duration.zero;
    for (final day in _attendanceDays) {
      for (final session in day.sessions) {
        if (session.tag == skillName && session.outTime != null) {
          total += session.duration;
        }
      }
    }
    return total;
  }

  /// Format hours for a skill (e.g. "142h 30m")
  String formatSkillHours(String skillName) {
    final d = getHoursForSkill(skillName);
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Get mastery progress (0.0 to 1.0) for a skill
  double getSkillProgress(String skillName) {
    final d = getHoursForSkill(skillName);
    final hours = d.inMinutes / 60.0;
    return (hours / 10000.0).clamp(0.0, 1.0);
  }

  // ─── Backend & Sync Methods ────────────────────────────────

  void _loadSyncSettings() {
    _backendUrl = _prefs?.getString(_backendUrlKey);
    _autoSyncEnabled = _prefs?.getBool(_autoSyncKey) ?? true;
    final lastSyncStr = _prefs?.getString(_lastSyncTimeKey);
    if (lastSyncStr != null) {
      _lastSyncTime = DateTime.tryParse(lastSyncStr);
    }
  }

  Future<void> setBackendUrl(String? url) async {
    final cleanUrl = url != null ? SyncService.normalizeUrl(url) : null;
    _backendUrl = (cleanUrl != null && cleanUrl.isNotEmpty) ? cleanUrl : null;
    if (_backendUrl != null) {
      await _prefs?.setString(_backendUrlKey, _backendUrl!);
    } else {
      await _prefs?.remove(_backendUrlKey);
    }
    _syncStatus = SyncStatus.idle;
    _lastSyncError = null;
    notifyListeners();

    if (isBackendConfigured && _autoSyncEnabled) {
      triggerSync();
    }
  }

  Future<void> setAutoSyncEnabled(bool value) async {
    _autoSyncEnabled = value;
    await _prefs?.setBool(_autoSyncKey, value);
    notifyListeners();
  }

  /// Trigger sync with backend in the background
  Future<bool> triggerSync() async {
    if (!isBackendConfigured) return false;
    if (_syncStatus == SyncStatus.syncing) return false;

    _syncStatus = SyncStatus.syncing;
    _lastSyncError = null;
    notifyListeners();

    try {
      final result = await SyncService.syncWithBackend(
        rawUrl: _backendUrl!,
        localDays: _attendanceDays,
        localSkills: _skills,
        localProfile: _profile,
      );

      if (result.success) {
        if (result.attendanceDays != null) {
          _attendanceDays = result.attendanceDays!;
          await _saveAttendance();
        }
        if (result.skills != null) {
          _skills = result.skills!;
          await _saveSkills();
        }
        if (result.profile != null) {
          _profile = result.profile;
          await _prefs?.setString(_nameKey, _profile!.name);
          await _prefs?.setString(_birthdayKey, _profile!.birthday.toIso8601String());
        }

        _lastSyncTime = DateTime.now();
        await _prefs?.setString(_lastSyncTimeKey, _lastSyncTime!.toIso8601String());
        _syncStatus = SyncStatus.success;
        _lastSyncError = null;

        if (Platform.isAndroid && _backendUrl != null) {
          await NotificationService.checkAndDeliverBackendNotifications(_backendUrl!);
        }

        notifyListeners();
        return true;
      } else {
        _syncStatus = SyncStatus.error;
        _lastSyncError = result.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _syncStatus = SyncStatus.error;
      _lastSyncError = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ─── Export / Clear ────────────────────────────────────────

  /// Export all data as JSON string
  String exportData() {
    final data = {
      'profile': _profile?.toJson(),
      'attendance': _attendanceDays.map((d) => d.toJson()).toList(),
      'skills': _skills.map((s) => s.toJson()).toList(),
      'settings': {
        'darkMode': _isDarkMode,
        'dailyTargetHours': _dailyTargetHours,
        'notificationsEnabled': _notificationsEnabled,
      },
      'exportedAt': DateTime.now().toIso8601String(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Clear all attendance data
  Future<void> clearAttendance() async {
    _attendanceDays = [];
    await _saveAttendance();
    notifyListeners();
  }

  /// Clear everything (profile + attendance + settings + skills)
  Future<void> clearAll() async {
    _profile = null;
    _attendanceDays = [];
    _skills = [];
    _isDarkMode = true;
    _dailyTargetHours = 8.0;
    _notificationsEnabled = true;
    _lastSyncTime = null;
    _syncStatus = SyncStatus.idle;
    _lastSyncError = null;
    await _prefs?.clear();
    final file = await _attendanceFilePath;
    if (await file.exists()) await file.delete();
    final skillsFile = await _skillsFilePath;
    if (await skillsFile.exists()) await skillsFile.delete();
    notifyListeners();
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import '../models/user_profile.dart';
import '../models/attendance_day.dart';
import '../models/session.dart';
import '../models/skill.dart';
import '../models/food_item.dart';
import '../models/app_restriction.dart';
import '../models/usage_session.dart';
import '../models/usage_reason.dart';
import 'sync_service.dart';
import 'notification_service.dart';
import 'food_prep_service.dart';

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
  static const _foodPrepEnabledKey = 'food_prep_enabled';
  static const _foodPrepTimeKey = 'food_prep_time';
  static const _foodPrepLastSkippedKey = 'food_prep_last_skipped_date';
  static const _foodPrepSnoozeUntilKey = 'food_prep_snooze_until';
  static const _foodPrepCheckedIdsKey = 'food_prep_checked_ids';
  static const _attendanceFile = 'attendance_data.json';
  static const _skillsFile = 'skills_data.json';
  static const _foodsFile = 'foods_data.json';
  static const _restrictionsFile = 'app_restrictions.json';
  static const _usageSessionsFile = 'usage_sessions.json';
  static const _usageReasonsFile = 'usage_reasons.json';
  static const _widgetChannel = MethodChannel('com.example.lnote/widgets');

  SharedPreferences? _prefs;
  UserProfile? _profile;
  List<AttendanceDay> _attendanceDays = [];
  List<Skill> _skills = [];
  List<FoodItem> _foods = [];
  List<AppRestriction> _appRestrictions = [];
  List<UsageSession> _usageSessions = [];
  List<UsageReason> _usageReasons = [];
  bool _isDarkMode = true;
  double _dailyTargetHours = 8.0;
  bool _notificationsEnabled = true;

  // ─── Food Preparation Settings ───
  bool _foodPrepEnabled = true;
  TimeOfDay _foodPrepTime = const TimeOfDay(hour: 20, minute: 0);
  String? _foodPrepLastSkippedDate;
  DateTime? _foodPrepSnoozeUntil;
  Set<String> _foodPrepCheckedIds = {};

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
  List<FoodItem> get foods => List.unmodifiable(_foods);
  List<AppRestriction> get appRestrictions => List.unmodifiable(_appRestrictions);
  List<UsageSession> get usageSessions => List.unmodifiable(_usageSessions);
  List<UsageReason> get usageReasons => List.unmodifiable(_usageReasons);
  bool get isDarkMode => _isDarkMode;
  double get dailyTargetHours => _dailyTargetHours;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get hasProfile => _profile != null;

  // ─── Food Preparation Getters ───
  bool get foodPrepEnabled => _foodPrepEnabled;
  TimeOfDay get foodPrepTime => _foodPrepTime;
  String? get foodPrepLastSkippedDate => _foodPrepLastSkippedDate;
  DateTime? get foodPrepSnoozeUntil => _foodPrepSnoozeUntil;
  Set<String> get foodPrepCheckedIds => Set.unmodifiable(_foodPrepCheckedIds);

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
    await _loadFoods();
    await _loadAppRestrictions();
    await _loadUsageSessions();
    await _loadUsageReasons();
    _loadFoodPrepSettings();

    // Schedule Android daily food prep alarm
    FoodPrepService.scheduleDailyAlarm(
      hour: _foodPrepTime.hour,
      minute: _foodPrepTime.minute,
      enabled: _foodPrepEnabled,
    );

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

  // ─── Foods ────────────────────────────────────────────────

  Future<File> get _foodsFilePath async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_foodsFile');
  }

  Future<void> _loadFoods() async {
    try {
      final file = await _foodsFilePath;
      if (await file.exists()) {
        final jsonStr = await file.readAsString();
        final List<dynamic> jsonList = json.decode(jsonStr);
        _foods = jsonList
            .map((j) => FoodItem.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading foods: $e');
      _foods = [];
    }
  }

  Future<void> _saveFoods() async {
    try {
      final file = await _foodsFilePath;
      final jsonStr = json.encode(
        _foods.map((f) => f.toJson()).toList(),
      );
      await file.writeAsString(jsonStr);
    } catch (e) {
      debugPrint('Error saving foods: $e');
    }
  }

  void _loadFoodPrepSettings() {
    _foodPrepEnabled = _prefs?.getBool(_foodPrepEnabledKey) ?? true;
    String timeStr = _prefs?.getString(_foodPrepTimeKey) ?? '20:00';
    if (timeStr == '21:00') {
      timeStr = '20:00';
      _prefs?.setString(_foodPrepTimeKey, '20:00');
    }
    final parts = timeStr.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 20 : 20;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    _foodPrepTime = TimeOfDay(hour: hour, minute: minute);
    _foodPrepLastSkippedDate = _prefs?.getString(_foodPrepLastSkippedKey);
    final snoozeStr = _prefs?.getString(_foodPrepSnoozeUntilKey);
    if (snoozeStr != null) {
      _foodPrepSnoozeUntil = DateTime.tryParse(snoozeStr);
    }
    final checkedList = _prefs?.getStringList(_foodPrepCheckedIdsKey) ?? [];
    _foodPrepCheckedIds = checkedList.toSet();
  }

  List<FoodItem> getFoodsForMeal(MealType mealType) {
    return _foods.where((f) => f.mealType == mealType).toList();
  }

  List<FoodItem> getFoodsForWeekday(int weekday) {
    return _foods.where((f) => f.isActiveOnWeekday(weekday)).toList();
  }

  List<FoodItem> getTomorrowFoods() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return _foods.where((f) => f.isActiveOnWeekday(tomorrow.weekday)).toList();
  }

  List<FoodItem> getTodayFoods() {
    final today = DateTime.now();
    return _foods.where((f) => f.isActiveOnWeekday(today.weekday)).toList();
  }

  Future<void> addFood(FoodItem food) async {
    _foods.add(food);
    await _saveFoods();
    notifyListeners();
  }

  Future<void> updateFood(FoodItem food) async {
    final index = _foods.indexWhere((f) => f.id == food.id);
    if (index >= 0) {
      _foods[index] = food;
      await _saveFoods();
      notifyListeners();
    }
  }

  Future<void> removeFood(String id) async {
    _foods.removeWhere((f) => f.id == id);
    _foodPrepCheckedIds.remove(id);
    await _saveFoods();
    notifyListeners();
  }

  Future<void> toggleFoodActive(String id) async {
    final index = _foods.indexWhere((f) => f.id == id);
    if (index >= 0) {
      final cur = _foods[index];
      _foods[index] = cur.copyWith(isEnabled: !cur.isEnabled);
      await _saveFoods();
      notifyListeners();
    }
  }

  // ─── Food Preparation Settings & Actions ───

  Future<void> setFoodPrepEnabled(bool enabled) async {
    _foodPrepEnabled = enabled;
    await _prefs?.setBool(_foodPrepEnabledKey, enabled);
    FoodPrepService.scheduleDailyAlarm(
      hour: _foodPrepTime.hour,
      minute: _foodPrepTime.minute,
      enabled: enabled,
    );
    notifyListeners();
  }

  Future<void> setFoodPrepTime(TimeOfDay time) async {
    _foodPrepTime = time;
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    await _prefs?.setString(_foodPrepTimeKey, timeStr);
    FoodPrepService.scheduleDailyAlarm(
      hour: time.hour,
      minute: time.minute,
      enabled: _foodPrepEnabled,
    );
    notifyListeners();
  }

  /// Temporary Skip: Pop up again after 10 minutes
  Future<void> temporarySkipFoodPrep([Duration duration = const Duration(minutes: 10)]) async {
    _foodPrepSnoozeUntil = DateTime.now().add(duration);
    await _prefs?.setString(
      _foodPrepSnoozeUntilKey,
      _foodPrepSnoozeUntil!.toIso8601String(),
    );
    await FoodPrepService.snooze10Minutes();
    await FoodPrepService.hideNativeFloatingWindow();
    notifyListeners();
  }

  /// Skip: Won't pop up again today
  Future<void> skipFoodPrepToday() async {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _foodPrepLastSkippedDate = todayStr;
    _foodPrepSnoozeUntil = null;
    await _prefs?.setString(_foodPrepLastSkippedKey, todayStr);
    await _prefs?.remove(_foodPrepSnoozeUntilKey);
    await FoodPrepService.hideNativeFloatingWindow();
    notifyListeners();
  }

  Future<void> toggleTomorrowFoodChecked(String foodId) async {
    if (_foodPrepCheckedIds.contains(foodId)) {
      _foodPrepCheckedIds.remove(foodId);
    } else {
      _foodPrepCheckedIds.add(foodId);
    }
    await _prefs?.setStringList(
      _foodPrepCheckedIdsKey,
      _foodPrepCheckedIds.toList(),
    );
    notifyListeners();
  }

  Future<void> resetTomorrowFoodChecks() async {
    _foodPrepCheckedIds.clear();
    await _prefs?.remove(_foodPrepCheckedIdsKey);
    notifyListeners();
  }

  bool isTomorrowFoodChecked(String foodId) => _foodPrepCheckedIds.contains(foodId);

  /// Check whether food prep popup should be triggered right now
  bool shouldTriggerFoodPrepNow() {
    if (!_foodPrepEnabled) return false;
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    // If already skipped today, don't popup again
    if (_foodPrepLastSkippedDate == todayStr) return false;

    // If snoozed, check if snooze time has elapsed
    if (_foodPrepSnoozeUntil != null) {
      return now.isAfter(_foodPrepSnoozeUntil!);
    }

    // Check if current time is at or past target prep time
    final targetTime = DateTime(
      now.year,
      now.month,
      now.day,
      _foodPrepTime.hour,
      _foodPrepTime.minute,
    );
    return now.isAfter(targetTime);
  }

  // ─── App Usage Control ─────────────────────────────────────

  Future<File> get _restrictionsFilePath async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_restrictionsFile');
  }

  Future<File> get _usageSessionsFilePath async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_usageSessionsFile');
  }

  Future<File> get _usageReasonsFilePath async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_usageReasonsFile');
  }

  Future<void> _loadAppRestrictions() async {
    try {
      final file = await _restrictionsFilePath;
      if (await file.exists()) {
        final jsonStr = await file.readAsString();
        final List<dynamic> jsonList = json.decode(jsonStr);
        _appRestrictions = jsonList
            .map((j) => AppRestriction.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading app restrictions: $e');
      _appRestrictions = [];
    }
  }

  Future<void> _saveAppRestrictions() async {
    try {
      final file = await _restrictionsFilePath;
      final jsonStr = json.encode(
        _appRestrictions.map((r) => r.toJson()).toList(),
      );
      await file.writeAsString(jsonStr);
    } catch (e) {
      debugPrint('Error saving app restrictions: $e');
    }
  }

  Future<void> _loadUsageSessions() async {
    try {
      final file = await _usageSessionsFilePath;
      if (await file.exists()) {
        final jsonStr = await file.readAsString();
        final List<dynamic> jsonList = json.decode(jsonStr);
        _usageSessions = jsonList
            .map((j) => UsageSession.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading usage sessions: $e');
      _usageSessions = [];
    }
  }

  Future<void> _saveUsageSessions() async {
    try {
      final file = await _usageSessionsFilePath;
      final jsonStr = json.encode(
        _usageSessions.map((s) => s.toJson()).toList(),
      );
      await file.writeAsString(jsonStr);
    } catch (e) {
      debugPrint('Error saving usage sessions: $e');
    }
  }

  Future<void> _loadUsageReasons() async {
    try {
      final file = await _usageReasonsFilePath;
      if (await file.exists()) {
        final jsonStr = await file.readAsString();
        if (jsonStr.isNotEmpty) {
          final List<dynamic> jsonList = json.decode(jsonStr);
          _usageReasons = jsonList
              .map((j) => UsageReason.fromJson(j as Map<String, dynamic>))
              .toList();
        }
      }

      // Also merge any reasons logged directly by native Blocker Activity in filesDir
      try {
        final supportDir = await getApplicationSupportDirectory();
        final nativeFile = File('${supportDir.path}/$_usageReasonsFile');
        if (await nativeFile.exists()) {
          final nativeJsonStr = await nativeFile.readAsString();
          if (nativeJsonStr.isNotEmpty) {
            final List<dynamic> nativeList = json.decode(nativeJsonStr);
            for (final j in nativeList) {
              final reason = UsageReason.fromJson(j as Map<String, dynamic>);
              if (!_usageReasons.any((r) => r.id == reason.id)) {
                _usageReasons.add(reason);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Note: Error checking native usage reasons: $e');
      }

      // Sort newest first
      _usageReasons.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      debugPrint('Error loading usage reasons: $e');
      _usageReasons = [];
    }
  }

  Future<void> _saveUsageReasons() async {
    try {
      final file = await _usageReasonsFilePath;
      final jsonStr = json.encode(
        _usageReasons.map((r) => r.toJson()).toList(),
      );
      await file.writeAsString(jsonStr);

      // Keep native copy in sync
      try {
        final supportDir = await getApplicationSupportDirectory();
        final nativeFile = File('${supportDir.path}/$_usageReasonsFile');
        await nativeFile.writeAsString(jsonStr);
      } catch (_) {}
    } catch (e) {
      debugPrint('Error saving usage reasons: $e');
    }
  }

  // ─── App Restriction CRUD ───

  AppRestriction? getRestriction(String packageId) {
    final idx = _appRestrictions.indexWhere((r) => r.packageId == packageId);
    return idx >= 0 ? _appRestrictions[idx] : null;
  }

  bool isPackageControlled(String packageId) =>
      _appRestrictions.any((r) => r.packageId == packageId && r.enabled);

  Future<void> saveAppRestriction(AppRestriction restriction) =>
      addOrUpdateRestriction(restriction);

  Future<void> removeAppRestriction(String packageId) =>
      removeRestriction(packageId);

  Future<void> startUsageSession(UsageSession session) =>
      addUsageSession(session);

  List<AppRestriction> get enabledRestrictions =>
      _appRestrictions.where((r) => r.enabled).toList();

  Future<void> addOrUpdateRestriction(AppRestriction restriction) async {
    final idx = _appRestrictions.indexWhere(
      (r) => r.packageId == restriction.packageId,
    );
    if (idx >= 0) {
      _appRestrictions[idx] = restriction;
    } else {
      _appRestrictions.add(restriction);
    }
    await _saveAppRestrictions();
    notifyListeners();
  }

  Future<void> removeRestriction(String packageId) async {
    _appRestrictions.removeWhere((r) => r.packageId == packageId);
    await _saveAppRestrictions();
    notifyListeners();
  }

  Future<void> toggleRestrictionEnabled(String packageId) async {
    final idx = _appRestrictions.indexWhere((r) => r.packageId == packageId);
    if (idx >= 0) {
      final cur = _appRestrictions[idx];
      _appRestrictions[idx] = cur.copyWith(enabled: !cur.enabled);
      await _saveAppRestrictions();
      notifyListeners();
    }
  }

  // ─── Usage Session CRUD ───

  Future<void> addUsageSession(UsageSession session) async {
    _usageSessions.add(session);
    await _saveUsageSessions();
    notifyListeners();
  }

  Future<void> updateUsageSession(UsageSession session) async {
    final idx = _usageSessions.indexWhere((s) => s.id == session.id);
    if (idx >= 0) {
      _usageSessions[idx] = session;
      await _saveUsageSessions();
      notifyListeners();
    }
  }

  List<UsageSession> getSessionsForDate(DateTime date) {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _usageSessions.where((s) => s.startedAt.startsWith(dateStr)).toList();
  }

  List<UsageSession> getSessionsForPackage(String packageId) {
    return _usageSessions.where((s) => s.packageId == packageId).toList();
  }

  /// Get total approved extra minutes used today for a given package.
  int getTodayExtraMinutes(String packageId) {
    final todayStr = _todayString();
    return _usageSessions
        .where((s) =>
            s.packageId == packageId &&
            s.startedAt.startsWith(todayStr) &&
            (s.status == SessionStatus.completed || s.status == SessionStatus.active))
        .fold(0, (sum, s) => sum + s.actualDurationMinutes);
  }

  // ─── Usage Reason CRUD ───

  Future<void> addUsageReason(UsageReason reason) async {
    _usageReasons.add(reason);
    await _saveUsageReasons();
    notifyListeners();
  }

  List<UsageReason> getReasonsForDate(DateTime date) {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _usageReasons.where((r) => r.timestamp.startsWith(dateStr)).toList();
  }

  List<UsageReason> getReasonsForPackage(String packageId) {
    return _usageReasons.where((r) => r.packageId == packageId).toList();
  }

  /// Today's conscious usage statistics.
  Map<String, dynamic> getTodayConsciousStats() {
    final todayStr = _todayString();
    final todayReasons = _usageReasons.where((r) => r.timestamp.startsWith(todayStr)).toList();
    final totalRequests = todayReasons.length;
    final approved = todayReasons.where((r) => r.wasAllowed).length;
    final denied = totalRequests - approved;
    final extraRequested = todayReasons.fold(0, (sum, r) => sum + r.requestedMinutes);
    final extraApproved = todayReasons.fold(0, (sum, r) => sum + r.approvedMinutes);

    // Most common reason category
    final categoryCounts = <ReasonCategory, int>{};
    for (final r in todayReasons) {
      categoryCounts[r.category] = (categoryCounts[r.category] ?? 0) + 1;
    }
    ReasonCategory? topCategory;
    int topCount = 0;
    for (final entry in categoryCounts.entries) {
      if (entry.value > topCount) {
        topCount = entry.value;
        topCategory = entry.key;
      }
    }

    return {
      'totalRequests': totalRequests,
      'approved': approved,
      'denied': denied,
      'extraRequestedMinutes': extraRequested,
      'extraApprovedMinutes': extraApproved,
      'topCategory': topCategory,
    };
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
      'foods': _foods.map((f) => f.toJson()).toList(),
      'appRestrictions': _appRestrictions.map((r) => r.toJson()).toList(),
      'usageSessions': _usageSessions.map((s) => s.toJson()).toList(),
      'usageReasons': _usageReasons.map((r) => r.toJson()).toList(),
      'settings': {
        'darkMode': _isDarkMode,
        'dailyTargetHours': _dailyTargetHours,
        'notificationsEnabled': _notificationsEnabled,
        'foodPrepEnabled': _foodPrepEnabled,
        'foodPrepTime': '${_foodPrepTime.hour.toString().padLeft(2, '0')}:${_foodPrepTime.minute.toString().padLeft(2, '0')}',
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

  /// Clear everything (profile + attendance + settings + skills + foods)
  Future<void> clearAll() async {
    _profile = null;
    _attendanceDays = [];
    _skills = [];
    _foods = [];
    _appRestrictions = [];
    _usageSessions = [];
    _usageReasons = [];
    _isDarkMode = true;
    _dailyTargetHours = 8.0;
    _notificationsEnabled = true;
    _foodPrepEnabled = true;
    _foodPrepTime = const TimeOfDay(hour: 21, minute: 0);
    _foodPrepLastSkippedDate = null;
    _foodPrepSnoozeUntil = null;
    _foodPrepCheckedIds.clear();
    _lastSyncTime = null;
    _syncStatus = SyncStatus.idle;
    _lastSyncError = null;
    await _prefs?.clear();
    final file = await _attendanceFilePath;
    if (await file.exists()) await file.delete();
    final skillsFile = await _skillsFilePath;
    if (await skillsFile.exists()) await skillsFile.delete();
    final foodsFile = await _foodsFilePath;
    if (await foodsFile.exists()) await foodsFile.delete();
    final restrictionsFile = await _restrictionsFilePath;
    if (await restrictionsFile.exists()) await restrictionsFile.delete();
    final sessionsFile = await _usageSessionsFilePath;
    if (await sessionsFile.exists()) await sessionsFile.delete();
    final reasonsFile = await _usageReasonsFilePath;
    if (await reasonsFile.exists()) await reasonsFile.delete();
    notifyListeners();
  }
}

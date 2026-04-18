import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'constants.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio _dio;
  String? _csrfToken;
  CookieJar? _cookieJar;

  ApiClient._internal() {
    _cookieJar = CookieJar();
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      followRedirects: true,
      validateStatus: (status) => true,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      },
    ));
    _dio.interceptors.add(CookieManager(_cookieJar!));
  }

  String? get csrfToken => _csrfToken;
  CookieJar? get cookieJar => _cookieJar;

  /// Extract CSRF token from HTML response - tries multiple patterns
  String? extractCsrf(String html) {
    // Pattern 1: Standard input field
    var match = RegExp(r'name="_csrf"\s+value="([^"]+)"').firstMatch(html);
    if (match != null) return match.group(1);

    // Pattern 2: Single quotes around value
    match = RegExp(r'name="_csrf"\s+value=\'([^\']+)\'').firstMatch(html);
    if (match != null) return match.group(1);

    // Pattern 3: Without quotes around name
    match = RegExp(r'_csrf"\s+value="([^"]+)"').firstMatch(html);
    if (match != null) return match.group(1);

    // Pattern 4: Meta tag (some frameworks use this)
    match = RegExp(r'name=["\']csrf-token["\']\s+content=["\']([^"\']+)["\']').firstMatch(html);
    if (match != null) return match.group(1);

    return null;
  }

  /// Get CSRF token from login page (for initial login)
  Future<String?> getLoginCsrf() async {
    try {
      final resp = await _dio.get(
        ApiConstants.loginUrl,
        options: Options(
          headers: {
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
        ),
      );

      print('Login page status: ${resp.statusCode}');
      print('Response type: ${resp.data.runtimeType}');

      if (resp.data is String) {
        final html = resp.data.toString();
        final token = extractCsrf(html);
        print('CSRF token found: $token');
        _csrfToken = token;
        return token;
      } else {
        print('Response is not a string: ${resp.data}');
      }
      return null;
    } catch (e) {
      print('Error getting CSRF: $e');
      return null;
    }
  }

  /// Refresh CSRF by fetching calendar page (after login)
  Future<bool> refreshCsrf() async {
    try {
      final resp = await _dio.get(ApiConstants.calendarUrl);
      if (resp.statusCode == 200 && resp.data is String) {
        final token = extractCsrf(resp.data);
        if (token != null) {
          _csrfToken = token;
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Login to OSDM
  Future<LoginResult> login({
    required String nip,
    required String password,
    bool rememberMe = false,
  }) async {
    // First get CSRF from login page (not calendar page!)
    final csrfToken = await getLoginCsrf();
    if (csrfToken == null || _csrfToken == null) {
      return LoginResult(success: false, error: 'Gagal mendapat CSRF token dari halaman login');
    }

    try {
      print('Attempting login with NIP: $nip');
      print('CSRF token: $_csrfToken');

      final resp = await _dio.post(
        ApiConstants.loginUrl,
        data: FormData.fromMap({
          'nip': nip,
          'password': password,
          '_csrf': _csrfToken,
        }),
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          headers: {
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Origin': ApiConstants.baseUrl,
            'Referer': '${ApiConstants.loginUrl}',
          },
        ),
      );

      print('Login response status: ${resp.statusCode}');
      final html = resp.data.toString();
      print('Response contains logout: ${html.contains('logout')}');
      print('Response contains Log Harian: ${html.contains('Log Harian')}');

      // Check if redirected to dashboard or still on login page
      // If login successful, should see dashboard content or logout button
      if (html.contains('logout') || html.contains('dashboard') || html.contains('Log Harian')) {
        // Refresh CSRF from calendar page for subsequent requests
        await refreshCsrf();
        return LoginResult(success: true);
      } else if (html.contains('Kata Sandi') || html.contains('Username tidak valid') || html.contains('Password tidak valid')) {
        return LoginResult(success: false, error: 'NIP atau Password salah');
      }

      // Check for error messages
      if (html.contains('error') || html.contains('gagal')) {
        return LoginResult(success: false, error: 'Login gagal. Periksa NIP dan Password.');
      }

      return LoginResult(success: false, error: 'Login gagal. Status: ${resp.statusCode}');
    } on DioException catch (e) {
      print('DioException: ${e.message}, Type: ${e.type}, Response: ${e.response?.statusCode}');
      return LoginResult(success: false, error: 'Network error: ${e.message}');
    } catch (e) {
      print('Exception: $e');
      return LoginResult(success: false, error: 'Error: $e');
    }
  }

  /// Get calendar page HTML
  Future<String?> getCalendarPage() async {
    try {
      final resp = await _dio.get(ApiConstants.calendarUrl);
      if (resp.statusCode == 200) {
        final html = resp.data.toString();
        final token = extractCsrf(html);
        if (token != null) _csrfToken = token;
        return html;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Parse calendar HTML to get work days and status
  CalendarData parseCalendar(String html) {
    final List<WorkDay> workDays = [];

    // Parse Evo Calendar event structure from JS
    // Pattern: id:"kerja_DD_MM_YYYY", title:"...", ...
    final eventRegex = RegExp('id\\s*:\\s*["\']kerja_(\\d+)_(\\d+)_(\\d+)["\']\\s*,\\s*title\\s*:\\s*["\']([^"\']+)["\']');
    final matches = eventRegex.allMatches(html);

    for (final match in matches) {
      final day = match.group(1)!;
      final month = match.group(2)!;
      final year = match.group(3)!;
      final title = match.group(4)!;

      final dateStr = '$year-${month.padLeft(2, '0')}-${day.padLeft(2, '0')}';
      final status = title.contains('Belum Terisi')
          ? DayStatus.unfilled
          : title.contains('Libur')
              ? DayStatus.holiday
              : DayStatus.filled;

      workDays.add(WorkDay(
        date: dateStr,
        status: status,
        title: title,
      ));
    }

    // Also try to find "Belum Terisi (X)" counter
    int? unfilledCount;
    final counterMatch = RegExp(r'Belum Terisi\s*\((\d+)\)').firstMatch(html);
    if (counterMatch != null) {
      unfilledCount = int.tryParse(counterMatch.group(1)!);
    }

    return CalendarData(workDays: workDays, unfilledCount: unfilledCount);
  }

  /// Submit a log entry
  Future<SubmitResult> submitLog({
    required String tanggal,
    required String namaAktivitas,
    required String deskripsi,
    required String indikator,
    required String kuantitas,
    required String satuan,
    String link = '',
  }) async {
    // Refresh CSRF for each submission
    final token = await getLoginCsrf();
    if (token == null) {
      return SubmitResult(success: false, error: 'CSRF token kosong');
    }

    try {
      final resp = await _dio.post(
        ApiConstants.saveLogUrl,
        data: FormData.fromMap({
          '_csrf': _csrfToken,
          'THarianLog[nama_aktivitas]': namaAktivitas,
          'THarianLog[deskripsi]': deskripsi,
          'THarianLog[tanggal]': tanggal,
          'THarianLog[indikator]': indikator,
          'THarianLog[output_kuantitas]': kuantitas,
          'THarianLog[output_satuan]': satuan,
          'THarianLog[link]': link,
        }),
        options: Options(contentType: 'application/x-www-form-urlencoded'),
      );

      final html = resp.data.toString();
      if (html.contains('success') || html.contains('berhasil') || resp.statusCode == 200) {
        return SubmitResult(success: true);
      } else if (html.contains('_csrf')) {
        return SubmitResult(success: false, error: 'CSRF invalid, coba lagi');
      }

      return SubmitResult(success: false, error: 'Gagal menyimpan log');
    } on DioException catch (e) {
      return SubmitResult(success: false, error: 'Network: ${e.message}');
    } catch (e) {
      return SubmitResult(success: false, error: '$e');
    }
  }

  /// Get log data for a specific date
  Future<String?> getLogData(String date) async {
    // Format: kerja_DD_MM_YYYY
    final parts = date.split('-');
    if (parts.length != 3) return null;
    final id = 'kerja_${parts[2]}_${parts[1]}_${parts[0]}'; // kerja_DD_MM_YYYY

    try {
      final resp = await _dio.get(
        ApiConstants.getDataAjaxUrl,
        queryParameters: {'t_harian_log_id': id},
      );
      if (resp.statusCode == 200) {
        return resp.data.toString();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Parse a single log entry from HTML response
  LogEntry? parseLogEntry(String html) {
    try {
      // Parse from input fields - more robust approach
      final nameInput = RegExp('name=["\']THarianLog\\[nama_aktivitas\\]["\']\\s+value=["\']([^"\']+)["\']').firstMatch(html);
      final descInput = RegExp('name=["\']THarianLog\\[deskripsi\\]["\']\\s[^>]*>([^<]+)<').firstMatch(html);

      // Find selected option in indikator select
      final indSelect = RegExp('<select[^>]*name=["\']THarianLog\\[indikator\\]["\'][^>]*>.*?<option[^>]*value=["\']([^"\']+)["\'][^>]*selected', dotAll: true).firstMatch(html);

      return LogEntry(
        namaAktivitas: nameInput?.group(1) ?? '',
        deskripsi: descInput?.group(1) ?? '',
        indikator: indSelect?.group(1) ?? '',
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if logged in (session valid)
  Future<bool> isLoggedIn() async {
    try {
      final resp = await _dio.get(ApiConstants.calendarUrl);
      final html = resp.data.toString();
      return html.contains('logout') || html.contains('ALLIF MAULANA');
    } catch (e) {
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      await _dio.get('${ApiConstants.baseUrl}/site/logout');
    } catch (e) {
      // ignore
    }
    _csrfToken = null;
  }
}

// --- Data Classes ---

class LoginResult {
  final bool success;
  final String? error;
  LoginResult({required this.success, this.error});
}

class SubmitResult {
  final bool success;
  final String? error;
  SubmitResult({required this.success, this.error});
}

enum DayStatus { filled, unfilled, holiday }

class WorkDay {
  final String date;
  final DayStatus status;
  final String title;
  WorkDay({
    required this.date,
    required this.status,
    required this.title,
  });

  DateTime get dateTime => DateTime.parse(date);
}

class CalendarData {
  final List<WorkDay> workDays;
  final int? unfilledCount;
  CalendarData({required this.workDays, this.unfilledCount});

  List<WorkDay> get filledDays => workDays.where((d) => d.status == DayStatus.filled).toList();
  List<WorkDay> get unfilledDays => workDays.where((d) => d.status == DayStatus.unfilled).toList();
  List<WorkDay> get holidays => workDays.where((d) => d.status == DayStatus.holiday).toList();
}

class LogEntry {
  final String namaAktivitas;
  final String deskripsi;
  final String indikator;
  LogEntry({
    required this.namaAktivitas,
    required this.deskripsi,
    required this.indikator,
  });
}

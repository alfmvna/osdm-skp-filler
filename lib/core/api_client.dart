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

  /// Extract CSRF token from HTML response
  void extractCsrf(String html) {
    final csrfMatch = RegExp(r'name="_csrf"\s+value="([^"]+)"').firstMatch(html);
    if (csrfMatch != null) {
      _csrfToken = csrfMatch.group(1);
    }
  }

  /// Refresh CSRF by fetching calendar page
  Future<bool> refreshCsrf() async {
    try {
      final resp = await _dio.get(ApiConstants.calendarUrl);
      if (resp.statusCode == 200 && resp.data is String) {
        extractCsrf(resp.data);
        return _csrfToken != null;
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
    // First get CSRF
    final csrfOk = await refreshCsrf();
    if (!csrfOk || _csrfToken == null) {
      return LoginResult(success: false, error: 'Gagal mendapat CSRF token');
    }

    try {
      final resp = await _dio.post(
        ApiConstants.loginUrl,
        data: FormData.fromMap({
          'nip': nip,
          'password': password,
          '_csrf': _csrfToken,
        }),
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
        ),
      );

      final html = resp.data.toString();

      // Check if login successful (has profile button, no error)
      if (html.contains('ALLIF MAULANA') || html.contains('logout') || !html.contains('error')) {
        // Double-check: fetch dashboard
        final dashResp = await _dio.get(ApiConstants.calendarUrl);
        if (dashResp.statusCode == 200) {
          extractCsrf(dashResp.data.toString());
          return LoginResult(success: true);
        }
        return LoginResult(success: true);
      } else if (html.contains('Kata Sandi') || html.contains('nip')) {
        return LoginResult(success: false, error: 'NIP atau Password salah');
      }

      return LoginResult(success: false, error: 'Login gagal. Status: ${resp.statusCode}');
    } on DioException catch (e) {
      return LoginResult(success: false, error: 'Network error: ${e.message}');
    } catch (e) {
      return LoginResult(success: false, error: 'Error: $e');
    }
  }

  /// Get calendar page HTML
  Future<String?> getCalendarPage() async {
    try {
      final resp = await _dio.get(ApiConstants.calendarUrl);
      if (resp.statusCode == 200) {
        extractCsrf(resp.data.toString());
        return resp.data.toString();
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
    final eventRegex = RegExp(r'id\s*:\s*["\']kerja_(\d+)_(\d+)_(\d+)["\']\s*,\s*title\s*:\s*["\']([^"\']+)["\']');
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
    await refreshCsrf();
    if (_csrfToken == null) {
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
      // Extract values from form fields
      final aktivitasMatch = RegExp(
        r'nama_aktivitas["\s][^>]*value=["\']([^"\']+)["\']',
        dotAll: true,
      ).firstMatch(html);
      final descMatch = RegExp(
        r'deskripsi["\s][^>]*value=["\']([^"\']+)["\']',
        dotAll: true,
      ).firstMatch(html);

      // More robust: parse from input fields
      final nameInput = RegExp(r'name=["\']THarianLog\[nama_aktivitas\]["\']\s+value=["\']([^"\']+)["\']').firstMatch(html);
      final descInput = RegExp(r'name=["\']THarianLog\[deskripsi\]["\']\s[^>]*>([^<]+)<').firstMatch(html);
      final indSelect = RegExp(r'<select[^>]*id=["\'][^"\']*indikator[^"\']*["\'][^>]*>.*?value=["\']([^"\']+)["\'][^>]*(?:selected|>.*?<\/select)', dotAll: true).firstMatch(html);

      return LogEntry(
        namaAktivitas: nameInput?.group(1) ?? descInput?.group(1) ?? '',
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

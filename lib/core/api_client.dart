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

  /// Extract CSRF token from HTML response (Yii framework uses YII_CSRF_TOKEN)
  String? extractCsrf(String html) {
    // Pattern 1: YII_CSRF_TOKEN (Yii Framework)
    var match = RegExp('name=["\']YII_CSRF_TOKEN["\']\\s+value=["\']([^"\']+)["\']').firstMatch(html);
    if (match != null) return match.group(1);

    // Pattern 1b: value before name
    match = RegExp('value=["\']([^"\']+)["\']\\s+name=["\']YII_CSRF_TOKEN["\']').firstMatch(html);
    if (match != null) return match.group(1);

    // Pattern 2: Standard _csrf
    match = RegExp('name=["\']_csrf["\']\\s+value=["\']([^"\']+)["\']').firstMatch(html);
    if (match != null) return match.group(1);

    // Pattern 3: Meta tag
    match = RegExp('name=["\']csrf-token["\']\\s+content=["\']([^"\']+)["\']').firstMatch(html);
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
          'LoginForm[username]': nip,
          'LoginForm[password]': password,
          'YII_CSRF_TOKEN': _csrfToken,
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

      // Status 302 means the server processed the login and is redirecting
      // We need to check if the redirect goes to dashboard (success) or back to login (failed)
      if (resp.statusCode == 302 || resp.statusCode == 301) {
        // Try to fetch the calendar page - if we can access it, login was successful
        try {
          final calendarResp = await _dio.get(ApiConstants.calendarUrl);
          final calendarHtml = calendarResp.data.toString();

          // If we can see calendar content or logout button, login was successful
          if (calendarHtml.contains('logout') || calendarHtml.contains('Log Harian') || calendarHtml.contains('kerja_')) {
            await refreshCsrf();
            return LoginResult(success: true);
          }
        } catch (e) {
          // Calendar page failed - probably redirected to login, meaning login failed
        }

        // If calendar access failed, check login page for error messages
        final checkResp = await _dio.get(ApiConstants.loginUrl);
        final checkHtml = checkResp.data.toString();
        if (checkHtml.contains('Password salah.') || checkHtml.contains('Username tidak valid')) {
          return LoginResult(success: false, error: 'NIP atau Password salah');
        }

        return LoginResult(success: false, error: 'Login gagal. Status: ${resp.statusCode}');
      }

      final html = resp.data.toString();
      print('Response contains logout: ${html.contains('logout')}');
      print('Response contains Log Harian: ${html.contains('Log Harian')}');
      print('Response contains Kata Sandi: ${html.contains('Kata Sandi')}');
      print('Response contains Username tidak valid: ${html.contains('Username tidak valid')}');
      print('Response contains Password tidak valid: ${html.contains('Password tidak valid')}');
      print('Response length: ${html.length}');
      // Show first 500 chars of response for debugging
      final preview = html.length > 500 ? html.substring(0, 500) : html;
      print('Response preview: $preview');

      // Check if redirected to dashboard or still on login page
      // If login successful, should see dashboard content or logout button
      if (html.contains('logout') || html.contains('dashboard') || html.contains('Log Harian')) {
        // Refresh CSRF from calendar page for subsequent requests
        await refreshCsrf();
        return LoginResult(success: true);
      } else if (html.contains('Password salah.') || html.contains('Username tidak valid') || html.contains('Kata Sandi')) {
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
      print('Fetching calendar from: ${ApiConstants.calendarUrl}');
      final resp = await _dio.get(ApiConstants.calendarUrl);
      print('Calendar response status: ${resp.statusCode}');
      if (resp.statusCode == 200) {
        final html = resp.data.toString();
        print('Calendar HTML length: ${html.length}');
        print('Contains logout: ${html.contains('logout')}');
        print('Contains Log Harian: ${html.contains('Log Harian')}');
        print('Contains kerja_: ${html.contains('kerja_')}');
        // Show first 500 chars for debugging
        final preview = html.length > 500 ? html.substring(0, 500) : html;
        print('Calendar preview: $preview');
        final token = extractCsrf(html);
        if (token != null) _csrfToken = token;
        return html;
      }
      return null;
    } catch (e) {
      print('Error fetching calendar: $e');
      return null;
    }
  }

  /// Parse calendar HTML to get work days and status
  CalendarData parseCalendar(String html) {
    final List<WorkDay> workDays = [];

    print('Parsing calendar HTML...');
    print('HTML contains kerja_: ${html.contains('kerja_')}');
    print('HTML contains myEvents: ${html.contains('myEvents')}');

    // Parse myEvents JSON array from JavaScript
    // Pattern: myEvents = [{"id":"kerja_XXX","name":"...","description":"...","date":"YYYY-MM-DD","type":"...","everyYear":...},...]
    final eventsRegex = RegExp('myEvents\\s*=\\s*(\\[\\{[^}]+\"date\"[^}]+\\}(?:,\\{[^}]+\"date\"[^}]+\\})*\\])', dotAll: true);
    final eventsMatch = eventsRegex.firstMatch(html);

    if (eventsMatch != null) {
      print('Found myEvents array');
      final eventsJson = eventsMatch.group(1)!;
      print('Events JSON length: ${eventsJson.length}');

      // Parse individual events from the JSON-like string
      // Pattern for each event: {"id":"kerja_XXX","name":"...","description":"...","date":"YYYY-MM-DD","type":"...","everyYear":...}
      final eventRegex = RegExp('\\{"id":"kerja_[^"]+","name":"([^"]*)","description":"([^"]*)","date":"(\\d{4}-\\d{2}-\\d{2})"[^}]*\\}');
      final matches = eventRegex.allMatches(eventsJson);

      print('Found ${matches.length} calendar events');

      for (final match in matches) {
        final name = match.group(1)!;
        final description = match.group(2)!;
        final date = match.group(3)!;

        // Determine status based on name and description
        final status = name.contains('Belum Terisi') || description.contains('Belum Terisi')
            ? DayStatus.unfilled
            : (name.contains('Libur') || name.contains('Cuti') || description.contains('Libur'))
                ? DayStatus.holiday
                : DayStatus.filled;

        final title = name.isEmpty ? description : name;

        print('Parsed event: $date - $title - $status');

        workDays.add(WorkDay(
          date: date,
          status: status,
          title: title,
        ));
      }
    } else {
      print('myEvents pattern not found!');
    }

    // Also try to find "Belum Terisi (X)" counter
    int? unfilledCount;
    final counterMatch = RegExp('Belum Terisi\\s*\\((\\d+)\\)').firstMatch(html);
    if (counterMatch != null) {
      unfilledCount = int.tryParse(counterMatch.group(1)!);
    }

    print('Total workDays parsed: ${workDays.length}');
    print('Unfilled count from page: $unfilledCount');

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
          'YII_CSRF_TOKEN': _csrfToken,
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
      } else if (html.contains('YII_CSRF_TOKEN') || html.contains('_csrf')) {
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
      final descInput = RegExp('name=["\']THarianLog\\[deskripsi\\]["\']\s[^>]*>([^<]+)<').firstMatch(html);

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

  // Filter workDays by month
  List<WorkDay> workDaysInMonth(int year, int month) {
    return workDays.where((d) {
      final dt = d.dateTime;
      return dt.year == year && dt.month == month;
    }).toList();
  }

  List<WorkDay> get filledDays => workDays.where((d) => d.status == DayStatus.filled).toList();
  List<WorkDay> get unfilledDays => workDays.where((d) => d.status == DayStatus.unfilled).toList();
  List<WorkDay> get holidays => workDays.where((d) => d.status == DayStatus.holiday).toList();

  // Get counts for specific month
  int filledCountInMonth(int year, int month) => workDaysInMonth(year, month).where((d) => d.status == DayStatus.filled).length;
  int unfilledCountInMonth(int year, int month) => workDaysInMonth(year, month).where((d) => d.status == DayStatus.unfilled).length;
  int holidayCountInMonth(int year, int month) => workDaysInMonth(year, month).where((d) => d.status == DayStatus.holiday).length;
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

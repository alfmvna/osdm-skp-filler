import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/api_client.dart';

abstract class DashboardState {}

class DashboardInitial extends DashboardState {}
class DashboardLoading extends DashboardState {}
class DashboardLoaded extends DashboardState {
  final CalendarData calendarData;
  final DateTime selectedMonth;
  DashboardLoaded({required this.calendarData, required this.selectedMonth});
}
class DashboardError extends DashboardState {
  final String message;
  DashboardError(this.message);
}

class DashboardCubit extends Cubit<DashboardState> {
  final ApiClient _api = ApiClient();
  DateTime _selectedMonth = DateTime.now();

  DashboardCubit() : super(DashboardInitial());

  DateTime get selectedMonth => _selectedMonth;

  Future<void> loadCalendar({DateTime? month}) async {
    emit(DashboardLoading());
    if (month != null) {
      _selectedMonth = month;
    }

    final html = await _api.getCalendarPage();
    if (html == null) {
      emit(DashboardError('Gagal mengambil data kalender'));
      return;
    }

    final data = _api.parseCalendar(html);
    emit(DashboardLoaded(calendarData: data, selectedMonth: _selectedMonth));
  }

  void changeMonth(DateTime month) {
    _selectedMonth = month;
    loadCalendar(month: month);
  }
}

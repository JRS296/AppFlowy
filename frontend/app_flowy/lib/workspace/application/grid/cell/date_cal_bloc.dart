import 'package:app_flowy/workspace/application/grid/field/field_service.dart';
import 'package:flowy_sdk/log.dart';
import 'package:flowy_sdk/protobuf/flowy-error/errors.pb.dart';
import 'package:flowy_sdk/protobuf/flowy-grid-data-model/grid.pb.dart' show Cell;
import 'package:flowy_sdk/protobuf/flowy-grid/date_type_option.pb.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:async';
import 'cell_service/cell_service.dart';
import 'package:dartz/dartz.dart';
import 'package:protobuf/protobuf.dart';
part 'date_cal_bloc.freezed.dart';

class DateCalBloc extends Bloc<DateCalEvent, DateCalState> {
  final GridDateCellContext cellContext;
  void Function()? _onCellChangedFn;

  DateCalBloc({
    required DateTypeOption dateTypeOption,
    required DateTime? selectedDay,
    required this.cellContext,
  }) : super(DateCalState.initial(dateTypeOption, selectedDay)) {
    on<DateCalEvent>(
      (event, emit) async {
        await event.map(
          initial: (_Initial value) async {
            _startListening();
            // await _loadDateTypeOption(emit);
          },
          selectDay: (_SelectDay value) {
            if (state.dateData != null) {
              if (!isSameDay(state.dateData!.date, value.day)) {
                final newDateData = state.dateData!.copyWith(date: value.day);
                emit(state.copyWith(dateData: newDateData));
              }
            } else {
              emit(state.copyWith(dateData: DateCellPersistenceData(date: value.day)));
            }
          },
          setCalFormat: (_CalendarFormat value) {
            emit(state.copyWith(format: value.format));
          },
          setFocusedDay: (_FocusedDay value) {
            emit(state.copyWith(focusedDay: value.day));
          },
          didReceiveCellUpdate: (_DidReceiveCellUpdate value) {},
          setIncludeTime: (_IncludeTime value) async {
            await _updateTypeOption(emit, includeTime: value.includeTime);
          },
          setDateFormat: (_DateFormat value) async {
            await _updateTypeOption(emit, dateFormat: value.dateFormat);
          },
          setTimeFormat: (_TimeFormat value) async {
            await _updateTypeOption(emit, timeFormat: value.timeFormat);
          },
          setTime: (_Time value) {
            if (state.dateData != null) {
              final newDateData = state.dateData!.copyWith(time: value.time);
              emit(state.copyWith(dateData: newDateData));
            } else {
              emit(state.copyWith(dateData: DateCellPersistenceData(date: DateTime.now(), time: value.time)));
            }
          },
        );
      },
    );
  }

  @override
  Future<void> close() async {
    if (_onCellChangedFn != null) {
      cellContext.removeListener(_onCellChangedFn!);
      _onCellChangedFn = null;
    }
    cellContext.dispose();
    return super.close();
  }

  void _startListening() {
    _onCellChangedFn = cellContext.startListening(
      onCellChanged: ((cell) {
        if (!isClosed) {
          add(DateCalEvent.didReceiveCellUpdate(cell));
        }
      }),
    );
  }

  Future<void>? _updateTypeOption(
    Emitter<DateCalState> emit, {
    DateFormat? dateFormat,
    TimeFormat? timeFormat,
    bool? includeTime,
  }) async {
    state.dateTypeOption.freeze();
    final newDateTypeOption = state.dateTypeOption.rebuild((typeOption) {
      if (dateFormat != null) {
        typeOption.dateFormat = dateFormat;
      }

      if (timeFormat != null) {
        typeOption.timeFormat = timeFormat;
      }

      if (includeTime != null) {
        typeOption.includeTime = includeTime;
      }
    });

    final result = await FieldService.updateFieldTypeOption(
      gridId: cellContext.gridId,
      fieldId: cellContext.field.id,
      typeOptionData: newDateTypeOption.writeToBuffer(),
    );

    result.fold(
      (l) => emit(state.copyWith(dateTypeOption: newDateTypeOption)),
      (err) => Log.error(err),
    );
  }
}

@freezed
class DateCalEvent with _$DateCalEvent {
  const factory DateCalEvent.initial() = _Initial;
  const factory DateCalEvent.selectDay(DateTime day) = _SelectDay;
  const factory DateCalEvent.setCalFormat(CalendarFormat format) = _CalendarFormat;
  const factory DateCalEvent.setFocusedDay(DateTime day) = _FocusedDay;
  const factory DateCalEvent.setTimeFormat(TimeFormat timeFormat) = _TimeFormat;
  const factory DateCalEvent.setDateFormat(DateFormat dateFormat) = _DateFormat;
  const factory DateCalEvent.setIncludeTime(bool includeTime) = _IncludeTime;
  const factory DateCalEvent.setTime(String time) = _Time;
  const factory DateCalEvent.didReceiveCellUpdate(Cell cell) = _DidReceiveCellUpdate;
}

@freezed
class DateCalState with _$DateCalState {
  const factory DateCalState({
    required DateTypeOption dateTypeOption,
    required CalendarFormat format,
    required DateTime focusedDay,
    required String time,
    required Option<FlowyError> inputTimeError,
    DateCellPersistenceData? dateData,
  }) = _DateCalState;

  factory DateCalState.initial(
    DateTypeOption dateTypeOption,
    DateTime? selectedDay,
  ) {
    DateCellPersistenceData? dateData;
    if (selectedDay != null) {
      dateData = DateCellPersistenceData(date: selectedDay);
    }

    return DateCalState(
      dateTypeOption: dateTypeOption,
      format: CalendarFormat.month,
      focusedDay: DateTime.now(),
      dateData: dateData,
      time: "",
      inputTimeError: none(),
    );
  }
}

import 'package:bloc/bloc.dart';

class LegacyBloc extends Bloc<LegacyEvent, LegacyState> {
  LegacyBloc() : super(LegacyInitial());
}

abstract class LegacyEvent {}

abstract class LegacyState {}

class LegacyInitial extends LegacyState {}

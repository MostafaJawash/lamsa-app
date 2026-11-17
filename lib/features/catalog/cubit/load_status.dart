import 'package:equatable/equatable.dart';

enum LoadStatus { loading, loaded, failed }

/// One independently loading piece of a screen (a home rail, a list of
/// brands...): its status, data and, when failed, the Arabic message.
final class Section<T> extends Equatable {
  const Section.loading() : this._(LoadStatus.loading, null, null);

  const Section.loaded(T data) : this._(LoadStatus.loaded, data, null);

  const Section.failed(String message)
      : this._(LoadStatus.failed, null, message);

  const Section._(this.status, this.data, this.error);

  final LoadStatus status;
  final T? data;
  final String? error;

  bool get isLoading => status == LoadStatus.loading;
  bool get isFailed => status == LoadStatus.failed;

  @override
  List<Object?> get props => [status, data, error];
}

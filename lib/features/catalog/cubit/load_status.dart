import 'package:equatable/equatable.dart';

enum LoadStatus { loading, loaded, failed }

/// One independently loading piece of a screen (a home rail, a list of
/// brands...): its status, data and, when failed, the Arabic message.
final class Section<T> extends Equatable {
  const Section.loading() : this._(LoadStatus.loading, null, null, false);

  const Section.loaded(T data) : this._(LoadStatus.loaded, data, null, false);

  /// [connection]: the backend could not be reached at all.
  const Section.failed(String message, {bool connection = false})
    : this._(LoadStatus.failed, null, message, connection);

  const Section._(this.status, this.data, this.error, this.connection);

  final LoadStatus status;
  final T? data;
  final String? error;
  final bool connection;

  bool get isLoading => status == LoadStatus.loading;
  bool get isFailed => status == LoadStatus.failed;

  @override
  List<Object?> get props => [status, data, error, connection];
}

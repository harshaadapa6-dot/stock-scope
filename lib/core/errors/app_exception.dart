/// Categories of failures the UI knows how to explain to the user.
enum AppErrorType {
  network,
  timeout,
  rateLimit,
  invalidKey,
  planRestricted,
  notFound,
  noData,
  parse,
  invalidInput,
  unknown,
}

/// A user-presentable error. Never carries stack traces.
class AppException implements Exception {
  const AppException(this.type, this.message, {this.hint});

  final AppErrorType type;
  final String message;

  /// Optional extra guidance, e.g. how to fix configuration problems.
  final String? hint;

  /// Whether an immediate manual retry is sensible. Rate limits and
  /// configuration problems are NOT retryable until the user changes something
  /// or waits.
  bool get retryable =>
      type == AppErrorType.network ||
      type == AppErrorType.timeout ||
      type == AppErrorType.unknown ||
      type == AppErrorType.parse;

  /// Converts any thrown object into an [AppException] without leaking
  /// internals (stack traces, type names) to the UI.
  static AppException from(Object error) {
    if (error is AppException) return error;
    return const AppException(
      AppErrorType.unknown,
      'Something went wrong while loading data.',
      hint: 'Please try again. If the problem continues, switch to demo mode.',
    );
  }

  @override
  String toString() => 'AppException(${type.name}): $message';
}

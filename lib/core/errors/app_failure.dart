enum FailureKind { network, rateLimited, notFound, unauthorized, validation, conflict, unknown }

class AppFailure implements Exception {
  const AppFailure(this.kind, this.message);

  const AppFailure.network([String message = "You're offline or the server is unreachable."])
    : this(FailureKind.network, message);

  const AppFailure.rateLimited([String message = 'Too many requests right now. Try again in a moment.'])
    : this(FailureKind.rateLimited, message);

  const AppFailure.notFound([String message = "We couldn't find that."]) : this(FailureKind.notFound, message);

  const AppFailure.unauthorized([String message = 'Please sign in again.']) : this(FailureKind.unauthorized, message);

  const AppFailure.validation(String message) : this(FailureKind.validation, message);

  const AppFailure.conflict(String message) : this(FailureKind.conflict, message);

  const AppFailure.unknown([String message = 'Something went wrong.']) : this(FailureKind.unknown, message);
  final FailureKind kind;
  final String message;

  static AppFailure from(Object error) => error is AppFailure ? error : const AppFailure.unknown();

  @override
  String toString() => 'AppFailure($kind, $message)';
}

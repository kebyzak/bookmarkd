/// Runs [futures] concurrently and rethrows the first *original* error.
/// Record `.wait` wraps errors in `ParallelWaitError`, which would hide the
/// `AppFailure` message from the UI.
Future<List<Object?>> waitAll(List<Future<Object?>> futures) => Future.wait(futures, eagerError: true);

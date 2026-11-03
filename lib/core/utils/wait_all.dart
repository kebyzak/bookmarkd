Future<void> waitAll(List<Future<Object?>> futures) => Future.wait(futures, eagerError: true);

/// Base class for all failures
abstract class Failure {
  final String message;

  const Failure(this.message);

  @override
  String toString() => message;
}

/// Authentication related failures
class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

/// Network related failures
class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// Server related failures
class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

/// Database related failures
class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message);
}

/// Validation related failures
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Unknown/Unexpected failures
class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}

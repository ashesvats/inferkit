sealed class InferKitException implements Exception {
  const InferKitException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BadRequestException extends InferKitException {
  const BadRequestException(super.message);
}

class AuthenticationException extends InferKitException {
  const AuthenticationException(super.message);
}

class RateLimitException extends InferKitException {
  const RateLimitException(super.message);
}

class ServerException extends InferKitException {
  const ServerException(super.message);
}

class InferKitTimeoutException extends InferKitException {
  const InferKitTimeoutException(super.message);
}

class InvalidResponseException extends InferKitException {
  const InvalidResponseException(super.message);
}

class NetworkException extends InferKitException {
  const NetworkException(super.message);
}

abstract class Failure {
  final String message;
  const Failure(this.message);
}

class StorageFailure extends Failure {
  const StorageFailure(super.message);
}

class ExportFailure extends Failure {
  const ExportFailure(super.message);
}

class FileSystemFailure extends Failure {
  const FileSystemFailure(super.message);
}

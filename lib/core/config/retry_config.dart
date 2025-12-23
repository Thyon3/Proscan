// core/config/retry_config.dart
import 'dart:math' as math;

/// Standardized retry configuration for sync operations.
///
/// Provides consistent exponential backoff retry logic across all sync services
/// (DocumentSyncService, DocumentUploadService, DocumentDownloadService).
///
/// **Configuration:**
/// - Maximum retries: 5 attempts
/// - Base delay: 1 second
/// - Maximum delay: 16 seconds
/// - Delay sequence: 1s, 2s, 4s, 8s, 16s
///
/// **Usage:**
/// ```dart
/// // Get delay for a specific attempt
/// final delay = RetryConfig.getDelay(attempt);
///
/// // Check if should retry
/// if (RetryConfig.shouldRetry(currentAttempt)) {
///   await Future.delayed(RetryConfig.getDelay(currentAttempt));
///   // retry operation
/// }
/// ```
///
/// **Requirements:**
/// - Requirements 5.1: Exponential backoff starting at 1 second, doubling up to 16 seconds
/// - Requirements 5.2: Maximum 5 retry attempts per operation
class RetryConfig {
  RetryConfig._();

  /// Maximum number of retry attempts before giving up.
  /// After this many attempts, the operation is marked as failed.
  static const int maxRetries = 5;

  /// Base delay for exponential backoff (first retry delay).
  static const Duration baseDelay = Duration(seconds: 1);

  /// Maximum delay cap for exponential backoff.
  /// Delays will not exceed this value regardless of attempt number.
  static const Duration maxDelay = Duration(seconds: 16);

  /// Calculates the retry delay for a given attempt number.
  ///
  /// Uses exponential backoff: delay = min(baseDelay * 2^attempt, maxDelay)
  ///
  /// **Delay sequence:**
  /// - Attempt 0: 1 second
  /// - Attempt 1: 2 seconds
  /// - Attempt 2: 4 seconds
  /// - Attempt 3: 8 seconds
  /// - Attempt 4: 16 seconds (capped at maxDelay)
  ///
  /// **Parameters:**
  /// - [attempt]: Zero-based attempt number (0 for first retry, 1 for second, etc.)
  ///
  /// **Returns:**
  /// - [Duration] representing the delay before the next retry attempt
  ///
  /// **Example:**
  /// ```dart
  /// final delay = RetryConfig.getDelay(2); // Returns 4 seconds
  /// await Future.delayed(delay);
  /// ```
  static Duration getDelay(int attempt) {
    if (attempt < 0) {
      return baseDelay;
    }

    // Calculate exponential delay: baseDelay * 2^attempt
    final multiplier = math.pow(2, attempt).toInt();
    final delaySeconds = baseDelay.inSeconds * multiplier;

    // Cap at maxDelay
    final cappedSeconds = math.min(delaySeconds, maxDelay.inSeconds);

    return Duration(seconds: cappedSeconds);
  }

  /// Calculates the retry delay with optional jitter to prevent thundering herd.
  ///
  /// Adds random jitter of up to 25% of the base delay to spread out retries
  /// when multiple operations fail simultaneously.
  ///
  /// **Parameters:**
  /// - [attempt]: Zero-based attempt number
  /// - [random]: Optional Random instance for testing (uses default if not provided)
  ///
  /// **Returns:**
  /// - [Duration] with jitter applied
  static Duration getDelayWithJitter(int attempt, [math.Random? random]) {
    final baseDelayDuration = getDelay(attempt);
    final rng = random ?? math.Random();

    // Add jitter: 0-25% of base delay
    final jitterMs = (baseDelayDuration.inMilliseconds * 0.25 * rng.nextDouble()).toInt();

    return Duration(milliseconds: baseDelayDuration.inMilliseconds + jitterMs);
  }

  /// Checks if another retry attempt should be made.
  ///
  /// **Parameters:**
  /// - [currentAttempt]: The current attempt number (0-based)
  ///
  /// **Returns:**
  /// - `true` if currentAttempt < maxRetries, `false` otherwise
  ///
  /// **Example:**
  /// ```dart
  /// int attempt = 0;
  /// while (RetryConfig.shouldRetry(attempt)) {
  ///   try {
  ///     await performOperation();
  ///     break; // Success
  ///   } catch (e) {
  ///     attempt++;
  ///     if (RetryConfig.shouldRetry(attempt)) {
  ///       await Future.delayed(RetryConfig.getDelay(attempt - 1));
  ///     }
  ///   }
  /// }
  /// ```
  static bool shouldRetry(int currentAttempt) {
    return currentAttempt < maxRetries;
  }

  /// Gets the total maximum time that could be spent on retries.
  ///
  /// This is the sum of all possible delays: 1 + 2 + 4 + 8 + 16 = 31 seconds
  ///
  /// **Returns:**
  /// - [Duration] representing the maximum total retry time
  static Duration get totalMaxRetryTime {
    int totalSeconds = 0;
    for (int i = 0; i < maxRetries; i++) {
      totalSeconds += getDelay(i).inSeconds;
    }
    return Duration(seconds: totalSeconds);
  }

  /// Gets all delay values as a list for debugging/logging.
  ///
  /// **Returns:**
  /// - List of [Duration] values for each retry attempt
  static List<Duration> get allDelays {
    return List.generate(maxRetries, (i) => getDelay(i));
  }
}

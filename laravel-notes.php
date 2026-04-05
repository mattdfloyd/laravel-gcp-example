<?php

// ============================================
// routes/web.php — add this health check route
// ============================================

// Cloud Run uses this to know your container is ready.
// Configure in Cloud Run: startup probe → HTTP GET /health
Route::get('/health', function () {
    // Optional: verify DB and Redis are reachable
    try {
        DB::connection()->getPdo();
        Cache::store('redis')->get('health-check');

        return response()->json(['status' => 'ok'], 200);
    } catch (\Throwable $e) {
        return response()->json([
            'status' => 'error',
            'message' => $e->getMessage(),
        ], 500);
    }
});


// ============================================
// config/logging.php — update the stack channel
// ============================================
//
// Cloud Run captures anything written to stderr/stdout.
// Set your LOG_CHANNEL=stderr in production so logs
// appear in Cloud Logging automatically.
//
// 'stderr' => [
//     'driver' => 'monolog',
//     'level' => env('LOG_LEVEL', 'debug'),
//     'handler' => StreamHandler::class,
//     'formatter' => env('LOG_STDERR_FORMATTER'),
//     'with' => [
//         'stream' => 'php://stderr',
//     ],
//     'processors' => [PsrLogMessageProcessor::class],
// ],
//
// For structured JSON logs in Cloud Logging, use:
//
//   LOG_CHANNEL=stderr
//   LOG_STDERR_FORMATTER=Monolog\Formatter\JsonFormatter
//
// This gives you filterable, searchable logs in the
// GCP Cloud Logging console with severity levels.

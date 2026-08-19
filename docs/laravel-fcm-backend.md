# Laravel FCM Backend

This document contains ready-to-copy Laravel backend code for the Flutter app's notification flow.

The Flutter app currently expects these endpoints:

- `POST /api/flutter/devices/token`
- `DELETE /api/flutter/devices/token`
- `POST /api/flutter/notifications/test`

It also expects Firebase Cloud Messaging HTTP v1 on the backend.

## Firebase setup

From Firebase Console:

1. Open `Project settings > Service accounts`.
2. Generate a new private key JSON file.
3. Store it on the server only.

Do not place the service account JSON inside the Flutter app.

The Firebase project ID from the Android config is:

```text
app-tasameem
```

## Composer

Install the official Google auth package:

```bash
composer require google/auth
```

## .env

```env
FIREBASE_PROJECT_ID=app-tasameem
GOOGLE_APPLICATION_CREDENTIALS=/var/www/secure/firebase/app-tasameem-service-account.json
```

## config/services.php

```php
'firebase' => [
    'project_id' => env('FIREBASE_PROJECT_ID'),
],
```

## Migration

Create a migration for device tokens:

```php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('device_tokens', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('token')->unique();
            $table->string('platform', 20)->default('android');
            $table->string('device_name')->nullable();
            $table->string('app_version', 50)->nullable();
            $table->timestamp('last_seen_at')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'platform']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('device_tokens');
    }
};
```

## Model

`app/Models/DeviceToken.php`

```php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DeviceToken extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'token',
        'platform',
        'device_name',
        'app_version',
        'last_seen_at',
    ];

    protected $casts = [
        'last_seen_at' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
```

## FCM service

`app/Services/FcmService.php`

```php
<?php

namespace App\Services;

use App\Models\DeviceToken;
use Google\Auth\ApplicationDefaultCredentials;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Http;
use RuntimeException;

class FcmService
{
    private const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

    public function sendToToken(
        string $token,
        string $title,
        string $body,
        array $data = []
    ): array {
        $response = $this->postMessage([
            'token' => $token,
            'notification' => [
                'title' => $title,
                'body' => $body,
            ],
            'data' => $this->stringifyData($data),
            'android' => [
                'priority' => 'HIGH',
                'notification' => [
                    'channel_id' => 'high_importance_channel',
                ],
            ],
        ]);

        if ($response->failed()) {
            $this->pruneInvalidToken($token, $response);
            $response->throw();
        }

        return $response->json();
    }

    public function sendToTokens(
        array $tokens,
        string $title,
        string $body,
        array $data = []
    ): array {
        $results = [];

        foreach (array_unique(array_filter($tokens)) as $token) {
            try {
                $results[$token] = [
                    'ok' => true,
                    'response' => $this->sendToToken($token, $title, $body, $data),
                ];
            } catch (\Throwable $e) {
                $results[$token] = [
                    'ok' => false,
                    'error' => $e->getMessage(),
                ];
            }
        }

        return $results;
    }

    private function postMessage(array $message): Response
    {
        $projectId = config('services.firebase.project_id');

        if (!is_string($projectId) || $projectId === '') {
            throw new RuntimeException('Missing Firebase project ID.');
        }

        return Http::withToken($this->accessToken())
            ->acceptJson()
            ->asJson()
            ->post(
                "https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send",
                ['message' => $message]
            );
    }

    private function accessToken(): string
    {
        $credentials = ApplicationDefaultCredentials::getCredentials(self::SCOPE);
        $token = $credentials->fetchAuthToken();

        if (!isset($token['access_token']) || !is_string($token['access_token'])) {
            throw new RuntimeException('Unable to fetch Firebase access token.');
        }

        return $token['access_token'];
    }

    private function stringifyData(array $data): array
    {
        $payload = [];

        foreach ($data as $key => $value) {
            $payload[(string) $key] = is_scalar($value)
                ? (string) $value
                : json_encode($value, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        }

        return $payload;
    }

    private function pruneInvalidToken(string $token, Response $response): void
    {
        $body = json_encode($response->json());

        if (is_string($body) && (
            str_contains($body, 'UNREGISTERED') ||
            str_contains($body, 'INVALID_ARGUMENT')
        )) {
            DeviceToken::query()->where('token', $token)->delete();
        }
    }
}
```

## Device token controller

`app/Http/Controllers/Api/Flutter/DeviceTokenController.php`

```php
<?php

namespace App\Http\Controllers\Api\Flutter;

use App\Http\Controllers\Controller;
use App\Models\DeviceToken;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DeviceTokenController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'token' => ['required', 'string', 'max:2048'],
            'platform' => ['required', 'string', 'in:android,ios,web'],
            'device_name' => ['nullable', 'string', 'max:255'],
            'app_version' => ['nullable', 'string', 'max:50'],
        ]);

        $record = DeviceToken::query()->updateOrCreate(
            ['token' => $validated['token']],
            [
                'user_id' => $request->user()->id,
                'platform' => $validated['platform'],
                'device_name' => $validated['device_name'] ?? null,
                'app_version' => $validated['app_version'] ?? null,
                'last_seen_at' => now(),
            ]
        );

        return response()->json([
            'message' => 'Device token synced.',
            'data' => [
                'id' => $record->id,
                'token' => $record->token,
                'platform' => $record->platform,
            ],
        ]);
    }

    public function destroy(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'token' => ['required', 'string', 'max:2048'],
        ]);

        DeviceToken::query()
            ->where('user_id', $request->user()->id)
            ->where('token', $validated['token'])
            ->delete();

        return response()->json([
            'message' => 'Device token removed.',
        ]);
    }
}
```

## Test notification controller

`app/Http/Controllers/Api/Flutter/NotificationTestController.php`

```php
<?php

namespace App\Http\Controllers\Api\Flutter;

use App\Http\Controllers\Controller;
use App\Models\DeviceToken;
use App\Services\FcmService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NotificationTestController extends Controller
{
    public function __construct(
        private readonly FcmService $fcmService
    ) {
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'title' => ['nullable', 'string', 'max:255'],
            'body' => ['nullable', 'string', 'max:1000'],
            'data' => ['nullable', 'array'],
        ]);

        $title = $validated['title'] ?? 'Hello from Tasameem';
        $body = $validated['body'] ?? 'This is a test notification.';
        $data = $validated['data'] ?? [
            'type' => 'test_notification',
            'screen' => 'notifications',
        ];

        $tokens = DeviceToken::query()
            ->where('user_id', $request->user()->id)
            ->pluck('token')
            ->all();

        if ($tokens === []) {
            return response()->json([
                'message' => 'No device tokens found for this user.',
            ], 422);
        }

        $results = $this->fcmService->sendToTokens($tokens, $title, $body, $data);

        return response()->json([
            'message' => 'Notification dispatch finished.',
            'results' => $results,
        ]);
    }
}
```

## Routes

`routes/api.php`

```php
use App\Http\Controllers\Api\Flutter\DeviceTokenController;
use App\Http\Controllers\Api\Flutter\NotificationTestController;
use Illuminate\Support\Facades\Route;

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/flutter/devices/token', [DeviceTokenController::class, 'store']);
    Route::delete('/flutter/devices/token', [DeviceTokenController::class, 'destroy']);
    Route::post('/flutter/notifications/test', [NotificationTestController::class, 'store']);
});
```

If your Flutter API already uses a different auth guard, keep the same guard here.

## Sending real app notifications

For production notifications, send data values that the Flutter app already understands:

```php
$fcmService->sendToTokens(
    $tokens,
    'Order updated',
    'Your order ORD-123 is now ready.',
    [
        'type' => 'order_status_changed',
        'screen' => 'order_details',
        'order_number' => 'ORD-123',
    ]
);
```

Currently supported `screen` values in the Flutter app:

- `notifications`
- `order_details`
- `orders`
- `wallet`

## Notes

- Use `FCM HTTP v1` only.
- Do not use the API key from `google-services.json` in Laravel.
- Keep the service account JSON outside the web root.
- When FCM returns `UNREGISTERED`, delete the token from your database.
- Test on a real Android device, not an emulator, if token delivery is unreliable.

## References

- https://firebase.google.com/docs/cloud-messaging/auth-server
- https://firebase.google.com/docs/reference/fcm/rest
- https://cloud.google.com/php/docs/reference/auth/latest/ApplicationDefaultCredentials
- https://laravel.com/docs/12.x/http-client

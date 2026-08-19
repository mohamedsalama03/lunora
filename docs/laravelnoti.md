# Laravel + FCM Integration Guide

هذا الملف يشرح ما الذي يجب عمله في `Laravel` لكي ترسل إشعارات `FCM` تلقائيًا عندما:

- يشتري العميل منتجًا
- يتم شحن المحفظة بنجاح

الهدف هنا هو أن يكون `Flutter` هو مستقبل الإشعار فقط، بينما يكون `Laravel` هو مصدر الحقيقة ومكان الإرسال الفعلي.

## ما الموجود بالفعل في Flutter

التطبيق الحالي يقوم بهذه الأمور مسبقًا:

- يطلب صلاحية الإشعارات من الجهاز
- يحصل على `FCM token`
- يرسل التوكن إلى الخادم عند تسجيل الدخول
- يحذف التوكن الحالي عند تسجيل الخروج
- يدعم استقبال الإشعار في الخلفية والأمام
- يوجّه المستخدم إلى شاشة مناسبة عند الضغط على الإشعار

الـ endpoints التي ينتظرها التطبيق حاليًا:

- `POST /api/flutter/devices/token`
- `DELETE /api/flutter/devices/token`
- `POST /api/flutter/notifications/test`

## ما الذي يجب على Laravel عمله

من جهة الخادم تحتاج إلى:

1. حفظ `FCM token` لكل جهاز لكل مستخدم.
2. إرسال الإشعار بعد التأكد من نجاح العملية من الخادم نفسه.
3. إرسال الإشعار عبر `FCM HTTP v1 API`.
4. تشغيل الإرسال داخل `Job` و `Queue` بدلًا من عمله مباشرة داخل الـ controller.
5. حذف التوكنات غير الصالحة عند اكتشاف أنها لم تعد صالحة.

## لماذا يجب أن يكون الإرسال من Laravel

لأن:

- الشراء أو شحن المحفظة لا يعتبر ناجحًا إلا بعد تأكيد الخادم.
- إرسال الإشعار من التطبيق نفسه غير آمن.
- بيانات `Firebase service account` لا يجب أن تكون داخل تطبيق Flutter.
- Laravel هو المكان الصحيح لتحديد متى يتم الإرسال ولمن يتم الإرسال.

## مهم

استخدم `FCM HTTP v1` ولا تعتمد على الطرق القديمة المبنية على `server key`.

بحسب وثائق Firebase الرسمية، إرسال رسائل `FCM` يجب أن يتم من بيئة موثوقة على الخادم باستخدام `OAuth 2.0 access token` أو عبر Admin SDK. في Laravel/PHP أبسط خيار عملي هنا هو استخدام `FCM HTTP v1` مع `google/auth`.

## تثبيت المتطلبات في Laravel

```bash
composer require google/auth
php artisan make:model UserDevice -m
php artisan make:controller Api/Flutter/DeviceTokenController
php artisan make:controller Api/Flutter/NotificationTestController
php artisan make:job SendPushNotificationJob
```

ثم أنشئ Service يدويًا:

- `app/Services/FcmService.php`

## إعداد Firebase على الخادم

من Firebase Console:

1. افتح مشروع Firebase المرتبط بالتطبيق.
2. اذهب إلى `Project settings`.
3. افتح تبويب `Service accounts`.
4. أنشئ `Private key` جديدًا.
5. ضع ملف الـ JSON في مكان آمن على الخادم.

لا ترفع ملف `service-account.json` إلى Git.

### مثال `.env`

```dotenv
GOOGLE_APPLICATION_CREDENTIALS=/var/www/app/storage/app/firebase/service-account.json
FIREBASE_PROJECT_ID=your-firebase-project-id
```

### مثال `config/services.php`

```php
'firebase' => [
    'project_id' => env('FIREBASE_PROJECT_ID'),
],
```

## جدول حفظ أجهزة المستخدم

### Migration

```php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('user_devices', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('token', 255)->unique();
            $table->string('platform', 20);
            $table->string('device_name')->nullable();
            $table->string('app_version', 30)->nullable();
            $table->timestamp('last_used_at')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'platform']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_devices');
    }
};
```

ثم:

```bash
php artisan migrate
```

### Model

```php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UserDevice extends Model
{
    protected $fillable = [
        'user_id',
        'token',
        'platform',
        'device_name',
        'app_version',
        'last_used_at',
    ];

    protected $casts = [
        'last_used_at' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
```

## Routes المطلوبة

إذا كنت تستخدم `Sanctum`:

```php
use App\Http\Controllers\Api\Flutter\DeviceTokenController;
use App\Http\Controllers\Api\Flutter\NotificationTestController;
use Illuminate\Support\Facades\Route;

Route::middleware('auth:sanctum')->prefix('flutter')->group(function () {
    Route::post('/devices/token', [DeviceTokenController::class, 'store']);
    Route::delete('/devices/token', [DeviceTokenController::class, 'destroy']);
    Route::post('/notifications/test', [NotificationTestController::class, 'store']);
});
```

إذا كنت تستخدم guard مختلفًا، استبدل `auth:sanctum` بنفس middleware المستخدم في بقية API الخاصة بالتطبيق.

## Controller لتسجيل وحذف التوكن

### `app/Http/Controllers/Api/Flutter/DeviceTokenController.php`

```php
namespace App\Http\Controllers\Api\Flutter;

use App\Http\Controllers\Controller;
use App\Models\UserDevice;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DeviceTokenController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'token' => ['required', 'string', 'max:255'],
            'platform' => ['required', 'string', 'in:android,ios,web'],
            'device_name' => ['nullable', 'string', 'max:255'],
            'app_version' => ['nullable', 'string', 'max:30'],
        ]);

        UserDevice::updateOrCreate(
            ['token' => $data['token']],
            [
                'user_id' => $request->user()->id,
                'platform' => $data['platform'],
                'device_name' => $data['device_name'] ?? null,
                'app_version' => $data['app_version'] ?? null,
                'last_used_at' => now(),
            ]
        );

        return response()->json([
            'message' => 'Device token stored successfully.',
        ]);
    }

    public function destroy(Request $request): JsonResponse
    {
        $data = $request->validate([
            'token' => ['required', 'string', 'max:255'],
        ]);

        UserDevice::query()
            ->where('user_id', $request->user()->id)
            ->where('token', $data['token'])
            ->delete();

        return response()->json([
            'message' => 'Device token removed successfully.',
        ]);
    }
}
```

## Service لإرسال الإشعارات إلى FCM

### `app/Services/FcmService.php`

```php
namespace App\Services;

use App\Models\User;
use App\Models\UserDevice;
use Google\Auth\ApplicationDefaultCredentials;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use RuntimeException;

class FcmService
{
    private const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

    public function sendToUser(User $user, string $title, string $body, array $data = []): void
    {
        $tokens = UserDevice::query()
            ->where('user_id', $user->id)
            ->pluck('token')
            ->filter()
            ->unique()
            ->values()
            ->all();

        if ($tokens === []) {
            return;
        }

        $payloadData = $this->normalizeData($data);

        foreach ($tokens as $token) {
            $response = Http::withToken($this->accessToken())
                ->acceptJson()
                ->post($this->endpoint(), [
                    'message' => [
                        'token' => $token,
                        'notification' => [
                            'title' => $title,
                            'body' => $body,
                        ],
                        'data' => $payloadData,
                        'android' => [
                            'priority' => 'HIGH',
                        ],
                        'apns' => [
                            'headers' => [
                                'apns-priority' => '10',
                            ],
                            'payload' => [
                                'aps' => [
                                    'sound' => 'default',
                                ],
                            ],
                        ],
                    ],
                ]);

            if ($response->successful()) {
                continue;
            }

            if ($this->isUnregisteredToken($response->body())) {
                UserDevice::where('token', $token)->delete();
                continue;
            }

            $response->throw();
        }
    }

    private function accessToken(): string
    {
        return Cache::remember('firebase_access_token', now()->addMinutes(50), function (): string {
            $credentials = ApplicationDefaultCredentials::getCredentials(self::SCOPE);

            if ($credentials === null) {
                throw new RuntimeException('Google application credentials are not configured.');
            }

            $token = $credentials->fetchAuthToken();

            if (! isset($token['access_token'])) {
                throw new RuntimeException('Unable to fetch Firebase access token.');
            }

            return $token['access_token'];
        });
    }

    private function endpoint(): string
    {
        $projectId = config('services.firebase.project_id');

        if (! $projectId) {
            throw new RuntimeException('FIREBASE_PROJECT_ID is missing.');
        }

        return "https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send";
    }

    private function normalizeData(array $data): array
    {
        $result = [];

        foreach ($data as $key => $value) {
            if (is_bool($value)) {
                $result[(string) $key] = $value ? 'true' : 'false';
                continue;
            }

            if (is_scalar($value) || $value === null) {
                $result[(string) $key] = (string) $value;
                continue;
            }

            $result[(string) $key] = json_encode($value, JSON_UNESCAPED_UNICODE);
        }

        return $result;
    }

    private function isUnregisteredToken(string $responseBody): bool
    {
        return str_contains($responseBody, 'UNREGISTERED')
            || str_contains($responseBody, 'registration-token-not-registered');
    }
}
```

## Job لإرسال الإشعار من الـ Queue

### `app/Jobs/SendPushNotificationJob.php`

```php
namespace App\Jobs;

use App\Models\User;
use App\Services\FcmService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class SendPushNotificationJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;

    public array $backoff = [30, 120, 300];

    public function __construct(
        public int $userId,
        public string $title,
        public string $body,
        public array $data = [],
    ) {
    }

    public function handle(FcmService $fcmService): void
    {
        $user = User::find($this->userId);

        if (! $user) {
            return;
        }

        $fcmService->sendToUser($user, $this->title, $this->body, $this->data);
    }
}
```

## Endpoint لإرسال إشعار اختبار

هذا endpoint مفيد لأن Flutter عندك لديه زر اختبار يرسل إلى:

- `POST /api/flutter/notifications/test`

### `app/Http/Controllers/Api/Flutter/NotificationTestController.php`

```php
namespace App\Http\Controllers\Api\Flutter;

use App\Http\Controllers\Controller;
use App\Jobs\SendPushNotificationJob;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NotificationTestController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'title' => ['nullable', 'string', 'max:120'],
            'body' => ['nullable', 'string', 'max:255'],
            'data' => ['nullable', 'array'],
        ]);

        SendPushNotificationJob::dispatch(
            $request->user()->id,
            $data['title'] ?? 'Hello from Tasameem',
            $data['body'] ?? 'This is a test notification.',
            array_merge([
                'type' => 'test_notification',
                'screen' => 'notifications',
            ], $data['data'] ?? [])
        );

        return response()->json([
            'message' => 'Notification queued successfully.',
        ]);
    }
}
```

## كيف يحدد Flutter الشاشة التي سيفتحها

التطبيق الحالي يعتمد على قيمة `screen` داخل `data`.

القيم المدعومة الآن:

- `notifications`
- `order_details`
- `orders`
- `wallet`

إذا كانت القيمة `order_details` فيجب إرسال:

- `order_number`

مثال:

```json
{
  "type": "order.created",
  "screen": "order_details",
  "order_number": "ORD-10045"
}
```

## أنواع `type` التي يفهمها التطبيق حاليًا

الواجهة الحالية تتعامل بصريًا مع هذه القيم:

- `order_status_changed`
- `order.created`
- `wallet_topup_completed`
- `wallet.topup.completed`
- `payment_failed`
- `payment.failed`

يمكنك الالتزام بهذه القيم حتى تظهر الأيقونات والألوان المناسبة داخل شاشة الإشعارات.

## مثال عند نجاح إنشاء طلب شراء

استخدم هذا بعد نجاح الطلب فعليًا على الخادم، وليس عند بداية العملية.

```php
use App\Jobs\SendPushNotificationJob;

SendPushNotificationJob::dispatch(
    $order->user_id,
    'تم تأكيد طلبك',
    "تم إنشاء الطلب رقم {$order->order_number} بنجاح.",
    [
        'type' => 'order.created',
        'screen' => 'order_details',
        'order_number' => $order->order_number,
    ]
)->afterCommit();
```

إذا كنت ترسل إشعارًا لاحقًا عند تغيّر حالة الطلب:

```php
SendPushNotificationJob::dispatch(
    $order->user_id,
    'تم تحديث حالة الطلب',
    "حالة الطلب رقم {$order->order_number} أصبحت {$order->status}.",
    [
        'type' => 'order_status_changed',
        'screen' => 'order_details',
        'order_number' => $order->order_number,
        'status' => $order->status,
    ]
)->afterCommit();
```

## مثال عند نجاح شحن المحفظة

بعد تأكيد الدفع وإضافة الرصيد بنجاح:

```php
use App\Jobs\SendPushNotificationJob;

SendPushNotificationJob::dispatch(
    $walletTransaction->user_id,
    'تم شحن المحفظة',
    'تمت إضافة الرصيد إلى محفظتك بنجاح.',
    [
        'type' => 'wallet.topup.completed',
        'screen' => 'wallet',
        'amount' => $walletTransaction->amount,
        'transaction_id' => $walletTransaction->id,
    ]
)->afterCommit();
```

## مثال عند فشل عملية الدفع

```php
SendPushNotificationJob::dispatch(
    $user->id,
    'فشلت عملية الدفع',
    'تعذر إتمام عملية الدفع، يرجى المحاولة مرة أخرى.',
    [
        'type' => 'payment.failed',
        'screen' => 'notifications',
    ]
)->afterCommit();
```

## Payload موصى به للطلب

```json
{
  "message": {
    "token": "FCM_DEVICE_TOKEN",
    "notification": {
      "title": "تم تأكيد طلبك",
      "body": "تم إنشاء الطلب رقم ORD-10045 بنجاح."
    },
    "data": {
      "type": "order.created",
      "screen": "order_details",
      "order_number": "ORD-10045"
    }
  }
}
```

## Payload موصى به لشحن المحفظة

```json
{
  "message": {
    "token": "FCM_DEVICE_TOKEN",
    "notification": {
      "title": "تم شحن المحفظة",
      "body": "تمت إضافة الرصيد إلى محفظتك بنجاح."
    },
    "data": {
      "type": "wallet.topup.completed",
      "screen": "wallet",
      "amount": "50",
      "transaction_id": "9812"
    }
  }
}
```

## ملاحظات مهمة جدًا

### 1. كل قيم `data` يجب أن تكون نصية

في `FCM HTTP v1` يجب أن تكون قيم `data` من نوع `string`.

لهذا السبب خدمة `FcmService` في الأعلى تقوم بتحويل القيم تلقائيًا إلى نص.

### 2. لا ترسل الإشعار قبل اكتمال العملية

لا ترسل عند:

- إنشاء طلب دفع مبدئي
- فتح صفحة الدفع
- تجهيز رابط بوابة الدفع

أرسل فقط بعد:

- نجاح إنشاء الطلب نهائيًا
- نجاح خصم المبلغ أو تأكيده
- نجاح إضافة الرصيد إلى المحفظة

### 3. احذف التوكنات غير الصالحة

إذا رجع `FCM` بأن التوكن لم يعد صالحًا، احذفه من قاعدة البيانات حتى لا تستمر المحاولات عليه.

### 4. لا تربط الإشعار بالواجهة مباشرة

يفضل أن يكون الإرسال من:

- `Service`
- `Action`
- `Event Listener`
- `Job`

وليس من داخل الـ controller بشكل مباشر إذا كانت العملية أكبر من مجرد اختبار.

### 5. استخدم Queue Worker

إذا كنت سترسل إشعارات حقيقية في الإنتاج:

```bash
php artisan queue:work
```

أو شغّل worker تحت `supervisor` في السيرفر.

## أماكن الربط المقترحة في مشروع Laravel

غالبًا ستربط الإرسال في أحد هذه المواضع:

- بعد نجاح `OrderService::createOrder()`
- بعد نجاح `WalletTopUpService::confirm()`
- بعد callback ناجح من بوابة الدفع
- بعد event مثل `OrderCreated`, `OrderPaid`, `WalletTopUpCompleted`

القاعدة العامة:

- إذا كانت العملية ما تزال قابلة للفشل فلا ترسل
- إذا تم تثبيت النتيجة في قاعدة البيانات، عندها أرسل

## Checklist نهائية

- تم إنشاء جدول `user_devices`
- تم حفظ `FCM token` من التطبيق في قاعدة البيانات
- تم حذف التوكن عند logout
- تم إعداد `GOOGLE_APPLICATION_CREDENTIALS`
- تم إعداد `FIREBASE_PROJECT_ID`
- تم إنشاء `FcmService`
- تم إنشاء `SendPushNotificationJob`
- تم إنشاء endpoint للاختبار
- تم ربط الإرسال مع نجاح الطلب
- تم ربط الإرسال مع نجاح شحن المحفظة
- تم تشغيل `queue worker`

## الخلاصة

نعم، أنت تحتاج إلى كود في `Laravel`.

الحد الأدنى المطلوب هو:

- endpoint لحفظ التوكن
- endpoint لحذف التوكن
- خدمة ترسل إلى `FCM`
- job للإرسال
- استدعاء هذا الـ job بعد نجاح الطلب أو شحن المحفظة

بهذا الشكل يصبح `Flutter` مستقبلًا للإشعار فقط، و`Laravel` هو المسؤول عن قرار الإرسال وتوقيته وصحة العملية.

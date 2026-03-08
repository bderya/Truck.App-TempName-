# Error handling & exception system

## Payment failures (Iyzico/API)

When a payment API returns an error, the app shows a **custom BottomSheet** with:
- The specific error message (in Turkish)
- **"Ödeme Yöntemini Güncelle"** (Update Payment Method) button → opens Add Card sheet; on success you can retry the flow
- **"Kapat"** to dismiss

Used in: Request Tow pre-auth, Add Card, and (when `userId` is passed) completion payment.

## No connectivity

- **Package**: `connectivity_plus`
- **Provider**: `connectivityStatusProvider` (stream of `true` = connected, `false` = offline)
- **UI**: Persistent **orange banner** at the top: *"İnternet bağlantısı yok. Yeniden bağlanmaya çalışılıyor..."* when offline. It hides automatically when connectivity returns.

## Driver search timeout (120 s)

If no driver accepts within **120 seconds** after "Request Tow", a dialog appears:
- **Title**: "Hala arıyoruz"
- **Message**: "Bir sürücü bulunamadı. Beklemeye devam etmek ister misiniz yoksa destek hattımızı mı arayalım?"
- **"Beklemeye devam et"** → dismiss and keep waiting
- **"Destek hattını ara"** → opens phone dialer with support number

Support number is set in `lib/features/map/map_view_screen.dart` as `_supportPhone` (default `+908501234567`). Change it to your real support line.

## Crash reporting (Sentry)

- **Package**: `sentry_flutter`
- **Setup**: In `lib/main.dart`, set `_sentryDsn` to your [Sentry DSN](https://docs.sentry.io/platforms/dart/guides/flutter/). Leave empty to disable.
- When DSN is set, **unhandled Flutter and Dart errors** are reported to Sentry (including async errors via the SDK’s zone).

## User-facing messages (Turkish)

- **`ErrorMessagesTr.from(error)`**: Maps technical exceptions (e.g. `SocketException`, timeout) to short Turkish text (e.g. *"Bağlantı sorunu oluştu. İnternet bağlantınızı kontrol edin."*).
- **`PaymentErrorHelper.userMessageTr(failure)`**: Payment failure messages in Turkish (insufficient balance, card declined, expired, etc.).
- Use these wherever you show errors to users so messages stay simple and non-technical.

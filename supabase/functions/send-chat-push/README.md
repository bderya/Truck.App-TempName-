# Send push on new chat message

Triggered when a row is **inserted** into `messages`. Sends an FCM notification to the recipient (the other party in the booking).

## Setup

1. **Database Webhook**  
   - Table: `messages`  
   - Events: **Insert**  
   - URL: `https://<project-ref>.supabase.co/functions/v1/send-chat-push`  
   (or local: `http://host.docker.internal:54321/functions/v1/send-chat-push`)

2. **FCM**  
   - Set secret: `FCM_SERVER_KEY` = your Firebase Cloud Messaging **server key** (Legacy HTTP).  
   - In Firebase Console: Project Settings → Cloud Messaging → Server key.

3. **Deploy**  
   - `supabase functions deploy send-chat-push`

## Note

Legacy FCM HTTP is deprecated in favor of FCM HTTP v1. For v1 you need a service account JSON and OAuth2 token; this stub uses the legacy key for simplicity.

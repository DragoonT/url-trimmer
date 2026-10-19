# Trim Playlist mobile API contract

The Android and iOS apps play files and direct media links on the device. They do not call this service. This contract is only for a future shared download service.

The desktop server binds to `127.0.0.1` and manages local files. It is not safe or suitable as a mobile backend.

That future service needs authenticated users and per-user storage. Mobile clients must never upload browser cookies or receive desktop cookie files.

## First endpoint

`GET /api/session` returns the signed-in state used by the starter mobile clients:

```json
{
  "authenticated": true,
  "user": { "id": "user_123", "name": "Example user" }
}
```

Use `401 Unauthorized` when no valid access token is provided. A production client should use an OAuth or platform-native sign-in flow and send a short-lived access token in `Authorization: Bearer <token>`.

## Next endpoints

| Endpoint | Purpose |
| --- | --- |
| `GET /api/playlists` | List the current user's playlists. |
| `POST /api/playlists` | Create a playlist. |
| `POST /api/playlists/{id}/items` | Add a local upload or approved online media reference. |
| `POST /api/downloads/preview` | Validate a public or user-authorized URL and show selectable items. |
| `POST /api/downloads` | Start a download job owned by the signed-in user. |
| `GET /api/downloads/{id}` | Read progress and final media details. |

Downloaded media should be stored per user, served through authorized HTTPS URLs, and deleted according to a documented retention policy.

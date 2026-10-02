# Wianu website

Run `pnpm dev` from this directory. The site uses the TMDB token in `.env` for movie search and metadata.

## Weekly editor

Set these server-side environment variables before starting the Node server:

| Variable                     | Purpose                                                                       |
| ---------------------------- | ----------------------------------------------------------------------------- |
| `TMDB_TOKEN`                 | TMDB API bearer token                                                         |
| `WEEKLY_ADMIN_PASSWORD_HASH` | Salted scrypt hash for `/admin/weekly`                                        |
| `WEEKLY_SESSION_SECRET`      | Long, random secret used to sign admin cookies                                |
| `WEEKLY_DATA_FILE`           | Absolute path to a writable, persistent JSON file for the published selection |

Generate a password hash with `node scripts/hash-admin-password.mjs` and enter the password at its hidden prompt. Generate the session secret with `openssl rand -hex 32`. Keep the hash and secret out of source control. Use HTTPS in production, and configure the Node adapter's `ORIGIN` to the site's public URL when running behind a reverse proxy.

The default data path is `.data/weekly.json`, relative to the server's working directory. For deployment, set `WEEKLY_DATA_FILE` to a path on a persistent volume. The file store assumes one writable Node instance; multiple instances need shared storage and a coordinated write strategy.

`GET /v1/weekly` returns an archive of ISO calendar weeks, with five movie IDs, a `reasons` map keyed by movie ID, and a publication time for each week. `PUT /v1/weekly` accepts `{ "movieIds": [1, 2, 3, 4, 5], "reasons": ["First reason", "Second reason", "Third reason", "Fourth reason", "Fifth reason"] }` from a signed-in admin session and verifies each ID against TMDB before publishing. Each reason must be 1–500 characters after trimming and corresponds to the movie ID at the same position. Publishing again during the same week replaces that week's selection; earlier weeks remain in the archive. The public page fetches details for each ID through `GET /v1/movie/:id`, so the TMDB token stays on the server. Older archive entries without reasons remain readable; the editor requires reasons when they are republished. An existing metadata snapshot remains readable and is converted to the archive format on the next publish.

# NEX-APP Backend Service

This is the standalone central backend server for NEX-APP, built with Node.js and Express.

## Requirements

- Node.js 18+
- npm or yarn
- Firebase Account (for Admin SDK)

## Setup Instructions

1. **Install dependencies**
   ```bash
   npm install
   ```

2. **Configuration**
   Copy the example environment file:
   ```bash
   cp .env.example .env
   ```
   Edit `.env` and fill in your configuration details. Be sure to include your `FIREBASE_API_KEY` (Web API Key) for admin login.

3. **Firebase Service Account**
   - Go to your Firebase Console > Project Settings > Service Accounts.
   - Click "Generate new private key".
   - Save the downloaded JSON file as `serviceAccountKey.json` in the root of the `backend_service` folder.

## Running the Server

**Development Mode:**
```bash
npm run dev
```

**Production Mode:**
```bash
npm start
```

## Admin Panel

Once the server is running, you can access the admin dashboard at:
http://localhost:3000/admin

## API Endpoints Reference

| Endpoint | Description |
|---|---|
| `/api/v1/health` | System health check |
| `/api/v1/users` | User management operations |
| `/api/v1/chat` | Chat and messaging services |
| `/api/v1/calls` | Call signaling and management |
| `/api/v1/status` | User status and presence |
| `/api/v1/gaming` | Gaming integrations |
| `/api/v1/cloner` | App cloner features |
| `/api/v1/defender` | Anti-malware and defender tools |
| `/api/v1/firewall` | Network filtering and firewall rules |
| `/api/v1/marketplace` | Mini-app marketplace management |
| `/api/v1/social` | Social feed and interactions |
| `/api/v1/admin` | Admin dashboard APIs and protected routes |

## Deployment Guide (Railway.app)

1. Create a free account on [Railway.app](https://railway.app/).
2. Click "New Project" > "Deploy from GitHub repo".
3. Select your repository and the root directory for this backend.
4. Go to the "Variables" tab and add all the environment variables from your `.env` file.
5. For the Firebase Service Account, you can either:
   - Provide the path to `serviceAccountKey.json` if committed (not recommended).
   - Encode the JSON to Base64, store it in an environment variable (e.g. `FIREBASE_SERVICE_ACCOUNT_BASE64`), and parse it in your config.
6. Railway will automatically build and deploy using `npm start`.

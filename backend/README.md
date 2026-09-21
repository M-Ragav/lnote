# LNote Python Sync Backend

Lightweight, high-performance synchronization server for LNote attendance tracker. Enables automatic cross-device sync between your laptop (Windows) and mobile phone (Android/iOS).

## Quick Start

### 1. Launch the Backend Server

Double-click **`start.bat`** (or run via PowerShell / Terminal):

```bash
cd backend
python run.py
```

You will see output similar to:
```
============================================================
   LNote Synchronization Backend Server
============================================================
 * Localhost (Laptop):  http://127.0.0.1:8000
 * Wi-Fi/LAN (Mobile):  http://192.168.1.7:8000
 * API Documentation:   http://127.0.0.1:8000/docs
 * Health Endpoint:     http://192.168.1.7:8000/api/health
============================================================
```

---

## 2. Connect Your Devices

### On Laptop (Windows)
1. Open the LNote app.
2. Go to **Profile** > **Cloud Sync** > **Backend Server**.
3. Tap **Laptop (Localhost)** or enter:
   ```
   http://127.0.0.1:8000
   ```
4. Click **Test Connection** (verify green indicator) > **Save & Sync Now**.

### On Mobile Phone (Android / iOS)
1. Connect your phone to the **same Wi-Fi network** as your laptop.
2. Open the LNote app on your phone.
3. Go to **Profile** > **Cloud Sync** > **Backend Server**.
4. Enter your laptop's Wi-Fi IP (e.g.):
   ```
   http://192.168.1.7:8000
   ```
5. Tap **Test Connection** > **Save & Sync Now**.

---

## How Synchronization Works

- **Automatic on App Open / Resume**: Reopening the app on either device immediately pulls latest updates.
- **Instant on Session Change**: Clocking IN, clocking OUT, or tagging a session immediately pushes the update to the backend in the background.
- **Periodic Background Sync**: While the app is open, it automatically syncs every 30 seconds.
- **Manual Sync**: Tap **Sync Now** in the Profile page whenever you want an instant refresh.
- **Data Persistence**: Data is persisted locally in `backend/lnote.db` (SQLite).

# Runbook: Bank Notification Collector Phone Operations

This runbook documents setup, permissions, operational checks, and device handover for the dedicated Android collector device running `collector_app`.

---

## 1. Device Purpose & Hardware Requirements

- **Role:** Dedicated Android phone stationed with bank SIM cards or bank apps installed, listening for financial transaction notifications and uploading sanitized parsed events.
- **Privacy Assurance:** The collector extracts only strictly necessary fields (`amount`, `occurred_at`, `direction`, `full owner account`, `bank description`). It **never logs, stores, or transmits bank balances, OTPs, or non-financial notifications**.
- **Supported Android Versions:** Android 8.0 (API 26) through Android 15 (API 35).

---

## 2. Building & Installing Collector APK

From repository root:

```bash
# Build release signed APK
python3 tool/build_apk.py collector

# Install onto USB-connected Android phone
adb install -r apps/collector_app/build/installers/collector-release-1.0.0.apk
```

---

## 3. Mandatory Android System Permissions

After installation, complete the following system settings on the collector phone:

### 3.1 Notification Access (Truy cập thông báo)
1. Open Android **Settings** > **Apps** > **Special app access** > **Notification access** (Cài đặt > Ứng dụng > Quyền truy cập đặc biệt > Truy cập thông báo).
2. Find **Collector App** (Quản lý Tao Collector) and toggle **Allow** (Cho phép).
3. Confirm system security warning prompt.

### 3.2 Battery Optimization Exemption (Tắt tối ưu pin)
1. Open Android **Settings** > **Apps** > **Collector App** > **Battery** (Pin).
2. Set to **Unrestricted** (Không hạn chế) or **Don't optimize** (Không tối ưu hóa).
3. This prevents Android Doze mode from killing the background notification listener.

### 3.3 Autostart & Background Running (OEM Specific)
- **Xiaomi / Redmi (MIUI / HyperOS):** Settings > Apps > Permissions > Autostart > Enable for Collector App.
- **Oppo / Realme (ColorOS):** Settings > App Management > Collector App > Allow Background Activity & Auto-launch.
- **Samsung (OneUI):** Settings > Battery and device care > Battery > Background usage limits > Never sleeping apps > Add Collector App.

---

## 4. Boot Recovery & Resilience

The collector registers `BOOT_COMPLETED` receiver (`BootReceiver.kt`). When the phone reboots:
- The `BankNotificationListenerService` is automatically re-bound by Android.
- The `UploadWorker` WorkManager job is enqueued to drain any queued events stored in the local Room database (`collector_queue.db`).

---

## 5. Collector Handover & Replacement Procedure

To replace a collector device or move the SIM card to a new device:

1. **Verify Outbox Drainage:**
   On the old collector phone, open the **Thiết bị** (Device) tab. Ensure **Hàng đợi** shows `0 sự kiện chưa đồng bộ`.
2. **Warning on Undrained Queue:**
   If unsynced events remain, press **Thử gửi lại ngay** (Retry now) with network connected.
3. **Register New Device:**
   Log into the new phone with administrator credentials. The backend creates a new collector session and advances the active collector epoch.
4. **Old Device Deactivation:**
   The backend enforces the **single active collector invariant**. Any upload attempts from the retired device with an older epoch are immediately rejected with `COLLECTOR_EPOCH_MISMATCH`.
5. **Wipe Old Collector:**
   Tap **Đăng xuất & Xóa dữ liệu cục bộ** on the old device.

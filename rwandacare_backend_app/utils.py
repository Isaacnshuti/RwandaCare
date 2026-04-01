"""
utils.py — Shared helpers for RwandaCare backend.

Main responsibilities:
  1. log_action()                         → creates an AuditLog entry
  2. send_ios_push()                      → sends an APNs push notification
  3. ensure_patient_notification_preferences() → bootstraps mobile settings
"""

import logging

logger = logging.getLogger(__name__)


DEFAULT_NOTIFICATION_PREFERENCES = [
    {
        "key": "appointment_reminders",
        "title": "Appointment Reminders",
        "subtitle": "24h before your visit",
        "icon": "calendar.badge.clock",
        "color_hex": "#3B82F6",
        "enabled": True,
    },
    {
        "key": "medication_reminders",
        "title": "Medication Reminders",
        "subtitle": "At dose time every day",
        "icon": "pills.fill",
        "color_hex": "#F97316",
        "enabled": True,
    },
    {
        "key": "lab_results_ready",
        "title": "Lab Results Ready",
        "subtitle": "When results are available",
        "icon": "doc.text.fill",
        "color_hex": "#22C55E",
        "enabled": True,
    },
    {
        "key": "health_tips",
        "title": "Health Tips",
        "subtitle": "Weekly wellness advice",
        "icon": "heart.text.square.fill",
        "color_hex": "#8B5CF6",
        "enabled": False,
    },
    {
        "key": "emergency_alerts",
        "title": "Emergency Alerts",
        "subtitle": "Urgent health news in Kigali",
        "icon": "exclamationmark.triangle.fill",
        "color_hex": "#EF4444",
        "enabled": True,
    },
    {
        "key": "new_doctor_available",
        "title": "New Doctor Available",
        "subtitle": "When a specialist joins nearby",
        "icon": "person.badge.plus",
        "color_hex": "#06B6D4",
        "enabled": False,
    },
]


# ─────────────────────────────────────────────
#  AUDIT LOG WRITER
# ─────────────────────────────────────────────

def log_action(request, action: str, description: str, hospital=None, meta: dict = None):
    """
    Creates an AuditLog entry. Call this from any view or signal.

    Args:
        request:     DRF request object (provides user + IP)
        action:      AuditLog.ACTION_CHOICES key, e.g. 'CREATE', 'CONSULT_CLOSE'
        description: Human-readable summary of what happened
        hospital:    Hospital instance (optional — auto-resolved from staff if omitted)
        meta:        Additional JSON payload to store (before/after snapshots, etc.)
    """
    from .models import AuditLog

    try:
        actor = request.user if request.user.is_authenticated else None
        resolved_hospital = hospital
        if resolved_hospital is None:
            try:
                resolved_hospital = actor.staff_profile.hospital
            except AttributeError:
                pass

        ip = _get_client_ip(request)

        AuditLog.objects.create(
            actor=actor,
            log_type='INFO',
            action=action,
            description=description,
            hospital=resolved_hospital,
            meta=meta or {},
            ip_address=ip,
            user_agent=request.META.get('HTTP_USER_AGENT', '')[:300],
        )
    except Exception as exc:
        # Never let audit logging crash the actual request
        logger.error(f"[AuditLog] Failed to write log: {exc}")


def _get_client_ip(request) -> str | None:
    """Extract real client IP, respecting X-Forwarded-For."""
    xff = request.META.get('HTTP_X_FORWARDED_FOR')
    if xff:
        return xff.split(',')[0].strip()
    return request.META.get('REMOTE_ADDR')


def ensure_patient_notification_preferences(patient):
    """
    Create the mobile notification preference rows expected by the Swift app.
    Existing preferences are preserved.
    """
    from .models import PatientNotificationPreference

    for pref in DEFAULT_NOTIFICATION_PREFERENCES:
        PatientNotificationPreference.objects.get_or_create(
            patient=patient,
            key=pref["key"],
            defaults={
                "title": pref["title"],
                "subtitle": pref["subtitle"],
                "icon": pref["icon"],
                "color_hex": pref["color_hex"],
                "enabled": pref["enabled"],
            },
        )


# ─────────────────────────────────────────────
#  iOS PUSH NOTIFICATION SENDER
# ─────────────────────────────────────────────

def send_ios_push(
    *,
    title: str,
    body: str,
    notif_type: str,
    data: dict = None,
    patient=None,
    staff=None,
):
    """
    Sends an APNs push notification to a patient or staff member
    and records it in IOSNotification for inbox display.

    Args:
        title:       Notification title (shown on lock screen)
        body:        Notification body text
        notif_type:  IOSNotification.NOTIF_TYPE_CHOICES key
        data:        Custom payload dict (for deep linking in iOS app)
        patient:     Patient instance (recipient — patient-facing notifications)
        staff:       StaffProfile instance (recipient — doctor/admin notifications)

    Usage:
        send_ios_push(
            patient=appt.patient,
            title="✅ Rendez-vous confirmé",
            body="Le 28 mars à 10:30 — Dr. Kamanzi",
            notif_type='BOOKING_CONFIRM',
            data={'appointment_id': str(appt.id)},
        )
    """
    from .models import IOSNotification

    if not patient and not staff:
        logger.warning("[Push] send_ios_push called with no recipient.")
        return

    # 1. Persist notification record
    notif = IOSNotification.objects.create(
        recipient_patient=patient,
        recipient_staff=staff,
        notif_type=notif_type,
        title=title,
        body=body,
        data_payload=data or {},
    )

    # 2. Determine device token
    device_token = None
    if staff and staff.ios_device_token:
        device_token = staff.ios_device_token
    elif patient and patient.ios_device_token:
        device_token = patient.ios_device_token

    if not device_token:
        logger.info(f"[Push] No device token for recipient — notification stored only (id={notif.id})")
        return

    # 3. Send via APNs (using aioapns or httpx in production)
    success = _send_apns(
        device_token=device_token,
        title=title,
        body=body,
        data=data or {},
        notif_id=str(notif.id),
    )

    # 4. Update delivery status
    notif.delivered = success
    notif.save(update_fields=['delivered'])


def _send_apns(device_token: str, title: str, body: str, data: dict, notif_id: str) -> bool:
    """
    Low-level APNs HTTP/2 delivery.

    In production, replace this stub with:
      - httpx + JWT auth (recommended for Django)
      - or the `apns2` / `aioapns` library

    Returns True on success, False on failure.
    """
    try:
        import httpx
        import jwt as pyjwt
        import time
        from django.conf import settings

        # Build JWT token for APNs
        token = pyjwt.encode(
            {'iss': settings.APNS_TEAM_ID, 'iat': int(time.time())},
            settings.APNS_AUTH_KEY,
            algorithm='ES256',
            headers={'kid': settings.APNS_KEY_ID},
        )

        payload = {
            'aps': {
                'alert': {'title': title, 'body': body},
                'sound': 'default',
                'badge': 1,
            },
            **data,
            'notif_id': notif_id,
        }

        url = f"https://api.push.apple.com/3/device/{device_token}"
        headers = {
            'authorization': f'bearer {token}',
            'apns-topic': settings.APNS_BUNDLE_ID,   # e.g. rw.rwandacare.app
            'apns-push-type': 'alert',
        }

        with httpx.Client(http2=True) as client:
            response = client.post(url, json=payload, headers=headers, timeout=10)

        if response.status_code == 200:
            logger.info(f"[Push] ✅ Delivered to {device_token[:12]}… (notif_id={notif_id})")
            return True
        else:
            logger.error(f"[Push] ❌ APNs error {response.status_code}: {response.text}")
            return False

    except ImportError:
        # httpx or PyJWT not installed — log and skip (safe in dev)
        logger.warning("[Push] httpx/jwt not available — APNs skipped (dev mode).")
        return False
    except Exception as exc:
        logger.error(f"[Push] Unexpected error sending APNs: {exc}")
        return False

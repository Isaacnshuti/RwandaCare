from django.contrib import admin
from django.utils.html import format_html

from .models import (
    Appointment,
    AuditLog,
    DoctorAvailabilitySlot,
    Hospital,
    IOSNotification,
    LabRequest,
    MedicalFacility,
    MedicalHistoryEntry,
    MedicationPlan,
    Patient,
    PatientLabResult,
    PatientNotificationPreference,
    PreAdmission,
    Prescription,
    StaffProfile,
    SymptomAssessment,
    Vitals,
)


@admin.register(Hospital)
class HospitalAdmin(admin.ModelAdmin):
    list_display = (
        "name",
        "district",
        "type",
        "total_beds",
        "occupancy_display",
        "doctor_count",
        "rwandacare_sync_enabled",
        "is_active",
    )
    list_filter = ("is_active", "type", "rwandacare_sync_enabled", "district")
    search_fields = ("name", "district", "phone")
    readonly_fields = ("id", "created_at", "occupancy_display")
    fieldsets = (
        ("General", {"fields": ("id", "name", "district", "address", "phone", "email", "type")}),
        ("Capacity", {"fields": ("total_beds", "occupied_beds", "occupancy_display")}),
        ("Coordinates", {"fields": ("latitude", "longitude")}),
        ("RwandaCare Sync", {"fields": ("rwandacare_sync_enabled", "sync_token")}),
        ("Status", {"fields": ("is_active", "created_at")}),
    )

    @admin.display(description="Occupancy")
    def occupancy_display(self, obj):
        rate = obj.occupancy_rate
        color = "#ef4444" if rate > 80 else "#f59e0b" if rate > 60 else "#10b981"
        return format_html(
            '<span style="color:{};font-weight:bold;">{} %</span>',
            color,
            rate,
        )

    @admin.display(description="Doctors")
    def doctor_count(self, obj):
        return obj.doctor_count


@admin.register(MedicalFacility)
class MedicalFacilityAdmin(admin.ModelAdmin):
    list_display = (
        "name",
        "facility_type",
        "district",
        "hospital",
        "is_open_24h",
        "rating",
        "distance_km",
        "is_active",
    )
    list_filter = ("facility_type", "district", "is_open_24h", "is_active")
    search_fields = ("name", "district", "address", "phone")
    autocomplete_fields = ("hospital",)


@admin.register(StaffProfile)
class StaffProfileAdmin(admin.ModelAdmin):
    list_display = (
        "full_name_display",
        "role",
        "specialty",
        "hospital",
        "is_available",
        "years_experience",
        "app_connected_display",
        "app_last_seen",
    )
    list_filter = ("role", "hospital", "is_available")
    search_fields = ("user__first_name", "user__last_name", "license_number", "hospital__name")
    autocomplete_fields = ("user", "hospital")
    readonly_fields = ("app_last_seen", "app_connected_display")
    fieldsets = (
        ("Account", {"fields": ("user", "role", "hospital")}),
        (
            "Medical Profile",
            {
                "fields": (
                    "specialty",
                    "phone",
                    "license_number",
                    "years_experience",
                    "consultation_fee",
                    "rating",
                    "bio",
                    "profile_picture",
                )
            },
        ),
        ("Availability & iOS", {"fields": ("is_available", "ios_device_token", "app_last_seen", "app_connected_display")}),
    )

    @admin.display(description="Name")
    def full_name_display(self, obj):
        return str(obj)

    @admin.display(description="iOS App", boolean=True)
    def app_connected_display(self, obj):
        return obj.is_app_connected


@admin.register(DoctorAvailabilitySlot)
class DoctorAvailabilitySlotAdmin(admin.ModelAdmin):
    list_display = ("doctor", "label", "starts_at", "ends_at", "is_booked", "source")
    list_filter = ("is_booked", "source", "starts_at")
    search_fields = ("doctor__user__first_name", "doctor__user__last_name", "label")
    autocomplete_fields = ("doctor",)


@admin.register(Patient)
class PatientAdmin(admin.ModelAdmin):
    list_display = (
        "full_name",
        "national_id",
        "email",
        "primary_hospital",
        "primary_doctor",
        "age_display",
        "blood_type",
        "insurance_type",
        "is_verified",
        "share_data_with_doctors",
        "created_at",
    )
    search_fields = ("national_id", "first_name", "last_name", "phone", "email")
    list_filter = ("blood_type", "insurance_type", "is_verified", "share_data_with_doctors")
    readonly_fields = ("id", "full_name", "age_display", "created_at", "updated_at", "bmi_display")
    autocomplete_fields = ("user", "primary_hospital", "primary_doctor")
    fieldsets = (
        ("Identity", {"fields": ("id", "user", "national_id", "first_name", "last_name", "email", "date_of_birth", "age_display", "sex", "profession", "is_verified")}),
        ("Care Assignment", {"fields": ("primary_hospital", "primary_doctor")}),
        ("Health", {"fields": ("blood_type", "weight_kg", "height_cm", "bmi_display", "insurance_type", "insurance_number")}),
        ("Contact", {"fields": ("phone", "address", "emergency_contact_name", "emergency_contact_phone")}),
        ("Mobile Settings", {"fields": ("auth_method", "share_data_with_doctors", "allow_analytics", "two_factor_enabled", "biometric_login", "location_enabled", "ios_device_token", "app_last_seen")}),
        ("Meta", {"fields": ("created_at", "updated_at")}),
    )

    @admin.display(description="Age")
    def age_display(self, obj):
        return f"{obj.age} yrs"

    @admin.display(description="BMI")
    def bmi_display(self, obj):
        return obj.bmi if obj.bmi is not None else "—"


@admin.register(Vitals)
class VitalsAdmin(admin.ModelAdmin):
    list_display = (
        "patient",
        "heart_rate",
        "spo2",
        "temperature",
        "triage_badge",
        "source",
        "recorded_at",
    )
    list_filter = ("triage_level", "source", "recorded_at")
    search_fields = ("patient__first_name", "patient__last_name", "patient__national_id")
    readonly_fields = ("id", "bmi", "recorded_at")
    date_hierarchy = "recorded_at"

    @admin.display(description="Triage")
    def triage_badge(self, obj):
        colors = {"URGENT": "#ef4444", "MODERE": "#f59e0b", "NORMAL": "#10b981"}
        color = colors.get(obj.triage_level, "#64748b")
        return format_html(
            '<span style="background:{};color:white;padding:2px 8px;border-radius:999px;font-size:11px;font-weight:bold;">{}</span>',
            color,
            obj.triage_level,
        )


class PrescriptionInline(admin.TabularInline):
    model = Prescription
    extra = 0
    fields = ("medication_name", "dosage", "duration_days", "notified_patient")
    readonly_fields = ("notified_patient",)


class LabRequestInline(admin.TabularInline):
    model = LabRequest
    extra = 0
    fields = ("test_name", "status", "doctor_notified", "requested_at")
    readonly_fields = ("requested_at", "doctor_notified")


@admin.register(Appointment)
class AppointmentAdmin(admin.ModelAdmin):
    list_display = (
        "reference_code",
        "patient",
        "doctor",
        "hospital",
        "date",
        "time",
        "status_badge",
        "source",
        "created_at",
    )
    list_filter = ("status", "source", "date", "hospital")
    search_fields = (
        "reference_code",
        "patient__national_id",
        "patient__last_name",
        "doctor__user__last_name",
        "hospital__name",
    )
    date_hierarchy = "date"
    readonly_fields = ("id", "reference_code", "created_at", "updated_at")
    autocomplete_fields = ("hospital", "doctor", "patient", "slot")
    inlines = [PrescriptionInline, LabRequestInline]

    @admin.display(description="Status")
    def status_badge(self, obj):
        colors = {
            "UPCOMING": "#3b82f6",
            "IN_PROGRESS": "#f59e0b",
            "COMPLETED": "#10b981",
            "CANCELLED": "#ef4444",
            "NO_SHOW": "#64748b",
        }
        color = colors.get(obj.status, "#64748b")
        return format_html(
            '<span style="background:{};color:white;padding:2px 8px;border-radius:999px;font-size:11px;font-weight:bold;">{}</span>',
            color,
            obj.get_status_display(),
        )


@admin.register(Prescription)
class PrescriptionAdmin(admin.ModelAdmin):
    list_display = ("medication_name", "dosage", "duration_days", "appointment", "notified_patient", "created_at")
    list_filter = ("notified_patient", "created_at")
    search_fields = ("medication_name", "appointment__patient__last_name")
    readonly_fields = ("id", "created_at", "notified_patient")


@admin.register(LabRequest)
class LabRequestAdmin(admin.ModelAdmin):
    list_display = ("test_name", "appointment", "status", "doctor_notified", "requested_at", "results_at")
    list_filter = ("status", "doctor_notified", "requested_at")
    search_fields = ("test_name", "appointment__patient__last_name")
    readonly_fields = ("id", "requested_at", "doctor_notified")


@admin.register(PatientLabResult)
class PatientLabResultAdmin(admin.ModelAdmin):
    list_display = ("test_name", "patient", "date", "result", "is_abnormal")
    list_filter = ("is_abnormal", "date")
    search_fields = ("test_name", "patient__first_name", "patient__last_name")
    autocomplete_fields = ("patient", "appointment", "lab_request")


@admin.register(MedicalHistoryEntry)
class MedicalHistoryEntryAdmin(admin.ModelAdmin):
    list_display = ("condition", "patient", "status", "doctor", "diagnosed_date")
    list_filter = ("status", "diagnosed_date")
    search_fields = ("condition", "patient__first_name", "patient__last_name")
    autocomplete_fields = ("patient", "doctor")


@admin.register(MedicationPlan)
class MedicationPlanAdmin(admin.ModelAdmin):
    list_display = ("name", "patient", "dosage", "frequency", "remaining", "total", "is_active")
    list_filter = ("is_active",)
    search_fields = ("name", "patient__first_name", "patient__last_name")
    autocomplete_fields = ("patient", "prescription")


@admin.register(PatientNotificationPreference)
class PatientNotificationPreferenceAdmin(admin.ModelAdmin):
    list_display = ("patient", "title", "enabled")
    list_filter = ("enabled",)
    search_fields = ("patient__first_name", "patient__last_name", "title")
    autocomplete_fields = ("patient",)


@admin.register(SymptomAssessment)
class SymptomAssessmentAdmin(admin.ModelAdmin):
    list_display = ("patient", "triage_level", "pain_level", "created_at")
    list_filter = ("triage_level", "created_at")
    search_fields = ("patient__first_name", "patient__last_name")
    autocomplete_fields = ("patient", "recommended_facility", "recommended_doctor")


@admin.register(PreAdmission)
class PreAdmissionAdmin(admin.ModelAdmin):
    list_display = ("full_name", "hospital", "status", "is_routine", "is_ill", "submitted_at")
    list_filter = ("status", "hospital", "is_routine", "is_ill")
    search_fields = ("full_name", "phone", "email")
    autocomplete_fields = ("patient", "submitted_by", "hospital")


@admin.register(IOSNotification)
class IOSNotificationAdmin(admin.ModelAdmin):
    list_display = ("title", "notif_type", "recipient_patient", "recipient_staff", "delivered", "read", "sent_at")
    list_filter = ("notif_type", "delivered", "read", "sent_at")
    search_fields = ("title", "recipient_patient__last_name", "recipient_staff__user__last_name")
    readonly_fields = ("id", "sent_at", "read_at")


@admin.register(AuditLog)
class AuditLogAdmin(admin.ModelAdmin):
    list_display = ("timestamp", "log_type_badge", "action", "actor", "hospital", "ip_address")
    list_filter = ("log_type", "action", "hospital", "timestamp")
    search_fields = ("description", "actor__first_name", "actor__last_name")
    date_hierarchy = "timestamp"
    readonly_fields = tuple(field.name for field in AuditLog._meta.get_fields())

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    @admin.display(description="Type")
    def log_type_badge(self, obj):
        colors = {"INFO": "#0d9488", "WARNING": "#f59e0b", "ERROR": "#ef4444", "SECURITY": "#8b5cf6"}
        color = colors.get(obj.log_type, "#64748b")
        return format_html(
            '<span style="background:{};color:white;padding:2px 8px;border-radius:999px;font-size:11px;font-weight:bold;">{}</span>',
            color,
            obj.log_type,
        )

from django.urls import include, path
from django.views.generic import TemplateView
from rest_framework.routers import DefaultRouter

from .views import (
    AuditLogViewSet,
    DashboardView,
    DoctorAppointmentViewSet,
    DoctorDirectoryViewSet,
    HospitalViewSet,
    IOSSyncWebhookView,
    LabRequestViewSet,
    MedicalFacilityViewSet,
    MedicalHistoryViewSet,
    MedicationPlanViewSet,
    MobileBootstrapView,
    PatientAppointmentViewSet,
    PatientDashboardView,
    PatientDeviceRegistrationView,
    PatientLabResultViewSet,
    PatientLoginView,
    PatientLogoutView,
    PatientNotificationPreferenceViewSet,
    PatientNotificationViewSet,
    PatientProfileView,
    PatientRegisterView,
    PatientViewSet,
    PreAdmissionViewSet,
    PrescriptionViewSet,
    PortalBootstrapView,
    StaffViewSet,
    SupabaseSessionAuthView,
    SymptomAssessmentViewSet,
    SymptomAssessmentAdminViewSet,
    SystemUserViewSet,
    VitalsViewSet,
)

router = DefaultRouter()

router.register(r"hospitals", HospitalViewSet, basename="hospital")
router.register(r"facilities", MedicalFacilityViewSet, basename="facility")
router.register(r"staff", StaffViewSet, basename="staff")
router.register(r"patients", PatientViewSet, basename="patient")
router.register(r"vitals", VitalsViewSet, basename="vitals")
router.register(r"my-appointments", PatientAppointmentViewSet, basename="patient-appointment")
router.register(r"appointments", DoctorAppointmentViewSet, basename="appointment")
router.register(r"prescriptions", PrescriptionViewSet, basename="prescription")
router.register(r"lab-requests", LabRequestViewSet, basename="lab-request")
router.register(r"notifications", PatientNotificationViewSet, basename="notification")
router.register(r"audit-logs", AuditLogViewSet, basename="audit-log")
router.register(r"system/users", SystemUserViewSet, basename="system-user")

# Mobile-facing resources
router.register(r"mobile/doctors", DoctorDirectoryViewSet, basename="mobile-doctor")
router.register(r"mobile/lab-results", PatientLabResultViewSet, basename="mobile-lab-result")
router.register(r"mobile/medical-history", MedicalHistoryViewSet, basename="mobile-medical-history")
router.register(r"mobile/medications", MedicationPlanViewSet, basename="mobile-medication")
router.register(
    r"mobile/notification-preferences",
    PatientNotificationPreferenceViewSet,
    basename="mobile-notification-preference",
)
router.register(
    r"mobile/symptom-assessments",
    SymptomAssessmentViewSet,
    basename="mobile-symptom-assessment",
)
router.register(
    r"mobile/symptom-assessments-admin",
    SymptomAssessmentAdminViewSet,
    basename="mobile-symptom-assessment-admin",
)
router.register(r"mobile/pre-admissions", PreAdmissionViewSet, basename="mobile-pre-admission")

urlpatterns = [
    path("", TemplateView.as_view(template_name="index.html"), name="home"),
    path("api/v1/", include(router.urls)),
    path("api/v1/dashboard/", DashboardView.as_view(), name="dashboard"),
    path("api/v1/portal/bootstrap/", PortalBootstrapView.as_view(), name="portal-bootstrap"),
    path("api/v1/sync/ios/", IOSSyncWebhookView.as_view(), name="ios-sync"),

    # Mobile auth + profile
    path("api/v1/mobile/auth/register/", PatientRegisterView.as_view(), name="mobile-register"),
    path("api/v1/mobile/auth/login/", PatientLoginView.as_view(), name="mobile-login"),
    path("api/v1/mobile/auth/supabase/", SupabaseSessionAuthView.as_view(), name="mobile-supabase-login"),
    path("api/v1/mobile/auth/logout/", PatientLogoutView.as_view(), name="mobile-logout"),
    path("api/v1/mobile/profile/", PatientProfileView.as_view(), name="mobile-profile"),
    path(
        "api/v1/mobile/profile/device/",
        PatientDeviceRegistrationView.as_view(),
        name="mobile-device-registration",
    ),
    path("api/v1/mobile/bootstrap/", MobileBootstrapView.as_view(), name="mobile-bootstrap"),
    path("api/v1/mobile/dashboard/", PatientDashboardView.as_view(), name="mobile-dashboard"),
]

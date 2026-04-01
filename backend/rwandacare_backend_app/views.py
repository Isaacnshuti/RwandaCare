import hashlib
import json
import os
from datetime import date, timedelta
from urllib import error as urllib_error
from urllib import request as urllib_request

from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.models import User
from django.db.models import Q
from django.utils import timezone
from django.utils.timezone import localdate, now
from rest_framework import generics, permissions, status, viewsets
from rest_framework.authentication import BasicAuthentication
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response
from rest_framework.views import APIView

from .authentication import CsrfExemptSessionAuthentication
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
from .permissions import (
    IsDoctor,
    IsHospitalAdmin,
    IsMedicalStaff,
    IsPatientUser,
    IsSuperAdmin,
)
from .serializers import (
    AppointmentCreateSerializer,
    AppointmentDetailSerializer,
    AppointmentListSerializer,
    AppointmentUpdateSerializer,
    AuditLogSerializer,
    DashboardSummarySerializer,
    DoctorDirectorySerializer,
    HospitalDetailSerializer,
    HospitalListSerializer,
    IOSNotificationSerializer,
    LabRequestSerializer,
    MedicalFacilitySerializer,
    MedicalHistoryEntrySerializer,
    MedicationPlanSerializer,
    NotificationPreferenceSerializer,
    PatientCreateSerializer,
    PatientDetailSerializer,
    PatientLabResultSerializer,
    PatientListSerializer,
    PatientLoginSerializer,
    PatientProfileSerializer,
    PatientRegisterSerializer,
    PreAdmissionSerializer,
    PrescriptionSerializer,
    StaffCreateSerializer,
    StaffListSerializer,
    StaffUpdateSerializer,
    SupabaseSessionAuthSerializer,
    SymptomAssessmentSerializer,
    VitalsSerializer,
)
from .utils import (
    ensure_patient_notification_preferences,
    log_action,
    send_ios_push,
)


class AuditMixin:
    def perform_create(self, serializer):
        instance = serializer.save()
        log_action(self.request, "CREATE", str(instance))

    def perform_update(self, serializer):
        instance = serializer.save()
        log_action(self.request, "UPDATE", str(instance))

    def perform_destroy(self, instance):
        log_action(self.request, "DELETE", str(instance))
        instance.delete()


def _patient_from_request(request):
    return getattr(request.user, "patient_profile", None)


def _staff_from_request(request):
    return getattr(request.user, "staff_profile", None)


def _mark_slot_booked(slot, is_booked):
    if slot:
        slot.is_booked = is_booked
        slot.save(update_fields=["is_booked"])


def _portal_role(staff):
    if staff.role == "SUPERADMIN":
        return "super_admin"
    if staff.role == "ADMIN":
        return "hospital_admin"
    return "doctor"


def _portal_appt_status(value):
    mapping = {
        "UPCOMING": "Confirmed",
        "IN_PROGRESS": "Checked in",
        "COMPLETED": "Completed",
        "CANCELLED": "Cancelled",
        "NO_SHOW": "Cancelled",
    }
    return mapping.get(value, "Confirmed")


def _portal_patient_status(value):
    mapping = {
        "UPCOMING": "Waiting",
        "IN_PROGRESS": "In consultation",
        "COMPLETED": "Completed",
        "CANCELLED": "Cancelled",
        "NO_SHOW": "Cancelled",
    }
    return mapping.get(value, "Waiting")


def _portal_triage(vitals):
    if not vitals:
        return "Routine"
    mapping = {
        "URGENT": "Urgent",
        "MODERE": "Moderate",
        "NORMAL": "Routine",
    }
    return mapping.get(vitals.triage_level, "Routine")


def _portal_insurance(patient):
    mapping = {
        "RSSB": "RSSB",
        "MUTUELLE": "MUTUELLE",
        "PRIVATE": "PRIVATE",
        "NONE": "NONE",
    }
    return mapping.get(patient.insurance_type, "RSSB")


def _supabase_project_url():
    return os.getenv(
        "SUPABASE_URL",
        "https://kbsqbxhfewvguwtchwzp.supabase.co",
    ).rstrip("/")


def _supabase_publishable_key():
    return os.getenv(
        "SUPABASE_PUBLISHABLE_KEY",
        "sb_publishable_Ch-HXaqwI8oBcMXxZmAgJQ_Mh7TDRwX",
    )


def _fetch_supabase_user(access_token):
    endpoint = f"{_supabase_project_url()}/auth/v1/user"
    req = urllib_request.Request(
        endpoint,
        headers={
            "apikey": _supabase_publishable_key(),
            "Authorization": f"Bearer {access_token}",
        },
    )
    try:
        with urllib_request.urlopen(req, timeout=10) as response:
            payload = response.read().decode("utf-8")
    except urllib_error.HTTPError as exc:
        exc.read().decode("utf-8", errors="ignore")
        raise PermissionDenied("The Supabase session is invalid or expired.") from exc
    except urllib_error.URLError as exc:
        raise PermissionDenied(
            "Supabase could not be reached while validating this session."
        ) from exc

    try:
        return json.loads(payload)
    except json.JSONDecodeError as exc:
        raise PermissionDenied("Supabase returned an invalid user payload.") from exc


def _generated_national_id(seed_value):
    digest = hashlib.sha256(seed_value.encode("utf-8")).hexdigest()
    candidate = str(int(digest, 16) % (10**16)).zfill(16)
    while Patient.objects.filter(national_id=candidate).exists():
        candidate = str((int(candidate) + 1) % (10**16)).zfill(16)
    return candidate


def _mobile_appt_status(value):
    mapping = {
        "UPCOMING": "Upcoming",
        "IN_PROGRESS": "Upcoming",
        "COMPLETED": "Completed",
        "CANCELLED": "Cancelled",
        "NO_SHOW": "Cancelled",
    }
    return mapping.get(value, "Upcoming")


def _mobile_date_label(value):
    if not value:
        return ""
    return value.strftime("%b %d, %Y")


def _mobile_time_label(value):
    if not value:
        return ""
    return value.strftime("%I:%M %p").lstrip("0")


class HospitalViewSet(viewsets.ModelViewSet):
    queryset = Hospital.objects.filter(is_active=True).prefetch_related("staff")

    def get_serializer_class(self):
        if self.action in ("retrieve", "create", "update", "partial_update"):
            return HospitalDetailSerializer
        return HospitalListSerializer

    def get_permissions(self):
        if self.action in ("list", "retrieve"):
            return [IsMedicalStaff()]
        if self.action in ("create", "destroy"):
            return [IsSuperAdmin()]
        return [IsHospitalAdmin()]

    def get_queryset(self):
        qs = super().get_queryset().order_by("name")
        staff = _staff_from_request(self.request)
        if staff and staff.role != "SUPERADMIN" and staff.hospital_id:
            qs = qs.filter(id=staff.hospital_id)
        return qs

    @action(detail=True, methods=["post"], permission_classes=[IsHospitalAdmin])
    def toggle_sync(self, request, pk=None):
        hospital = self.get_object()
        hospital.rwandacare_sync_enabled = not hospital.rwandacare_sync_enabled
        hospital.save(update_fields=["rwandacare_sync_enabled"])
        log_action(request, "UPDATE", f"Sync toggled for {hospital.name}")
        return Response({"rwandacare_sync_enabled": hospital.rwandacare_sync_enabled})


class MedicalFacilityViewSet(AuditMixin, viewsets.ModelViewSet):
    queryset = MedicalFacility.objects.filter(is_active=True)

    def get_permissions(self):
        if self.action in ("list", "retrieve"):
            return [permissions.AllowAny()]
        return [IsHospitalAdmin()]

    serializer_class = MedicalFacilitySerializer

    def get_queryset(self):
        qs = super().get_queryset().select_related("hospital")
        staff = _staff_from_request(self.request)
        if self.action not in ("list", "retrieve") and staff and staff.role != "SUPERADMIN":
            if not staff.hospital_id:
                return qs.none()
            qs = qs.filter(hospital=staff.hospital)

        facility_type = self.request.query_params.get("type")
        district = self.request.query_params.get("district")
        q = self.request.query_params.get("q")
        open_24h = self.request.query_params.get("open_24h")

        if facility_type:
            qs = qs.filter(facility_type=facility_type.upper())
        if district:
            qs = qs.filter(district__icontains=district)
        if q:
            qs = qs.filter(
                Q(name__icontains=q)
                | Q(address__icontains=q)
                | Q(district__icontains=q)
            )
        if open_24h in ("1", "true", "True"):
            qs = qs.filter(is_open_24h=True)
        return qs.order_by("distance_km", "name")

    def perform_create(self, serializer):
        staff = _staff_from_request(self.request)
        if staff and staff.role != "SUPERADMIN":
            if not staff.hospital_id:
                raise PermissionDenied("Hospital admin account is not linked to a hospital.")
            target_hospital = serializer.validated_data.get("hospital")
            if target_hospital and target_hospital.id != staff.hospital_id:
                raise PermissionDenied("You can only create facilities for your own hospital.")
            serializer.save(hospital=target_hospital or staff.hospital)
            return
        serializer.save()

    def perform_update(self, serializer):
        staff = _staff_from_request(self.request)
        if staff and staff.role != "SUPERADMIN":
            target_hospital = serializer.validated_data.get("hospital", serializer.instance.hospital)
            if not target_hospital or target_hospital.id != staff.hospital_id:
                raise PermissionDenied("You can only manage facilities for your own hospital.")
        serializer.save()


class StaffViewSet(AuditMixin, viewsets.ModelViewSet):
    queryset = StaffProfile.objects.select_related("user", "hospital").all()

    def get_serializer_class(self):
        if self.action == "create":
            return StaffCreateSerializer
        if self.action in ("update", "partial_update"):
            return StaffUpdateSerializer
        return StaffListSerializer

    def get_permissions(self):
        if self.action in ("list", "retrieve"):
            return [IsMedicalStaff()]
        if self.action == "destroy":
            return [IsSuperAdmin()]
        return [IsHospitalAdmin()]

    def get_queryset(self):
        qs = super().get_queryset()
        viewer = _staff_from_request(self.request)
        if viewer and viewer.role != "SUPERADMIN" and viewer.hospital_id:
            qs = qs.filter(hospital=viewer.hospital)

        role = self.request.query_params.get("role")
        hospital_id = self.request.query_params.get("hospital")
        specialty = self.request.query_params.get("specialty")
        if role:
            qs = qs.filter(role=role)
        if hospital_id:
            qs = qs.filter(hospital_id=hospital_id)
        if specialty:
            qs = qs.filter(specialty__icontains=specialty)
        return qs

    def perform_create(self, serializer):
        requester = _staff_from_request(self.request)
        role = serializer.validated_data.get("role")
        hospital = serializer.validated_data.get("hospital")

        if requester and requester.role != "SUPERADMIN":
            if role == "SUPERADMIN":
                raise PermissionDenied("Only super admins can create super admin accounts.")
            if not requester.hospital_id:
                raise PermissionDenied("Hospital admin account is not linked to a hospital.")
            serializer.save(hospital=requester.hospital)
            return

        if requester and requester.role == "SUPERADMIN" and role != "SUPERADMIN" and hospital is None:
            raise PermissionDenied("Hospital must be provided for non-super-admin accounts.")
        serializer.save()

    def perform_update(self, serializer):
        requester = _staff_from_request(self.request)
        target = self.get_object()
        role = serializer.validated_data.get("role", target.role)
        hospital = serializer.validated_data.get("hospital", target.hospital)

        if requester and requester.role != "SUPERADMIN":
            if target.role == "SUPERADMIN" or role == "SUPERADMIN":
                raise PermissionDenied("Only super admins can manage super admin accounts.")
            if not requester.hospital_id:
                raise PermissionDenied("Hospital admin account is not linked to a hospital.")
            if hospital and hospital.id != requester.hospital_id:
                raise PermissionDenied("You can only manage staff in your own hospital.")
            serializer.save(hospital=requester.hospital)
            return

        if requester and requester.role == "SUPERADMIN" and role != "SUPERADMIN" and hospital is None:
            raise PermissionDenied("Hospital must be provided for non-super-admin accounts.")
        serializer.save()

    @action(detail=True, methods=["post"], permission_classes=[IsHospitalAdmin])
    def toggle_availability(self, request, pk=None):
        staff = self.get_object()
        staff.is_available = not staff.is_available
        staff.save(update_fields=["is_available"])
        log_action(request, "UPDATE", f"Availability toggled for {staff}")
        return Response({"is_available": staff.is_available})

    @action(detail=True, methods=["post"], permission_classes=[permissions.IsAuthenticated])
    def register_device(self, request, pk=None):
        staff = self.get_object()
        if staff.user != request.user:
            return Response({"detail": "Forbidden"}, status=status.HTTP_403_FORBIDDEN)
        token = request.data.get("device_token")
        if not token:
            return Response({"detail": "device_token required"}, status=400)
        staff.ios_device_token = token
        staff.app_last_seen = now()
        staff.save(update_fields=["ios_device_token", "app_last_seen"])
        return Response({"detail": "Device token registered."})


class DoctorDirectoryViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = DoctorDirectorySerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        qs = (
            StaffProfile.objects.select_related("user", "hospital")
            .prefetch_related("availability_slots")
            .filter(role="DOCTOR")
        )
        specialty = self.request.query_params.get("specialty")
        hospital_id = self.request.query_params.get("hospital")
        q = self.request.query_params.get("q")
        available = self.request.query_params.get("available")
        if specialty:
            qs = qs.filter(specialty__icontains=specialty)
        if hospital_id:
            qs = qs.filter(hospital_id=hospital_id)
        if q:
            qs = qs.filter(
                Q(user__first_name__icontains=q)
                | Q(user__last_name__icontains=q)
                | Q(specialty__icontains=q)
            )
        if available in ("1", "true", "True"):
            qs = qs.filter(is_available=True)
        return qs.order_by("user__last_name", "user__first_name")


class PatientViewSet(AuditMixin, viewsets.ModelViewSet):
    def get_serializer_class(self):
        if self.action == "create":
            return PatientCreateSerializer
        if self.action in ("retrieve", "update", "partial_update"):
            return PatientDetailSerializer
        return PatientListSerializer

    def get_permissions(self):
        if self.action == "destroy":
            return [IsHospitalAdmin()]
        if self.action in ("update", "partial_update", "create"):
            return [IsDoctor()]
        return [IsMedicalStaff()]

    def get_queryset(self):
        qs = (
            Patient.objects.select_related("primary_hospital", "primary_doctor__user")
            .all()
            .prefetch_related("vitals", "appointments__doctor__user")
        )
        role = _staff_from_request(self.request)
        if role and role.role != "SUPERADMIN" and role.hospital_id:
            qs = qs.filter(
                Q(primary_hospital=role.hospital) | Q(appointments__hospital=role.hospital)
            ).distinct()
        q = self.request.query_params.get("q")
        if q:
            qs = qs.filter(
                Q(national_id__icontains=q)
                | Q(first_name__icontains=q)
                | Q(last_name__icontains=q)
                | Q(phone__icontains=q)
            )
        return qs.distinct()

    def perform_create(self, serializer):
        staff = _staff_from_request(self.request)
        save_kwargs = {}
        if (
            staff
            and staff.role != "SUPERADMIN"
            and staff.hospital_id
            and not serializer.validated_data.get("primary_hospital")
        ):
            save_kwargs["primary_hospital"] = staff.hospital
        if (
            staff
            and staff.role == "DOCTOR"
            and not serializer.validated_data.get("primary_doctor")
        ):
            save_kwargs["primary_doctor"] = staff

        patient = serializer.save(**save_kwargs)
        log_action(self.request, "CREATE", f"Patient created: {patient.full_name}")


class PatientProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = PatientProfileSerializer
    permission_classes = [IsPatientUser]
    authentication_classes = [CsrfExemptSessionAuthentication, BasicAuthentication]

    def get_object(self):
        patient = self.request.user.patient_profile
        ensure_patient_notification_preferences(patient)
        return patient

    def perform_update(self, serializer):
        patient = serializer.save()
        log_action(self.request, "UPDATE", f"Patient profile updated: {patient.full_name}")


class PatientDeviceRegistrationView(APIView):
    permission_classes = [IsPatientUser]
    authentication_classes = [CsrfExemptSessionAuthentication, BasicAuthentication]

    def post(self, request):
        token = request.data.get("device_token")
        if not token:
            return Response({"detail": "device_token required"}, status=400)
        patient = request.user.patient_profile
        patient.ios_device_token = token
        patient.app_last_seen = now()
        patient.save(update_fields=["ios_device_token", "app_last_seen"])
        return Response({"detail": "Device token registered."})


class PatientRegisterView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = PatientRegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        patient = serializer.save()
        ensure_patient_notification_preferences(patient)
        patient.is_verified = True
        patient.save(update_fields=["is_verified"])
        patient.user.backend = "django.contrib.auth.backends.ModelBackend"
        login(request, patient.user)
        log_action(request, "CREATE", f"Patient account created: {patient.full_name}")
        return Response(
            {"patient": PatientProfileSerializer(patient).data},
            status=status.HTTP_201_CREATED,
        )


class SupabaseSessionAuthView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = SupabaseSessionAuthSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        supabase_user = _fetch_supabase_user(serializer.validated_data["access_token"])
        email = (supabase_user.get("email") or "").strip().lower()
        if not email:
            return Response(
                {"detail": "This Supabase account did not return an email address."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        app_metadata = supabase_user.get("app_metadata") or {}
        user_metadata = supabase_user.get("user_metadata") or {}
        auth_method = (
            serializer.validated_data.get("auth_method")
            or app_metadata.get("provider")
            or "google"
        )
        first_name = (
            serializer.validated_data.get("first_name")
            or user_metadata.get("first_name")
            or user_metadata.get("given_name")
            or "RwandaCare"
        ).strip()
        last_name = (
            serializer.validated_data.get("last_name")
            or user_metadata.get("last_name")
            or user_metadata.get("family_name")
            or "User"
        ).strip()
        phone = serializer.validated_data.get("phone", "").strip()
        national_id = serializer.validated_data.get("national_id", "").strip()
        date_of_birth = serializer.validated_data.get("date_of_birth") or date(2000, 1, 1)
        blood_type = serializer.validated_data.get("blood_type") or "O+"

        user = User.objects.filter(email__iexact=email).first()
        if not user:
            user = User.objects.create_user(
                username=email,
                email=email,
                first_name=first_name,
                last_name=last_name,
            )
            user.set_unusable_password()
            user.save(update_fields=["password"])
        else:
            updated_fields = []
            if first_name and user.first_name != first_name:
                user.first_name = first_name
                updated_fields.append("first_name")
            if last_name and user.last_name != last_name:
                user.last_name = last_name
                updated_fields.append("last_name")
            if user.username != email:
                user.username = email
                updated_fields.append("username")
            if user.email != email:
                user.email = email
                updated_fields.append("email")
            if updated_fields:
                user.save(update_fields=updated_fields)

        patient = getattr(user, "patient_profile", None)
        if patient is None:
            patient = Patient.objects.filter(email__iexact=email).select_related("user").first()

        created = False
        if patient is None:
            created = True
            patient = Patient.objects.create(
                user=user,
                first_name=first_name or "RwandaCare",
                last_name=last_name or "User",
                email=email,
                phone=phone,
                national_id=national_id or _generated_national_id(supabase_user.get("id") or email),
                date_of_birth=date_of_birth,
                blood_type=blood_type,
                auth_method=auth_method,
                is_verified=False,
                app_last_seen=now(),
            )
        else:
            updated_fields = []
            if patient.user_id != user.id:
                patient.user = user
                updated_fields.append("user")
            if first_name and patient.first_name != first_name:
                patient.first_name = first_name
                updated_fields.append("first_name")
            if last_name and patient.last_name != last_name:
                patient.last_name = last_name
                updated_fields.append("last_name")
            if patient.email != email:
                patient.email = email
                updated_fields.append("email")
            if phone and patient.phone != phone:
                patient.phone = phone
                updated_fields.append("phone")
            if national_id and patient.national_id != national_id:
                duplicate = Patient.objects.filter(national_id=national_id).exclude(pk=patient.pk).exists()
                if duplicate:
                    return Response(
                        {"detail": "That National ID is already linked to another patient."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )
                patient.national_id = national_id
                updated_fields.append("national_id")
            if serializer.validated_data.get("date_of_birth") and patient.date_of_birth != date_of_birth:
                patient.date_of_birth = date_of_birth
                updated_fields.append("date_of_birth")
            if serializer.validated_data.get("blood_type") and patient.blood_type != blood_type:
                patient.blood_type = blood_type
                updated_fields.append("blood_type")
            if patient.auth_method != auth_method:
                patient.auth_method = auth_method
                updated_fields.append("auth_method")
            patient.app_last_seen = now()
            updated_fields.append("app_last_seen")
            if updated_fields:
                patient.save(update_fields=updated_fields)

        ensure_patient_notification_preferences(patient)
        user.backend = "django.contrib.auth.backends.ModelBackend"
        login(request, user)
        log_action(
            request,
            "LOGIN" if not created else "CREATE",
            f"Supabase session linked for {patient.full_name}",
        )
        return Response({"patient": PatientProfileSerializer(patient).data})


class PatientLoginView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = PatientLoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        email = serializer.validated_data["email"].lower()
        password = serializer.validated_data["password"]
        user = authenticate(request, username=email, password=password)

        if user is None:
            fallback_user = User.objects.filter(email__iexact=email).first()
            if fallback_user and fallback_user.check_password(password):
                user = fallback_user

        if user is None or not hasattr(user, "patient_profile") or not user.is_active:
            log_action(request, "LOGIN_FAILED", f"Failed mobile login for {email}")
            return Response(
                {"detail": "Invalid patient credentials."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user.backend = "django.contrib.auth.backends.ModelBackend"
        login(request, user)

        patient = user.patient_profile
        ensure_patient_notification_preferences(patient)
        patient.auth_method = serializer.validated_data.get("auth_method", patient.auth_method or "email")
        device_token = serializer.validated_data.get("device_token")
        if device_token:
            patient.ios_device_token = device_token
        patient.app_last_seen = now()
        if not patient.email:
            patient.email = user.email
        patient.save(update_fields=["auth_method", "ios_device_token", "app_last_seen", "email"])

        log_action(request, "LOGIN", f"Patient logged in: {patient.full_name}")
        return Response({"patient": PatientProfileSerializer(patient).data})


class PatientLogoutView(APIView):
    permission_classes = [IsPatientUser]
    authentication_classes = [CsrfExemptSessionAuthentication, BasicAuthentication]

    def post(self, request):
        patient = request.user.patient_profile
        log_action(request, "LOGOUT", f"Patient logged out: {patient.full_name}")
        logout(request)
        return Response({"detail": "Logged out."})


class VitalsViewSet(viewsets.ModelViewSet):
    serializer_class = VitalsSerializer
    permission_classes = [permissions.IsAuthenticated]
    authentication_classes = [CsrfExemptSessionAuthentication, BasicAuthentication]

    def get_queryset(self):
        qs = Vitals.objects.select_related("patient").all()
        patient_id = self.request.query_params.get("patient")
        if patient_id:
            qs = qs.filter(patient_id=patient_id)

        patient = _patient_from_request(self.request)
        staff = _staff_from_request(self.request)
        if patient:
            qs = qs.filter(patient=patient)
        elif staff and staff.role != "SUPERADMIN" and staff.hospital_id:
            qs = qs.filter(patient__appointments__hospital=staff.hospital).distinct()
        elif not staff:
            qs = qs.none()
        return qs

    def perform_create(self, serializer):
        target_patient = serializer.validated_data["patient"]
        patient_user = _patient_from_request(self.request)
        staff = _staff_from_request(self.request)

        if patient_user:
            if target_patient.id != patient_user.id:
                raise PermissionDenied("Patients can only submit their own vitals.")
        elif staff:
            if staff.role != "SUPERADMIN":
                if not staff.hospital_id:
                    raise PermissionDenied("Staff account is not linked to a hospital.")
                allowed = (
                    target_patient.primary_hospital_id == staff.hospital_id
                    or target_patient.appointments.filter(hospital=staff.hospital).exists()
                )
                if not allowed:
                    raise PermissionDenied("You can only record vitals for patients in your hospital scope.")
        else:
            raise PermissionDenied("Only authenticated patient or staff accounts can record vitals.")

        vitals = serializer.save()
        patient = vitals.patient
        update_fields = []
        if vitals.weight_kg is not None:
            patient.weight_kg = vitals.weight_kg
            update_fields.append("weight_kg")
        if vitals.height_cm is not None:
            patient.height_cm = vitals.height_cm
            update_fields.append("height_cm")
        if update_fields:
            patient.save(update_fields=update_fields)

        if vitals.triage_level == "URGENT":
            appointments = (
                vitals.patient.appointments.filter(
                    date=localdate(),
                    status__in=["UPCOMING", "IN_PROGRESS"],
                )
                .select_related("doctor")
            )
            for appt in appointments:
                send_ios_push(
                    staff=appt.doctor,
                    title="Urgent vitals alert",
                    body=(
                        f"{vitals.patient.full_name} | "
                        f"SpO2: {vitals.spo2}% | HR: {vitals.heart_rate} bpm | "
                        f"Temp: {vitals.temperature}C"
                    ),
                    notif_type="VITALS_ALERT",
                    data={"patient_id": str(vitals.patient.id)},
                )


class PatientAppointmentViewSet(viewsets.ModelViewSet):
    permission_classes = [IsPatientUser]
    authentication_classes = [CsrfExemptSessionAuthentication, BasicAuthentication]

    def get_serializer_class(self):
        if self.action == "create":
            return AppointmentCreateSerializer
        if self.action in ("update", "partial_update"):
            return AppointmentUpdateSerializer
        if self.action == "retrieve":
            return AppointmentDetailSerializer
        return AppointmentListSerializer

    def get_queryset(self):
        patient = self.request.user.patient_profile
        return (
            Appointment.objects.filter(patient=patient)
            .select_related("hospital", "doctor__user", "slot")
            .order_by("-date", "-time")
        )

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        instance = Appointment.objects.select_related("hospital", "doctor__user", "slot").get(
            pk=serializer.instance.pk
        )
        headers = self.get_success_headers(serializer.data)
        return Response(
            AppointmentDetailSerializer(instance).data,
            status=status.HTTP_201_CREATED,
            headers=headers,
        )

    def perform_create(self, serializer):
        appt = serializer.save(
            patient=self.request.user.patient_profile,
            source="IOS_APP",
        )
        patient_updates = []
        if appt.hospital_id and appt.patient.primary_hospital_id != appt.hospital_id:
            appt.patient.primary_hospital = appt.hospital
            patient_updates.append("primary_hospital")
        if appt.doctor_id and appt.patient.primary_doctor_id != appt.doctor_id:
            appt.patient.primary_doctor = appt.doctor
            patient_updates.append("primary_doctor")
        if patient_updates:
            appt.patient.save(update_fields=patient_updates)
        if appt.slot:
            _mark_slot_booked(appt.slot, True)
        log_action(self.request, "CREATE", f"Patient booked appointment {appt.reference_code}")
        send_ios_push(
            patient=appt.patient,
            title="Appointment confirmed",
            body=f"{appt.date} at {appt.time} - {appt.doctor.user.get_full_name()}",
            notif_type="BOOKING_CONFIRM",
            data={"appointment_id": str(appt.id)},
        )

    @action(detail=True, methods=["post"])
    def cancel(self, request, pk=None):
        appt = self.get_object()
        appt.status = "CANCELLED"
        appt.save(update_fields=["status", "updated_at"])
        if appt.slot and not appt.slot.appointments.exclude(pk=appt.pk).exclude(
            status__in=["CANCELLED", "NO_SHOW"]
        ).exists():
            _mark_slot_booked(appt.slot, False)
        log_action(request, "UPDATE", f"Appointment cancelled: {appt.reference_code}")
        return Response({"status": "CANCELLED"})


class DoctorAppointmentViewSet(viewsets.ModelViewSet):
    permission_classes = [IsDoctor]

    def get_serializer_class(self):
        if self.action == "create":
            return AppointmentCreateSerializer
        if self.action in ("update", "partial_update"):
            return AppointmentUpdateSerializer
        if self.action == "retrieve":
            return AppointmentDetailSerializer
        return AppointmentListSerializer

    def get_queryset(self):
        qs = Appointment.objects.select_related("patient", "doctor__user", "hospital", "slot")
        date_param = self.request.query_params.get("date")
        doctor_id = self.request.query_params.get("doctor")
        status_param = self.request.query_params.get("status")
        staff = _staff_from_request(self.request)

        if self.action == "list":
            date_value = date_param or localdate().isoformat()
            if date_value and date_value != "all":
                qs = qs.filter(date=date_value)
        elif date_param and date_param != "all":
            qs = qs.filter(date=date_param)
        if doctor_id:
            qs = qs.filter(doctor_id=doctor_id)
        elif staff:
            if staff.role == "DOCTOR":
                qs = qs.filter(doctor=staff)
            elif staff.role != "SUPERADMIN" and staff.hospital_id:
                qs = qs.filter(hospital=staff.hospital)
        if status_param:
            qs = qs.filter(status=status_param)
        return qs.order_by("time")

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        instance = Appointment.objects.select_related("patient", "doctor__user", "hospital", "slot").get(
            pk=serializer.instance.pk
        )
        headers = self.get_success_headers(serializer.data)
        return Response(
            AppointmentDetailSerializer(instance).data,
            status=status.HTTP_201_CREATED,
            headers=headers,
        )

    def perform_create(self, serializer):
        save_kwargs = {}
        if not serializer.validated_data.get("source"):
            save_kwargs["source"] = "PORTAL"
        appt = serializer.save(**save_kwargs)
        patient_updates = []
        if appt.hospital_id and appt.patient.primary_hospital_id != appt.hospital_id:
            appt.patient.primary_hospital = appt.hospital
            patient_updates.append("primary_hospital")
        if appt.doctor_id and appt.patient.primary_doctor_id != appt.doctor_id:
            appt.patient.primary_doctor = appt.doctor
            patient_updates.append("primary_doctor")
        if patient_updates:
            appt.patient.save(update_fields=patient_updates)
        if appt.slot:
            _mark_slot_booked(appt.slot, True)
        log_action(self.request, "CREATE", f"Appointment created: {appt.reference_code}")

    @action(detail=True, methods=["post"])
    def start(self, request, pk=None):
        appt = self.get_object()
        appt.status = "IN_PROGRESS"
        appt.save(update_fields=["status", "updated_at"])
        if appt.slot:
            _mark_slot_booked(appt.slot, True)
        log_action(request, "CONSULT_OPEN", str(appt))
        return Response({"status": "IN_PROGRESS"})

    @action(detail=True, methods=["post"])
    def close(self, request, pk=None):
        appt = self.get_object()
        appt.soap_notes = request.data.get("soap_notes", "")
        appt.status = "COMPLETED"
        appt.save(update_fields=["soap_notes", "status", "updated_at"])
        log_action(request, "CONSULT_CLOSE", str(appt))
        send_ios_push(
            patient=appt.patient,
            title="Consultation completed",
            body="Your medical record has been updated in RwandaCare.",
            notif_type="GENERAL",
            data={"appointment_id": str(appt.id)},
        )
        return Response(AppointmentDetailSerializer(appt).data)


class PrescriptionViewSet(AuditMixin, viewsets.ModelViewSet):
    serializer_class = PrescriptionSerializer
    permission_classes = [IsDoctor]

    def get_queryset(self):
        appointment_id = self.request.query_params.get("appointment")
        qs = Prescription.objects.select_related("appointment__patient")
        if appointment_id:
            qs = qs.filter(appointment_id=appointment_id)
        staff = _staff_from_request(self.request)
        if staff and staff.role == "DOCTOR":
            qs = qs.filter(appointment__doctor=staff)
        elif staff and staff.role != "SUPERADMIN" and staff.hospital_id:
            qs = qs.filter(appointment__hospital=staff.hospital)
        return qs

    def perform_create(self, serializer):
        rx = serializer.save()
        MedicationPlan.objects.create(
            patient=rx.appointment.patient,
            prescription=rx,
            name=rx.medication_name,
            dosage=rx.dosage,
            frequency=rx.instructions or "As prescribed",
            next_dose_at=now(),
            remaining=rx.duration_days or 30,
            total=rx.duration_days or 30,
            color_hex="#22C55E",
        )
        log_action(self.request, "PRESCRIPTION", str(rx))
        send_ios_push(
            patient=rx.appointment.patient,
            title="New prescription",
            body=f"{rx.medication_name} - {rx.dosage}",
            notif_type="PRESCRIPTION",
            data={"prescription_id": str(rx.id)},
        )
        rx.notified_patient = True
        rx.save(update_fields=["notified_patient"])


class LabRequestViewSet(AuditMixin, viewsets.ModelViewSet):
    serializer_class = LabRequestSerializer
    permission_classes = [IsMedicalStaff]

    def get_queryset(self):
        qs = LabRequest.objects.select_related("appointment__patient", "appointment__doctor")
        appointment_id = self.request.query_params.get("appointment")
        if appointment_id:
            qs = qs.filter(appointment_id=appointment_id)
        staff = _staff_from_request(self.request)
        if staff and staff.role != "SUPERADMIN" and staff.hospital_id:
            qs = qs.filter(appointment__hospital=staff.hospital)
        return qs

    @action(detail=True, methods=["post"], permission_classes=[IsMedicalStaff])
    def mark_ready(self, request, pk=None):
        lab = self.get_object()
        lab.status = "RESULTS_READY"
        lab.results_at = now()
        if "result_summary" in request.data:
            lab.result_summary = request.data.get("result_summary", "")
        lab.save(update_fields=["status", "results_at", "result_summary"])

        PatientLabResult.objects.update_or_create(
            lab_request=lab,
            defaults={
                "patient": lab.appointment.patient,
                "appointment": lab.appointment,
                "test_name": lab.test_name,
                "date": localdate(),
                "result": request.data.get("result", lab.result_summary or "Result ready"),
                "reference_range": request.data.get("reference_range", ""),
                "icon": request.data.get("icon", "doc.text.fill"),
                "is_abnormal": bool(request.data.get("is_abnormal", False)),
                "notes": lab.notes,
            },
        )

        log_action(request, "UPDATE", f"Lab results ready: {lab}")
        send_ios_push(
            staff=lab.appointment.doctor,
            title="Lab results available",
            body=f"{lab.test_name} - {lab.appointment.patient.full_name}",
            notif_type="LAB_READY",
            data={"lab_request_id": str(lab.id)},
        )
        send_ios_push(
            patient=lab.appointment.patient,
            title="Lab results ready",
            body=f"{lab.test_name} is now available in your RwandaCare app.",
            notif_type="LAB_READY",
            data={"lab_request_id": str(lab.id)},
        )
        lab.doctor_notified = True
        lab.save(update_fields=["doctor_notified"])
        return Response({"status": "RESULTS_READY"})


class PatientLabResultViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = PatientLabResultSerializer
    permission_classes = [permissions.IsAuthenticated]
    authentication_classes = [CsrfExemptSessionAuthentication, BasicAuthentication]

    def get_queryset(self):
        qs = PatientLabResult.objects.select_related("patient", "appointment", "lab_request")
        patient = _patient_from_request(self.request)
        staff = _staff_from_request(self.request)
        if patient:
            qs = qs.filter(patient=patient)
        elif staff and staff.role != "SUPERADMIN" and staff.hospital_id:
            qs = qs.filter(appointment__hospital=staff.hospital)
        elif not staff:
            qs = qs.none()
        return qs


class MedicalHistoryViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = MedicalHistoryEntrySerializer
    permission_classes = [permissions.IsAuthenticated]
    authentication_classes = [CsrfExemptSessionAuthentication, BasicAuthentication]

    def get_queryset(self):
        qs = MedicalHistoryEntry.objects.select_related("patient", "doctor__user")
        patient = _patient_from_request(self.request)
        staff = _staff_from_request(self.request)
        if patient:
            qs = qs.filter(patient=patient)
        elif staff and staff.role != "SUPERADMIN" and staff.hospital_id:
            qs = qs.filter(patient__appointments__hospital=staff.hospital).distinct()
        elif not staff:
            qs = qs.none()
        return qs


class MedicationPlanViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = MedicationPlanSerializer
    permission_classes = [permissions.IsAuthenticated]
    authentication_classes = [CsrfExemptSessionAuthentication, BasicAuthentication]

    def get_queryset(self):
        qs = MedicationPlan.objects.select_related("patient", "prescription")
        patient = _patient_from_request(self.request)
        staff = _staff_from_request(self.request)
        if patient:
            qs = qs.filter(patient=patient)
        elif staff and staff.role != "SUPERADMIN" and staff.hospital_id:
            qs = qs.filter(patient__appointments__hospital=staff.hospital).distinct()
        elif not staff:
            qs = qs.none()
        return qs


class PatientNotificationPreferenceViewSet(viewsets.ModelViewSet):
    serializer_class = NotificationPreferenceSerializer
    permission_classes = [IsPatientUser]
    authentication_classes = [CsrfExemptSessionAuthentication, BasicAuthentication]
    http_method_names = ["get", "patch", "put"]

    def get_queryset(self):
        patient = self.request.user.patient_profile
        ensure_patient_notification_preferences(patient)
        return patient.notification_preferences.all()


class SymptomAssessmentViewSet(viewsets.ModelViewSet):
    serializer_class = SymptomAssessmentSerializer
    permission_classes = [IsPatientUser]
    authentication_classes = [CsrfExemptSessionAuthentication, BasicAuthentication]
    http_method_names = ["get", "post"]

    def get_queryset(self):
        return SymptomAssessment.objects.filter(patient=self.request.user.patient_profile)

    def perform_create(self, serializer):
        assessment = serializer.save(patient=self.request.user.patient_profile)
        if not assessment.recommended_facility:
            if assessment.triage_level == "URGENT":
                facility = MedicalFacility.objects.filter(
                    facility_type="HOSPITAL",
                    is_active=True,
                ).order_by("distance_km").first()
            elif assessment.triage_level == "MILD":
                facility = MedicalFacility.objects.filter(
                    facility_type="PHARMACY",
                    is_active=True,
                ).order_by("distance_km").first()
            else:
                facility = MedicalFacility.objects.filter(
                    facility_type__in=["CLINIC", "HOSPITAL"],
                    is_active=True,
                ).order_by("distance_km").first()
            if facility:
                assessment.recommended_facility = facility
                assessment.save(update_fields=["recommended_facility"])


class SymptomAssessmentAdminViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = SymptomAssessmentSerializer
    permission_classes = [IsMedicalStaff]

    def get_queryset(self):
        qs = SymptomAssessment.objects.select_related(
            "patient",
            "recommended_facility",
            "recommended_doctor__user",
        )
        staff = _staff_from_request(self.request)
        if staff and staff.role != "SUPERADMIN" and staff.hospital_id:
            qs = qs.filter(
                Q(patient__primary_hospital=staff.hospital)
                | Q(patient__appointments__hospital=staff.hospital)
            ).distinct()
        return qs.order_by("-created_at")


class PreAdmissionViewSet(viewsets.ModelViewSet):
    serializer_class = PreAdmissionSerializer
    permission_classes = [permissions.IsAuthenticated]
    authentication_classes = [CsrfExemptSessionAuthentication, BasicAuthentication]
    http_method_names = ["get", "post", "patch"]

    def get_permissions(self):
        if self.action == "create":
            return [IsPatientUser()]
        if self.action in ("update", "partial_update"):
            return [IsMedicalStaff()]
        return [permissions.IsAuthenticated()]

    def get_queryset(self):
        patient = _patient_from_request(self.request)
        staff = _staff_from_request(self.request)
        qs = PreAdmission.objects.select_related("hospital", "patient", "submitted_by")
        if patient:
            return qs.filter(patient=patient)
        if staff and staff.role != "SUPERADMIN" and staff.hospital_id:
            return qs.filter(hospital=staff.hospital)
        if staff and staff.role == "SUPERADMIN":
            return qs
        return qs.none()

    def perform_create(self, serializer):
        patient = _patient_from_request(self.request)
        snapshot = {}
        if patient:
            snapshot = {
                "patient": patient,
                "submitted_by": self.request.user,
                "full_name": serializer.validated_data.get("full_name") or patient.full_name,
                "phone": serializer.validated_data.get("phone") or patient.phone,
                "email": serializer.validated_data.get("email") or patient.email,
                "date_of_birth": serializer.validated_data.get("date_of_birth") or patient.date_of_birth,
                "insurance_type": serializer.validated_data.get("insurance_type") or patient.insurance_type,
            }
        pre_admission = serializer.save(**snapshot)
        log_action(
            self.request,
            "CREATE",
            f"Pre-admission submitted for {pre_admission.full_name} at {pre_admission.hospital.name}",
        )


class PatientNotificationViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = IOSNotificationSerializer
    permission_classes = [permissions.IsAuthenticated]
    authentication_classes = [CsrfExemptSessionAuthentication, BasicAuthentication]

    def get_queryset(self):
        patient = _patient_from_request(self.request)
        staff = _staff_from_request(self.request)
        if patient:
            return IOSNotification.objects.filter(recipient_patient=patient).order_by("-sent_at")
        if staff:
            return IOSNotification.objects.filter(recipient_staff=staff).order_by("-sent_at")
        return IOSNotification.objects.none()

    @action(detail=True, methods=["post"])
    def mark_read(self, request, pk=None):
        notif = self.get_object()
        notif.read = True
        notif.read_at = now()
        notif.save(update_fields=["read", "read_at"])
        return Response({"read": True})

    @action(detail=False, methods=["post"])
    def mark_all_read(self, request):
        patient = _patient_from_request(request)
        staff = _staff_from_request(request)
        qs = IOSNotification.objects.filter(read=False)
        if patient:
            qs = qs.filter(recipient_patient=patient)
        elif staff:
            qs = qs.filter(recipient_staff=staff)
        else:
            qs = IOSNotification.objects.none()
        qs.update(read=True, read_at=now())
        return Response({"detail": "All notifications marked as read."})


class AuditLogViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = AuditLogSerializer
    permission_classes = [IsHospitalAdmin]
    queryset = AuditLog.objects.select_related("actor", "hospital").all()

    def get_queryset(self):
        qs = super().get_queryset()
        staff = _staff_from_request(self.request)
        if staff and staff.role != "SUPERADMIN" and staff.hospital_id:
            qs = qs.filter(hospital=staff.hospital)

        log_type = self.request.query_params.get("type")
        action = self.request.query_params.get("action")
        hospital_id = self.request.query_params.get("hospital")
        date_from = self.request.query_params.get("from")
        date_to = self.request.query_params.get("to")
        if log_type:
            qs = qs.filter(log_type=log_type)
        if action:
            qs = qs.filter(action=action)
        if hospital_id and (not staff or staff.role == "SUPERADMIN"):
            qs = qs.filter(hospital_id=hospital_id)
        if date_from:
            qs = qs.filter(timestamp__date__gte=date_from)
        if date_to:
            qs = qs.filter(timestamp__date__lte=date_to)
        return qs


class DashboardView(APIView):
    permission_classes = [IsMedicalStaff]

    def get(self, request):
        today = localdate()
        role = _staff_from_request(request)

        appts = Appointment.objects.filter(date=today)
        if role and role.role != "SUPERADMIN" and role.hospital_id:
            appts = appts.filter(hospital=role.hospital)

        unread_notifications = (
            IOSNotification.objects.filter(recipient_staff=role, read=False).count()
            if role
            else 0
        )

        data = {
            "patients_today": appts.values("patient").distinct().count(),
            "waiting": appts.filter(status="UPCOMING").count(),
            "in_progress": appts.filter(status="IN_PROGRESS").count(),
            "completed": appts.filter(status="COMPLETED").count(),
            "urgent": Vitals.objects.filter(
                recorded_at__date=today,
                triage_level="URGENT",
            ).values("patient").distinct().count(),
            "hospitals_online": Hospital.objects.filter(
                is_active=True,
                rwandacare_sync_enabled=True,
            ).count(),
            "doctors_available": StaffProfile.objects.filter(
                role="DOCTOR",
                is_available=True,
            ).count(),
            "ios_notifications_unread": unread_notifications,
        }
        return Response(DashboardSummarySerializer(data).data)


class PortalBootstrapView(APIView):
    """
    Dashboard bootstrap payload consumed by rwandacare_pro.html.
    Uses HTTP Basic or session auth and scopes data by staff role.
    """
    permission_classes = [IsMedicalStaff]

    def get(self, request):
        staff = request.user.staff_profile
        today = localdate()

        hospitals_qs = Hospital.objects.filter(is_active=True).order_by("name")
        doctors_qs = (
            StaffProfile.objects.select_related("user", "hospital")
            .filter(role="DOCTOR")
            .order_by("user__first_name", "user__last_name")
        )
        users_qs = StaffProfile.objects.select_related("user", "hospital").order_by(
            "user__first_name",
            "user__last_name",
        )
        appointments_qs = Appointment.objects.select_related(
            "patient",
            "doctor__user",
            "hospital",
        ).filter(date__gte=today - timedelta(days=14), date__lte=today + timedelta(days=30))
        patients_qs = Patient.objects.select_related(
            "primary_hospital",
            "primary_doctor__user",
        ).prefetch_related(
            "vitals",
            "appointments__doctor__user",
            "appointments__hospital",
            "appointments__prescriptions",
        )
        pre_admissions_qs = PreAdmission.objects.select_related(
            "hospital",
            "patient",
            "submitted_by",
        ).order_by("-submitted_at")
        symptom_assessments_qs = SymptomAssessment.objects.select_related(
            "patient",
            "recommended_facility",
            "recommended_doctor__user",
        ).order_by("-created_at")
        audit_qs = AuditLog.objects.select_related("actor", "hospital").all()
        notif_qs = IOSNotification.objects.filter(recipient_staff=staff).order_by("-sent_at")[:50]

        if staff.role != "SUPERADMIN" and staff.hospital_id:
            doctors_qs = doctors_qs.filter(hospital=staff.hospital)
            users_qs = users_qs.filter(hospital=staff.hospital)
            appointments_qs = appointments_qs.filter(hospital=staff.hospital)
            patients_qs = patients_qs.filter(
                Q(primary_hospital=staff.hospital) | Q(appointments__hospital=staff.hospital)
            ).distinct()
            pre_admissions_qs = pre_admissions_qs.filter(hospital=staff.hospital)
            symptom_assessments_qs = symptom_assessments_qs.filter(
                Q(patient__primary_hospital=staff.hospital)
                | Q(patient__appointments__hospital=staff.hospital)
            ).distinct()
            audit_qs = audit_qs.filter(hospital=staff.hospital)

        pre_admissions_qs = pre_admissions_qs[:100]
        symptom_assessments_qs = symptom_assessments_qs[:100]
        audit_qs = audit_qs[:100]

        hospitals = []
        for hospital in hospitals_qs:
            occupancy = 0
            if hospital.total_beds:
                occupancy = round((hospital.occupied_beds / hospital.total_beds) * 100)
            hospitals.append(
                {
                    "id": str(hospital.id),
                    "name": hospital.name,
                    "district": hospital.district,
                    "type": hospital.type,
                    "beds": hospital.total_beds,
                    "occupancy": occupancy,
                    "phone": hospital.phone,
                    "email": hospital.email,
                    "address": hospital.address,
                    "syncEnabled": hospital.rwandacare_sync_enabled,
                }
            )

        users = []
        for profile in users_qs:
            users.append(
                {
                    "id": str(profile.id),
                    "fullName": profile.user.get_full_name().strip() or profile.user.username,
                    "role": _portal_role(profile),
                    "hospitalId": str(profile.hospital_id) if profile.hospital_id else "",
                    "email": profile.user.email or "",
                    "active": profile.user.is_active,
                    "mobileActive": profile.is_app_connected,
                    "lastLogin": (
                        timezone.localtime(profile.user.last_login).strftime("%Y-%m-%d %H:%M")
                        if profile.user.last_login
                        else "Never"
                    ),
                    "accent": "#11836c" if profile.role == "DOCTOR" else "#9a5e11" if profile.role == "ADMIN" else "#2454aa",
                }
            )

        doctors = []
        for doctor in doctors_qs:
            doctors.append(
                {
                    "id": str(doctor.id),
                    "userId": str(doctor.id),
                    "fullName": doctor.user.get_full_name().strip() or doctor.user.username,
                    "specialty": doctor.specialty or "General Medicine",
                    "hospitalId": str(doctor.hospital_id) if doctor.hospital_id else "",
                    "phone": doctor.phone or "",
                    "licenseNumber": doctor.license_number or "",
                    "available": doctor.is_available,
                }
            )

        patient_records = []
        for patient in patients_qs:
            latest_vitals = patient.vitals.order_by("-recorded_at").first()
            active_appt = (
                patient.appointments.filter(status__in=["UPCOMING", "IN_PROGRESS"])
                .order_by("date", "time")
                .first()
            )
            recent_appt = (
                patient.appointments.order_by("-date", "-time").first()
            )
            appt_for_payload = active_appt or recent_appt
            linked_hospital = appt_for_payload.hospital if appt_for_payload and appt_for_payload.hospital_id else patient.primary_hospital
            linked_doctor = appt_for_payload.doctor if appt_for_payload and appt_for_payload.doctor_id else patient.primary_doctor

            prescriptions = []
            if appt_for_payload:
                prescriptions = [
                    {"medication": rx.medication_name, "dosage": rx.dosage}
                    for rx in appt_for_payload.prescriptions.all()[:8]
                ]

            bp_value = ""
            if latest_vitals and latest_vitals.systolic_bp and latest_vitals.diastolic_bp:
                bp_value = f"{latest_vitals.systolic_bp}/{latest_vitals.diastolic_bp}"

            patient_records.append(
                {
                    "id": str(patient.id),
                    "fullName": patient.full_name,
                    "nationalId": patient.national_id,
                    "dateOfBirth": patient.date_of_birth.isoformat(),
                    "phone": patient.phone,
                    "bloodType": patient.blood_type,
                    "insuranceType": _portal_insurance(patient),
                    "reason": appt_for_payload.reason_for_visit if appt_for_payload else "General consultation",
                    "hospitalId": str(linked_hospital.id) if linked_hospital else "",
                    "doctorId": str(linked_doctor.id) if linked_doctor else "",
                    "status": _portal_patient_status(appt_for_payload.status if appt_for_payload else "UPCOMING"),
                    "triage": _portal_triage(latest_vitals),
                    "consent": bool(patient.share_data_with_doctors),
                    "vitals": {
                        "heartRate": int(latest_vitals.heart_rate) if latest_vitals and latest_vitals.heart_rate else 0,
                        "spo2": float(latest_vitals.spo2) if latest_vitals and latest_vitals.spo2 is not None else 0,
                        "temperature": float(latest_vitals.temperature) if latest_vitals and latest_vitals.temperature is not None else 0,
                        "bloodPressure": bp_value,
                    },
                    "soapNotes": appt_for_payload.soap_notes if appt_for_payload else "",
                    "prescriptions": prescriptions,
                }
            )

        appointments = []
        for appt in appointments_qs:
            appointments.append(
                {
                    "id": str(appt.id),
                    "patientId": str(appt.patient_id),
                    "doctorId": str(appt.doctor_id),
                    "hospitalId": str(appt.hospital_id),
                    "date": appt.date.isoformat(),
                    "time": appt.time.strftime("%H:%M"),
                    "duration": appt.duration_minutes,
                    "type": appt.reason_for_visit or "General consultation",
                    "source": appt.get_source_display(),
                    "status": _portal_appt_status(appt.status),
                }
            )

        notifications = [
            {
                "id": str(item.id),
                "title": item.title,
                "body": item.body,
                "time": timezone.localtime(item.sent_at).strftime("%H:%M"),
                "read": item.read,
            }
            for item in notif_qs
        ]

        audit_logs = []
        for item in audit_qs:
            if item.log_type == "WARNING":
                level = "warning"
            elif item.log_type == "ERROR":
                level = "warning"
            else:
                level = "info"
            audit_logs.append(
                {
                    "id": str(item.id),
                    "level": level,
                    "action": item.description,
                    "actor": item.actor.get_full_name() if item.actor else "System",
                    "hospitalName": item.hospital.name if item.hospital else "National",
                    "time": timezone.localtime(item.timestamp).strftime("%H:%M"),
                }
            )

        pre_admissions = []
        for entry in pre_admissions_qs:
            pre_admissions.append(
                {
                    "id": str(entry.id),
                    "patientId": str(entry.patient_id) if entry.patient_id else "",
                    "fullName": entry.full_name,
                    "hospitalId": str(entry.hospital_id),
                    "hospitalName": entry.hospital.name,
                    "status": entry.get_status_display(),
                    "isRoutine": bool(entry.is_routine),
                    "isIll": bool(entry.is_ill),
                    "symptoms": entry.symptoms or "",
                    "insuranceType": entry.insurance_type,
                    "submittedAt": timezone.localtime(entry.submitted_at).strftime("%Y-%m-%d %H:%M"),
                }
            )

        symptom_assessments = []
        for entry in symptom_assessments_qs:
            latest_appt = entry.patient.appointments.order_by("-date", "-time").first()
            linked_hospital_id = (
                entry.patient.primary_hospital_id
                or (latest_appt.hospital_id if latest_appt else None)
            )
            symptom_assessments.append(
                {
                    "id": str(entry.id),
                    "patientId": str(entry.patient_id),
                    "patientName": entry.patient.full_name,
                    "hospitalId": str(linked_hospital_id) if linked_hospital_id else "",
                    "triageLevel": entry.get_triage_level_display(),
                    "painLevel": int(entry.pain_level),
                    "symptoms": ", ".join(entry.symptoms or []),
                    "recommendedFacility": entry.recommended_facility.name if entry.recommended_facility else "",
                    "recommendedDoctor": (
                        entry.recommended_doctor.user.get_full_name().strip()
                        if entry.recommended_doctor
                        else ""
                    ),
                    "createdAt": timezone.localtime(entry.created_at).strftime("%Y-%m-%d %H:%M"),
                }
            )

        store_payload = {
            "meta": {"version": 4},
            "session": {"userId": str(staff.id), "lastTab": "overview"},
            "hospitals": hospitals,
            "users": users,
            "doctors": doctors,
            "patients": patient_records,
            "appointments": appointments,
            "preAdmissions": pre_admissions,
            "symptomAssessments": symptom_assessments,
            "notifications": notifications,
            "auditLogs": audit_logs,
        }

        current_user_payload = {
            "id": str(staff.id),
            "fullName": staff.user.get_full_name().strip() or staff.user.username,
            "role": _portal_role(staff),
            "hospitalId": str(staff.hospital_id) if staff.hospital_id else "",
            "email": staff.user.email or "",
            "active": staff.user.is_active,
            "mobileActive": staff.is_app_connected,
            "lastLogin": (
                timezone.localtime(staff.user.last_login).strftime("%Y-%m-%d %H:%M")
                if staff.user.last_login
                else "Never"
            ),
            "accent": "#11836c" if staff.role == "DOCTOR" else "#9a5e11" if staff.role == "ADMIN" else "#2454aa",
        }

        return Response(
            {
                "store": store_payload,
                "current_user": current_user_payload,
                "server_time": timezone.now().isoformat(),
            }
        )


class PatientDashboardView(APIView):
    permission_classes = [IsPatientUser]
    authentication_classes = [CsrfExemptSessionAuthentication, BasicAuthentication]

    def get(self, request):
        patient = request.user.patient_profile
        ensure_patient_notification_preferences(patient)

        next_appointment = (
            patient.appointments.filter(status="UPCOMING")
            .select_related("hospital", "doctor__user")
            .order_by("date", "time")
            .first()
        )
        medications = patient.medications.filter(is_active=True).order_by("next_dose_at", "-created_at")[:5]
        lab_results = patient.patient_lab_results.order_by("-date", "-created_at")[:5]

        payload = {
            "profile": PatientProfileSerializer(patient).data,
            "next_appointment": AppointmentListSerializer(next_appointment).data if next_appointment else None,
            "medications": MedicationPlanSerializer(medications, many=True).data,
            "recent_lab_results": PatientLabResultSerializer(lab_results, many=True).data,
            "unread_notifications": patient.notifications.filter(read=False).count(),
        }
        return Response(payload)


class MobileBootstrapView(APIView):
    """
    Unified payload shaped for the Swift app store models.
    """

    permission_classes = [IsPatientUser]
    authentication_classes = [CsrfExemptSessionAuthentication, BasicAuthentication]

    def get(self, request):
        patient = request.user.patient_profile
        ensure_patient_notification_preferences(patient)

        appointments = (
            patient.appointments.select_related("doctor__user", "hospital")
            .order_by("-date", "-time")[:30]
        )
        lab_results = patient.patient_lab_results.order_by("-date", "-created_at")[:30]
        history = patient.medical_history_entries.select_related("doctor__user").order_by("-diagnosed_date", "-created_at")[:20]
        medications = patient.medications.filter(is_active=True).order_by("next_dose_at", "-created_at")[:20]
        notifications = patient.notifications.order_by("-sent_at")[:50]
        prefs = patient.notification_preferences.order_by("title")
        facilities = MedicalFacility.objects.filter(is_active=True).order_by("distance_km", "name")[:200]
        doctors = (
            StaffProfile.objects.select_related("user", "hospital")
            .prefetch_related("availability_slots")
            .filter(role="DOCTOR", is_available=True)
            .order_by("user__last_name", "user__first_name")[:100]
        )

        payload = {
            "authMethod": patient.auth_method or "email",
            "profile": {
                "firstName": patient.first_name,
                "lastName": patient.last_name,
                "email": patient.email,
                "phone": patient.phone,
                "nationalID": patient.national_id,
                "dateOfBirth": patient.date_of_birth.strftime("%d / %m / %Y"),
                "sex": patient.sex,
                "address": patient.address,
                "profession": patient.profession,
                "weight": str(patient.weight_kg) if patient.weight_kg is not None else "",
                "height": str(patient.height_cm) if patient.height_cm is not None else "",
                "bloodType": patient.blood_type,
                "insuranceNum": patient.insurance_number,
                "isVerified": patient.is_verified,
                "shareDataWithDoctors": patient.share_data_with_doctors,
                "allowAnalytics": patient.allow_analytics,
                "twoFactorEnabled": patient.two_factor_enabled,
                "biometricLogin": patient.biometric_login,
                "locationEnabled": patient.location_enabled,
            },
            "notifPrefs": [
                {
                    "id": str(pref.id),
                    "title": pref.title,
                    "subtitle": pref.subtitle,
                    "icon": pref.icon,
                    "color": pref.color_hex,
                    "enabled": pref.enabled,
                }
                for pref in prefs
            ],
            "appointments": [
                {
                    "id": str(appt.id),
                    "doctorName": appt.doctor.user.get_full_name().strip() or appt.doctor.user.username,
                    "specialty": appt.doctor.specialty or "General Medicine",
                    "hospital": appt.hospital.name,
                    "date": _mobile_date_label(appt.date),
                    "time": _mobile_time_label(appt.time),
                    "appointmentID": appt.reference_code,
                    "status": _mobile_appt_status(appt.status),
                }
                for appt in appointments
            ],
            "labResults": [
                {
                    "id": str(item.id),
                    "testName": item.test_name,
                    "date": _mobile_date_label(item.date),
                    "result": item.result,
                    "referenceRange": item.reference_range,
                    "icon": item.icon,
                    "isAbnormal": item.is_abnormal,
                }
                for item in lab_results
            ],
            "medHistory": [
                {
                    "id": str(item.id),
                    "condition": item.condition,
                    "diagnosedDate": item.diagnosed_date.strftime("%b %Y") if item.diagnosed_date else "",
                    "status": item.get_status_display(),
                    "doctor": item.doctor.user.get_full_name().strip() if item.doctor else "",
                    "notes": item.notes,
                    "icon": item.icon,
                    "color": item.color_hex,
                }
                for item in history
            ],
            "medications": [
                {
                    "id": str(item.id),
                    "name": item.name,
                    "dosage": item.dosage,
                    "frequency": item.frequency,
                    "nextDose": timezone.localtime(item.next_dose_at).strftime("%I:%M %p").lstrip("0")
                    if item.next_dose_at
                    else "",
                    "remaining": item.remaining,
                    "total": item.total,
                    "color": item.color_hex,
                }
                for item in medications
            ],
            "notifications": [
                {
                    "id": str(item.id),
                    "title": item.title,
                    "message": item.body,
                    "time": timezone.localtime(item.sent_at).strftime("%H:%M"),
                    "icon": "bell.fill",
                    "color": "#3B82F6",
                    "isRead": item.read,
                }
                for item in notifications
            ],
            "facilities": [
                {
                    "id": str(item.id),
                    "name": item.name,
                    "phone": item.phone,
                    "address": item.address,
                    "district": item.district,
                    "type": item.get_facility_type_display(),
                    "coordinate": {
                        "latitude": float(item.latitude),
                        "longitude": float(item.longitude),
                    },
                    "isOpen24h": item.is_open_24h,
                    "rating": float(item.rating),
                    "services": item.services,
                    "distanceKm": float(item.distance_km),
                }
                for item in facilities
            ],
            "doctors": [
                {
                    "id": str(doc.id),
                    "name": doc.user.get_full_name().strip() or doc.user.username,
                    "specialty": doc.specialty or "General Medicine",
                    "hospital": doc.hospital.name if doc.hospital else "",
                    "experience": f"{doc.years_experience} yrs" if doc.years_experience else "",
                    "consultFee": (
                        f"RWF {int(doc.consultation_fee):,}".replace(",", ",")
                        if doc.consultation_fee is not None
                        else ""
                    ),
                    "imagePlaceholder": "person.crop.circle.fill",
                    "rating": float(doc.rating),
                    "slots": [
                        {
                            "id": str(slot.id),
                            "label": slot.label or timezone.localtime(slot.starts_at).strftime("%I:%M %p %b %d").lstrip("0"),
                            "startsAt": timezone.localtime(slot.starts_at).isoformat(),
                            "endsAt": timezone.localtime(slot.ends_at).isoformat() if slot.ends_at else "",
                        }
                        for slot in doc.availability_slots.filter(is_booked=False, starts_at__gte=timezone.now())
                        .order_by("starts_at")[:6]
                    ],
                }
                for doc in doctors
            ],
        }
        return Response(payload)


class SystemUserViewSet(viewsets.ModelViewSet):
    permission_classes = [IsHospitalAdmin]

    def get_serializer_class(self):
        if self.action == "create":
            return StaffCreateSerializer
        if self.action in ("update", "partial_update"):
            return StaffUpdateSerializer
        return StaffListSerializer

    def get_queryset(self):
        qs = StaffProfile.objects.select_related("user", "hospital").all()
        staff = _staff_from_request(self.request)
        if staff and staff.role != "SUPERADMIN" and staff.hospital_id:
            qs = qs.filter(hospital=staff.hospital)
        return qs

    def perform_create(self, serializer):
        staff = _staff_from_request(self.request)
        role = serializer.validated_data.get("role")
        hospital = serializer.validated_data.get("hospital")
        save_kwargs = {}

        if staff and staff.role != "SUPERADMIN":
            if role == "SUPERADMIN":
                raise PermissionDenied("Only super admins can create super admin accounts.")
            if not staff.hospital_id:
                raise PermissionDenied("Hospital admin account is not linked to a hospital.")
            save_kwargs["hospital"] = staff.hospital
        elif staff and staff.role == "SUPERADMIN" and role != "SUPERADMIN" and hospital is None:
            raise PermissionDenied("Hospital must be provided for non-super-admin accounts.")

        serializer.save(**save_kwargs)

    def perform_update(self, serializer):
        requester = _staff_from_request(self.request)
        target = self.get_object()
        next_role = serializer.validated_data.get("role", target.role)
        next_hospital = serializer.validated_data.get("hospital", target.hospital)

        if requester and requester.role != "SUPERADMIN":
            if target.role == "SUPERADMIN" or next_role == "SUPERADMIN":
                raise PermissionDenied("Only super admins can manage super admin accounts.")
            if requester.hospital_id and next_hospital and next_hospital.id != requester.hospital_id:
                raise PermissionDenied("Hospital admins can only manage users in their own hospital.")
            serializer.save(hospital=requester.hospital)
            return

        if requester and requester.role == "SUPERADMIN" and next_role != "SUPERADMIN" and not next_hospital:
            raise PermissionDenied("Hospital must be provided for non-super-admin accounts.")

        serializer.save()

    @action(detail=True, methods=["post"])
    def suspend(self, request, pk=None):
        staff = self.get_object()
        requester = _staff_from_request(request)
        if requester and requester.role != "SUPERADMIN" and staff.role == "SUPERADMIN":
            return Response({"detail": "Not allowed."}, status=403)
        staff.user.is_active = False
        staff.user.save(update_fields=["is_active"])
        log_action(request, "ACCOUNT_SUSPEND", f"Suspended: {staff}")
        return Response({"is_active": False})

    @action(detail=True, methods=["post"])
    def reactivate(self, request, pk=None):
        staff = self.get_object()
        requester = _staff_from_request(request)
        if requester and requester.role != "SUPERADMIN" and staff.role == "SUPERADMIN":
            return Response({"detail": "Not allowed."}, status=403)
        staff.user.is_active = True
        staff.user.save(update_fields=["is_active"])
        log_action(request, "UPDATE", f"Reactivated: {staff}")
        return Response({"is_active": True})

    @action(detail=True, methods=["post"])
    def change_role(self, request, pk=None):
        staff = self.get_object()
        requester = _staff_from_request(request)
        new_role = request.data.get("role")
        valid_roles = [choice[0] for choice in StaffProfile.ROLE_CHOICES]
        if new_role not in valid_roles:
            return Response(
                {"detail": f"Invalid role. Choose from: {valid_roles}"},
                status=400,
            )
        if requester and requester.role != "SUPERADMIN":
            if new_role == "SUPERADMIN" or staff.role == "SUPERADMIN":
                return Response({"detail": "Not allowed."}, status=403)
        old_role = staff.role
        staff.role = new_role
        staff.save(update_fields=["role"])
        log_action(
            request,
            "ROLE_CHANGE",
            f"{staff} role changed {old_role} -> {new_role}",
        )
        return Response({"role": new_role})


class IOSSyncWebhookView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        token = request.headers.get("X-RwandaCare-Token")
        hospital = Hospital.objects.filter(
            sync_token=token,
            rwandacare_sync_enabled=True,
        ).first()
        if not hospital:
            return Response(
                {"detail": "Invalid sync token or sync is disabled."},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        payload = request.data
        results = {"vitals": 0, "appointments": 0, "errors": []}

        for v in payload.get("vitals", []):
            try:
                patient = Patient.objects.get(national_id=v["national_id"])
                serializer = VitalsSerializer(
                    data={**v, "patient": patient.id, "source": "IOS_APP"}
                )
                if serializer.is_valid(raise_exception=False):
                    serializer.save()
                    results["vitals"] += 1
                else:
                    results["errors"].append({"vitals": serializer.errors})
            except Patient.DoesNotExist:
                results["errors"].append(
                    {"national_id": v.get("national_id"), "error": "Patient not found"}
                )

        for a in payload.get("appointments", []):
            try:
                appt = Appointment.objects.get(id=a["id"])
                new_status = a.get("status")
                if new_status in [choice[0] for choice in Appointment.STATUS_CHOICES]:
                    appt.status = new_status
                    appt.save(update_fields=["status", "updated_at"])
                    results["appointments"] += 1
            except Appointment.DoesNotExist:
                results["errors"].append(
                    {"appointment_id": a.get("id"), "error": "Not found"}
                )

        AuditLog.objects.create(
            log_type="INFO",
            action="SYNC_OK" if not results["errors"] else "SYNC_FAIL",
            description=(
                f"iOS sync from {hospital.name}: "
                f"{results['vitals']} vitals, {results['appointments']} appts."
            ),
            hospital=hospital,
        )

        return Response(results, status=status.HTTP_200_OK)

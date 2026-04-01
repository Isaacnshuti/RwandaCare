from datetime import date

from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework import serializers

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


class HospitalListSerializer(serializers.ModelSerializer):
    occupancy_rate = serializers.ReadOnlyField()
    doctor_count = serializers.ReadOnlyField()

    class Meta:
        model = Hospital
        fields = [
            "id",
            "name",
            "district",
            "address",
            "phone",
            "email",
            "latitude",
            "longitude",
            "type",
            "total_beds",
            "occupied_beds",
            "occupancy_rate",
            "doctor_count",
            "rwandacare_sync_enabled",
            "is_active",
        ]


class HospitalDetailSerializer(HospitalListSerializer):
    class Meta(HospitalListSerializer.Meta):
        fields = HospitalListSerializer.Meta.fields + ["sync_token", "created_at"]
        extra_kwargs = {
            "sync_token": {"write_only": True},
        }


class UserMinimalSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ["id", "first_name", "last_name", "email"]


class DoctorAvailabilitySlotSerializer(serializers.ModelSerializer):
    class Meta:
        model = DoctorAvailabilitySlot
        fields = [
            "id",
            "label",
            "starts_at",
            "ends_at",
            "is_booked",
            "source",
        ]
        read_only_fields = ["id"]


class StaffListSerializer(serializers.ModelSerializer):
    full_name = serializers.CharField(source="user.get_full_name", read_only=True)
    email = serializers.EmailField(source="user.email", read_only=True)
    is_app_connected = serializers.ReadOnlyField()
    patients_today = serializers.ReadOnlyField()
    hospital_name = serializers.CharField(source="hospital.name", read_only=True)
    available = serializers.BooleanField(source="is_available", read_only=True)

    class Meta:
        model = StaffProfile
        fields = [
            "id",
            "full_name",
            "email",
            "role",
            "specialty",
            "phone",
            "license_number",
            "hospital",
            "hospital_name",
            "is_available",
            "available",
            "is_app_connected",
            "patients_today",
            "app_last_seen",
            "years_experience",
            "consultation_fee",
            "rating",
            "bio",
        ]


class StaffCreateSerializer(serializers.ModelSerializer):
    first_name = serializers.CharField(write_only=True)
    last_name = serializers.CharField(write_only=True)
    email = serializers.EmailField(write_only=True)
    password = serializers.CharField(write_only=True, style={"input_type": "password"})

    class Meta:
        model = StaffProfile
        fields = [
            "first_name",
            "last_name",
            "email",
            "password",
            "role",
            "specialty",
            "phone",
            "license_number",
            "hospital",
            "is_available",
            "years_experience",
            "consultation_fee",
            "rating",
            "bio",
        ]

    def validate_email(self, value):
        lowered = value.lower()
        if User.objects.filter(email__iexact=lowered).exists():
            raise serializers.ValidationError("An account with this email already exists.")
        return lowered

    def create(self, validated_data):
        email = validated_data.pop("email")
        first_name = validated_data.pop("first_name")
        last_name = validated_data.pop("last_name")
        password = validated_data.pop("password")
        user = User.objects.create_user(
            username=email,
            email=email,
            first_name=first_name,
            last_name=last_name,
            password=password,
        )
        return StaffProfile.objects.create(user=user, **validated_data)


class StaffUpdateSerializer(serializers.ModelSerializer):
    first_name = serializers.CharField(write_only=True, required=False)
    last_name = serializers.CharField(write_only=True, required=False)
    email = serializers.EmailField(write_only=True, required=False)
    password = serializers.CharField(
        write_only=True,
        required=False,
        allow_blank=True,
        style={"input_type": "password"},
    )

    class Meta:
        model = StaffProfile
        fields = [
            "first_name",
            "last_name",
            "email",
            "password",
            "role",
            "specialty",
            "phone",
            "license_number",
            "hospital",
            "is_available",
            "years_experience",
            "consultation_fee",
            "rating",
            "bio",
        ]

    def validate_email(self, value):
        lowered = value.lower()
        qs = User.objects.filter(email__iexact=lowered)
        if self.instance:
            qs = qs.exclude(pk=self.instance.user_id)
        if qs.exists():
            raise serializers.ValidationError("An account with this email already exists.")
        return lowered

    def update(self, instance, validated_data):
        user = instance.user
        first_name = validated_data.pop("first_name", None)
        last_name = validated_data.pop("last_name", None)
        email = validated_data.pop("email", None)
        password = validated_data.pop("password", None)

        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()

        if first_name is not None:
            user.first_name = first_name
        if last_name is not None:
            user.last_name = last_name
        if email is not None:
            user.email = email
            user.username = email
        if password:
            user.set_password(password)
        user.save()
        return instance


class VitalsSerializer(serializers.ModelSerializer):
    bmi = serializers.ReadOnlyField()
    triage_level_display = serializers.CharField(
        source="get_triage_level_display",
        read_only=True,
    )

    class Meta:
        model = Vitals
        fields = [
            "id",
            "patient",
            "appointment",
            "heart_rate",
            "spo2",
            "temperature",
            "systolic_bp",
            "diastolic_bp",
            "weight_kg",
            "height_cm",
            "bmi",
            "triage_level",
            "triage_level_display",
            "source",
            "recorded_at",
        ]
        read_only_fields = ["id", "recorded_at"]

    def create(self, validated_data):
        vitals = Vitals(**validated_data)
        vitals.compute_triage()
        vitals.save()
        return vitals


class VitalsLatestSerializer(VitalsSerializer):
    class Meta(VitalsSerializer.Meta):
        fields = [
            "heart_rate",
            "spo2",
            "temperature",
            "systolic_bp",
            "diastolic_bp",
            "triage_level",
            "source",
            "recorded_at",
        ]


class NotificationPreferenceSerializer(serializers.ModelSerializer):
    color = serializers.CharField(source="color_hex", read_only=True)

    class Meta:
        model = PatientNotificationPreference
        fields = [
            "id",
            "key",
            "title",
            "subtitle",
            "icon",
            "color_hex",
            "color",
            "enabled",
        ]
        read_only_fields = ["id"]


class PatientListSerializer(serializers.ModelSerializer):
    full_name = serializers.ReadOnlyField()
    age = serializers.ReadOnlyField()
    latest_vitals = VitalsLatestSerializer(read_only=True)
    current_status = serializers.ReadOnlyField()
    current_triage = serializers.ReadOnlyField()
    consent = serializers.BooleanField(source="share_data_with_doctors", read_only=True)
    assigned_doctor_name = serializers.SerializerMethodField()
    assigned_hospital_name = serializers.SerializerMethodField()

    class Meta:
        model = Patient
        fields = [
            "id",
            "national_id",
            "full_name",
            "first_name",
            "last_name",
            "email",
            "age",
            "date_of_birth",
            "blood_type",
            "phone",
            "insurance_type",
            "insurance_number",
            "primary_hospital",
            "primary_doctor",
            "current_status",
            "current_triage",
            "consent",
            "assigned_doctor_name",
            "assigned_hospital_name",
            "latest_vitals",
        ]

    def get_assigned_doctor_name(self, obj):
        doctor = obj.current_doctor
        return doctor.user.get_full_name() if doctor else ""

    def get_assigned_hospital_name(self, obj):
        hospital = obj.current_hospital
        return hospital.name if hospital else ""


class PatientDetailSerializer(PatientListSerializer):
    bmi = serializers.ReadOnlyField()

    class Meta(PatientListSerializer.Meta):
        fields = PatientListSerializer.Meta.fields + [
            "sex",
            "profession",
            "address",
            "emergency_contact_name",
            "emergency_contact_phone",
            "weight_kg",
            "height_cm",
            "bmi",
            "is_verified",
            "auth_method",
            "share_data_with_doctors",
            "allow_analytics",
            "two_factor_enabled",
            "biometric_login",
            "location_enabled",
            "created_at",
            "updated_at",
        ]

    def update(self, instance, validated_data):
        user = instance.user
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        if user:
            user.first_name = instance.first_name
            user.last_name = instance.last_name
            if instance.email:
                user.email = instance.email
                user.username = instance.email.lower()
            user.save(update_fields=["first_name", "last_name", "email", "username"])
        instance.save()
        return instance


class PatientProfileSerializer(PatientDetailSerializer):
    notification_preferences = NotificationPreferenceSerializer(many=True, read_only=True)
    unread_notifications_count = serializers.SerializerMethodField()
    upcoming_appointments_count = serializers.SerializerMethodField()
    completed_appointments_count = serializers.SerializerMethodField()
    lab_results_count = serializers.SerializerMethodField()
    active_medications_count = serializers.SerializerMethodField()

    class Meta(PatientDetailSerializer.Meta):
        fields = PatientDetailSerializer.Meta.fields + [
            "notification_preferences",
            "unread_notifications_count",
            "upcoming_appointments_count",
            "completed_appointments_count",
            "lab_results_count",
            "active_medications_count",
        ]

    def get_unread_notifications_count(self, obj):
        return obj.notifications.filter(read=False).count()

    def get_upcoming_appointments_count(self, obj):
        return obj.appointments.filter(status="UPCOMING").count()

    def get_completed_appointments_count(self, obj):
        return obj.appointments.filter(status="COMPLETED").count()

    def get_lab_results_count(self, obj):
        return obj.patient_lab_results.count()

    def get_active_medications_count(self, obj):
        return obj.medications.filter(is_active=True).count()


class PatientCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Patient
        fields = [
            "national_id",
            "first_name",
            "last_name",
            "email",
            "date_of_birth",
            "blood_type",
            "phone",
            "sex",
            "profession",
            "insurance_type",
            "insurance_number",
            "primary_hospital",
            "primary_doctor",
            "address",
            "emergency_contact_name",
            "emergency_contact_phone",
            "weight_kg",
            "height_cm",
            "is_verified",
            "auth_method",
            "share_data_with_doctors",
            "allow_analytics",
            "two_factor_enabled",
            "biometric_login",
            "location_enabled",
        ]

    def validate_national_id(self, value):
        cleaned = value.replace(" ", "")
        if not cleaned.isdigit() or len(cleaned) != 16:
            raise serializers.ValidationError(
                "Le NID rwandais doit contenir exactement 16 chiffres."
            )
        return cleaned

    def validate_email(self, value):
        return value.lower() if value else value

    def validate(self, attrs):
        doctor = attrs.get("primary_doctor")
        hospital = attrs.get("primary_hospital")
        if doctor and doctor.role != "DOCTOR":
            raise serializers.ValidationError("Primary doctor must be a doctor account.")
        if doctor and hospital and doctor.hospital_id and doctor.hospital_id != hospital.id:
            raise serializers.ValidationError("Primary doctor does not belong to selected hospital.")
        if doctor and not hospital and doctor.hospital_id:
            attrs["primary_hospital"] = doctor.hospital
        return attrs


class MedicalFacilitySerializer(serializers.ModelSerializer):
    type = serializers.CharField(source="facility_type", read_only=True)
    type_display = serializers.CharField(source="get_facility_type_display", read_only=True)
    is_open24h = serializers.BooleanField(source="is_open_24h", read_only=True)
    distanceKm = serializers.DecimalField(source="distance_km", max_digits=6, decimal_places=2, read_only=True)
    coordinate = serializers.SerializerMethodField()

    class Meta:
        model = MedicalFacility
        fields = [
            "id",
            "name",
            "type",
            "type_display",
            "phone",
            "address",
            "district",
            "coordinate",
            "latitude",
            "longitude",
            "is_open24h",
            "rating",
            "services",
            "distanceKm",
            "hospital",
        ]

    def get_coordinate(self, obj):
        return {
            "latitude": float(obj.latitude),
            "longitude": float(obj.longitude),
        }


class DoctorDirectorySerializer(serializers.ModelSerializer):
    full_name = serializers.CharField(source="user.get_full_name", read_only=True)
    hospital_name = serializers.CharField(source="hospital.name", read_only=True)
    consult_fee = serializers.SerializerMethodField()
    experience = serializers.SerializerMethodField()
    image_placeholder = serializers.CharField(default="person.crop.circle.fill", read_only=True)
    slots = serializers.SerializerMethodField()

    class Meta:
        model = StaffProfile
        fields = [
            "id",
            "full_name",
            "specialty",
            "hospital",
            "hospital_name",
            "experience",
            "consult_fee",
            "image_placeholder",
            "rating",
            "slots",
            "phone",
            "license_number",
            "is_available",
            "bio",
        ]

    def get_consult_fee(self, obj):
        if obj.consultation_fee is None:
            return ""
        return f"RWF {int(obj.consultation_fee):,}".replace(",", ",")

    def get_experience(self, obj):
        return f"{obj.years_experience} yrs" if obj.years_experience else ""

    def get_slots(self, obj):
        slots = obj.availability_slots.filter(
            is_booked=False,
            starts_at__gte=timezone.now(),
        ).order_by("starts_at")[:6]
        return [
            {
                "id": str(slot.id),
                "label": slot.label or timezone.localtime(slot.starts_at).strftime("%I:%M %p %b %d").lstrip("0"),
                "startsAt": timezone.localtime(slot.starts_at).isoformat(),
                "endsAt": timezone.localtime(slot.ends_at).isoformat() if slot.ends_at else "",
            }
            for slot in slots
        ]


class AppointmentListSerializer(serializers.ModelSerializer):
    patient_name = serializers.CharField(source="patient.full_name", read_only=True)
    patient_nid = serializers.CharField(source="patient.national_id", read_only=True)
    doctor_name = serializers.CharField(source="doctor.user.get_full_name", read_only=True)
    doctor_specialty = serializers.CharField(source="doctor.specialty", read_only=True)
    hospital_name = serializers.CharField(source="hospital.name", read_only=True)
    status_display = serializers.CharField(source="get_status_display", read_only=True)
    portal_status = serializers.ReadOnlyField()
    appointmentID = serializers.CharField(source="reference_code", read_only=True)

    class Meta:
        model = Appointment
        fields = [
            "id",
            "appointmentID",
            "reference_code",
            "date",
            "time",
            "duration_minutes",
            "status",
            "status_display",
            "portal_status",
            "patient",
            "patient_name",
            "patient_nid",
            "doctor",
            "doctor_name",
            "doctor_specialty",
            "hospital",
            "hospital_name",
            "reason_for_visit",
            "source",
            "slot",
            "created_at",
        ]
        read_only_fields = ["id", "reference_code", "created_at"]


class AppointmentDetailSerializer(AppointmentListSerializer):
    latest_vitals = VitalsLatestSerializer(source="vitals", many=True, read_only=True)
    prescriptions = serializers.SerializerMethodField()
    lab_requests = serializers.SerializerMethodField()

    class Meta(AppointmentListSerializer.Meta):
        fields = AppointmentListSerializer.Meta.fields + [
            "soap_notes",
            "latest_vitals",
            "prescriptions",
            "lab_requests",
            "updated_at",
        ]

    def get_prescriptions(self, obj):
        return PrescriptionSerializer(obj.prescriptions.all(), many=True).data

    def get_lab_requests(self, obj):
        return LabRequestSerializer(obj.lab_requests.all(), many=True).data


class AppointmentCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Appointment
        fields = [
            "hospital",
            "doctor",
            "patient",
            "slot",
            "date",
            "time",
            "duration_minutes",
            "reason_for_visit",
            "source",
        ]
        extra_kwargs = {
            "patient": {"required": False},
            "hospital": {"required": False},
            "date": {"required": False},
            "time": {"required": False},
            "source": {"required": False},
        }

    def validate(self, data):
        slot = data.get("slot")
        doctor = data.get("doctor")
        hospital = data.get("hospital")

        if slot:
            if slot.is_booked:
                raise serializers.ValidationError("This slot has already been booked.")
            if doctor and slot.doctor_id != doctor.id:
                raise serializers.ValidationError("The selected slot does not belong to that doctor.")
            data["doctor"] = slot.doctor
            data["hospital"] = slot.doctor.hospital
            data["date"] = timezone.localtime(slot.starts_at).date()
            data["time"] = timezone.localtime(slot.starts_at).time().replace(second=0, microsecond=0)

        doctor = data.get("doctor")
        hospital = data.get("hospital")
        if not doctor:
            raise serializers.ValidationError("A doctor is required.")
        if doctor.role != "DOCTOR":
            raise serializers.ValidationError("Appointments can only be assigned to a doctor.")
        if hospital and doctor.hospital_id and doctor.hospital_id != hospital.id:
            raise serializers.ValidationError("The selected doctor does not belong to that hospital.")
        if not hospital and doctor.hospital:
            data["hospital"] = doctor.hospital

        if "date" not in data or "time" not in data:
            raise serializers.ValidationError("Both date and time are required.")

        qs = Appointment.objects.filter(
            doctor=data["doctor"],
            date=data["date"],
            time=data["time"],
        ).exclude(status__in=["CANCELLED", "NO_SHOW"])
        if self.instance:
            qs = qs.exclude(pk=self.instance.pk)
        if qs.exists():
            raise serializers.ValidationError(
                "This doctor already has an appointment in that time slot."
            )

        patient = data.get("patient")
        request = self.context.get("request")
        if not patient and request and hasattr(request.user, "patient_profile"):
            data["patient"] = request.user.patient_profile
        if not data.get("patient"):
            raise serializers.ValidationError("A patient is required.")

        return data


class AppointmentUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Appointment
        fields = [
            "hospital",
            "doctor",
            "patient",
            "slot",
            "date",
            "time",
            "duration_minutes",
            "reason_for_visit",
            "source",
            "status",
            "soap_notes",
        ]
        extra_kwargs = {
            "patient": {"required": False},
            "hospital": {"required": False},
            "doctor": {"required": False},
            "slot": {"required": False, "allow_null": True},
            "date": {"required": False},
            "time": {"required": False},
            "duration_minutes": {"required": False},
            "reason_for_visit": {"required": False},
            "source": {"required": False},
            "status": {"required": False},
            "soap_notes": {"required": False},
        }

    def validate(self, data):
        instance = self.instance
        slot = data.get("slot", instance.slot if instance else None)
        doctor = data.get("doctor", instance.doctor if instance else None)
        hospital = data.get("hospital", instance.hospital if instance else None)
        date_value = data.get("date", instance.date if instance else None)
        time_value = data.get("time", instance.time if instance else None)
        patient = data.get("patient", instance.patient if instance else None)

        if slot:
            slot_conflict = slot.is_booked and (
                not instance or slot.id != instance.slot_id
            )
            if slot_conflict:
                raise serializers.ValidationError("This slot has already been booked.")
            doctor = slot.doctor
            hospital = slot.doctor.hospital
            date_value = timezone.localtime(slot.starts_at).date()
            time_value = timezone.localtime(slot.starts_at).time().replace(second=0, microsecond=0)
            data["doctor"] = doctor
            data["hospital"] = hospital
            data["date"] = date_value
            data["time"] = time_value

        if doctor and doctor.role != "DOCTOR":
            raise serializers.ValidationError("Appointments can only be assigned to a doctor.")
        if doctor and hospital and doctor.hospital_id and doctor.hospital_id != hospital.id:
            raise serializers.ValidationError("The selected doctor does not belong to that hospital.")
        if doctor and not hospital and doctor.hospital:
            data["hospital"] = doctor.hospital
            hospital = doctor.hospital

        if doctor and date_value and time_value:
            qs = Appointment.objects.filter(
                doctor=doctor,
                date=date_value,
                time=time_value,
            ).exclude(status__in=["CANCELLED", "NO_SHOW"])
            if instance:
                qs = qs.exclude(pk=instance.pk)
            if qs.exists():
                raise serializers.ValidationError(
                    "This doctor already has an appointment in that time slot."
                )

        if "patient" in data and not patient:
            raise serializers.ValidationError("A patient is required.")

        return data


class PrescriptionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Prescription
        fields = [
            "id",
            "appointment",
            "medication_name",
            "dosage",
            "duration_days",
            "instructions",
            "notified_patient",
            "created_at",
        ]
        read_only_fields = ["id", "created_at", "notified_patient"]


class LabRequestSerializer(serializers.ModelSerializer):
    status_display = serializers.CharField(source="get_status_display", read_only=True)

    class Meta:
        model = LabRequest
        fields = [
            "id",
            "appointment",
            "test_name",
            "notes",
            "status",
            "status_display",
            "result_summary",
            "result_file",
            "doctor_notified",
            "requested_at",
            "results_at",
        ]
        read_only_fields = ["id", "requested_at", "doctor_notified"]


class PatientLabResultSerializer(serializers.ModelSerializer):
    class Meta:
        model = PatientLabResult
        fields = [
            "id",
            "patient",
            "appointment",
            "lab_request",
            "test_name",
            "date",
            "result",
            "reference_range",
            "icon",
            "is_abnormal",
            "notes",
            "created_at",
        ]
        read_only_fields = ["id", "created_at"]


class MedicalHistoryEntrySerializer(serializers.ModelSerializer):
    doctor_name = serializers.SerializerMethodField()
    diagnosed_date_label = serializers.SerializerMethodField()

    class Meta:
        model = MedicalHistoryEntry
        fields = [
            "id",
            "patient",
            "doctor",
            "doctor_name",
            "condition",
            "diagnosed_date",
            "diagnosed_date_label",
            "status",
            "notes",
            "icon",
            "color_hex",
            "created_at",
        ]
        read_only_fields = ["id", "created_at"]

    def get_doctor_name(self, obj):
        return obj.doctor.user.get_full_name() if obj.doctor else ""

    def get_diagnosed_date_label(self, obj):
        if not obj.diagnosed_date:
            return ""
        return obj.diagnosed_date.strftime("%b %Y")


class MedicationPlanSerializer(serializers.ModelSerializer):
    color = serializers.CharField(source="color_hex", read_only=True)
    nextDose = serializers.SerializerMethodField()

    class Meta:
        model = MedicationPlan
        fields = [
            "id",
            "patient",
            "prescription",
            "name",
            "dosage",
            "frequency",
            "next_dose_at",
            "nextDose",
            "remaining",
            "total",
            "color_hex",
            "color",
            "is_active",
            "created_at",
        ]
        read_only_fields = ["id", "created_at"]

    def get_nextDose(self, obj):
        if not obj.next_dose_at:
            return ""
        return timezone.localtime(obj.next_dose_at).strftime("%I:%M %p").lstrip("0")


class SymptomAssessmentSerializer(serializers.ModelSerializer):
    class Meta:
        model = SymptomAssessment
        fields = [
            "id",
            "patient",
            "heart_rate",
            "spo2",
            "temperature",
            "symptoms",
            "makes_worse",
            "feeling",
            "location",
            "pain_level",
            "started_when",
            "triage_level",
            "triage_advice",
            "recommended_facility",
            "recommended_doctor",
            "chosen_slot_label",
            "created_at",
        ]
        read_only_fields = ["id", "triage_level", "triage_advice", "created_at"]


class PreAdmissionSerializer(serializers.ModelSerializer):
    hospital_name = serializers.CharField(source="hospital.name", read_only=True)

    class Meta:
        model = PreAdmission
        fields = [
            "id",
            "patient",
            "submitted_by",
            "hospital",
            "hospital_name",
            "full_name",
            "phone",
            "email",
            "date_of_birth",
            "insurance_type",
            "is_routine",
            "is_ill",
            "symptoms",
            "agreed",
            "status",
            "submitted_at",
        ]
        read_only_fields = ["id", "submitted_at", "status", "submitted_by", "patient"]

    def validate(self, data):
        if not data.get("agreed"):
            raise serializers.ValidationError(
                "The pre-admission form must be acknowledged before submission."
            )
        return data


class IOSNotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = IOSNotification
        fields = [
            "id",
            "notif_type",
            "title",
            "body",
            "data_payload",
            "sent_at",
            "delivered",
            "read",
            "read_at",
        ]
        read_only_fields = ["id", "sent_at"]


class AuditLogSerializer(serializers.ModelSerializer):
    actor_name = serializers.CharField(source="actor.get_full_name", read_only=True)
    hospital_name = serializers.CharField(source="hospital.name", read_only=True)
    log_type_display = serializers.CharField(source="get_log_type_display", read_only=True)
    action_display = serializers.CharField(source="get_action_display", read_only=True)

    class Meta:
        model = AuditLog
        fields = [
            "id",
            "actor_name",
            "log_type",
            "log_type_display",
            "action",
            "action_display",
            "description",
            "hospital_name",
            "ip_address",
            "timestamp",
        ]
        read_only_fields = fields


class DashboardSummarySerializer(serializers.Serializer):
    patients_today = serializers.IntegerField()
    waiting = serializers.IntegerField()
    in_progress = serializers.IntegerField()
    completed = serializers.IntegerField()
    urgent = serializers.IntegerField()
    hospitals_online = serializers.IntegerField()
    doctors_available = serializers.IntegerField()
    ios_notifications_unread = serializers.IntegerField()


class MobileDashboardSerializer(serializers.Serializer):
    profile = PatientProfileSerializer()
    next_appointment = AppointmentListSerializer(allow_null=True)
    medications = MedicationPlanSerializer(many=True)
    recent_lab_results = PatientLabResultSerializer(many=True)
    unread_notifications = serializers.IntegerField()


class PatientRegisterSerializer(serializers.Serializer):
    first_name = serializers.CharField()
    last_name = serializers.CharField()
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, style={"input_type": "password"})
    phone = serializers.CharField()
    national_id = serializers.CharField()
    date_of_birth = serializers.DateField()
    blood_type = serializers.ChoiceField(choices=Patient.BLOOD_TYPES)
    auth_method = serializers.CharField(required=False, allow_blank=True)
    device_token = serializers.CharField(required=False, allow_blank=True)

    def validate_email(self, value):
        lowered = value.lower()
        if User.objects.filter(email__iexact=lowered).exists():
            raise serializers.ValidationError("An account with this email already exists.")
        return lowered

    def validate_national_id(self, value):
        cleaned = value.replace(" ", "")
        if not cleaned.isdigit() or len(cleaned) != 16:
            raise serializers.ValidationError("National ID must contain exactly 16 digits.")
        if Patient.objects.filter(national_id=cleaned).exists():
            raise serializers.ValidationError("A patient with this National ID already exists.")
        return cleaned

    def create(self, validated_data):
        email = validated_data["email"]
        password = validated_data["password"]
        user = User.objects.create_user(
            username=email,
            email=email,
            first_name=validated_data["first_name"],
            last_name=validated_data["last_name"],
            password=password,
        )
        patient = Patient.objects.create(
            user=user,
            first_name=validated_data["first_name"],
            last_name=validated_data["last_name"],
            email=email,
            phone=validated_data["phone"],
            national_id=validated_data["national_id"],
            date_of_birth=validated_data["date_of_birth"],
            blood_type=validated_data["blood_type"],
            auth_method=validated_data.get("auth_method", "email"),
            ios_device_token=validated_data.get("device_token", ""),
            app_last_seen=timezone.now(),
        )
        return patient


class PatientLoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, style={"input_type": "password"})
    auth_method = serializers.CharField(required=False, allow_blank=True)
    device_token = serializers.CharField(required=False, allow_blank=True)


class SupabaseSessionAuthSerializer(serializers.Serializer):
    access_token = serializers.CharField()
    auth_method = serializers.CharField(required=False, allow_blank=True)
    first_name = serializers.CharField(required=False, allow_blank=True)
    last_name = serializers.CharField(required=False, allow_blank=True)
    phone = serializers.CharField(required=False, allow_blank=True)
    national_id = serializers.CharField(required=False, allow_blank=True)
    date_of_birth = serializers.DateField(required=False)
    blood_type = serializers.ChoiceField(choices=Patient.BLOOD_TYPES, required=False)

    def validate_national_id(self, value):
        cleaned = value.replace(" ", "")
        if not cleaned:
            return ""
        if not cleaned.isdigit() or len(cleaned) != 16:
            raise serializers.ValidationError("National ID must contain exactly 16 digits.")
        return cleaned

    def validate_date_of_birth(self, value):
        if value > date.today():
            raise serializers.ValidationError("Date of birth cannot be in the future.")
        return value

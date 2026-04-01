import uuid
from datetime import date

from django.contrib.auth.models import User
from django.db import models
from django.utils import timezone


class Hospital(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=255)
    district = models.CharField(max_length=100)
    address = models.TextField(blank=True)
    phone = models.CharField(max_length=20)
    email = models.EmailField(blank=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    type = models.CharField(max_length=50, default="Public hospital")
    total_beds = models.PositiveIntegerField(default=0)
    occupied_beds = models.PositiveIntegerField(default=0)
    rwandacare_sync_enabled = models.BooleanField(default=False)
    sync_token = models.CharField(max_length=64, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.name

    @property
    def occupancy_rate(self):
        if self.total_beds == 0:
            return 0
        return round((self.occupied_beds / self.total_beds) * 100, 1)

    @property
    def doctor_count(self):
        return self.staff.filter(role="DOCTOR").count()


class StaffProfile(models.Model):
    ROLE_CHOICES = [
        ("SUPERADMIN", "Super Admin"),
        ("ADMIN", "Hospital Admin"),
        ("DOCTOR", "Doctor"),
        ("NURSE", "Nurse"),
        ("LAB", "Lab Technician"),
    ]

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name="staff_profile")
    hospital = models.ForeignKey(
        Hospital,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="staff",
    )
    role = models.CharField(max_length=20, choices=ROLE_CHOICES)
    specialty = models.CharField(max_length=100, blank=True)
    phone = models.CharField(max_length=20, blank=True)
    license_number = models.CharField(max_length=50, blank=True)
    is_available = models.BooleanField(default=True)
    years_experience = models.PositiveSmallIntegerField(default=0)
    consultation_fee = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    rating = models.DecimalField(max_digits=3, decimal_places=2, default=0)
    bio = models.TextField(blank=True)
    ios_device_token = models.CharField(max_length=255, blank=True)
    app_last_seen = models.DateTimeField(null=True, blank=True)
    profile_picture = models.FileField(upload_to="staff/", blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["user__last_name", "user__first_name"]

    def __str__(self):
        prefix = "Dr." if self.role == "DOCTOR" else ""
        return f"{prefix} {self.user.get_full_name()}".strip()

    @property
    def is_app_connected(self):
        if not self.app_last_seen:
            return False
        return (timezone.now() - self.app_last_seen).total_seconds() < 86400

    @property
    def patients_today(self):
        from django.utils.timezone import localdate

        return self.appointments.filter(date=localdate()).count()


class Patient(models.Model):
    BLOOD_TYPES = [
        ("O+", "O+"),
        ("O-", "O-"),
        ("A+", "A+"),
        ("A-", "A-"),
        ("B+", "B+"),
        ("B-", "B-"),
        ("AB+", "AB+"),
        ("AB-", "AB-"),
    ]
    INSURANCE_CHOICES = [
        ("RSSB", "RSSB"),
        ("MUTUELLE", "Community Health Insurance"),
        ("PRIVATE", "Private Insurance"),
        ("NONE", "None"),
    ]
    SEX_CHOICES = [
        ("M", "Male"),
        ("F", "Female"),
        ("OTHER", "Other"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="patient_profile",
    )
    primary_hospital = models.ForeignKey(
        Hospital,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="primary_patients",
    )
    primary_doctor = models.ForeignKey(
        StaffProfile,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="primary_patients",
        limit_choices_to={"role": "DOCTOR"},
    )
    national_id = models.CharField(max_length=16, unique=True, db_index=True)
    first_name = models.CharField(max_length=100)
    last_name = models.CharField(max_length=100)
    email = models.EmailField(blank=True)
    date_of_birth = models.DateField()
    blood_type = models.CharField(max_length=5, choices=BLOOD_TYPES)
    phone = models.CharField(max_length=20)
    sex = models.CharField(max_length=10, choices=SEX_CHOICES, blank=True)
    profession = models.CharField(max_length=100, blank=True)
    insurance_type = models.CharField(max_length=20, choices=INSURANCE_CHOICES, default="RSSB")
    insurance_number = models.CharField(max_length=50, blank=True)
    address = models.TextField(blank=True)
    emergency_contact_name = models.CharField(max_length=150, blank=True)
    emergency_contact_phone = models.CharField(max_length=20, blank=True)
    weight_kg = models.DecimalField(max_digits=5, decimal_places=1, null=True, blank=True)
    height_cm = models.PositiveSmallIntegerField(null=True, blank=True)
    is_verified = models.BooleanField(default=False)
    auth_method = models.CharField(max_length=30, blank=True)
    share_data_with_doctors = models.BooleanField(default=True)
    allow_analytics = models.BooleanField(default=False)
    two_factor_enabled = models.BooleanField(default=False)
    biometric_login = models.BooleanField(default=True)
    location_enabled = models.BooleanField(default=True)
    ios_device_token = models.CharField(max_length=255, blank=True)
    app_last_seen = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["last_name", "first_name"]

    def __str__(self):
        return f"{self.first_name} {self.last_name} ({self.national_id})"

    @property
    def full_name(self):
        return f"{self.first_name} {self.last_name}".strip()

    @property
    def age(self):
        today = date.today()
        return today.year - self.date_of_birth.year - (
            (today.month, today.day) < (self.date_of_birth.month, self.date_of_birth.day)
        )

    @property
    def bmi(self):
        if self.weight_kg and self.height_cm:
            height_m = float(self.height_cm) / 100
            if height_m > 0:
                return round(float(self.weight_kg) / (height_m * height_m), 1)
        return None

    @property
    def is_app_connected(self):
        if not self.app_last_seen:
            return False
        return (timezone.now() - self.app_last_seen).total_seconds() < 86400

    @property
    def latest_vitals(self):
        return self.vitals.order_by("-recorded_at").first()

    @property
    def current_appointment(self):
        return (
            self.appointments.filter(status__in=["UPCOMING", "IN_PROGRESS"])
            .select_related("doctor__user", "hospital")
            .order_by("date", "time")
            .first()
        )

    @property
    def current_status(self):
        appointment = self.current_appointment
        if not appointment:
            latest = self.appointments.order_by("-date", "-time").first()
            if latest and latest.status == "COMPLETED":
                return "Completed"
            return "Inactive"
        mapping = {
            "UPCOMING": "Waiting",
            "IN_PROGRESS": "In consultation",
            "COMPLETED": "Completed",
            "CANCELLED": "Cancelled",
            "NO_SHOW": "No show",
        }
        return mapping.get(appointment.status, appointment.status.title())

    @property
    def current_doctor(self):
        appointment = self.current_appointment
        return appointment.doctor if appointment else self.primary_doctor

    @property
    def current_hospital(self):
        appointment = self.current_appointment
        return appointment.hospital if appointment else self.primary_hospital

    @property
    def current_triage(self):
        vitals = self.latest_vitals
        if not vitals:
            return "Normal"
        return vitals.get_triage_level_display()


class MedicalFacility(models.Model):
    FACILITY_TYPE_CHOICES = [
        ("HOSPITAL", "Hospital"),
        ("PHARMACY", "Pharmacy"),
        ("CLINIC", "Clinic"),
        ("DENTAL", "Dental"),
        ("EYE", "Eye Care"),
        ("LAB", "Laboratory"),
        ("HEALTH_POST", "Health Post"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    hospital = models.OneToOneField(
        Hospital,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="facility_profile",
    )
    name = models.CharField(max_length=255)
    facility_type = models.CharField(max_length=20, choices=FACILITY_TYPE_CHOICES)
    phone = models.CharField(max_length=20)
    address = models.TextField(blank=True)
    district = models.CharField(max_length=100)
    latitude = models.DecimalField(max_digits=9, decimal_places=6)
    longitude = models.DecimalField(max_digits=9, decimal_places=6)
    is_open_24h = models.BooleanField(default=False)
    rating = models.DecimalField(max_digits=3, decimal_places=2, default=0)
    services = models.JSONField(default=list, blank=True)
    distance_km = models.DecimalField(max_digits=6, decimal_places=2, default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["facility_type", "name"]

    def __str__(self):
        return f"{self.get_facility_type_display()} - {self.name}"


class DoctorAvailabilitySlot(models.Model):
    SOURCE_CHOICES = [
        ("IOS_APP", "iOS App"),
        ("PORTAL", "Web Portal"),
        ("SYSTEM", "System"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    doctor = models.ForeignKey(
        StaffProfile,
        on_delete=models.CASCADE,
        related_name="availability_slots",
        limit_choices_to={"role": "DOCTOR"},
    )
    label = models.CharField(max_length=120, blank=True)
    starts_at = models.DateTimeField()
    ends_at = models.DateTimeField(null=True, blank=True)
    is_booked = models.BooleanField(default=False)
    source = models.CharField(max_length=20, choices=SOURCE_CHOICES, default="PORTAL")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["starts_at"]

    def __str__(self):
        return self.label or f"{self.doctor} @ {self.starts_at:%Y-%m-%d %H:%M}"


class Vitals(models.Model):
    TRIAGE_CHOICES = [
        ("URGENT", "Urgent"),
        ("MODERE", "Moderate"),
        ("NORMAL", "Normal"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(Patient, on_delete=models.CASCADE, related_name="vitals")
    appointment = models.ForeignKey(
        "Appointment",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="vitals",
    )
    heart_rate = models.PositiveSmallIntegerField(null=True, blank=True)
    spo2 = models.DecimalField(max_digits=4, decimal_places=1, null=True, blank=True)
    temperature = models.DecimalField(max_digits=4, decimal_places=1, null=True, blank=True)
    systolic_bp = models.PositiveSmallIntegerField(null=True, blank=True)
    diastolic_bp = models.PositiveSmallIntegerField(null=True, blank=True)
    weight_kg = models.DecimalField(max_digits=5, decimal_places=1, null=True, blank=True)
    height_cm = models.PositiveSmallIntegerField(null=True, blank=True)
    triage_level = models.CharField(max_length=10, choices=TRIAGE_CHOICES, default="NORMAL")
    source = models.CharField(
        max_length=20,
        choices=[("IOS_APP", "iOS App"), ("PORTAL", "Web Portal"), ("DEVICE", "Medical Device")],
        default="IOS_APP",
    )
    recorded_at = models.DateTimeField(default=timezone.now)

    class Meta:
        ordering = ["-recorded_at"]
        verbose_name_plural = "Vitals"

    def __str__(self):
        return f"Vitals for {self.patient} at {self.recorded_at:%Y-%m-%d %H:%M}"

    @property
    def bmi(self):
        if self.weight_kg and self.height_cm:
            height_m = float(self.height_cm) / 100
            if height_m > 0:
                return round(float(self.weight_kg) / (height_m * height_m), 1)
        return None

    def compute_triage(self):
        urgent = (
            (self.heart_rate and (self.heart_rate > 120 or self.heart_rate < 50))
            or (self.spo2 and self.spo2 < 95)
            or (self.temperature and (self.temperature > 39.5 or self.temperature < 35))
            or (self.systolic_bp and self.systolic_bp > 180)
        )
        moderate = (
            (self.heart_rate and (self.heart_rate > 100 or self.heart_rate < 60))
            or (self.spo2 and self.spo2 < 97)
            or (self.temperature and self.temperature > 37.5)
        )
        if urgent:
            self.triage_level = "URGENT"
        elif moderate:
            self.triage_level = "MODERE"
        else:
            self.triage_level = "NORMAL"
        return self.triage_level


class Appointment(models.Model):
    STATUS_CHOICES = [
        ("UPCOMING", "Upcoming"),
        ("IN_PROGRESS", "In Progress"),
        ("COMPLETED", "Completed"),
        ("CANCELLED", "Cancelled"),
        ("NO_SHOW", "No Show"),
    ]
    SOURCE_CHOICES = [
        ("IOS_APP", "iOS App"),
        ("PORTAL", "Web Portal"),
        ("WALK_IN", "Walk-in"),
        ("PHONE", "Phone"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    reference_code = models.CharField(max_length=20, unique=True, blank=True, db_index=True)
    hospital = models.ForeignKey(Hospital, on_delete=models.CASCADE, related_name="appointments")
    doctor = models.ForeignKey(
        StaffProfile,
        on_delete=models.CASCADE,
        limit_choices_to={"role": "DOCTOR"},
        related_name="appointments",
    )
    patient = models.ForeignKey(Patient, on_delete=models.CASCADE, related_name="appointments")
    slot = models.ForeignKey(
        DoctorAvailabilitySlot,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="appointments",
    )
    date = models.DateField()
    time = models.TimeField()
    duration_minutes = models.PositiveSmallIntegerField(default=30)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="UPCOMING")
    reason_for_visit = models.TextField(blank=True)
    source = models.CharField(max_length=20, choices=SOURCE_CHOICES, default="IOS_APP")
    soap_notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["date", "time"]

    def __str__(self):
        return f"{self.patient.last_name} ↔ {self.doctor} on {self.date} at {self.time}"

    @property
    def portal_status(self):
        mapping = {
            "UPCOMING": "Confirmed",
            "IN_PROGRESS": "Checked in",
            "COMPLETED": "Completed",
            "CANCELLED": "Cancelled",
            "NO_SHOW": "No show",
        }
        return mapping.get(self.status, self.status.title())

    def save(self, *args, **kwargs):
        if not self.reference_code:
            reference_stub = self.id.hex[:6].upper()
            self.reference_code = f"RDV-{reference_stub}"
        super().save(*args, **kwargs)


class Prescription(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    appointment = models.ForeignKey(
        Appointment,
        on_delete=models.CASCADE,
        related_name="prescriptions",
    )
    medication_name = models.CharField(max_length=200)
    dosage = models.CharField(max_length=100)
    duration_days = models.PositiveSmallIntegerField(null=True, blank=True)
    instructions = models.TextField(blank=True)
    notified_patient = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.medication_name} — {self.appointment.patient.last_name}"


class LabRequest(models.Model):
    STATUS_CHOICES = [
        ("PENDING", "Pending"),
        ("IN_LAB", "In Lab"),
        ("RESULTS_READY", "Results Ready"),
        ("REVIEWED", "Reviewed by Doctor"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    appointment = models.ForeignKey(
        Appointment,
        on_delete=models.CASCADE,
        related_name="lab_requests",
    )
    test_name = models.CharField(max_length=200)
    notes = models.TextField(blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="PENDING")
    result_file = models.FileField(upload_to="lab_results/", blank=True, null=True)
    result_summary = models.TextField(blank=True)
    doctor_notified = models.BooleanField(default=False)
    requested_at = models.DateTimeField(auto_now_add=True)
    results_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"{self.test_name} — {self.appointment.patient.last_name}"


class PatientLabResult(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(Patient, on_delete=models.CASCADE, related_name="patient_lab_results")
    appointment = models.ForeignKey(
        Appointment,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="patient_lab_results",
    )
    lab_request = models.OneToOneField(
        LabRequest,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="patient_result",
    )
    test_name = models.CharField(max_length=200)
    date = models.DateField(default=timezone.localdate)
    result = models.CharField(max_length=200)
    reference_range = models.CharField(max_length=120, blank=True)
    icon = models.CharField(max_length=50, default="doc.text.fill")
    is_abnormal = models.BooleanField(default=False)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-date", "-created_at"]

    def __str__(self):
        return f"{self.test_name} — {self.patient.full_name}"


class MedicalHistoryEntry(models.Model):
    STATUS_CHOICES = [
        ("MONITORING", "Monitoring"),
        ("CONTROLLED", "Controlled"),
        ("RESOLVED", "Resolved"),
        ("ACTIVE", "Active"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(Patient, on_delete=models.CASCADE, related_name="medical_history_entries")
    doctor = models.ForeignKey(
        StaffProfile,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="medical_history_entries",
    )
    condition = models.CharField(max_length=200)
    diagnosed_date = models.DateField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="ACTIVE")
    notes = models.TextField(blank=True)
    icon = models.CharField(max_length=50, default="cross.case.fill")
    color_hex = models.CharField(max_length=7, default="#22C55E")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-diagnosed_date", "-created_at"]

    def __str__(self):
        return f"{self.condition} — {self.patient.full_name}"


class MedicationPlan(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(Patient, on_delete=models.CASCADE, related_name="medications")
    prescription = models.ForeignKey(
        Prescription,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="medication_plans",
    )
    name = models.CharField(max_length=200)
    dosage = models.CharField(max_length=100)
    frequency = models.CharField(max_length=100)
    next_dose_at = models.DateTimeField(null=True, blank=True)
    remaining = models.PositiveIntegerField(default=0)
    total = models.PositiveIntegerField(default=0)
    color_hex = models.CharField(max_length=7, default="#22C55E")
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["next_dose_at", "-created_at"]

    def __str__(self):
        return f"{self.name} — {self.patient.full_name}"


class PatientNotificationPreference(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(
        Patient,
        on_delete=models.CASCADE,
        related_name="notification_preferences",
    )
    key = models.CharField(max_length=50)
    title = models.CharField(max_length=100)
    subtitle = models.CharField(max_length=150, blank=True)
    icon = models.CharField(max_length=50, default="bell.fill")
    color_hex = models.CharField(max_length=7, default="#3B82F6")
    enabled = models.BooleanField(default=True)

    class Meta:
        ordering = ["title"]
        unique_together = ("patient", "key")

    def __str__(self):
        return f"{self.patient.full_name} - {self.title}"


class SymptomAssessment(models.Model):
    TRIAGE_CHOICES = [
        ("URGENT", "Urgent"),
        ("MODERATE", "Moderate"),
        ("MILD", "Mild"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(
        Patient,
        on_delete=models.CASCADE,
        related_name="symptom_assessments",
    )
    heart_rate = models.PositiveSmallIntegerField(null=True, blank=True)
    spo2 = models.DecimalField(max_digits=4, decimal_places=1, null=True, blank=True)
    temperature = models.DecimalField(max_digits=4, decimal_places=1, null=True, blank=True)
    symptoms = models.JSONField(default=list, blank=True)
    makes_worse = models.CharField(max_length=120, blank=True)
    feeling = models.CharField(max_length=120, blank=True)
    location = models.CharField(max_length=120, blank=True)
    pain_level = models.PositiveSmallIntegerField(default=0)
    started_when = models.CharField(max_length=120, blank=True)
    triage_level = models.CharField(max_length=20, choices=TRIAGE_CHOICES, blank=True)
    triage_advice = models.TextField(blank=True)
    recommended_facility = models.ForeignKey(
        MedicalFacility,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="recommended_assessments",
    )
    recommended_doctor = models.ForeignKey(
        StaffProfile,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="recommended_assessments",
    )
    chosen_slot_label = models.CharField(max_length=120, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"Assessment for {self.patient.full_name} at {self.created_at:%Y-%m-%d %H:%M}"

    def compute_triage(self):
        if (
            self.pain_level >= 8
            or self.location == "Chest or upper back"
            or (self.spo2 and self.spo2 < 95)
        ):
            self.triage_level = "URGENT"
            self.triage_advice = (
                "Your symptoms suggest emergency care is needed immediately. "
                "Go to the nearest hospital."
            )
        elif (
            self.pain_level <= 3
            and (not self.heart_rate or self.heart_rate < 95)
            and (not self.temperature or self.temperature < 38)
        ):
            self.triage_level = "MILD"
            self.triage_advice = (
                "Your symptoms appear mild. A pharmacist may help with basic treatment."
            )
        else:
            self.triage_level = "MODERATE"
            self.triage_advice = (
                "You should see a doctor today or tomorrow. Book an appointment or visit a clinic."
            )
        return self.triage_level

    def save(self, *args, **kwargs):
        if not self.triage_level:
            self.compute_triage()
        super().save(*args, **kwargs)


class PreAdmission(models.Model):
    STATUS_CHOICES = [
        ("SUBMITTED", "Submitted"),
        ("REVIEWED", "Reviewed"),
        ("APPROVED", "Approved"),
        ("REJECTED", "Rejected"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(
        Patient,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="pre_admissions",
    )
    submitted_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="submitted_pre_admissions",
    )
    hospital = models.ForeignKey(Hospital, on_delete=models.CASCADE, related_name="pre_admissions")
    full_name = models.CharField(max_length=200)
    phone = models.CharField(max_length=20)
    email = models.EmailField(blank=True)
    date_of_birth = models.DateField(null=True, blank=True)
    insurance_type = models.CharField(max_length=20, choices=Patient.INSURANCE_CHOICES, default="RSSB")
    is_routine = models.BooleanField(default=True)
    is_ill = models.BooleanField(default=False)
    symptoms = models.TextField(blank=True)
    agreed = models.BooleanField(default=False)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="SUBMITTED")
    submitted_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-submitted_at"]

    def __str__(self):
        return f"Pre-admission {self.full_name} → {self.hospital.name}"


class IOSNotification(models.Model):
    NOTIF_TYPE_CHOICES = [
        ("BOOKING_CONFIRM", "Booking Confirmed"),
        ("BOOKING_REMINDER", "Appointment Reminder"),
        ("VITALS_ALERT", "Vitals Alert"),
        ("PRESCRIPTION", "New Prescription"),
        ("LAB_READY", "Lab Results Ready"),
        ("GENERAL", "General"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    recipient_patient = models.ForeignKey(
        Patient,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="notifications",
    )
    recipient_staff = models.ForeignKey(
        StaffProfile,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="notifications",
    )
    notif_type = models.CharField(max_length=30, choices=NOTIF_TYPE_CHOICES)
    title = models.CharField(max_length=200)
    body = models.TextField()
    data_payload = models.JSONField(default=dict, blank=True)
    sent_at = models.DateTimeField(auto_now_add=True)
    delivered = models.BooleanField(default=False)
    read = models.BooleanField(default=False)
    read_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-sent_at"]

    def __str__(self):
        target = self.recipient_patient or self.recipient_staff
        return f"[{self.notif_type}] → {target} at {self.sent_at:%H:%M}"


class AuditLog(models.Model):
    LOG_TYPE_CHOICES = [
        ("INFO", "Info"),
        ("WARNING", "Warning"),
        ("ERROR", "Error"),
        ("SECURITY", "Security"),
    ]
    ACTION_CHOICES = [
        ("LOGIN", "User Login"),
        ("LOGIN_FAILED", "Failed Login"),
        ("LOGOUT", "Logout"),
        ("CREATE", "Record Created"),
        ("UPDATE", "Record Updated"),
        ("DELETE", "Record Deleted"),
        ("CONSULT_OPEN", "Consultation Opened"),
        ("CONSULT_CLOSE", "Consultation Closed"),
        ("PRESCRIPTION", "Prescription Issued"),
        ("LAB_REQUEST", "Lab Request"),
        ("SYNC_OK", "iOS Sync Success"),
        ("SYNC_FAIL", "iOS Sync Failed"),
        ("ROLE_CHANGE", "Role Changed"),
        ("ACCOUNT_SUSPEND", "Account Suspended"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    actor = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="audit_logs",
    )
    log_type = models.CharField(max_length=10, choices=LOG_TYPE_CHOICES, default="INFO")
    action = models.CharField(max_length=30, choices=ACTION_CHOICES)
    description = models.TextField()
    hospital = models.ForeignKey(
        Hospital,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
    )
    meta = models.JSONField(default=dict, blank=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.CharField(max_length=300, blank=True)
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-timestamp"]

    def __str__(self):
        actor = self.actor.get_full_name() if self.actor else "System"
        return f"[{self.log_type}] {self.action} by {actor} at {self.timestamp:%Y-%m-%d %H:%M}"

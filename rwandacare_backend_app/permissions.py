from rest_framework import permissions


def _get_role(user):
    """Helper: returns the staff role string or None."""
    try:
        return user.staff_profile.role
    except AttributeError:
        return None


class IsSuperAdmin(permissions.BasePermission):
    """
    Grants access only to users with role SUPERADMIN.
    Maps to the 'superadmin' role in the portal & iOS admin section.
    """
    message = "Access is limited to super administrators."

    def has_permission(self, request, view):
        return (
            request.user.is_authenticated and
            _get_role(request.user) == 'SUPERADMIN'
        )


class IsHospitalAdmin(permissions.BasePermission):
    """
    Grants access to ADMIN or SUPERADMIN roles.
    Maps to hospital management pages in the portal.
    """
    message = "Access is limited to hospital administrators."

    def has_permission(self, request, view):
        return (
            request.user.is_authenticated and
            _get_role(request.user) in ('ADMIN', 'SUPERADMIN')
        )


class IsDoctor(permissions.BasePermission):
    """Grants access to DOCTOR role (and above)."""
    message = "Access is limited to doctors."

    def has_permission(self, request, view):
        return (
            request.user.is_authenticated and
            _get_role(request.user) in ('DOCTOR', 'ADMIN', 'SUPERADMIN')
        )


class IsMedicalStaff(permissions.BasePermission):
    """
    Any authenticated staff member (doctor, nurse, lab, admin, superadmin).
    Used for endpoints that all staff can read but only specific roles can write.
    """
    def has_permission(self, request, view):
        return (
            request.user.is_authenticated and
            _get_role(request.user) is not None
        )


class IsPatientOwner(permissions.BasePermission):
    """
    Patients can only access their own records.
    Used for iOS app patient-facing endpoints.
    """
    message = "You can only access your own data."

    def has_object_permission(self, request, view, obj):
        try:
            return obj.patient.user == request.user
        except AttributeError:
            return False


class IsPatientUser(permissions.BasePermission):
    """
    Authenticated user linked to a patient profile.
    Used for patient-facing mobile endpoints.
    """
    message = "Access is limited to signed-in patients."

    def has_permission(self, request, view):
        return (
            request.user.is_authenticated and
            hasattr(request.user, 'patient_profile')
        )


class IsSameHospital(permissions.BasePermission):
    """
    A staff member can only manage records belonging to their own hospital.
    Super admins bypass this restriction.
    """
    def has_object_permission(self, request, view, obj):
        if _get_role(request.user) == 'SUPERADMIN':
            return True
        try:
            staff_hospital = request.user.staff_profile.hospital
            obj_hospital = getattr(obj, 'hospital', None)
            return obj_hospital == staff_hospital
        except AttributeError:
            return False


class ReadOnly(permissions.BasePermission):
    """Allow safe (GET/HEAD/OPTIONS) methods for any authenticated user."""
    def has_permission(self, request, view):
        return (
            request.user.is_authenticated and
            request.method in permissions.SAFE_METHODS
        )

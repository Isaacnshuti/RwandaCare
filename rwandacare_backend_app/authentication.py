from rest_framework.authentication import SessionAuthentication


class CsrfExemptSessionAuthentication(SessionAuthentication):
    """
    Native mobile clients authenticate with the Django session cookie but do not
    participate in browser-style CSRF flows.
    """

    def enforce_csrf(self, request):
        return

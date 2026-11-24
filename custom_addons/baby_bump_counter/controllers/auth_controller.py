import json
import logging

import odoo
from odoo import http
from odoo.http import request
from odoo.exceptions import AccessDenied, AccessError

_logger = logging.getLogger(__name__)


class BabyAuthController(http.Controller):
    """Authentication controller providing REST and JSON login APIs for mobile/web clients."""

    def _get_request_payload(self):
        """Extract request payload from JSON body or form/query parameters."""
        data = {}
        if request.httprequest.data:
            try:
                data = json.loads(request.httprequest.data.decode("utf-8"))
            except Exception:
                pass
        if not data and request.params:
            data = dict(request.params)
        return data

    def _resolve_db(self, params):
        """Resolve database name from request params, session, or server configuration."""
        db = (
            params.get("db")
            or params.get("database")
            or request.session.db
            or getattr(request, "db", None)
            or odoo.tools.config.get("db_name")
        )
        if not db:
            host = request.httprequest.environ.get("HTTP_HOST", "")
            try:
                dbs = http.db_list(force=True, host=host)
                if len(dbs) == 1:
                    db = dbs[0]
            except Exception as e:
                _logger.warning("Failed to auto-detect database: %s", e)
        return db

    def _build_user_data(self, env, user, session_sid):
        """Build dictionary of user details and profile info for response."""
        data = {
            "uid": user.id,
            "name": user.name,
            "username": user.login,
            "email": user.email or "",
            "partner_id": user.partner_id.id if user.partner_id else None,
            "company_id": user.company_id.id if user.company_id else None,
            "company_name": user.company_id.name if user.company_id else "",
            "session_id": session_sid,
        }

        # Check for pregnancy profile if the model is installed
        if "baby.pregnancy.profile" in env:
            profile_domain = []
            if user.email:
                profile_domain.append(("email", "=ilike", user.email))
            profile = env["baby.pregnancy.profile"].sudo().search(profile_domain, limit=1) if profile_domain else None
            if not profile:
                profile = env["baby.pregnancy.profile"].sudo().search([("name", "=ilike", user.name)], limit=1)
            
            if profile:
                data["pregnancy_profile"] = {
                    "id": profile.id,
                    "name": profile.name,
                    "email": profile.email or "",
                    "mobile": profile.mobile or "",
                    "lmp_date": str(profile.lmp_date) if profile.lmp_date else None,
                    "due_date": str(profile.due_date) if profile.due_date else None,
                }
            else:
                data["pregnancy_profile"] = None

        return data

    @http.route(
        ["/api/auth/login", "/api/login"],
        type="http",
        auth="none",
        methods=["POST"],
        csrf=False,
        cors="*",
    )
    def api_login_http(self, **kwargs):
        """REST Login API endpoint accepting JSON or form body.
        
        Expected payload:
        {
            "username": "user@example.com",  # or "login"
            "password": "yourpassword",
            "db": "database_name"            # optional if single db
        }
        """
        params = self._get_request_payload()
        login = params.get("username") or params.get("login")
        password = params.get("password")
        db = self._resolve_db(params)

        if not login or not password:
            return request.make_json_response(
                {
                    "success": False,
                    "message": "Both username and password are required.",
                    "error": "Missing credentials",
                },
                status=400,
            )

        if not db:
            return request.make_json_response(
                {
                    "success": False,
                    "message": "Database name is required or could not be determined.",
                    "error": "Missing database",
                },
                status=400,
            )

        if not http.db_filter([db]):
            return request.make_json_response(
                {
                    "success": False,
                    "message": "Database not found or access denied.",
                    "error": "Invalid database",
                },
                status=400,
            )

        try:
            pre_uid = request.session.authenticate(db, login, password)
        except (AccessDenied, AccessError):
            return request.make_json_response(
                {
                    "success": False,
                    "message": "Invalid username or password.",
                    "error": "Access Denied",
                },
                status=401,
            )
        except Exception as e:
            _logger.exception("Unexpected error during login for %s", login)
            return request.make_json_response(
                {
                    "success": False,
                    "message": "An error occurred during authentication.",
                    "error": str(e),
                },
                status=500,
            )

        if not request.session.uid:
            return request.make_json_response(
                {
                    "success": False,
                    "message": "Two-factor authentication or additional verification required.",
                    "error": "MFA Required",
                },
                status=401,
            )

        request.session.db = db
        registry = odoo.modules.registry.Registry(db)
        with registry.cursor() as cr:
            env = odoo.api.Environment(cr, request.session.uid, request.session.context)
            if not request.db:
                http.root.session_store.rotate(request.session, env)
                request.future_response.set_cookie(
                    "session_id",
                    request.session.sid,
                    max_age=http.get_session_max_inactivity(env),
                    httponly=True,
                )

            user = env["res.users"].browse(request.session.uid)
            user_data = self._build_user_data(env, user, request.session.sid)

        return request.make_json_response(
            {
                "success": True,
                "message": "Login successful.",
                "data": user_data,
            },
            status=200,
        )

    @http.route(
        "/api/auth/login_json",
        type="json",
        auth="none",
        methods=["POST"],
        csrf=False,
        cors="*",
    )
    def api_login_json(self, **kwargs):
        """JSON-RPC compatible login API endpoint."""
        params = request.params or {}
        login = params.get("username") or params.get("login")
        password = params.get("password")
        db = self._resolve_db(params)

        if not login or not password:
            return {
                "success": False,
                "message": "Both username and password are required.",
                "error": "Missing credentials",
            }

        if not db:
            return {
                "success": False,
                "message": "Database name is required or could not be determined.",
                "error": "Missing database",
            }

        if not http.db_filter([db]):
            return {
                "success": False,
                "message": "Database not found or access denied.",
                "error": "Invalid database",
            }

        try:
            pre_uid = request.session.authenticate(db, login, password)
        except (AccessDenied, AccessError):
            return {
                "success": False,
                "message": "Invalid username or password.",
                "error": "Access Denied",
            }
        except Exception as e:
            _logger.exception("Unexpected error during JSON login for %s", login)
            return {
                "success": False,
                "message": "An error occurred during authentication.",
                "error": str(e),
            }

        if not request.session.uid:
            return {
                "success": False,
                "message": "Two-factor authentication or additional verification required.",
                "error": "MFA Required",
            }

        request.session.db = db
        registry = odoo.modules.registry.Registry(db)
        with registry.cursor() as cr:
            env = odoo.api.Environment(cr, request.session.uid, request.session.context)
            if not request.db:
                http.root.session_store.rotate(request.session, env)
                request.future_response.set_cookie(
                    "session_id",
                    request.session.sid,
                    max_age=http.get_session_max_inactivity(env),
                    httponly=True,
                )

            user = env["res.users"].browse(request.session.uid)
            user_data = self._build_user_data(env, user, request.session.sid)

        return {
            "success": True,
            "message": "Login successful.",
            "data": user_data,
        }

    @http.route(
        ["/api/auth/logout", "/api/logout"],
        type="http",
        auth="none",
        methods=["POST"],
        csrf=False,
        cors="*",
    )
    def api_logout_http(self, **kwargs):
        """Logout endpoint invalidating the current session."""
        try:
            request.session.logout(keep_db=True)
            return request.make_json_response(
                {
                    "success": True,
                    "message": "Logged out successfully.",
                },
                status=200,
            )
        except Exception as e:
            _logger.exception("Error during logout")
            return request.make_json_response(
                {
                    "success": False,
                    "message": "Failed to logout.",
                    "error": str(e),
                },
                status=500,
            )

    @http.route(
        ["/api/auth/me", "/api/auth/check"],
        type="http",
        auth="none",
        methods=["GET", "POST"],
        csrf=False,
        cors="*",
    )
    def api_check_session_http(self, **kwargs):
        """Check current session status and return logged-in user details."""
        uid = request.session.uid
        db = request.session.db or getattr(request, "db", None)

        if not uid or not db:
            return request.make_json_response(
                {
                    "success": False,
                    "authenticated": False,
                    "message": "Not authenticated or session expired.",
                },
                status=401,
            )

        try:
            registry = odoo.modules.registry.Registry(db)
            with registry.cursor() as cr:
                env = odoo.api.Environment(cr, uid, request.session.context)
                user = env["res.users"].browse(uid)
                if not user.exists() or not user.active:
                    return request.make_json_response(
                        {
                            "success": False,
                            "authenticated": False,
                            "message": "User not found or inactive.",
                        },
                        status=401,
                    )

                user_data = self._build_user_data(env, user, request.session.sid)
                return request.make_json_response(
                    {
                        "success": True,
                        "authenticated": True,
                        "data": user_data,
                    },
                    status=200,
                )
        except Exception as e:
            _logger.exception("Error verifying session")
            return request.make_json_response(
                {
                    "success": False,
                    "authenticated": False,
                    "message": "Failed to verify session.",
                    "error": str(e),
                },
                status=500,
            )

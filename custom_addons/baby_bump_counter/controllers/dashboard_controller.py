import logging
import odoo
from odoo import http, fields
from odoo.http import request

_logger = logging.getLogger(__name__)


class BabyDashboardController(http.Controller):
    """Dashboard statistics controller for Flutter app and web client."""

    def _resolve_db(self, params):
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
            except Exception:
                pass
        return db

    def _get_uid(self, params):
        if request.session.uid:
            return request.session.uid
        sid = (
            request.httprequest.headers.get("X-Session-Id")
            or request.httprequest.headers.get("X-Openerp-Session-Id")
            or params.get("session_id")
        )
        auth_header = request.httprequest.headers.get("Authorization", "")
        if auth_header.startswith("Bearer "):
            sid = auth_header.split("Bearer ", 1)[1].strip()
        if sid and hasattr(http.root, "session_store"):
            try:
                s = http.root.session_store.get(sid)
                if s and s.uid:
                    return s.uid
            except Exception:
                pass
        uid_param = params.get("user_id") or params.get("uid")
        if uid_param:
            try:
                return int(uid_param)
            except (ValueError, TypeError):
                pass
        return None

    @http.route(
        ["/api/bump/dashboard", "/api/dashboard/stats"],
        type="http",
        auth="none",
        methods=["GET"],
        csrf=False,
        cors="*",
    )
    def api_get_dashboard(self, **kwargs):
        """Get summary dashboard metrics for the current user."""
        params = dict(request.params) if request.params else {}
        db = self._resolve_db(params)
        uid = self._get_uid(params)

        if not db or not uid:
            return request.make_json_response(
                {"success": False, "message": "Authentication required.", "error": "Unauthorized"},
                status=401,
            )

        today = fields.Date.today()
        registry = odoo.modules.registry.Registry(db)
        try:
            with registry.cursor() as cr:
                env = odoo.api.Environment(cr, uid, request.session.context)
                user = env["res.users"].browse(uid)
                user_id_val = int(user.id)
                user_name_val = str(user.name or "")

                stats = env["baby.bump.entry"].get_user_stats(user.id, target_date=today)
                recent_records = env["baby.bump.entry"].search(
                    [("user_id", "=", user.id)], order="date desc, time desc, id desc", limit=5
                )

                recent_data = [
                    {
                        "id": r.id,
                        "name": str(r.name or ""),
                        "date": str(r.date),
                        "day": str(r.day or (r.date.strftime("%A") if r.date else "")),
                        "time": str(r.time or ""),
                        "location": str(r.location_id.name if r.location_id else (r.location or "")),
                        "bump_count": int(r.bump_count or 1),
                        "observation": str(r.observation or ""),
                    }
                    for r in recent_records
                ]

                return request.make_json_response(
                    {
                        "success": True,
                        "data": {
                            "user": {"id": user_id_val, "name": user_name_val},
                            "today": str(today),
                            "day": today.strftime("%A"),
                            "counts": {
                                "today_logs_count": stats.get("today_logs", 0),
                                "total_logs_count": stats.get("total_logs", 0),
                                "today_bumps_count": stats.get("today_bumps", 0),
                                "total_bumps_count": stats.get("total_bumps", 0),
                            },
                            "recent_entries": recent_data,
                        },
                    },
                    status=200,
                )
        except Exception as e:
            _logger.exception("Error in dashboard API: %s", e)
            return request.make_json_response(
                {"success": False, "message": "Failed to load dashboard.", "error": str(e)},
                status=500,
            )

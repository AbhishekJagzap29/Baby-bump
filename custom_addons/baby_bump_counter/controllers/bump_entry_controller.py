import json
import logging
import re
from datetime import datetime

import odoo
from odoo import http, fields
from odoo.http import request

_logger = logging.getLogger(__name__)


class BabyBumpEntryController(http.Controller):
    """Controller providing RESTful APIs for logging baby bumps,

    retrieving bump logs, and tracking user bump log counts.
    """

    def _get_request_payload(self):
        """Extract request payload from JSON body, form data, or query parameters."""
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

    def _get_session_uid(self, params):
        """Extract user id from active session, authorization headers, or payload."""
        if request.session.uid:
            return request.session.uid

        # Check session_id in header or payload
        session_sid = (
            request.httprequest.headers.get("X-Session-Id")
            or request.httprequest.headers.get("X-Openerp-Session-Id")
            or params.get("session_id")
        )
        auth_header = request.httprequest.headers.get("Authorization", "")
        if auth_header.startswith("Bearer "):
            session_sid = auth_header.split("Bearer ", 1)[1].strip()

        if session_sid and hasattr(http.root, "session_store"):
            try:
                sess = http.root.session_store.get(session_sid)
                if sess and sess.uid:
                    return sess.uid
            except Exception as e:
                _logger.warning("Failed to get session from sid: %s", e)

        # Fallback to direct user_id/uid if provided in params
        uid_param = params.get("user_id") or params.get("uid")
        if uid_param:
            try:
                return int(uid_param)
            except (ValueError, TypeError):
                pass

        return None

    def _serialize_entry(self, entry):
        """Convert a baby.bump.entry record to a plain serializable dictionary."""
        loc_id = None
        loc_name = ""
        if entry.location_id:
            loc_id = entry.location_id.id
            loc_name = str(entry.location_id.name or "")
        elif entry.location:
            loc_name = str(entry.location)

        prof_id = None
        prof_name = ""
        if entry.profile_id:
            prof_id = entry.profile_id.id
            prof_name = str(entry.profile_id.name or "")

        u_id = None
        u_name = ""
        if entry.user_id:
            u_id = entry.user_id.id
            u_name = str(entry.user_id.name or "")

        return {
            "id": entry.id,
            "name": str(entry.name or ""),
            "date": str(entry.date) if entry.date else None,
            "day": str(entry.day) if entry.day else (entry.date.strftime("%A") if entry.date else None),
            "time": str(entry.time or ""),
            "bump_location": {
                "id": loc_id,
                "name": loc_name,
            },
            "bump_count": int(entry.bump_count or 1),
            "observation": str(entry.observation or ""),
            "note": str(entry.note or ""),
            "profile_id": prof_id,
            "profile_name": prof_name,
            "user_id": u_id,
            "user_name": u_name,
            "created_at": fields.Datetime.to_string(entry.create_date) if entry.create_date else None,
        }

    # =========================================================================
    # 1. LOG BABY BUMP API (REST POST)
    # =========================================================================
    @http.route(
        ["/api/bump/log", "/api/bump/entry", "/api/bump/create"],
        type="http",
        auth="none",
        methods=["POST"],
        csrf=False,
        cors="*",
    )
    def api_log_baby_bump(self, **kwargs):
        """Log a baby bump entry.

        Accepted Fields:
        - date (string, optional): Date in YYYY-MM-DD format (defaults to today's date).
        - day (string, optional): Day of week (defaults to date's day e.g., 'Monday').
        - time (string, optional): Time in 24h format HH:MM (defaults to current time).
        - bump_location / location_id / location (int or string, optional):
            Location ID or Location Name (e.g., 'Upper Right', 'Lower Belly').
            If string is provided, existing location is matched or automatically created.
        - bump_count (int, optional): Count of kicks/bumps (defaults to 1).
        - observation (string, optional): Optional observation notes.
        - note / notes (string, optional): Additional notes.
        - profile_id (int, optional): Pregnancy profile ID (auto-resolved if omitted).
        - user_id (int, optional): User ID (defaults to authenticated user).

        Returns:
        - Logged bump entry details.
        - User log counts (today logs count, total logs count, today bumps count, total bumps count).
        """
        params = self._get_request_payload()
        db = self._resolve_db(params)
        uid = self._get_session_uid(params)

        if not db:
            return request.make_json_response(
                {
                    "success": False,
                    "message": "Database name is required or could not be determined.",
                    "error": "Missing database",
                },
                status=400,
            )

        if not uid:
            return request.make_json_response(
                {
                    "success": False,
                    "message": "Authentication required. Please provide a valid session_id or login.",
                    "error": "Unauthorized",
                },
                status=401,
            )

        # Validate Date
        raw_date = params.get("date")
        if raw_date:
            try:
                entry_date = fields.Date.from_string(str(raw_date).strip())
                if not entry_date:
                    raise ValueError()
            except Exception:
                return request.make_json_response(
                    {
                        "success": False,
                        "message": f"Invalid date format '{raw_date}'. Expected YYYY-MM-DD.",
                        "error": "Invalid date",
                    },
                    status=400,
                )
        else:
            entry_date = fields.Date.today()

        # Day of Week
        raw_day = params.get("day")
        if raw_day and str(raw_day).strip():
            entry_day = str(raw_day).strip().capitalize()
        else:
            entry_day = entry_date.strftime("%A")

        # Validate Time (24h format HH:MM)
        raw_time = params.get("time")
        time_str = None
        if raw_time:
            t = str(raw_time).strip()
            single_digit = re.match(r"^([0-9]):([0-5]\d)$", t)
            if single_digit:
                time_str = f"0{t}"
            elif re.match(r"^([01]\d|2[0-3])([0-5]\d)$", t):
                time_str = f"{t[:2]}:{t[2:]}"
            else:
                time_str = t

            if not re.match(r"^([01]\d|2[0-3]):([0-5]\d)$", time_str):
                return request.make_json_response(
                    {
                        "success": False,
                        "message": f"Invalid time '{raw_time}'. Time must be in 24-hour format HH:MM (e.g., 09:15, 14:30).",
                        "error": "Invalid time format",
                    },
                    status=400,
                )

        # Validate Bump Count
        raw_bump_count = params.get("bump_count", 1)
        try:
            bump_count = int(raw_bump_count)
            if bump_count <= 0:
                return request.make_json_response(
                    {
                        "success": False,
                        "message": "Bump count must be a positive integer greater than 0.",
                        "error": "Invalid bump count",
                    },
                    status=400,
                )
        except (ValueError, TypeError):
            return request.make_json_response(
                {
                    "success": False,
                    "message": "Bump count must be a valid integer.",
                    "error": "Invalid bump count",
                },
                status=400,
            )

        observation = str(params.get("observation", "")).strip()
        note = str(params.get("note") or params.get("notes") or "").strip()
        location_input = params.get("bump_location") or params.get("location_id") or params.get("location")
        custom_name = params.get("name")

        registry = odoo.modules.registry.Registry(db)
        try:
            with registry.cursor() as cr:
                env = odoo.api.Environment(cr, uid, request.session.context)
                user = env["res.users"].browse(uid)
                if not user.exists() or not user.active:
                    return request.make_json_response(
                        {
                            "success": False,
                            "message": "User not found or inactive.",
                            "error": "Invalid user",
                        },
                        status=401,
                    )

                user_id_val = int(user.id)
                user_name_val = str(user.name or "")

                # Default time if not provided
                if not time_str:
                    time_str = fields.Datetime.context_timestamp(
                        env["baby.bump.entry"], fields.Datetime.now()
                    ).strftime("%H:%M")

                # Resolve or create bump location
                location_id = None
                if location_input:
                    if isinstance(location_input, int) or (isinstance(location_input, str) and location_input.isdigit()):
                        loc = env["baby.bump.location"].browse(int(location_input))
                        if loc.exists():
                            location_id = loc.id
                    elif isinstance(location_input, str) and location_input.strip():
                        loc_name = location_input.strip()
                        loc = env["baby.bump.location"].search([("name", "=ilike", loc_name)], limit=1)
                        if not loc:
                            loc = env["baby.bump.location"].create({"name": loc_name})
                        location_id = loc.id

                # Resolve pregnancy profile
                profile = None
                profile_param = params.get("profile_id")
                if profile_param:
                    try:
                        p = env["baby.pregnancy.profile"].browse(int(profile_param))
                        if p.exists():
                            profile = p
                    except (ValueError, TypeError):
                        pass

                if not profile and "baby.pregnancy.profile" in env:
                    domain = []
                    if user.email:
                        domain.append(("email", "=ilike", user.email))
                    profile = env["baby.pregnancy.profile"].search(domain, limit=1) if domain else None
                    if not profile:
                        profile = env["baby.pregnancy.profile"].search([("name", "=ilike", user.name)], limit=1)
                    if not profile:
                        profile = env["baby.pregnancy.profile"].create({
                            "name": user.name or f"Profile for {user.login}",
                            "email": user.email or "",
                        })

                # Prepare entry values
                entry_vals = {
                    "name": custom_name or f"Bump - {entry_date} {time_str}",
                    "user_id": user.id,
                    "profile_id": profile.id if profile else False,
                    "date": entry_date,
                    "day": entry_day,
                    "time": time_str,
                    "location_id": location_id,
                    "bump_count": bump_count,
                    "observation": observation or False,
                    "note": note or False,
                }

                entry = env["baby.bump.entry"].create(entry_vals)

                # Calculate user log counts
                stats = env["baby.bump.entry"].get_user_stats(user.id, target_date=entry_date)
                entry_data = self._serialize_entry(entry)

                today_logs_count = int(stats.get("today_logs", 0))
                total_logs_count = int(stats.get("total_logs", 0))
                today_bumps_count = int(stats.get("today_bumps", 0))
                total_bumps_count = int(stats.get("total_bumps", 0))

                return request.make_json_response(
                    {
                        "success": True,
                        "message": "Baby bump logged successfully.",
                        "data": entry_data,
                        "user_log_counts": {
                            "user_id": user_id_val,
                            "user_name": user_name_val,
                            "selected_date": str(entry_date),
                            "selected_day": entry_day,
                            "today_logs_count": today_logs_count,
                            "total_logs_count": total_logs_count,
                            "today_bumps_count": today_bumps_count,
                            "total_bumps_count": total_bumps_count,
                        },
                    },
                    status=201,
                )

        except Exception as e:
            _logger.exception("Error logging baby bump for user %s: %s", uid, e)
            return request.make_json_response(
                {
                    "success": False,
                    "message": "Failed to log baby bump.",
                    "error": str(e),
                },
                status=500,
            )

    # =========================================================================
    # 2. GET USER BUMP LOGS API (LIST with counts and pagination)
    # =========================================================================
    @http.route(
        ["/api/bump/logs", "/api/bump/entries"],
        type="http",
        auth="none",
        methods=["GET"],
        csrf=False,
        cors="*",
    )
    def api_get_bump_logs(self, **kwargs):
        """Retrieve logged baby bumps for the user with counts and optional filters."""
        params = self._get_request_payload()
        db = self._resolve_db(params)
        uid = self._get_session_uid(params)

        if not db or not uid:
            return request.make_json_response(
                {
                    "success": False,
                    "message": "Authentication required. Missing database or user session.",
                    "error": "Unauthorized",
                },
                status=401,
            )

        page = max(1, int(params.get("page", 1)))
        limit = min(100, max(1, int(params.get("limit", 20))))
        offset = (page - 1) * limit

        registry = odoo.modules.registry.Registry(db)
        try:
            with registry.cursor() as cr:
                env = odoo.api.Environment(cr, uid, request.session.context)
                user = env["res.users"].browse(uid)
                user_id_val = int(user.id)
                user_name_val = str(user.name or "")

                domain = [("user_id", "=", user.id)]

                filter_date = params.get("date")
                if filter_date:
                    domain.append(("date", "=", filter_date))

                start_date = params.get("start_date")
                if start_date:
                    domain.append(("date", ">=", start_date))

                end_date = params.get("end_date")
                if end_date:
                    domain.append(("date", "<=", end_date))

                location_id = params.get("location_id")
                if location_id:
                    domain.append(("location_id", "=", int(location_id)))

                total_matching_entries = env["baby.bump.entry"].search_count(domain)
                records = env["baby.bump.entry"].search(domain, limit=limit, offset=offset)
                entries_list = [self._serialize_entry(r) for r in records]

                # Overall user counts
                stats = env["baby.bump.entry"].get_user_stats(user.id)

                return request.make_json_response(
                    {
                        "success": True,
                        "data": entries_list,
                        "pagination": {
                            "page": page,
                            "limit": limit,
                            "total_records": total_matching_entries,
                            "total_pages": (total_matching_entries + limit - 1) // limit if total_matching_entries else 0,
                        },
                        "user_log_counts": {
                            "user_id": user_id_val,
                            "user_name": user_name_val,
                            "today_logs_count": stats.get("today_logs", 0),
                            "total_logs_count": stats.get("total_logs", 0),
                            "today_bumps_count": stats.get("today_bumps", 0),
                            "total_bumps_count": stats.get("total_bumps", 0),
                        },
                    },
                    status=200,
                )

        except Exception as e:
            _logger.exception("Error fetching bump logs: %s", e)
            return request.make_json_response(
                {
                    "success": False,
                    "message": "Failed to fetch bump logs.",
                    "error": str(e),
                },
                status=500,
            )

    # =========================================================================
    # 3. GET USER BUMP COUNTS AND STATISTICS API
    # =========================================================================
    @http.route(
        ["/api/bump/counts", "/api/bump/stats"],
        type="http",
        auth="none",
        methods=["GET"],
        csrf=False,
        cors="*",
    )
    def api_get_bump_counts(self, **kwargs):
        """Retrieve aggregated bump counts and statistics for the user."""
        params = self._get_request_payload()
        db = self._resolve_db(params)
        uid = self._get_session_uid(params)

        if not db or not uid:
            return request.make_json_response(
                {
                    "success": False,
                    "message": "Authentication required.",
                    "error": "Unauthorized",
                },
                status=401,
            )

        target_date_str = params.get("date")
        target_date = (
            fields.Date.from_string(target_date_str)
            if target_date_str
            else fields.Date.today()
        )

        registry = odoo.modules.registry.Registry(db)
        try:
            with registry.cursor() as cr:
                env = odoo.api.Environment(cr, uid, request.session.context)
                user = env["res.users"].browse(uid)
                user_id_val = int(user.id)
                user_name_val = str(user.name or "")

                # Base user statistics
                stats = env["baby.bump.entry"].get_user_stats(user.id, target_date=target_date)

                # Counts by location
                entries = env["baby.bump.entry"].search([("user_id", "=", user.id)])
                location_counts = {}
                day_counts = {}

                for entry in entries:
                    loc_name = str(entry.location_id.name if entry.location_id else (entry.location or "Unspecified"))
                    location_counts[loc_name] = location_counts.get(loc_name, 0) + (entry.bump_count or 0)

                    day_name = str(entry.day or (entry.date.strftime("%A") if entry.date else "Unknown"))
                    day_counts[day_name] = day_counts.get(day_name, 0) + (entry.bump_count or 0)

                return request.make_json_response(
                    {
                        "success": True,
                        "data": {
                            "user_id": user_id_val,
                            "user_name": user_name_val,
                            "target_date": str(target_date),
                            "target_day": target_date.strftime("%A"),
                            "today_logs_count": stats.get("today_logs", 0),
                            "total_logs_count": stats.get("total_logs", 0),
                            "today_bumps_count": stats.get("today_bumps", 0),
                            "total_bumps_count": stats.get("total_bumps", 0),
                            "bumps_by_location": location_counts,
                            "bumps_by_day": day_counts,
                        },
                    },
                    status=200,
                )

        except Exception as e:
            _logger.exception("Error computing bump counts: %s", e)
            return request.make_json_response(
                {
                    "success": False,
                    "message": "Failed to compute bump counts.",
                    "error": str(e),
                },
                status=500,
            )

    # =========================================================================
    # 4. GET AVAILABLE BUMP LOCATIONS API
    # =========================================================================
    @http.route(
        "/api/bump/locations",
        type="http",
        auth="none",
        methods=["GET"],
        csrf=False,
        cors="*",
    )
    def api_get_bump_locations(self, **kwargs):
        """Retrieve list of pre-configured and custom baby bump locations."""
        params = self._get_request_payload()
        db = self._resolve_db(params)

        if not db:
            return request.make_json_response(
                {
                    "success": False,
                    "message": "Database name is required or could not be determined.",
                    "error": "Missing database",
                },
                status=400,
            )

        registry = odoo.modules.registry.Registry(db)
        try:
            with registry.cursor() as cr:
                env = odoo.api.Environment(cr, odoo.SUPERUSER_ID, request.session.context)
                locations = env["baby.bump.location"].search([])
                data = [
                    {
                        "id": loc.id,
                        "name": str(loc.name),
                        "sequence": int(loc.sequence or 0),
                    }
                    for loc in locations
                ]

                return request.make_json_response(
                    {
                        "success": True,
                        "count": len(data),
                        "data": data,
                    },
                    status=200,
                )

        except Exception as e:
            _logger.exception("Error fetching locations: %s", e)
            return request.make_json_response(
                {
                    "success": False,
                    "message": "Failed to fetch bump locations.",
                    "error": str(e),
                },
                status=500,
            )

    # =========================================================================
    # 5. JSON-RPC LOG BABY BUMP ENDPOINT
    # =========================================================================
    @http.route(
        "/api/bump/log_json",
        type="json",
        auth="none",
        methods=["POST"],
        csrf=False,
        cors="*",
    )
    def api_log_baby_bump_json(self, **kwargs):
        """JSON-RPC compatible version of logging a baby bump."""
        params = request.params or {}
        db = self._resolve_db(params)
        uid = self._get_session_uid(params)

        if not db:
            return {"success": False, "message": "Missing database", "error": "Missing database"}
        if not uid:
            return {"success": False, "message": "Unauthorized. Please authenticate.", "error": "Unauthorized"}

        raw_date = params.get("date")
        if raw_date:
            try:
                entry_date = fields.Date.from_string(str(raw_date).strip())
                if not entry_date:
                    raise ValueError()
            except Exception:
                return {"success": False, "message": "Invalid date format YYYY-MM-DD", "error": "Invalid date"}
        else:
            entry_date = fields.Date.today()

        entry_day = str(params.get("day", "")).strip().capitalize() or entry_date.strftime("%A")

        raw_time = params.get("time")
        time_str = str(raw_time).strip() if raw_time else ""
        if time_str:
            single = re.match(r"^([0-9]):([0-5]\d)$", time_str)
            if single:
                time_str = f"0{time_str}"
            elif re.match(r"^([01]\d|2[0-3])([0-5]\d)$", time_str):
                time_str = f"{time_str[:2]}:{time_str[2:]}"
        else:
            time_str = datetime.now().strftime("%H:%M")

        try:
            bump_count = max(1, int(params.get("bump_count", 1)))
        except (ValueError, TypeError):
            bump_count = 1

        observation = str(params.get("observation", "")).strip()
        location_input = params.get("bump_location") or params.get("location_id") or params.get("location")

        registry = odoo.modules.registry.Registry(db)
        with registry.cursor() as cr:
            env = odoo.api.Environment(cr, uid, request.session.context)
            user = env["res.users"].browse(uid)
            user_id_val = int(user.id)
            user_name_val = str(user.name or "")

            location_id = None
            if location_input:
                if isinstance(location_input, int) or (isinstance(location_input, str) and location_input.isdigit()):
                    loc = env["baby.bump.location"].browse(int(location_input))
                    if loc.exists():
                        location_id = loc.id
                elif isinstance(location_input, str) and location_input.strip():
                    loc_name = location_input.strip()
                    loc = env["baby.bump.location"].search([("name", "=ilike", loc_name)], limit=1)
                    if not loc:
                        loc = env["baby.bump.location"].create({"name": loc_name})
                    location_id = loc.id

            profile = env["baby.pregnancy.profile"].search([
                "|", ("email", "=ilike", user.email or ""), ("name", "=ilike", user.name)
            ], limit=1)
            if not profile:
                profile = env["baby.pregnancy.profile"].create({
                    "name": user.name or f"Profile {user.login}",
                    "email": user.email or "",
                })

            entry = env["baby.bump.entry"].create({
                "name": f"Bump - {entry_date} {time_str}",
                "user_id": user.id,
                "profile_id": profile.id,
                "date": entry_date,
                "day": entry_day,
                "time": time_str,
                "location_id": location_id,
                "bump_count": bump_count,
                "observation": observation or False,
            })

            stats = env["baby.bump.entry"].get_user_stats(user.id, target_date=entry_date)
            entry_data = self._serialize_entry(entry)

            today_logs = int(stats.get("today_logs", 0))
            total_logs = int(stats.get("total_logs", 0))
            today_bumps = int(stats.get("today_bumps", 0))
            total_bumps = int(stats.get("total_bumps", 0))

            return {
                "success": True,
                "message": "Baby bump logged successfully.",
                "data": entry_data,
                "user_log_counts": {
                    "user_id": user_id_val,
                    "user_name": user_name_val,
                    "today_logs_count": today_logs,
                    "total_logs_count": total_logs,
                    "today_bumps_count": today_bumps,
                    "total_bumps_count": total_bumps,
                },
            }

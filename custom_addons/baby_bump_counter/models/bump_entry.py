import re
from odoo import models, fields, api, _
from odoo.exceptions import ValidationError


def _default_time(self):
    return fields.Datetime.context_timestamp(self, fields.Datetime.now()).strftime("%H:%M")


class BabyBumpEntry(models.Model):
    _name = "baby.bump.entry"
    _description = "Baby Bump Entry"
    _order = "date desc, time desc, id desc"

    name = fields.Char(
        string="Entry Reference",
        required=True,
        default="New Entry",
    )
    profile_id = fields.Many2one(
        "baby.pregnancy.profile",
        string="Pregnancy Profile",
        required=True,
    )
    user_id = fields.Many2one(
        "res.users",
        string="User",
        required=True,
        default=lambda self: self.env.user,
    )
    date = fields.Date(
        string="Date",
        required=True,
        default=fields.Date.today,
    )
    day = fields.Char(
        string="Day",
        compute="_compute_day",
        store=True,
        readonly=False,
        help="Day of the week (e.g., Monday, Tuesday)",
    )
    time = fields.Char(
        string="Time (24h)",
        required=True,
        default=_default_time,
        help="Time in 24-hour format HH:MM (e.g., 14:30)",
    )
    location_id = fields.Many2one(
        "baby.bump.location",
        string="Bump Location",
        help="Select location or create a new one",
    )
    location = fields.Char(
        string="Location Name",
        related="location_id.name",
        store=True,
        readonly=False,
    )
    bump_count = fields.Integer(
        string="Bump Count",
        default=1,
        required=True,
    )
    observation = fields.Text(
        string="Observation",
        help="Optional observation (e.g., kick strength, baby position, duration)",
    )
    note = fields.Text(string="Notes")

    @api.depends("date")
    def _compute_day(self):
        for record in self:
            if record.date:
                record.day = record.date.strftime("%A")
            elif not record.day:
                record.day = fields.Date.today().strftime("%A")

    @api.onchange("time")
    def _onchange_time(self):
        if self.time:
            clean = self.time.strip()
            single_digit_hour = re.match(r"^([0-9]):([0-5]\d)$", clean)
            if single_digit_hour:
                self.time = f"0{clean}"

    @api.constrains("time")
    def _check_time_format(self):
        time_regex = re.compile(r"^([01]?\d|2[0-3]):([0-5]\d)$")
        for record in self:
            if record.time:
                clean = record.time.strip()
                if not time_regex.match(clean):
                    raise ValidationError(
                        _(
                            "Invalid time '%s'. Please enter time in 24-hour format HH:MM (e.g., 09:15, 14:30, 23:45)."
                        )
                        % record.time
                    )

    @api.model_create_multi
    def create(self, vals_list):
        for vals in vals_list:
            if not vals.get("date"):
                vals["date"] = fields.Date.today()
            if not vals.get("day") and vals.get("date"):
                d = fields.Date.from_string(str(vals["date"])) if isinstance(vals["date"], str) else vals["date"]
                if hasattr(d, "strftime"):
                    vals["day"] = d.strftime("%A")
            if vals.get("time"):
                t = str(vals["time"]).strip()
                if re.match(r"^[0-9]:[0-5]\d$", t):
                    vals["time"] = f"0{t}"
                elif not re.match(r"^([01]\d|2[0-3]):[0-5]\d$", t):
                    # Also try handling without colon like 1430
                    if re.match(r"^([01]\d|2[0-3])([0-5]\d)$", t):
                        vals["time"] = f"{t[:2]}:{t[2:]}"
            if not vals.get("name") or vals.get("name") == "New Entry":
                entry_date = vals.get("date") or fields.Date.today()
                entry_time = vals.get("time") or ""
                vals["name"] = f"Bump - {entry_date} {entry_time}".strip()
        return super().create(vals_list)

    def write(self, vals):
        if vals.get("date") and not vals.get("day"):
            d = fields.Date.from_string(str(vals["date"])) if isinstance(vals["date"], str) else vals["date"]
            if hasattr(d, "strftime"):
                vals["day"] = d.strftime("%A")
        if vals.get("time"):
            t = str(vals["time"]).strip()
            if re.match(r"^[0-9]:[0-5]\d$", t):
                vals["time"] = f"0{t}"
            elif re.match(r"^([01]\d|2[0-3])([0-5]\d)$", t):
                vals["time"] = f"{t[:2]}:{t[2:]}"
        return super().write(vals)

    @api.model
    def get_user_stats(self, user_id, target_date=None):
        """Get bump log statistics and counts for a specific user."""
        if not target_date:
            target_date = fields.Date.today()
        elif isinstance(target_date, str):
            target_date = fields.Date.from_string(target_date)

        domain_user = [("user_id", "=", user_id)]
        domain_today = [("user_id", "=", user_id), ("date", "=", target_date)]

        total_logs = self.search_count(domain_user)
        today_logs = self.search_count(domain_today)

        user_entries = self.search(domain_user)
        total_bumps = sum(user_entries.mapped("bump_count"))

        today_entries = self.search(domain_today)
        today_bumps = sum(today_entries.mapped("bump_count"))

        return {
            "user_id": user_id,
            "target_date": str(target_date),
            "total_logs": total_logs,
            "today_logs": today_logs,
            "total_bumps": total_bumps,
            "today_bumps": today_bumps,
        }


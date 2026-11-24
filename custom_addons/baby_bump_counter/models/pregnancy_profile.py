from odoo import models, fields


class BabyPregnancyProfile(models.Model):
    _name = "baby.pregnancy.profile"
    _description = "Pregnancy Profile"
    _rec_name = "name"

    name = fields.Char(string="Full Name", required=True)
    email = fields.Char(string="Email")
    mobile = fields.Char(string="Mobile")
    lmp_date = fields.Date(string="Last Menstrual Period")
    due_date = fields.Date(string="Expected Due Date")
    active = fields.Boolean(default=True)

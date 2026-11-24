from odoo import models, fields


class BabyBumpLocation(models.Model):
    _name = "baby.bump.location"
    _description = "Baby Bump Location"
    _order = "sequence, id"

    name = fields.Char(string="Location Name", required=True)
    sequence = fields.Integer(string="Sequence", default=10)
    active = fields.Boolean(default=True)

    _sql_constraints = [
        ("name_uniq", "unique (name)", "Bump location name must be unique!"),
    ]

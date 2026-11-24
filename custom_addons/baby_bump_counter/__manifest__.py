{
    "name": "Baby Bump Counter",
    "version": "17.0.1.0.0",
    "category": "Healthcare",
    "summary": "Baby Bump Counter Management",
    "depends": ["base", "web"],
    "data": [
        "security/ir.model.access.csv",
        "data/bump_location_data.xml",
        "views/pregnancy_profile_views.xml",
        "views/bump_location_views.xml",
        "views/bump_entry_views.xml",
        "views/dashboard_views.xml",
        "views/menu_views.xml",
    ],
    "installable": True,
    "application": True,
    "license": "LGPL-3",
}

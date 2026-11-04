"""Select simple plate components, preserving the source's exact descriptions."""

import re

MEAT_CATEGORIES = {"Beef Products", "Pork Products", "Poultry Products", "Lamb, Veal, and Game Products", "Finfish and Shellfish Products"}
COOKED = r"\b(?:cooked|boiled|baked|roasted|broiled|grilled|braised|poached|steamed|canned|smoked)\b"
COMPOSITE = r"\b(?:ravioli|tortellini|pizza|sandwich|dinner|entree|meal|soup|sauce|gravy|salad|pudding|dessert|cookie|cake|biscuit|jam|jelly|preserve|candy|candied|sweetened|syrup|snack|stuffed|mix|coated|glazed)\b"


def select_group(food, dataset):
    name = food["description"].lower()
    category = food.get("foodCategory", {}).get("description", "")
    if re.search(r"\b(?:industrial|human|unprepared|unheated|mixed)\b|ready-to-(?:bake|fry)|for reference only", name):
        return None
    # FNDDS is predominantly prepared dishes. Only deliberately reviewed
    # individual foods from SR Legacy are used for this basic catalog.
    if dataset == "fndds":
        return None
    # Common baking ingredients are intentional exceptions to the cooked-food
    # catalog. Dry rice and pasta remain excluded further below.
    if category in {"Cereal Grains and Pasta", "Legumes and Legume Products"}:
        if re.match(r"(?:wheat|rice|rye|oat|barley|buckwheat|spelt|sorghum|quinoa|amaranth|millet|corn|chickpea|soy|triticale|arrowroot) flours?\b", name):
            if not re.search(r"\b(?:self-rising|mix|seasoned)\b", name):
                return "flour"
    if category == "Baked Products" and re.match(r"bread(?:,)? crumbs\b", name):
        return "breadcrumbs" if not re.search(r"\b(?:seasoned|flavored|cheese)\b", name) else None
    if category == "Spices and Herbs":
        return None
    if re.search(r"\b(?:mushrooms?|fungi|fungus|morels?|chanterelles?|truffles?|seaweed|spirulina|kelp|agar|laver|nori|wakame|kombu|powders?|powdered|extracts?|spread)\b", name):
        return None
    if category == "Fats and Oils":
        if re.search(r"\b(?:replacement|spray|hydrogenated|lecithin|added|blend)\b", name):
            return None
        if name.startswith("oil,"):
            return "fat_or_oil" if re.match(r"oil, (?:olive|canola|rapeseed|sunflower|soybean|corn|coconut|flaxseed|sesame|peanut|grapeseed|avocado|walnut|almond|palm)(?:,|$)", name) and not re.search(r"\band\b", name.split(",", 2)[1]) and ", and " not in name else None
        return "fat_or_oil" if re.match(r"(?:butter,|lard\b|fat, (?:beef|chicken|turkey|goose)\b)", name) else None
    if re.search(COMPOSITE, name):
        return None
    # Salt and skin/peel describe plain food; hidden recipe additions do not.
    without_plain_salt = re.sub(r"\bwith(?:out)?(?: added)? (?:salt|skin|peel)\b", "", name)
    if re.search(r"\bwith\b", without_plain_salt):
        return None
    if category in MEAT_CATEGORIES:
        if name.startswith("game meat"):
            if not re.match(r"game meat, (?:rabbit|deer|boar),", name):
                return None
        elif not re.match(r"(?:beef|pork|lamb|veal|chicken|turkey|duck|goose|quail|pheasant|fish|salmon|crustaceans|mollusks)\b", name):
            return None
        if name.startswith("chicken patty"):
            return None
        if re.search(r"\b(?:raw|uncooked|unheated|unprepared|breaded|battered|fried|frankfurter|sausage)\b", name):
            return None
        return "cooked_meat_or_fish" if re.search(COOKED, name) else None
    if category == "Cereal Grains and Pasta":
        if not re.match(r"(?:rice, (?:white|brown)|wild rice|barley|buckwheat|bulgur|couscous|quinoa|millet|amaranth|spelt|teff|pasta|noodles|macaroni|spaghetti)\b", name):
            return None
        if re.search(r"\b(?:raw|uncooked|dry|flour|bran|crunchy)\b", name):
            return None
        return "cooked_grain_or_pasta" if re.search(COOKED, name) else None
    if category == "Vegetables and Vegetable Products":
        if re.search(r"\b(?:juice|french|fried|chips|mashed|scalloped|creamed|cream|flour|starch|dehydrated|powder|hash|pancake|puff|souffle|fritter|au gratin)\b", name):
            return None
        if re.match(r"(?:potatoes|potato|sweet potato|sweet potatoes|yam|yams|taro|cassava)\b", name):
            return "cooked_potato_or_root" if re.search(COOKED, name) and not re.search(r"\braw\b", name) else None
        return "vegetable"
    if category == "Fruits and Fruit Juices":
        if re.search(r"\b(?:juice|nectar|syrup|pie|sauce|sweetened)\b", name):
            return None
        return "fruit"
    if category == "Legumes and Legume Products":
        if re.search(r"\b(?:flour|raw|dry|fried|baked beans|refried)\b", name):
            return None
        if re.match(r"(?:tofu|tempeh)\b", name):
            return "legume"
        return "legume" if re.search(COOKED, name) else None
    if category == "Nut and Seed Products":
        if re.search(r"\b(?:butter|paste|spread|oil|flour|milk|water|desiccated)\b", name):
            return None
        return "nut_or_seed"
    if category == "Fats and Oils":
        if re.search(r"\b(?:replacement|powder|spray|hydrogenated|lecithin)\b", name):
            return None
        return "fat_or_oil" if re.match(r"(?:oil,|butter\b|lard\b|fat,)", name) else None
    if category == "Dairy and Egg Products":
        if re.match(r"egg, whole, cooked, (?:hard-boiled|poached)\b", name):
            return "cooked_egg"
        if re.match(r"(?:cheese,|milk,|butter,)", name) and not re.search(r"\b(?:chocolate|flavored|powder|dry|dried|condensed|spread|imitation|substitute)\b", name):
            return "plain_dairy"
        if name.startswith("yogurt,") and "plain" in name:
            return "plain_dairy"
    if category == "Baked Products":
        if re.match(r"(?:bread,|rolls,|tortillas,)", name) and not re.search(r"\b(?:fruit|raisin|banana|pumpkin|chocolate|cinnamon|cheese|garlic|sweet|zucchini)\b", name):
            return "plain_bread"
    return None

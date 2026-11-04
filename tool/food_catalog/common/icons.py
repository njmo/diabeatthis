"""Conservative name matching against the app's existing bundled icon catalog."""

import re

from common.usda import normalized

IRREGULAR = {"potatoes": "potato", "tomatoes": "tomato", "leaves": "leaf", "berries": "berry", "cherries": "cherry", "strawberries": "strawberry", "blueberries": "blueberry", "raspberries": "raspberry", "blackberries": "blackberry", "fries": "fry"}
SKIP = {"and", "or", "the", "a", "of"}
EXCLUDE = {"generic", "amphora", "bowl_with_spoon", "fork_and_knife", "kitchen_knife", "spoon", "teapot", "takeout_box", "cooking", "shallow_pan_of_food", "tumbler_glass", "wine_glass", "teacup_without_handle"}
HEAD_RULES = [
    (r"\b(?:juice|lemonade|smoothie|fruit drink)\b", "drink", {"juice", "lemonade", "smoothie", "drink"}),
    (r"^chocolate milk\b", "milk", {"milk"}),
    (r"\binfant formula\b", "baby_bottle", {"formula"}),
    (r"\b(?:ravioli|tortellini|spaghetti|lasagna|macaroni|noodles)\b", "pasta", {"ravioli", "tortellini", "spaghetti", "lasagna", "macaroni", "noodle", "pasta"}),
    (r"\b(?:wafer|wafers|cookie|cookies)\b", "cookie", {"wafer", "cookie"}),
    (r"\b(?:biscuit|biscuits)\b", "bread", {"biscuit", "bread"}),
    (r"^shellfish mixture\b", "fish", {"shellfish", "fish"}),
    (r"^(?:beef|pork|veal|lamb|game meat)\b", "cut_of_meat", {"beef", "pork", "veal", "lamb", "meat"}),
    (r"^(?:turkey|duck|goose|quail)\b", "meat_on_bone", {"turkey", "duck", "goose", "quail"}),
    (r"^(?:oil|oils)\b", "pouring_liquid", {"oil"}),
    (r"^(?:candies|candy)\b", "candy", {"candy", "candies"}),
    (r"^mushrooms?\b", "brown_mushroom", {"mushroom"}),
    (r"^(?:tea|beverages, tea)\b", "teacup_without_handle", {"tea"}),
    (r"^(?:roll|rolls)\b", "bread", {"roll", "bread"}),
    (r"^(?:peas|pea)\b", "pea_pod", {"pea"}),
]


def tokens(name):
    result = []
    for word in normalized(name).split():
        if word in SKIP:
            continue
        result.append(IRREGULAR.get(word, word[:-1] if word.endswith("s") and len(word) > 3 and not word.endswith(("ss", "us")) else word))
    return result


class IconCatalog:
    def __init__(self, root):
        directory = root / "lib/features/ingredients/data/icons"
        wicked = (directory / "wicked_food_icon_assets.dart").read_text()
        bundled = (directory / "food_icon_assets.dart").read_text()
        paths = dict(re.findall(r"'([^']+)'\s*:\s*'([^']+)'", wicked.split("static const names")[0] + bundled))
        paths = {key: path for key, path in paths.items() if path.startswith("assets/")}
        missing = [path for path in paths.values() if not (root / path).is_file()]
        if missing:
            raise ValueError(f"Missing bundled icons: {missing}")
        self.paths = paths
        self.candidates = [(key, tokens(key.removeprefix("wicked_").replace("_", " "))) for key in paths if key not in EXCLUDE]

    def match(self, name):
        flour_words = tokens(name)
        if "flour" in flour_words:
            key = "wicked_corn_flour" if "corn" in flour_words else "wicked_oat_flour" if "oat" in flour_words else "wicked_whole_wheat_flour" if "wheat" in flour_words and "whole" in flour_words else "wicked_white_flour"
            return {"iconId": key, "iconAssetPath": self.paths[key], "iconMatchMethod": "category_match"}
        # Ignore explicit secondary ingredients after 'with'; the dish itself
        # should determine the illustration (bread with cheese stays bread).
        primary = re.split(r"\b(?:with|without)\b", name, maxsplit=1, flags=re.IGNORECASE)[0]
        words = tokens(primary)
        positions = {word: words.index(word) for word in words}
        matches = []
        for key, required in self.candidates:
            if required and all(word in positions for word in required):
                matches.append((min(positions[word] for word in required), -len(set(required)), not key.startswith("wicked_"), key))
        if matches:
            _, _, _, key = min(matches)
            method = "name_match"
        else:
            key, method = "generic", "fallback"
        selected_tokens = set(tokens(key.removeprefix("wicked_")))
        for pattern, category_key, anchors in HEAD_RULES:
            if re.search(pattern, primary, re.IGNORECASE):
                if not selected_tokens.intersection(anchors):
                    key, method = category_key, "category_match"
                break
        return {"iconId": key, "iconAssetPath": self.paths[key], "iconMatchMethod": method}

/// Shared structural contract for the model API and prompt. Numeric bounds,
/// collection limits and distinct component identities remain strictly checked
/// by the application parser. Each item source is a separate provider branch:
/// catalog matches cannot also carry estimated reference nutrition.
abstract final class MealPhotoResponseSchema {
  static const Map<String, Object?> confidenceLevel = {
    'type': 'string',
    'enum': ['low', 'medium', 'high', 'certain'],
  };
  static const Map<String, Object?> value = {
    "anyOf": [
      {
        "type": "object",
        "additionalProperties": false,
        "required": [
          "schema_version",
          "status",
          "name",
          "itemized",
          "reference",
        ],
        "properties": {
          "schema_version": {
            "type": "integer",
            "enum": [1],
          },
          "status": {
            "type": "string",
            "enum": ["proposal"],
          },
          "name": {"type": "string"},
          "itemized": {
            "type": "array",
            "items": {
              "anyOf": [
                {
                  "type": "object",
                  "additionalProperties": false,
                  "required": [
                    "id",
                    "name",
                    "search_query",
                    "kind",
                    "candidate_key",
                    "estimated_weight_grams",
                    "recognition_confidence",
                    "quantity_confidence",
                    "nutrition_confidence",
                    "reason",
                    "reference_nutrition",
                  ],
                  "properties": {
                    "id": {"type": "string"},
                    "name": {"type": "string"},
                    "search_query": {"type": "string"},
                    "usda_food_name": {
                      "type": ["string", "null"],
                    },
                    "kind": {
                      "type": "string",
                      "enum": ["matched"],
                    },
                    "candidate_key": {"type": "string"},
                    "estimated_weight_grams": {
                      "type": ["number", "null"],
                    },
                    "recognition_confidence": confidenceLevel,
                    "quantity_confidence": confidenceLevel,
                    "nutrition_confidence": confidenceLevel,
                    "reason": {"type": "string"},
                    "reference_nutrition": {"type": "null"},
                  },
                },
                {
                  "type": "object",
                  "additionalProperties": false,
                  "required": [
                    "id",
                    "name",
                    "search_query",
                    "kind",
                    "candidate_key",
                    "estimated_weight_grams",
                    "recognition_confidence",
                    "quantity_confidence",
                    "nutrition_confidence",
                    "reason",
                    "reference_nutrition",
                  ],
                  "properties": {
                    "id": {"type": "string"},
                    "name": {"type": "string"},
                    "search_query": {"type": "string"},
                    "usda_food_name": {
                      "type": ["string", "null"],
                    },
                    "kind": {
                      "type": "string",
                      "enum": ["needs_assignment"],
                    },
                    "candidate_key": {"type": "null"},
                    "estimated_weight_grams": {
                      "type": ["number", "null"],
                    },
                    "recognition_confidence": confidenceLevel,
                    "quantity_confidence": confidenceLevel,
                    "nutrition_confidence": confidenceLevel,
                    "reason": {"type": "string"},
                    "reference_nutrition": {"type": "null"},
                  },
                },
                {
                  "type": "object",
                  "additionalProperties": false,
                  "required": [
                    "id",
                    "name",
                    "search_query",
                    "kind",
                    "candidate_key",
                    "estimated_weight_grams",
                    "recognition_confidence",
                    "quantity_confidence",
                    "nutrition_confidence",
                    "reason",
                    "reference_nutrition",
                  ],
                  "properties": {
                    "id": {"type": "string"},
                    "name": {"type": "string"},
                    "search_query": {"type": "string"},
                    "usda_food_name": {
                      "type": ["string", "null"],
                    },
                    "kind": {
                      "type": "string",
                      "enum": ["proposed_reference"],
                    },
                    "candidate_key": {"type": "null"},
                    "estimated_weight_grams": {
                      "type": ["number", "null"],
                    },
                    "recognition_confidence": confidenceLevel,
                    "quantity_confidence": confidenceLevel,
                    "nutrition_confidence": confidenceLevel,
                    "reason": {"type": "string"},
                    "reference_nutrition": {
                      "type": "object",
                      "additionalProperties": false,
                      "required": [
                        "carbs",
                        "fiber",
                        "fat",
                        "protein",
                        "carbs_label_mode",
                      ],
                      "properties": {
                        "carbs": {"type": "number"},
                        "fiber": {"type": "number"},
                        "fat": {"type": "number"},
                        "protein": {"type": "number"},
                        "carbs_label_mode": {
                          "type": "string",
                          "enum": ["eu", "non_eu"],
                        },
                      },
                    },
                  },
                },
              ],
            },
          },
          "reference": {
            "type": "object",
            "additionalProperties": false,
            "required": [
              "id",
              "name",
              "search_query",
              "kind",
              "candidate_key",
              "estimated_weight_grams",
              "recognition_confidence",
              "quantity_confidence",
              "nutrition_confidence",
              "reason",
              "reference_nutrition",
            ],
            "properties": {
              "id": {
                "type": "string",
                "enum": ["plate_reference"],
              },
              "name": {"type": "string"},
              "search_query": {"type": "string"},
              "usda_food_name": {
                "type": ["string", "null"],
              },
              "kind": {
                "type": "string",
                "enum": ["proposed_reference"],
              },
              "candidate_key": {"type": "null"},
              "estimated_weight_grams": {
                "type": ["number", "null"],
              },
              "recognition_confidence": confidenceLevel,
              "quantity_confidence": confidenceLevel,
              "nutrition_confidence": confidenceLevel,
              "reason": {"type": "string"},
              "reference_nutrition": {
                "type": "object",
                "additionalProperties": false,
                "required": [
                  "carbs",
                  "fiber",
                  "fat",
                  "protein",
                  "carbs_label_mode",
                ],
                "properties": {
                  "carbs": {"type": "number"},
                  "fiber": {"type": "number"},
                  "fat": {"type": "number"},
                  "protein": {"type": "number"},
                  "carbs_label_mode": {
                    "type": "string",
                    "enum": ["eu", "non_eu"],
                  },
                },
              },
            },
          },
        },
      },
      {
        "type": "object",
        "additionalProperties": false,
        "required": ["schema_version", "status", "reason", "questions"],
        "properties": {
          "schema_version": {
            "type": "integer",
            "enum": [1],
          },
          "status": {
            "type": "string",
            "enum": ["needs_clarification"],
          },
          "reason": {
            "type": "string",
            "enum": [
              "ambiguous_menu_item",
              "unreadable_menu",
              "missing_menu",
              "conflicting_evidence",
            ],
          },
          "questions": {
            "type": "array",
            "items": {"type": "string"},
          },
        },
      },
    ],
  };
}

const Map<String, Object?> unifiedMealPhotoResponseSchema =
    MealPhotoResponseSchema.value;

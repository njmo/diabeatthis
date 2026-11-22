package pl.diabeatthis.wear;

import android.content.Context;
import android.content.SharedPreferences;
import android.content.res.Configuration;
import java.util.Locale;

final class WatchLanguage {
    private static final String PREFERENCES = "mealDecisionWatch";
    private static final String LANGUAGE = "languageTag";

    private WatchLanguage() {}

    static Context savedLabels(Context context) {
        String saved = preferences(context).getString(LANGUAGE, "");
        return labels(context, Locale.forLanguageTag(saved));
    }

    static Context update(Context context, String tag) {
        Locale locale = Locale.forLanguageTag(tag.replace('_', '-'));
        if (locale.getLanguage().isEmpty()) return savedLabels(context);
        SharedPreferences preferences = preferences(context);
        String normalized = locale.toLanguageTag();
        if (!normalized.equals(preferences.getString(LANGUAGE, ""))) {
            preferences.edit().putString(LANGUAGE, normalized).apply();
        }
        return labels(context, locale);
    }

    private static SharedPreferences preferences(Context context) {
        return context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE);
    }

    private static Context labels(Context context, Locale locale) {
        if (locale.getLanguage().isEmpty()) return context;
        Configuration configuration = new Configuration(context.getResources().getConfiguration());
        configuration.setLocale(locale);
        return context.createConfigurationContext(configuration);
    }
}

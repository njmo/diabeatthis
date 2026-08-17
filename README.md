<img width="192" height="192" alt="ic_launcher" src="https://github.com/user-attachments/assets/7d646654-523c-46f8-8c5d-ea2bf8f5a282" />

# DiaBeatThis

**DiaBeatThis is an intelligent diabetes companion for people living with Type 1 Diabetes and the families who support them.**

It brings together meal planning, CGM context, insulin/treatment events, activity tracking, meal history, and AI-assisted food recognition to reduce the daily mental load of T1D. The app does not replace medical judgement or deliver insulin automatically. It helps users remember the right steps, see the right context, and make more confident decisions.

---

## Why It Exists

Managing T1D is not only about counting carbs. It is about understanding how real food, real timing, school routines, activity, and insulin context work together.

DiaBeatThis exists because families should not have to repeat the same exact school meals forever just to make diabetes manageable. A parent should not need to send a child with paper notes explaining which box has how many grams of carbs. The app keeps the plan, the portions, the meal context, and the follow-up data in one place.

Over time, that creates practical memory:

- how a specific school meal affected glucose,
- what happened when a child ate before physical education,
- how glucose behaved during a particular activity after a particular meal,
- how the child reacted to food that parents do not fully control, like school soup,
- whether a restaurant meal should use a different reference portion next time,
- whether the same breakfast works differently at another time of day.

DiaBeatThis turns those repeated situations into reusable meal and activity context, so the next plan can be better than the last one.

---

## The Key Idea: Food First, Insulin In AAPS

DiaBeatThis is built around **food, grams, portions, and real-life meal context**. AAPS is built around **insulin delivery, pump logic, and therapy execution**.

That distinction matters:

- DiaBeatThis helps plan what will actually be eaten: grams, portions, net carbs, fat, protein, fiber, add-ons, and what was left on the plate.
- AAPS remains the place where insulin is calculated, confirmed, and delivered.
- DiaBeatThis can open or guide the calculator flow, but it does not assume that insulin was given just because the user tapped a button.
- Bolused meal states are reached only after calculator/treatment evidence appears.

In practice, DiaBeatThis translates messy real food into structured context, then helps the user use AAPS more reliably.

---

## What The App Can Do

### Meal Planning

- Create planned meals with ingredients, portions, carbs, fat, protein, and fiber.
- Build a daily meal list with clear meal statuses.
- Define custom portions such as pieces, slices, a child's handful, a school serving, or any other practical unit.
- Help children use predefined portions when weighing food is not realistic.
- Keep active unfinished meals visible, even if they were planned on a previous day.
- Block starting another meal while one meal is still active, so a user cannot lose an unfinished meal in the background.
- Use meal summaries to record what was actually eaten.
- Support add-ons when the user eats more than planned.
- Keep meal data structured enough to compare future meals with previous reactions.

### School Meal Support

DiaBeatThis is designed for the parent + child scenario where a parent plans the day and the child gradually becomes more independent.

A parent can prepare meals for school in advance, including grams, portions, and nutrition data. The child does not need a separate card explaining which container has how many carbs. When meal time comes, the app can guide the child through the actual flow: temp target reminder, meal advice, bolus reminder, eating confirmation, and later meal summary. This reduces the chance that a meal remains in a vague "planned" state while the child has already started eating.

For families, this means fewer blind spots during the school day. The parent can plan once, the child gets simpler actions, and the family can later review how that meal behaved in the real school context.

### Meal Monitor

The foreground meal monitor follows the user from planned meal to finished meal:

- Finds the next planned meal automatically.
- Uses CGM/device context such as glucose, trend, IOB, and COB.
- Normalizes meal timing around recent CGM readings.
- Suggests a meal temp target when useful.
- Repeats temp target reminders until a real treatment event is detected.
- Calculates meal advice from macros and glucose context.
- Supports three practical meal decisions:
  - eat now, bolus later,
  - bolus and eat now,
  - bolus, wait, then eat.
- Opens the right AAPS/calculator flow when the user accepts advice.
- Tracks a dedicated `waiting-for-bolus` state so bolused statuses are reached only after calculator bolus evidence.
- Repeats bolus reminders if the user agreed to eat but no calculator bolus appears.
- Keeps reminding about missing bolus actions instead of silently letting the meal continue in a risky state.
- Allows skipping/cancelling the meal from the bolus reminder.
- Asks whether the user has finished eating.
- Schedules meal summary reminders after the meal is finalized.

The important part: the app does not treat a button click as proof that insulin was given. It waits for calculator/treatment data before moving into bolused meal states.

### Meal Target And Activity Target Reminders

DiaBeatThis helps users remember temporary targets before the moment when they matter most:

- reminds about setting a meal temp target before a planned meal,
- repeats meal target reminders until a real target/treatment event is detected,
- reminds about setting an activity temp target before planned physical activity,
- repeats activity target reminders until the target is actually detected,
- avoids treating a dismissed notification as a completed diabetes action.

This is especially useful for children at school, where the parent may have planned the day but the child still needs simple, repeated prompts at the right time.

### Smarter Bolus Timing Support

For meals where the user should bolus and wait before eating, DiaBeatThis can:

- wait from the actual bolus moment,
- track the recommended wait time,
- monitor glucose trend during the wait,
- shorten the wait when glucose starts dropping quickly,
- notify the user when it is time to eat,
- support the whole "bolus, wait, then eat" routine without requiring the user to manually remember the timer,
- record the final wait outcome for future learning.

This makes "wait 15 minutes" less mechanical and more connected to the user's real glucose behavior.

### Add-ons And Low Treatments

Real meals are rarely perfect. Children eat more, leave food on the plate, ask for an extra snack, or need fast carbs during activity. DiaBeatThis models those moments explicitly:

- add extra food to an active meal as an add-on,
- calculate add-on carbs separately from the original plan,
- remind about bolus when an add-on requires calculator action,
- record low treatments related to a meal,
- record low treatments related to physical activity,
- keep those events connected to the context that caused them.

That means a post-meal correction, a school snack, or fast carbs during football practice can become part of the history instead of disappearing as an isolated note.

### Reference Meals And Learning From History

DiaBeatThis is built around the idea that yesterday's data should make tomorrow easier.

Reference meals and meal history help users compare new meals with previous entries:

- Reuse meals that are already known.
- Copy and adjust ingredients or portions instead of rebuilding everything.
- Compare planned portions with what was actually eaten.
- Keep post-meal summaries so users can review how glucose behaved after similar meals.
- Use previous meals as a starting point when tuning school lunches, breakfasts, snacks, or sports-day meals.
- Tune a reference meal after uncontrolled meals, for example when a child reacts strongly to school soup and the next plan needs a larger or smaller reference portion.
- Tune restaurant reference meals visit by visit, using the glucose chart and actual meal impact instead of guessing from scratch every time.

For example: if a child repeatedly eats a similar sandwich at school, the parent can use previous entries as a reference, adjust the portion, and observe how glucose responded last time. The same applies to restaurant meals: create a reference meal once, refine it after each visit, and make the next bolus/portion plan better informed.

### Meal Analysis And Timeline

After a meal, DiaBeatThis can help explain what happened around it:

- show glucose behavior before and after the meal,
- include boluses, corrections, carbs, extended carbs, and temporary targets,
- show meal status history and when each step happened,
- include nearby meals that may have affected the chart,
- include linked activity around the same time,
- include low treatments connected with the meal,
- use longer analysis windows for heavier mixed meals,
- help compare the same or similar meals across different times of day.

This is where reference meals become useful. A family can look at the chart, see the real impact, and adjust grams or portions next time.

### Activity Tracking

Physical activity is treated as a first-class diabetes context, not just a note.

The activity monitor can:

- track planned and active activities,
- remind the user to set an activity temp target 45 minutes before the activity,
- repeat temp target reminders until a real treatment event is detected,
- react to manual start, stop, and cancellation,
- monitor activities with a planned duration,
- ask whether the activity has ended,
- leave manual activities under user control when there is no duration,
- connect low treatments with activity context,
- help distinguish "I needed sugar during this activity" from a random standalone snack.

This is useful for school PE, football practice, walks, cycling, or spontaneous activity where glucose behavior often depends on timing, IOB, COB, and previous food.

For school activity, the key value is context: what the child ate before exercise, how that meal affected the activity, whether a temp target was set, whether low treatment was needed, and what glucose did during and after the activity.

### Food Recognition And Faster Data Entry

The app includes AI-assisted food workflows to reduce typing and improve consistency:

- scan or look up ingredients by barcode,
- scan product photos and nutrition labels,
- extract nutrition per 100 g,
- recognize portions,
- keep incomplete scans editable instead of silently trusting bad data,
- search ingredients from photos,
- build local ingredient and portion history.

The goal is not to make users depend on AI. The goal is to make food entry faster while keeping the user in control of validation.

### Integrations And Data Sources

DiaBeatThis is integration-first:

- Nightscout-style glucose and treatment history,
- AAPS-oriented suggestions and calculator handoff,
- local app data for meals, ingredients, activities, and summaries,
- support for push-based data sources where available.

The architecture is designed so the app can combine CGM readings, meal context, activity context, treatments, and local history into one practical workflow.

---

## Example Day

1. A parent plans breakfast and a school lunch in the morning.
2. The app tracks the next meal and checks current glucose context.
3. Before lunch, it reminds the child about the meal temp target if needed.
4. At meal time, it recommends whether to eat now, bolus now, or wait after bolus.
5. If the child opens the bolus flow but forgets to use the calculator, the app keeps reminding instead of assuming the bolus happened.
6. After eating, the app asks whether the meal is finished.
7. Later, the parent reviews what was actually eaten and can use that meal as a reference for future school lunches.
8. If there is PE or football practice, the activity monitor reminds about the activity temp target and tracks whether the activity actually ended.

---

## Who It Helps

- **Parents of children with T1D** who need structure, reminders, and better visibility during school days.
- **Children and teenagers** who are learning independence but still need guardrails.
- **Adults with T1D** who want less guesswork around meals, activity, and recurring routines.
- **Caregivers, educators, and relatives** who need simple context instead of raw diabetes data.

---

## Product Principles

- **User remains responsible.** The app supports decisions, it does not prescribe therapy or deliver insulin.
- **Food is tracked in grams.** DiaBeatThis models the real meal; AAPS handles insulin.
- **Evidence beats intent.** A tapped button is not treated as a bolus; calculator/treatment data matters.
- **Context matters.** Meals, insulin, glucose trend, COB, IOB, and activity belong together.
- **History should be useful.** Past meals and activities should help tune future plans.
- **Parents need peace of mind.** Especially when a child eats at school or is away from home.
- **Data entry must be fast.** AI and reusable meals reduce friction, but the user validates the result.

---

## Current Focus

The project is focused on building a practical MVP for the parent + child use case:

- reliable meal and bolus monitoring,
- activity temp target support,
- high-quality meal history,
- reference meals,
- AI-assisted ingredient entry,
- local-first structured data,
- integrations with diabetes data sources.

---

## Contributing

DiaBeatThis is an open, mission-driven project. Contributions are welcome from:

- Flutter/mobile developers,
- backend and data integration developers,
- AI/ML engineers,
- UX/UI designers,
- diabetes educators and clinicians,
- parents, adults, and people with lived T1D experience.

---

## Safety Note

DiaBeatThis is not a medical device, does not replace professional medical advice, and does not make autonomous insulin decisions. It is a decision-support and workflow assistant. All therapy decisions remain with the user, caregiver, and medical team.

---

## License

TBD.

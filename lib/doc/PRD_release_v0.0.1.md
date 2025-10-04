# PRD_release_v0.0.1

## 1. Product Goal
The goal of version **v0.0.1** is to enable a parent to plan meals for their child with diabetes and support the child in making food-related decisions based on **real-time Nightscout data (BG, trend, IOB, COB)**.  

The minimal feature set should allow:
- connecting to a Nightscout account,  
- the parent to plan meals,  
- the child to see current glucose values and the planned meals,  
- the child to mark meals as eaten,  
- a simple daily meal history to be stored.  

---

## 2. Scope of v0.0.1

### 2.1 Nightscout Integration
- The parent provides **URL + token** for their Nightscout instance.  
- The app fetches in **read-only mode**:
  - current blood glucose (BG),  
  - trend (arrow),  
  - Carbs on Board (COB),  
  - Insulin on Board (IOB).  
- Data is refreshed every **5 minutes** (aligned with CGM updates).  
- Error handling: unavailable server, invalid token, or no internet connection should display a clear error message.  

### 2.2 Child View
- **Home screen:**
  - current BG, trend, IOB, COB,  
  - list of planned meals for the current day,  
  - meal status: *planned / in progress / eaten*.  
- **Meal details:**
  - show grams of carbohydrates (or WW) contained,  
  - a simple recommendation message:
    - "eat now",  
    - "wait",  
    - "eat partially".  
- Child can mark a meal as *eating* or *eaten*.  

### 2.3 Parent View
- Add product (name, grams, WW).  
- Create a meal from products.  
- Schedule a meal for the current day (time, name, WW).  
- See a daily list of planned meals with statuses.  

### 2.4 Minimal History
- Display a daily list of meals with time and status.  
- No pre/post glucose analysis in this version.  

---

## 3. Out of Scope for v0.0.1
- Historical analysis of meals with BG correlation before/after.  
- Training sessions and their history.  
- Past products and recommendations.  
- Authentication / multi-user accounts.  
- Advanced analytics, statistics, or reports.  

---

## 4. Users & Scenarios

### 4.1 Parent
- Adds products and creates meals.  
- Plans child’s meals for the day.  
- Monitors whether meals were eaten.  

### 4.2 Child
- Sees real-time glucose data from Nightscout.  
- Views today’s meals.  
- Decides whether to eat (with simple recommendations).  
- Marks a meal as eaten.  

---

## 5. Key User Stories (MVP)

1. **As a user I want to connect my Nightscout account**, so the app can fetch my glucose data.  
2. **As a child I want to see my current BG, trend, IOB, and COB**, so I know my status before meals.  
3. **As a parent I want to add products and create meals**, so I can plan what my child eats.  
4. **As a parent I want to schedule meals for specific times**, so my child knows what to eat during the day.  
5. **As a child I want to open a meal and see its carbohydrate content and a simple recommendation**, so I know how to act.  
6. **As a child I want to mark a meal as eaten**, so my daily record is updated.  
7. **As a parent I want to see a daily list of meals with their statuses**, so I can monitor my child’s day.  

---

## 6. Success Criteria
- The app can successfully connect and read data from Nightscout (BG, trend, IOB, COB).  
- Parent can add at least one product and create a meal.  
- Child sees planned meals alongside current glucose data.  
- Child can mark meals as eaten.  
- Parent can see a simple history of meals for the current day.  

---

## 7. Non-Functional Requirements
- All data (except Nightscout data) is stored locally on the device.  
- App works offline (without Nightscout, only meal planning is available).  
- Minimalist interface with child-friendly UX (large buttons, simple flow).  
- Multilingual support: English and Polish.  

---

## 8. Release Plan
- **Sprint 1:** Nightscout integration + basic BG display.  
- **Sprint 2:** Product & meal CRUD (parent).  
- **Sprint 3:** Child view with meal list and statuses.  
- **Sprint 4:** Simple daily history.  
- **Release v0.0.1**  

---
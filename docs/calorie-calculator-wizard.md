Below is a practical, science-backed form design for your calorie-target calculator. It uses **Mifflin-St Jeor → activity factor → goal adjustment**, then later adapts from real user weight trends.

Important: present the output as an **estimate**, not a precise prescription. A systematic review found Mifflin-St Jeor was the most reliable among several common RMR equations, but still warned that individual errors exist and indirect calorimetry is the direct measurement method. ([PubMed][1])

---

# 1. Form objective

The form should calculate:

```text
BMR / RMR estimate
  ↓
TDEE / maintenance calories
  ↓
goal-adjusted daily calorie target
  ↓
recommended range
```

Use:

```text
Men:
BMR = 10 × weight_kg + 6.25 × height_cm − 5 × age + 5

Women:
BMR = 10 × weight_kg + 6.25 × height_cm − 5 × age − 161

TDEE = BMR × activity_factor
```

Then:

```text
Fat loss target = TDEE − deficit
Maintenance target = TDEE
Muscle gain target = TDEE + surplus
```

---

# 2. Required form questions

## Question 1 — Date of birth or age

**Question shown to user**

```text
What is your age?
```

**Input**

```text
Number, in years
```

**Why needed**

Age is part of the Mifflin-St Jeor equation. Resting energy expenditure generally changes with age, and age is one of the formula variables.

**Validation**

```text
Minimum: 18
Maximum: 80 or 100
```

For minors, do not use the normal adult calculator without medical/professional guidance.

---

## Question 2 — Biological sex used for the equation

**Question shown to user**

```text
Which biological sex should be used for the calorie equation?
```

**Options**

```text
Male
Female
```

---

## Question 3 — Height

**Question shown to user**

```text
What is your height?
```

**Input**

```text
cm
or
feet/inches converted to cm
```

**Why needed**

Height is part of the Mifflin-St Jeor equation.

**Validation**

```text
120–230 cm
```

---

## Question 4 — Current body weight

**Question shown to user**

```text
What is your current weight?
```

**Input**

```text
kg
or
lb converted to kg
```

**Why needed**

Weight is part of the Mifflin-St Jeor equation and also needed for tracking goal progress.

**Validation**

```text
35–250 kg
```

---

## Question 5 — Main goal

**Question shown to user**

```text
What is your main goal?
```

**Options**

```text
Lose fat
Maintain weight
Gain muscle / weight
Recomposition
```

**Why needed**

Maintenance calories are not the final target unless the user wants to maintain. Weight loss requires a deficit; weight gain generally requires a surplus.

NHLBI states that weight loss requires reducing calorie intake and/or increasing activity, and that many people need a 500–750 kcal/day reduction for about 1–1.5 lb/week loss. ([NHLBI, NIH][2])

---

## Question 6 — Activity level

**Question shown to user**

```text
Which option best describes your usual weekly activity?
```

Use this as a required question.

Activity multipliers are practical approximations, not direct measurements. They are widely used with BMR equations in calculators, but users frequently overestimate activity, so the labels must be concrete.

---

# 3. Activity factor definitions for the app

Use these options.

## Sedentary — `1.2`

**App label**

```text
Sedentary
```

**User-facing explanation**

```text
Mostly seated during the day, desk job or studying, little walking, and no structured exercise or only very occasional exercise.
```

**Examples**

```text
Desk job
Student seated most of the day
Drives or uses transport everywhere
0–1 short/light workouts per week
Low daily steps
```

**Use when**

```text
The user does not train regularly and daily movement is low.
```

NHLBI defines sedentary activity as only light physical activity as part of the typical daily routine. ([NHLBI, NIH][3])

---

## Lightly active — `1.375`

**App label**

```text
Lightly active
```

**User-facing explanation**

```text
Mostly seated lifestyle, but you walk regularly or do light exercise 1–3 days per week.
```

**Examples**

```text
Desk job + walks most days
1–3 gym sessions per week, not very intense
Several thousand daily steps
Light cycling/walking
```

**Use when**

```text
The user has some regular movement but not hard training.
```

---

## Moderately active — `1.55`

**App label**

```text
Moderately active
```

**User-facing explanation**

```text
Regular exercise 3–5 days per week, or a daily routine with meaningful walking/standing plus some training.
```

**Examples**

```text
Gym 3–5 days/week
Regular running/cycling/sports
Active daily routine
Roughly 8k–12k steps/day for many users
```

**Use when**

```text
The user trains consistently but does not have a physically demanding job or daily hard training.
```

NHLBI defines moderately active as physical activity equivalent to walking about 1.5–3 miles/day at 3–4 mph, plus light daily activity. ([NHLBI, NIH][3]) CDC also recommends adults aim for 150 minutes of moderate-intensity activity or 75 minutes of vigorous-intensity activity weekly, plus muscle-strengthening activity, which can help users understand what “regular activity” means. ([CDC][4])

---

## Very active — `1.725`

**App label**

```text
Very active
```

**User-facing explanation**

```text
Hard exercise most days, or a physically active job combined with regular training.
```

**Examples**

```text
Hard training 5–7 days/week
Manual job + some training
Competitive sport practice most days
High daily steps and regular intense exercise
```

**Use when**

```text
The user has high weekly exercise volume or physically demanding work.
```

NHLBI defines active as activity equivalent to walking more than 3 miles/day at 3–4 mph, plus light daily activity. ([NHLBI, NIH][3])

---

## Extra active — `1.9`

**App label**

```text
Extra active / athlete-level
```

**User-facing explanation**

```text
Very demanding physical job, endurance training, two-a-day training, or athlete-level workload.
```

**Examples**

```text
Construction/manual labor + training
Endurance athlete
Two training sessions per day
Military-style training workload
Competitive athlete in high-volume phase
```

**Use when**

```text
The user has unusually high total daily energy expenditure.
```

**Product warning**

Most users should not choose this. If selected, show:

```text
This level is only for very high activity. If unsure, choose Very active or Moderately active.
```

---


## Question 11 — Target rate of change

For fat loss:

```text
How fast do you want to lose weight?
```

Options:

```text
Slow / easier to maintain
Moderate / recommended
Aggressive
```

For weight gain:

```text
How fast do you want to gain weight?
```

Options:

```text
Lean / minimal fat gain
Standard
Aggressive
```

This controls deficit/surplus.


---


# 5. Goal adjustment: deficits and surpluses

## Fat loss deficit options

Use percentage-based deficit as your app default, with kcal caps.

### Conservative fat loss

```text
−10% of TDEE
```

Best for:

```text
lean users
performance-sensitive users
beginners who want sustainability
users worried about hunger/adherence
```

### Moderate fat loss — recommended default

```text
−15% to −20% of TDEE
```

Best for most users.


### Implementation rule

Calculate both:

```text
percentage_deficit = TDEE × selected_percentage
absolute_deficit = 300–750 kcal depending on goal
```

Then choose a safe bounded value.

Example:

```ts
deficit = clamp(TDEE * 0.15, 300, 750)
```

For aggressive:

```ts
deficit = clamp(TDEE * 0.25, 500, 1000)
```

But do not allow very low targets without warning.

---

## Maintenance

```text
target_calories = TDEE
```

Show a range:

```text
TDEE ± 100–150 kcal
```

Because daily expenditure fluctuates.

---

## Muscle gain / weight gain surplus options

Evidence for exact surplus size is less precise than for weight loss. ACSM notes that common sports-nutrition recommendations often start around **+500 kcal/day**, but also states that intentional weight-gain guidance is based more on estimates and assumptions than strong direct evidence. ([ACSM][5])

Use conservative surplus recommendations:

### Lean gain

```text
+5% of TDEE
or roughly +100–200 kcal/day
```

Best for:

```text
users who want minimal fat gain
intermediate/advanced lifters
```

### Standard muscle gain

```text
+10% of TDEE
or roughly +200–350 kcal/day
```

Best default for most users trying to gain muscle.

# 6. Recommended form flow

## Screen 1 — Basic profile

```text
1. Age
2. Biological sex for equation
3. Height
4. Current weight
```

## Screen 2 — Activity

```text
5. Normal day type
6. Training days per week
```

Use job/day type + training frequency to suggest an activity factor, then let the user confirm.

## Screen 3 — Goal

```text
9. Goal: lose fat / maintain / gain muscle / 
```

## Screen 5 — Result

Show:

```text
Estimated BMR
Estimated maintenance calories
Recommended target calories
Recommended range
Explanation
Adjustment plan
```

Example:

```text
Estimated BMR: 1,780 kcal/day
Estimated maintenance: 2,760 kcal/day
Goal: fat loss
Recommended target: 2,300 kcal/day
Range: 2,200–2,400 kcal/day

This is an estimate. Track your weight trend for 2–4 weeks and we’ll adjust.
```

---

# 7. Product rules for safer outputs

## Minimum calorie guardrails

Do not recommend below:

```text
Women: around 1,200 kcal/day
Men: around 1,500 kcal/day
```

NHLBI states eating plans of 1,200–1,500 kcal/day help many women lose weight safely, while 1,500–1,800 kcal/day are suitable for many men and heavier/exercising women; it also warns not to use diets under 800 kcal/day without medical monitoring. ([NHLBI, NIH][2])

Use these as **guardrails**, not rigid universal rules.

---

## Adaptive recalibration

The best “accuracy” improvement is not a more complex initial form. It is recalibration.

After 2–4 weeks:

```text
If weight loss is slower than expected:
  reduce target by 100–200 kcal/day

If weight loss is too fast:
  increase target by 100–200 kcal/day

If weight gain is too fast:
  reduce surplus by 100–200 kcal/day

If weight gain is not happening:
  increase by 100–200 kcal/day
```

This is critical because formulas estimate population averages, not exact individual expenditure.

---

# 10. Recommended app defaults

Use these defaults:

```text
Default formula:
Mifflin-St Jeor

Default fat loss:
15% deficit, capped around 500–750 kcal/day

Default muscle gain:
10% surplus, usually around 200–350 kcal/day

Default maintenance:
TDEE ± 100–150 kcal

Default activity:
Suggest from day type + training days; let user confirm

Default recalibration:
After 14–28 days of weight trend data
```

The final UX should say:

```text
This is a starting estimate, not a perfect number. Your app will adjust it using your real weight trend and logging data.
```



[1]: https://pubmed.ncbi.nlm.nih.gov/15883556/?utm_source=chatgpt.com "Comparison of predictive equations for resting metabolic rate in healthy nonobese and obese adults: a systematic review - PubMed"
[2]: https://www.nhlbi.nih.gov/health/educational/lose_wt/eat/calories.htm?utm_source=chatgpt.com "Healthy Eating Plan"
[3]: https://www.nhlbi.nih.gov/health/dash/following-dash?utm_source=chatgpt.com "DASH - Following DASH | NHLBI, NIH"
[4]: https://www.cdc.gov/physical-activity-basics/adding-adults/what-counts.html?CDC_AAref_Val=https%3A%2F%2Fwww.cdc.gov%2Fphysicalactivity%2Fbasics%2Fadults%2Findex.htm&utm_source=chatgpt.com "What Counts as Physical Activity for Adults | Physical Activity Basics | CDC"
[5]: https://acsm.org/healthy-weight-gain-athletes/?utm_source=chatgpt.com "Is Healthy Weight Gain in Athletes Realistic?"

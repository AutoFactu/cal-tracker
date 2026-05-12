# Calorie Estimation Methodology

This document describes how Better Calories calculates the first-run calorie target estimate. The app presents the result as a starting estimate, not a medical prescription.

## Inputs

The calculator uses:

- Age in years, validated from 18 to 100.
- Biological sex for the equation: male or female.
- Height in centimeters, validated from 120 to 230 cm.
- Weight in kilograms, validated from 35 to 250 kg.
- Activity level.
- Main goal and, when relevant, target rate of change.

The mobile form may collect height and weight in imperial units, but the backend receives centimeters and kilograms.

## BMR Formula

The backend uses Mifflin-St Jeor.

```text
Male:
BMR = 10 * weight_kg + 6.25 * height_cm - 5 * age + 5

Female:
BMR = 10 * weight_kg + 6.25 * height_cm - 5 * age - 161
```

The resulting BMR is multiplied by an activity factor to estimate maintenance calories.

```text
TDEE = BMR * activity_factor
```

## Activity Factors

The app uses the activity factors below. They are estimates, so the labels are intentionally concrete to reduce over-selection.

| Activity level | Factor | App meaning |
| --- | ---: | --- |
| Sedentary | 1.2 | Mostly seated, low daily movement, 0-1 short/light workouts per week. |
| Lightly active | 1.375 | Regular walks or light exercise 1-3 days per week. |
| Moderately active | 1.55 | Training 3-5 days per week or a meaningfully active routine. |
| Very active | 1.725 | Hard exercise most days or active work plus regular training. |
| Extra active | 1.9 | Athlete-level workload, two-a-days, or demanding physical work. |

Selecting extra active returns a warning because most users should choose a lower activity level unless their total daily workload is unusually high.

## Goal Adjustments

Maintenance and recomposition use estimated TDEE directly.

```text
target_calories = TDEE
recommended_range = target_calories +/- 150 kcal
```

Fat loss subtracts a bounded deficit.

| Pace | Formula | Bounds |
| --- | --- | --- |
| Slow | TDEE * 10% | 250-500 kcal |
| Moderate | TDEE * 15% | 300-750 kcal |
| Aggressive | TDEE * 25% | 500-1000 kcal |

Muscle gain adds a bounded surplus.

| Pace | Formula | Bounds |
| --- | --- | --- |
| Lean | TDEE * 5% | 100-200 kcal |
| Standard | TDEE * 10% | 200-350 kcal |
| Aggressive | TDEE * 15% | 350-500 kcal |

Fat-loss and muscle-gain recommended ranges use `target_calories +/- 100 kcal`.

## Rounding And Guardrails

- BMR is rounded to the nearest whole calorie.
- Maintenance, target, adjustment, and range values are rounded to the nearest 10 kcal.
- The backend never returns a target below the app's saveable minimum of 800 kcal.
- If the estimate falls below 1200 kcal for the female equation or 1500 kcal for the male equation, the response includes a warning.
- Existing goal validation still limits saved targets to 800-10000 kcal.

## Example Calculation

Example: male, 30 years old, 80 kg, 180 cm, moderately active, maintenance.

```text
BMR = 10 * 80 + 6.25 * 180 - 5 * 30 + 5
BMR = 1780 kcal/day

TDEE = 1780 * 1.55
TDEE = 2759 kcal/day

Rounded maintenance target = 2760 kcal/day
Recommended range = 2610-2910 kcal/day
```

Example: female, 35 years old, 70 kg, 165 cm, lightly active, moderate fat loss.

```text
BMR = 10 * 70 + 6.25 * 165 - 5 * 35 - 161
BMR = 1395 kcal/day

TDEE = 1395 * 1.375
TDEE = 1918 kcal/day

Deficit = clamp(1918 * 15%, 300, 750)
Deficit = 300 kcal/day

Rounded target = 1620 kcal/day
Recommended range = 1520-1720 kcal/day
```

## Sources

- Mifflin-St Jeor equation record: https://agris.fao.org/search/en/providers/122535/records/65de26fe7c7033e84be9ee76
- Systematic review comparing RMR equations: https://www.sciencedirect.com/science/article/abs/pii/S0002822305001495
- NHLBI calorie guidance and low-calorie guardrails: https://www.nhlbi.nih.gov/health/educational/lose_wt/eat/calories.htm
- NHLBI activity definitions: https://www.nhlbi.nih.gov/health/dash/following-dash
- CDC adult activity guidance: https://www.cdc.gov/physical-activity-basics/guidelines/adults.html
- ACSM discussion of weight-gain surplus limitations: https://acsm.org/healthy-weight-gain-athletes/

## Limitations

Predictive equations estimate population averages. Real energy expenditure varies by body composition, non-exercise activity, training adaptation, logging accuracy, and weight trend. Future adaptive recalibration should compare the user's 14-28 day weight trend against the selected goal and adjust the target by 100-200 kcal when needed.

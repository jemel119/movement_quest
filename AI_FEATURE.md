# Gear Match

## Purpose

Gear Match suggests a saved workout plan using the user's equipment
preference and most recently completed session. It explains its choice
and lets the user view the plan or dismiss the suggestion.

The helper runs offline. It uses deterministic rules, with no trained
model, external inference service, or network request.

## Inputs

- Saved workout plans, including their IDs and equipment tags.
- The equipment preference saved in Settings.
- Training logs grouped by session key.

A missing equipment preference means the user has no preference.
The equipment tag `None` means a preference for workouts without
equipment. Those values are treated differently.

## Scoring

Each plan receives:

- Two points if its equipment tag matches the saved preference.
- One point if it differs from the most recently completed session's plan.

If no preference is saved, no equipment points are awarded.
If no completed session exists, no recent-session points are awarded.

The highest score wins. Equal scores use ascending plan ID.

## Identifying the recent session

Sets are grouped by session key. Only completed sessions are considered.

Sessions are ordered by their latest set timestamp, newest first.
Equal timestamps use ascending session key.

Several sets belonging to one session count as one session.
A newer unfinished session does not replace completed history.

## User interaction

Gear Match appears on the Workouts page.

1. The user selects Find a plan.
2. The helper reads all saved plans, the equipment preference, and history.
3. It displays the suggested plan, rule score, and explanation.
4. View plan opens workout details.
5. Not now dismisses the suggestion.

The catalog's equipment filter does not restrict the helper's candidates.
Viewing a suggestion does not automatically start a session.

The score describes the rules applied. It is not a confidence estimate,
fitness rating, or measure of workout suitability.

## Empty and invalid inputs

An empty catalog produces a message asking the user to add a plan.

Invalid equipment preferences, unsaved plans, and duplicate plan IDs are
rejected. Inconsistent session metadata is also rejected rather than
silently used.

Storage and preference-loading failures produce feedback and allow
another request.

## Baseline

The baseline uses equipment matching alone:

- Matching equipment earns two points.
- No preference means no equipment points.
- Equal scores use ascending plan ID.

It does not use recent-session history.

Both methods received the same candidate plans and equipment preference
for each evaluation case. Gear Match also used the supplied history;
the baseline intentionally ignored it.

## Development tests

The scoring tests cover normal, empty, invalid, boundary, and
counterexample inputs, including:

- Combined equipment and recent-session points.
- Equipment matching outweighing the recent-session bonus.
- Missing preference and missing completed history.
- No-equipment preference.
- Stable tie-breaking.
- A single candidate.
- Multiple sets in one session.
- Unfinished sessions being ignored.
- Invalid preferences, duplicate IDs, and unsaved plans.
- Inconsistent session metadata.
- A case where Gear Match differs from the baseline.

Interface tests cover recommendations, explanations, dismissal, the
View plan callback, empty catalogs, disabled controls, and error recovery.

These are development tests. They are separate from the held-out cases.

## Held-out evaluation

Five new synthetic cases and their rule-based reference choices were
committed before evaluation. They were not used in the development tests.

The reference choices describe the required scoring behavior. They are
not independently collected user preferences.

Frozen inputs:
`evaluation/gear_match_held_out.json`

Evaluator:
`tool/evaluate_gear_match.dart`

Generated results:
`evaluation/gear_match_results.json`

| Case | Reference plan | Gear Match | Baseline |
|---|---:|---:|---:|
| H1 | 11 | 11 | 11 |
| H2 | 44 | 44 | 38 |
| H3 | 52 | 52 | 52 |
| H4 | 71 | 71 | 71 |
| H5 | 96 | 96 | 91 |

| Method | Reference matches | Mismatches | Runtime errors |
|---|---:|---:|---:|
| Gear Match | 5/5 | 0/5 | 0 |
| Equipment-only baseline | 3/5 | 2/5 | 0 |

In H2, both relevant plans matched the equipment preference. Gear Match
selected the plan that differed from the recent session, while the
baseline selected the lower ID.

In H5, no plan matched the equipment preference. Gear Match used the
recent-session bonus and selected plan 96. The baseline selected plan 91
through its ID tie-break.

The results file records the evaluation time, source revision, and
commit associated with the frozen cases.

## Reproducing the evaluation

From the project root:

```powershell
dart run tool/evaluate_gear_match.dart
```

This reruns the evaluation and replaces the generated results file.

If the helper is revised after reviewing these results, a fresh held-out
case set is needed for the revised evaluation.

## Limitations

Five synthetic cases provide a small check of rule compliance.
They do not establish that users prefer these suggestions or that the
suggested workouts improve fitness outcomes.

Equipment tags are broad, and the helper does not interpret exercise
notes, assess health conditions, or determine whether a workout is safe.

Session recency uses the latest logged set timestamp. It is not a
separately recorded completion timestamp.

The evaluation exercises scoring with constructed inputs. It does not
verify Android storage, app restart persistence, or the full device UI.

## Implementation files

- `lib/services/gear_match_service.dart`
- `lib/widgets/gear_match_panel.dart`
- `lib/models/training_session.dart`
- `test/services/gear_match_service_test.dart`
- `test/widgets/gear_match_panel_test.dart`
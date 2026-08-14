/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — the search box: a discarded constructor argument and a null dereference

Subject: `src/app/ctbrec/ui/controls/SearchBox.java` (76 lines). Seven live call sites.

## Finding 1 — the `boolean` constructor parameter is DISCARDED

```java
public SearchBox(boolean icon) {
   this();
   this.icon.setVisible(false);                        // unconditional
   this.icon.getStyleClass().remove("search-box-icon"); // unconditional
   this.setStyle("-fx-padding: 5");                     // unconditional
}
```

The parameter is never read. `new SearchBox(true)` and `new SearchBox(false)` produce **identical**
objects, both with the icon hidden. `the_parameter_is_ignored` states this at full strength: the
shipped constructor cannot distinguish any two arguments, quantified over both.

The call sites, measured:

| site | argument | wanted | got (shipped) |
|---|---|---|---|
| `settings/api/Preferences.java:72` | `true` | the icon | **no icon** |
| `sites/myfreecams/MyFreeCamsTableTab.java:180` | `false` | no icon | no icon |
| `tabs/RecentlyWatchedTab.java:90` | `false` | no icon | no icon |
| `tabs/recorded/AbstractRecordedModelsTab.java:263` | `false` | no icon | no icon |
| `tabs/recorded/GroupsTab.java:89` | `false` | no icon | no icon |
| `tabs/ThumbOverviewTab.java:156` | `false` | no icon | no icon |
| `tabs/ThumbOverviewTab.java:174` | *(no-arg ctor)* | the icon | the icon |

Six callers were right by accident. One — the only one that asked for an icon — was silently
overruled. The no-arg constructor at `ThumbOverviewTab.java:174` leaves the icon visible, which
fixes the intended reading of `true` without guesswork: `SearchBox(true)` must equal `SearchBox()`.

`every_false_caller_is_unchanged` is the anti-regression theorem — the repair moves **exactly** the
one call site whose argument was being thrown away, and no other.

## Finding 2 — the listener dereferences a value JavaFX is documented to allow to be null

```java
public void changed(ObservableValue<? extends String> ov, String oldValue, String newValue) {
   this.clearButton.setVisible(newValue.length() > 0);
}
```

MEASURED on Temurin 21 with the real JavaFX 21.0.8 (`/tmp/NT.java`):

```
initial getText()      -> ""
setText("abc")         -> listener got newValue="abc"
setText(null)          -> listener got newValue=NULL
after setText(null)    -> getText() is NULL
  .length() on it      -> NullPointerException
```

So a null reaches the listener and `newValue.length()` throws. `changed` is a **public** method on a
public class, and `setText(null)` is idiomatic in this very tree — seventeen call sites use it on
other `TextInputControl`s (`GroupsTab.java:279,282,314,325,368,429`, `RecordingsTab.java:212,235`,
`ModelNameTableCell.java:20`, and more).

Honest scope: no *current* SearchBox caller passes null, so this does not throw today — the clear
button's own handler uses `setText("")`. It is the armed-and-unwired shape again, and the repair
costs one branch. The right reading of null is "no text", identical to `""`:
`a_null_box_hides_the_clear_button`, and `null_and_empty_agree`.
-/

namespace CtbrecSpec

/-- What the clear button did when the text changed. `threw` is a `NullPointerException` escaping
into the JavaFX change-notification loop, which no caller can handle. -/
inductive ClearButton where
  | shown
  | hidden
  | threw
  deriving DecidableEq, Repr

/-- `changed()` as shipped: `newValue.length() > 0`, with no null test. -/
def shippedClearButton : Option String → ClearButton
  | none => .threw
  | some s => if s.length > 0 then .shown else .hidden

/-- `changed()` repaired: null reads as "no text", exactly like `""`. -/
def repairedClearButton : Option String → ClearButton
  | none => .hidden
  | some s => if s.length > 0 then .shown else .hidden

/-- Whether the magnifier icon ends up visible. The no-arg constructor leaves it visible. -/
def noArgIconShown : Bool := true

/-- `SearchBox(boolean)` as shipped: the argument is discarded and the icon is always hidden. -/
def shippedIconShown (_arg : Bool) : Bool := false

/-- `SearchBox(boolean)` repaired: the argument is honoured. -/
def repairedIconShown (arg : Bool) : Bool := arg

/-! ### Finding 1 — the discarded argument -/

/-- **The shipped constructor cannot distinguish its arguments.** Quantified over both, so this is
a statement about the constructor and not about two chosen values: no `Bool` a caller can pass
changes anything. -/
theorem the_parameter_is_ignored (a b : Bool) : shippedIconShown a = shippedIconShown b := rfl

/-- The repair honours it, for every argument. -/
theorem the_repair_honours_the_parameter (a : Bool) : repairedIconShown a = a := rfl

/-- **Anti-regression.** Every caller passing `false` — six of the seven — sees no change at all.
This is what makes the repair safe to ship rather than a rendering change scattered across the UI. -/
theorem every_false_caller_is_unchanged :
    shippedIconShown false = repairedIconShown false := rfl

/-- **Exactly one call site moves**, and it is the one whose argument was being thrown away. -/
theorem only_the_true_caller_moves :
    shippedIconShown true ≠ repairedIconShown true := by decide

/-- The repair agrees with the no-arg constructor, which is how the intended meaning of `true` is
known rather than guessed: `ThumbOverviewTab.java:174` already builds an icon-bearing box that way. -/
theorem the_repair_agrees_with_the_no_arg_constructor :
    repairedIconShown true = noArgIconShown := rfl

/-- And `false` still means no icon, so the repair did not simply invert the parameter. -/
theorem the_repair_still_hides_when_asked :
    repairedIconShown false = false := rfl

/-- The two constructors are distinguishable after the repair — a search box built with `true` and
one built with `false` are no longer the same object. Under the shipped rule they always were. -/
theorem the_two_constructors_differ_only_after_the_repair :
    (∀ a b : Bool, shippedIconShown a = shippedIconShown b) ∧
    (∃ a b : Bool, repairedIconShown a ≠ repairedIconShown b) :=
  ⟨fun _ _ => rfl, ⟨true, false, by decide⟩⟩

/-! ### Finding 2 — the null dereference -/

/-- **A null reaches the shipped listener and it throws.** MEASURED: JavaFX delivers `null` from
`setText(null)`. -/
theorem the_shipped_listener_throws_on_null : shippedClearButton none = .threw := rfl

/-- The repair never throws, for every possible text including null. -/
theorem the_repaired_listener_never_throws (t : Option String) : repairedClearButton t ≠ .threw := by
  cases t with
  | none => simp [repairedClearButton]
  | some s =>
      simp only [repairedClearButton]
      split <;> simp

/-- **Anti-amputation.** "Never throws" is also satisfied by a listener that hides the button
always, which would break the clear button entirely. The repair must agree with the shipped rule on
every non-null string — so nothing that worked has changed. -/
theorem the_repair_agrees_on_every_real_string (s : String) :
    repairedClearButton (some s) = shippedClearButton (some s) := rfl

/-- ...and it must still SHOW the button when there is text. -/
theorem the_repair_still_shows_the_clear_button (s : String) (h : s.length > 0) :
    repairedClearButton (some s) = .shown := by
  simp [repairedClearButton, h]

/-- An empty box hides the clear button — the behaviour the clear button's own handler relies on,
since it calls `setText("")`. -/
theorem an_empty_box_hides_the_clear_button : repairedClearButton (some "") = .hidden := rfl

/-- A null box hides it too. -/
theorem a_null_box_hides_the_clear_button : repairedClearButton none = .hidden := rfl

/-- **Null and empty agree**, which is the whole content of the repair: there is no third state a
user could observe, so treating null as "no text" is the only reading that keeps the button honest. -/
theorem null_and_empty_agree :
    repairedClearButton none = repairedClearButton (some "") := rfl

#guard shippedClearButton none == ClearButton.threw
#guard shippedClearButton (some "") == ClearButton.hidden
#guard shippedClearButton (some "a") == ClearButton.shown
#guard repairedClearButton none == ClearButton.hidden
#guard repairedClearButton (some "") == ClearButton.hidden
#guard repairedClearButton (some "a") == ClearButton.shown
#guard repairedClearButton (some "hello") == ClearButton.shown
#guard shippedIconShown true == shippedIconShown false
#guard repairedIconShown true == true
#guard repairedIconShown false == false
#guard repairedIconShown true == noArgIconShown
#guard shippedIconShown true != repairedIconShown true

end CtbrecSpec

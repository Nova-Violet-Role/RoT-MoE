/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — the popover's page stack

Subject: `src/app/ctbrec/ui/controls/Popover.java`, a LIVE class — `ThumbOverviewTab.java:191`
constructs one and pushes exactly **one** page onto it.

The pages live in a `LinkedList<Page>` used as a stack. Measured on Temurin 21 before modelling
(`/tmp/LL.java`), because the whole finding turns on which operations are partial:

```
pop on empty                    -> java.util.NoSuchElementException
getFirst on empty               -> java.util.NoSuchElementException
getFirst after popping the last -> java.util.NoSuchElementException
push a, push b -> getFirst = b     (LIFO: the last pushed is the top)
```

## Finding 1 — `popPage()` throws on the last page, and its own `hide()` branch is unreachable

```java
public final void popPage() {
   Popover.Page oldPage = this.pages.pop();      // 214  throws if the stack is empty
   oldPage.handleHidden();
   oldPage.setPopover(null);
   Popover.Page page = this.pages.getFirst();    // 217  throws if that WAS the last page
   this.leftButton.setVisible(page.leftButtonText() != null);
   ...
   if (!this.pages.isEmpty()) {                  // 222  the guard, four lines too late
      ... animate ...
   } else {
      this.hide();                               // 244  UNREACHABLE
   }
}
```

The author wrote down the intended behaviour — pop the last page and the popover hides — and a
single line placed four lines too early makes it dead code. Control never reaches line 244, because
line 217 has already thrown. `the_hide_branch_is_unreachable` states exactly that: there is **no**
stack for which the shipped rule hides, so the branch cannot be exercised by any input.

This has never fired because `popPage()` has **zero callers**: the only `Popover.Page` in the tree,
`SearchPopoverTreeList`, calls `popover.hide()` directly from `handleRightButton()`. That is the
`PreviewPipeline.frameBytes` shape of checkpoint 16c — armed and unwired. The census reports it as
`no-evidence`, which reads as harmless and is not: it is a public `final` method on a live class
that throws `NoSuchElementException` the first time anyone uses it as written.

## Finding 2 — the buttons dispatch through `getFirst()` with no guard

```java
public void handle(Event event) {
   if (event.getSource() == this.leftButton)       this.pages.getFirst().handleLeftButton();
   else if (event.getSource() == this.rightButton) this.pages.getFirst().handleRightButton();
}
```

`computeMinWidth` and `computeMinHeight` in the same file guard the identical access with
`pages.isEmpty() ? null : pages.getFirst()`. `handle` does not. `clearPages()` is public and empties
the stack **without** hiding the buttons or clearing their text, so a click after it throws. Two
readings of one invariant inside one class is the defect; the guarded reading is the correct one.
-/

namespace CtbrecSpec

/-- A page, identified well enough to track stack order. -/
abbrev PageId := Nat

/-- What a `popPage()` call did. `threw` is `NoSuchElementException` escaping into the FX event
loop, which is not a return value the caller can handle. -/
inductive PopResult where
  | ok (pages : List PageId) (hidden : Bool)
  | threw
  deriving DecidableEq, Repr

/-- `popPage()` as shipped: `pop()`, then `getFirst()`, and only then the `isEmpty()` test. -/
def shippedPop : List PageId → PopResult
  | [] => .threw           -- line 214: pop() on an empty LinkedList
  | [_] => .threw          -- line 217: getFirst() after popping the last page
  | _ :: rest => .ok rest false

/-- `popPage()` repaired: test first, then act. Popping the last page hides the popover, which is
what the shipped `else` branch says it wanted to do. -/
def repairedPop : List PageId → PopResult
  | [] => .ok [] true      -- nothing to pop; hiding is the honest response, not an exception
  | [_] => .ok [] true     -- the author's intent, now reachable
  | _ :: rest => .ok rest false

/-- What a left/right button click did. -/
inductive ClickResult where
  | delivered (target : PageId)
  | ignored
  | threw
  deriving DecidableEq, Repr

/-- `handle()` as shipped: `pages.getFirst()` with no guard. -/
def shippedClick : List PageId → ClickResult
  | [] => .threw
  | p :: _ => .delivered p

/-- `handle()` repaired, matching the guard `computeMinWidth` already uses in the same file. -/
def repairedClick : List PageId → ClickResult
  | [] => .ignored
  | p :: _ => .delivered p

/-- `pushPage`. The top of the stack is the head, matching the measured LIFO of `LinkedList`. -/
def pushPage (p : PageId) (st : List PageId) : List PageId := p :: st

/-- `clearPages()` — the shipped loop pops until empty, which is total and correct. -/
def clearPages (_ : List PageId) : List PageId := []

/-! ### Finding 1 — the last page -/

/-- **The shipped rule throws on the last page** — the live case, since `ThumbOverviewTab.java:191`
pushes exactly one. -/
theorem the_shipped_pop_throws_on_the_last_page (p : PageId) : shippedPop [p] = .threw := rfl

/-- **The shipped rule throws on an empty stack too.** -/
theorem the_shipped_pop_throws_when_empty : shippedPop [] = .threw := rfl

/-- **The `hide()` branch at line 244 is unreachable.** There is no stack whatsoever on which the
shipped rule hides, so the branch cannot be exercised by any input — it is dead code that documents
an intent the code does not implement. Quantified over every stack, so this is a fact about the
rule and not about a chosen example. -/
theorem the_hide_branch_is_unreachable (st : List PageId) : shippedPop st ≠ .ok [] true := by
  cases st with
  | nil => simp [shippedPop]
  | cons a rest =>
      cases rest with
      | nil => simp [shippedPop]
      | cons b more => simp [shippedPop]

/-- **The repair reaches it.** -/
theorem the_repair_hides_on_the_last_page (p : PageId) : repairedPop [p] = .ok [] true := rfl

/-- **The repair never throws**, for every stack. -/
theorem the_repair_never_throws (st : List PageId) : repairedPop st ≠ .threw := by
  cases st with
  | nil => simp [repairedPop]
  | cons a rest =>
      cases rest with
      | nil => simp [repairedPop]
      | cons b more => simp [repairedPop]

/-- **Anti-amputation.** "Never throws" is satisfied by a method that does nothing at all, so the
repair must still POP: with two or more pages it removes exactly the top one and keeps the rest in
order, and it does not hide. -/
theorem the_repair_still_pops (a b : PageId) (more : List PageId) :
    repairedPop (a :: b :: more) = .ok (b :: more) false := rfl

/-- The repair agrees with the shipped rule everywhere the shipped rule managed to return at all.
So this is a strictly-more-defined replacement, not a different one — nothing that worked changed. -/
theorem the_repair_extends_rather_than_replaces (st : List PageId) (r : List PageId) (h : Bool)
    (hs : shippedPop st = .ok r h) : repairedPop st = .ok r h := by
  cases st with
  | nil => simp [shippedPop] at hs
  | cons a rest =>
      cases rest with
      | nil => simp [shippedPop] at hs
      | cons b more => simpa [shippedPop, repairedPop] using hs

/-! ### Finding 2 — the unguarded button -/

/-- **A click with no pages throws**, which is what `clearPages()` leaves behind. -/
theorem the_shipped_button_throws_with_no_pages : shippedClick [] = .threw := rfl

/-- The repair ignores it instead, matching the guard `computeMinWidth` already uses. -/
theorem the_repaired_button_ignores_an_empty_stack : repairedClick [] = .ignored := rfl

theorem the_repaired_button_never_throws (st : List PageId) : repairedClick st ≠ .threw := by
  cases st <;> simp [repairedClick]

/-- **Anti-amputation for the button**: it still delivers to the top page when there is one. -/
theorem the_repaired_button_still_delivers (p : PageId) (rest : List PageId) :
    repairedClick (p :: rest) = .delivered p := rfl

/-- `clearPages()` is what makes finding 2 reachable: it is public and empties the stack. -/
theorem clearing_empties_the_stack (st : List PageId) : clearPages st = [] := rfl

theorem a_click_after_clearing_throws (st : List PageId) : shippedClick (clearPages st) = .threw :=
  rfl

/-! ### The stack discipline itself -/

/-- The top is the last pushed — the measured LIFO of `LinkedList.push`/`getFirst`. -/
theorem the_top_is_the_last_pushed (p : PageId) (st : List PageId) :
    repairedClick (pushPage p st) = .delivered p := rfl

/-- Pushing then popping restores the stack exactly, for every stack. -/
theorem pushing_then_popping_restores_the_stack (p : PageId) (a : PageId) (st : List PageId) :
    repairedPop (pushPage p (a :: st)) = .ok (a :: st) false := rfl

/-- Pushing onto an empty stack and popping hides, rather than leaving a popover with no pages
visible on screen. -/
theorem pushing_one_then_popping_hides (p : PageId) :
    repairedPop (pushPage p []) = .ok [] true := rfl

/-- The stack never grows by more than one push, and push never loses a page. -/
theorem pushing_preserves_every_page (p : PageId) (st : List PageId) (q : PageId)
    (hq : q ∈ st) : q ∈ pushPage p st := List.mem_cons_of_mem p hq

#guard shippedPop [] == PopResult.threw
#guard shippedPop [1] == PopResult.threw
#guard shippedPop [1, 2] == PopResult.ok [2] false
#guard repairedPop [] == PopResult.ok [] true
#guard repairedPop [1] == PopResult.ok [] true
#guard repairedPop [1, 2] == PopResult.ok [2] false
#guard repairedPop [1, 2, 3] == PopResult.ok [2, 3] false
#guard shippedClick [] == ClickResult.threw
#guard repairedClick [] == ClickResult.ignored
#guard repairedClick [7, 8] == ClickResult.delivered 7
#guard clearPages [1, 2, 3] == ([] : List PageId)
#guard repairedClick (pushPage 5 [1]) == ClickResult.delivered 5

end CtbrecSpec

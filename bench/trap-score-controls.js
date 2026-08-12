// Positive controls for bench/trap-score.js, run BEFORE the corpus.
// Three scenarios, each with a verdict fixed by the pre-registration:
//   1 saturated (both arms correct everywhere)   -> noPower
//   2 strong routed advantage, no silence        -> advantage
//   3 turn files absent                          -> FATAL exit 3
//   4 routed wins only because arm a was SILENT  -> explained away -> null
const fs = require("fs");
const path = require("path");
const os = require("os");
const { spawnSync } = require("child_process");

// BOTH OF THESE WERE HARDCODED WINDOWS DRIVE PATHS, AND IT COST TWO RED CI JOBS.
// Measured on run 31629035282 (ubuntu + macos): all four scenarios exited 1,
// including the one whose expected verdict is exit 3, because
// spawning node against an absolute Windows checkout path for bench/trap-score.js
// resolves to nothing on a Linux runner -> MODULE_NOT_FOUND -> 1. The scorer was
// never executed at all, so the suite reported four scoring failures when the
// real fault was that no scoring had happened. That is why the failure text had
// to be taught to print the scorer's stderr first: the exit code alone said
// "the scorer disagrees" when the truth was "the scorer is absent".
//
// `checker/no-local-paths.sh` exists to catch exactly this and did NOT, because
// `checker/patterns-forbidden.txt` listed only the BACKSLASH spellings of the
// checkout and temp roots, and this file used forward slashes. The needle was
// narrower than the gate's description. Widened there; derived here.
const ROOT = path.join(__dirname, "..");
const T = path.join(os.tmpdir(), "rotmoe-trapctl");
fs.rmSync(T, { recursive: true, force: true });

const items = [];
for (let i = 1; i <= 30; i++) items.push({ id: i, family: "f", file: "x", naive: 100 + i, truth: 200 + i });
fs.mkdirSync(T, { recursive: true });
const cand = path.join(T, "cand.jsonl");
fs.writeFileSync(cand, items.map((x) => JSON.stringify(x)).join("\n") + "\n");

function mk(dir, fn) {
  fs.mkdirSync(dir, { recursive: true });
  for (const it of items) {
    const v = fn(it);
    if (v === null) continue;                 // deliberately absent
    fs.writeFileSync(path.join(dir, "turn-" + String(it.id).padStart(3, "0") + ".txt"), v);
  }
}
function run(a, b) {
  const r = spawnSync("node", [path.join(ROOT, "bench/trap-score.js"), cand, a, b], { encoding: "utf8" });
  return { code: r.status, out: r.stdout, err: r.stderr };
}

// A control that reports only an exit code cannot say WHY. Measured
// 2026-08-12: on the ubuntu and macos runners all four scenarios returned
// exit 1 and every message read "gave exit 1" -- true, useless, and it hid
// whatever the scorer had printed to stderr. Same defect as the checker one
// level up, which pointed at a /tmp log the runner throws away.
// The line-splitter below uses a REGEX, not a "\n" string literal, on purpose:
// this helper was first written through a shell heredoc and the escape became a
// real newline inside the source, producing a SyntaxError. A regex literal
// survives that round trip.
const why = (r) => "exit " + r.code +
  (r.err ? " -- stderr: " + String(r.err).trim().split(/\r?\n/).slice(0, 3).join(" / ")
         : " -- stderr was EMPTY");

let pass = 0, fail = 0;
const ok = (m) => { console.log("  ok   " + m); pass++; };
const bad = (m) => { console.log("  FAIL " + m); fail++; };

// 1 saturated
mk(T + "/sat_a", (it) => "the answer is " + it.truth);
mk(T + "/sat_b", (it) => "the answer is " + it.truth);
let r = run(T + "/sat_a", T + "/sat_b");
let j = r.code === 0 ? JSON.parse(r.out) : null;
if (j && j.verdict === "noPower" && j.band === 0) ok("saturated corpus -> noPower (band 0)");
else bad("saturated corpus gave " + (j ? j.verdict + " band=" + j.band : why(r)));

// 2 strong routed advantage: b correct everywhere, a falls in the trap
mk(T + "/adv_a", (it) => "the answer is " + it.naive);
mk(T + "/adv_b", (it) => "the answer is " + it.truth);
r = run(T + "/adv_a", T + "/adv_b");
j = r.code === 0 ? JSON.parse(r.out) : null;
if (j && j.verdict === "advantage" && j.arms.a.trapped === 30 && j.arms.b.correct === 30)
  ok("routed advantage IS detected (a trapped 30/30, b correct 30/30, p=" + j.pDeconfounded.toExponential(2) + ")");
else bad("advantage scenario gave " + (j ? j.verdict : why(r)));

// 3 missing files must FATAL, not score
mk(T + "/miss_a", (it) => (it.id > 5 ? null : "x " + it.truth));
mk(T + "/miss_b", (it) => "y " + it.truth);
r = run(T + "/miss_a", T + "/miss_b");
if (r.code === 3 && /MISSING/.test(r.err)) ok("absent turn files -> FATAL exit 3, not a scored noPower");
else bad("missing-file scenario gave " + why(r) + " (expected exit 3)");

// 4 routed 'wins' only where a was silent -> explained -> null
mk(T + "/sil_a", (it) => (it.id <= 12 ? "I cannot determine that." : "the answer is " + it.truth));
mk(T + "/sil_b", (it) => "the answer is " + it.truth);
r = run(T + "/sil_a", T + "/sil_b");
j = r.code === 0 ? JSON.parse(r.out) : null;
if (j && j.explained === 12 && j.bandDeconfounded === 0 && j.verdict !== "advantage")
  ok("wins explained by silence are excluded (explained=12, deconfounded band=0, verdict=" + j.verdict + ")");
else bad("silence scenario gave " + (j ? JSON.stringify({ e: j.explained, bd: j.bandDeconfounded, v: j.verdict }) : why(r)));

console.log("\n== trap-score controls: " + pass + " passed, " + fail + " failed");
process.exit(fail === 0 ? 0 : 1);

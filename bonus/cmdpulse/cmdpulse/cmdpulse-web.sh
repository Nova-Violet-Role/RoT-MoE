#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
# ~/.claude/cmdpulse/cmdpulse-web.sh
# CmdPulse web inspector — full input/output dashboard, selectable and copyable.
#
#   bash cmdpulse-web.sh            regenerate every 2s and open the page once
#   bash cmdpulse-web.sh --once     generate once, print the path, exit
#   bash cmdpulse-web.sh --no-open  loop without launching a browser
#
# Writes a self-contained page to ~/.claude/cmdpulse/dashboard.html.
# Local by design: no network, no upload, nothing published anywhere.

set -u
ROOT="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/cmdpulse"
EVENTS="$ROOT/events.ndjson"
ACTIVE="$ROOT/active"
RUNS="$ROOT/runs"
OUT="$ROOT/dashboard.html"
MAXROWS="${CMDPULSE_MAX_ROWS:-300}"
INTERVAL="${CMDPULSE_WEB_INTERVAL:-2}"
ONCE=0; NOOPEN=0
for a in "$@"; do
  case "$a" in --once) ONCE=1 ;; --no-open) NOOPEN=1 ;; esac
done
mkdir -p "$ACTIVE" "$RUNS" 2>/dev/null

JQ=""
for c in jq "$HOME/scoop/shims/jq.exe" /usr/bin/jq /usr/local/bin/jq /opt/homebrew/bin/jq; do
  if command -v "$c" >/dev/null 2>&1; then JQ=$(command -v "$c"); break; fi
done
[ -n "$JQ" ] || { echo "cmdpulse-web: jq not found" >&2; exit 1; }

# jq.exe on Windows writes CRLF; a stray CR inside the embedded JSON breaks the page script.
JQBIN="$JQ"
jqlf() { "$JQBIN" "$@" | tr -d '\r'; }
JQ=jqlf

build_payload() {
  local base active calls stats totals now
  now=$(( $(date +%s) * 1000 ))

  if [ -s "$EVENTS" ]; then
    base=$("$JQ" -s -c '
      map(select(.ev=="post" and (.dur // -1) >= 0))
      | group_by(.sig)
      | map({ key: .[0].sig,
              value: ((map(.dur)|sort) as $v | ($v|length) as $n |
                { n: $n,
                  median: (if $n % 2 == 1 then $v[($n/2|floor)] else (($v[$n/2-1]+$v[$n/2])/2) end),
                  p95: $v[([$n-1,($n*0.95|floor)]|min)], max: $v[$n-1], total: ($v|add) }) })
      | from_entries' "$EVENTS" 2>/dev/null) || base='{}'
    stats=$("$JQ" -s -c '
      map(select(.ev=="post"))
      | group_by(.sig)
      | map({ sig: .[0].sig, calls: length,
              fails: (map(select(.err))|length),
              total: (map(.dur // 0)|add),
              v: (map(.dur // 0)|sort) })
      | map(. + {n:(.v|length)})
      | map({ sig, calls, fails, total,
              median: (if .n % 2 == 1 then .v[(.n/2|floor)] else ((.v[.n/2-1]+.v[.n/2])/2) end),
              p95: .v[([.n-1,(.n*0.95|floor)]|min)], max: .v[.n-1] })
      | sort_by(-.total)' "$EVENTS" 2>/dev/null) || stats='[]'
    totals=$("$JQ" -s -c '
      map(select(.ev=="post"))
      | { calls: length, fails: (map(select(.err))|length), time: (map(.dur // 0)|add // 0) }' "$EVENTS" 2>/dev/null) || totals='{}'
  else
    base='{}'; stats='[]'; totals='{"calls":0,"fails":0,"time":0}'
  fi
  [ -n "$base" ] || base='{}'; [ -n "$stats" ] || stats='[]'; [ -n "$totals" ] || totals='{"calls":0,"fails":0,"time":0}'

  # in-flight calls, enriched with their learned baseline
  if ls "$ACTIVE"/*.json >/dev/null 2>&1; then
    active=$(for f in "$ACTIVE"/*.json; do cat "$f"; echo; done | "$JQ" -s -c --argjson b "$base" '
      map({ id, tool, sig, subject, cwd, agent, start,
            median: ($b[.sig].median // 0), samples: ($b[.sig].n // 0), p95: ($b[.sig].p95 // 0) })') || active='[]'
  else active='[]'; fi
  [ -n "$active" ] || active='[]'

  # completed calls: pre and post payloads joined on tool_use_id.
  # Piped through a loop rather than argv so a large runs/ cannot overflow the command line.
  if ls "$RUNS"/*.json >/dev/null 2>&1; then
    calls=$({ ls -t "$RUNS"/*.pre.json 2>/dev/null | head -"$MAXROWS"
              ls -t "$RUNS"/*.post.json 2>/dev/null | head -"$MAXROWS"; } |
      while IFS= read -r f; do [ -f "$f" ] && { cat "$f"; echo; }; done |
      "$JQ" -s -c --argjson b "$base" '
        def files:
          [ (.tool_input.file_path // empty), (.tool_input.path // empty), (.tool_input.notebook_path // empty) ]
          + ( if (.tool_name=="Bash" or .tool_name=="PowerShell")
              then [ (.tool_input.command // "") | match("[A-Za-z]:[\\\\/][^ \"'"'"']{2,180}"; "g").string ]
              else [] end )
          | map(select(. != null and . != "")) | unique | .[0:12];
        map(select(.tool_use_id != null))
        | group_by(.tool_use_id)
        | map( (map(select(.tool_response == null)) | .[0]) as $pre
             | (map(select(.tool_response != null)) | .[0]) as $post
             | ($post // $pre) as $any
             | select($any != null)
             | { id: $any.tool_use_id,
                 tool: ($any.tool_name // "Unknown"),
                 sig: ($any.tool_name // "Unknown"),
                 subject: (($any.tool_input.command // $any.tool_input.file_path // $any.tool_input.pattern
                            // $any.tool_input.url // $any.tool_input.query // ($any.tool_name)) | tostring),
                 cwd: ($any.cwd // ""), agent: ($any.agent_type // ""), pmode: ($any.permission_mode // ""),
                 dur: ($post.duration_ms // null),
                 bytes: (if $post then ($post.tool_response | tostring | length) else 0 end),
                 code: (($post.tool_response.exit_code // $post.tool_response.exitCode) // null),
                 err: ((($post.tool_response.is_error // $post.tool_response.isError) // false) == true),
                 running: ($post == null),
                 files: ($any | files),
                 input: ($any.tool_input | tojson),
                 response: (if $post then ($post.tool_response | if type=="string" then . else tojson end) else "" end) } )
        | map(. + { median: ($b[.sig].median // 0) })
        | sort_by(-( .dur // 0 )) | .[0:'"$MAXROWS"']') || calls='[]'
  else calls='[]'; fi
  [ -n "$calls" ] || calls='[]'

  printf '{"generated":%s,"active":%s,"calls":%s,"stats":%s,"totals":%s}' \
    "$now" "$active" "$calls" "$stats" "$totals"
}

read -r -d '' HEAD <<'HTMLHEAD' || true
<!doctype html><html lang="en"><head><meta charset="utf-8"><title>CmdPulse</title>
<meta name="viewport" content="width=device-width,initial-scale=1"><style>
:root{--bg:#0d0b12;--panel:#151220;--line:#2a2438;--txt:#e8e4f0;--dim:#8b829e;
--violet:#b464ff;--gold:#ffd700;--grey:#808080;--red:#ff5f5f;--green:#78dc8c;--cyan:#6edceb}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--txt);font:13px/1.5 "JetBrainsMono Nerd Font",Consolas,monospace}
header{position:sticky;top:0;z-index:9;background:var(--bg);padding:14px 18px 10px;border-bottom:1px solid var(--line)}
h1{margin:0;font-size:15px;letter-spacing:.14em;color:var(--violet)}
h1 small{color:var(--dim);letter-spacing:0;font-weight:400;margin-left:10px}
.kpis{display:flex;gap:22px;margin-top:8px;flex-wrap:wrap;color:var(--dim);font-size:12px}
.kpis b{color:var(--txt)}
.controls{display:flex;gap:8px;margin-top:10px;flex-wrap:wrap;align-items:center}
input[type=search]{flex:1;min-width:220px;background:var(--panel);border:1px solid var(--line);
color:var(--txt);padding:6px 10px;border-radius:5px;font:inherit}
.chip{background:var(--panel);border:1px solid var(--line);color:var(--dim);padding:5px 11px;
border-radius:20px;cursor:pointer;user-select:none;font-size:12px}
.chip:hover{border-color:var(--violet);color:var(--txt)}
.chip.on{background:var(--violet);border-color:var(--violet);color:#0d0b12;font-weight:600}
main{padding:14px 18px 60px}section{margin-bottom:26px}
h2{font-size:11px;letter-spacing:.2em;color:var(--cyan);margin:0 0 10px}
.row{background:var(--panel);border:1px solid var(--line);border-radius:7px;margin-bottom:6px;overflow:hidden}
.row.fail{border-left:3px solid var(--red)}.row.run{border-left:3px solid var(--gold)}
.head{display:grid;grid-template-columns:20px 92px 1fr 260px 82px 74px;gap:10px;align-items:center;padding:8px 12px;cursor:pointer}
.head:hover{background:#1c1729}
.tool{color:var(--cyan);font-size:11px}
.subj{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.meta{text-align:right;color:var(--dim);font-size:11px}
.bar{height:10px;background:#221c30;border-radius:5px;overflow:hidden}
.bar i{display:block;height:100%;border-radius:5px;transition:width .25s linear}
.bar.indet i{width:30%;animation:sweep 1.5s ease-in-out infinite;background:var(--violet)}
@keyframes sweep{0%{margin-left:-30%}100%{margin-left:100%}}
.body{display:none;border-top:1px solid var(--line);padding:12px;background:#100d18}
.row.open .body{display:block}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:8px 22px;margin-bottom:12px}
.f{color:var(--dim);font-size:11px}.f b{display:block;color:var(--txt);font-weight:500;font-size:12px;word-break:break-all;user-select:all}
.blk{position:relative;margin-top:10px}
.blk h3{font-size:10px;letter-spacing:.18em;color:var(--gold);margin:0 0 5px}
pre{background:#0a0810;border:1px solid var(--line);border-radius:5px;padding:10px 12px;margin:0;
max-height:420px;overflow:auto;white-space:pre-wrap;word-break:break-word;user-select:text;font-size:12px}
.copy{position:absolute;right:7px;top:20px;background:var(--panel);border:1px solid var(--line);
color:var(--dim);padding:3px 9px;border-radius:4px;cursor:pointer;font:inherit;font-size:11px}
.copy:hover{color:var(--txt);border-color:var(--violet)}.copy.ok{color:var(--green);border-color:var(--green)}
.files span{display:inline-block;background:#1c1729;border:1px solid var(--line);padding:3px 8px;
border-radius:4px;margin:2px 4px 2px 0;color:var(--cyan);font-size:11px;user-select:all}
table{width:100%;border-collapse:collapse;font-size:12px}
th{text-align:left;color:var(--dim);font-size:10px;letter-spacing:.14em;padding:5px 8px;border-bottom:1px solid var(--line)}
td{padding:5px 8px;border-bottom:1px solid #1c1729}td.n{text-align:right;color:var(--dim)}
.empty{color:var(--dim);padding:16px;text-align:center}
footer{position:fixed;bottom:0;left:0;right:0;background:var(--panel);border-top:1px solid var(--line);
padding:5px 18px;color:var(--dim);font-size:11px;display:flex;gap:18px}
.dot{width:7px;height:7px;border-radius:50%;background:var(--green);display:inline-block;animation:pulse 1.4s infinite}
@keyframes pulse{50%{opacity:.25}}
</style></head><body>
<header><h1>CMDPULSE<small>local tool-call inspector — nothing leaves this machine</small></h1>
<div class="kpis" id="kpis"></div>
<div class="controls"><input type="search" id="q" placeholder="filter by command, file, tool, output…">
<span class="chip" id="cFail">failures only</span><span class="chip" id="cStats">stats</span>
<span class="chip" id="cAuto">auto-refresh</span></div></header>
<main><section><h2>RUNNING</h2><div id="run"></div></section>
<section id="secStats" style="display:none"><h2>WHERE THE TIME GOES</h2><div id="stats"></div></section>
<section><h2>CALLS</h2><div id="calls"></div></section></main>
<footer><span><span class="dot"></span> live</span><span id="gen"></span><span id="cnt"></span></footer>
<script>const D=
HTMLHEAD

read -r -d '' TAIL <<'HTMLTAIL' || true
;
const esc=s=>String(s??'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const dur=ms=>ms==null||ms<0?'—':ms<1000?ms.toFixed(0)+'ms':ms<60000?(ms/1000).toFixed(1)+'s':
  Math.floor(ms/60000)+'m'+String(Math.floor(ms%60000/1000)).padStart(2,'0')+'s';
const byt=b=>!b?'0B':b<1024?b+'B':b<1048576?(b/1024).toFixed(1)+'K':b<1073741824?(b/1048576).toFixed(1)+'M':(b/1073741824).toFixed(2)+'G';
const S=k=>{try{return localStorage.getItem(k)}catch(e){return null}};
const P=(k,v)=>{try{localStorage.setItem(k,v)}catch(e){}};
let failOnly=S('cp.fail')==='1',showStats=S('cp.stats')==='1',auto=S('cp.auto')!=='0',q=S('cp.q')||'';
const open=new Set(JSON.parse(S('cp.open')||'[]'));
document.getElementById('q').value=q;
const chips={cFail:['fail',()=>failOnly,v=>failOnly=v],cStats:['stats',()=>showStats,v=>showStats=v],cAuto:['auto',()=>auto,v=>auto=v]};
for(const[id,[key,get,set]]of Object.entries(chips)){const el=document.getElementById(id);
 const sync=()=>el.classList.toggle('on',get());el.onclick=()=>{set(!get());P('cp.'+key,get()?'1':'0');sync();render()};sync();}
document.getElementById('q').oninput=e=>{q=e.target.value;P('cp.q',q);render()};
function bar(pct,indet,col){if(indet)return '<div class="bar indet"><i></i></div>';
 const p=Math.max(0,Math.min(1,pct))*100;return `<div class="bar"><i style="width:${p}%;background:${col}"></i></div>`}
let cid=0;
function copyBtn(t){const k='_c'+(++cid);window[k]=t;
 return `<button class="copy" onclick="navigator.clipboard.writeText(window['${k}']).then(()=>{this.textContent='copied';this.classList.add('ok');setTimeout(()=>{this.textContent='copy';this.classList.remove('ok')},1200)})">copy</button>`}
function match(c){if(!q)return true;const s=q.toLowerCase();
 return (c.subject||'').toLowerCase().includes(s)||(c.tool||'').toLowerCase().includes(s)
 ||(c.files||[]).join(' ').toLowerCase().includes(s)||(c.response||'').toLowerCase().includes(s)}
function renderRunning(){const now=Date.now(),el=document.getElementById('run');
 if(!D.active.length){el.innerHTML='<div class="empty">idle — no tool call in flight</div>';return}
 el.innerHTML=D.active.map(a=>{const e=now-a.start,indet=!a.samples||a.samples<2,pct=indet?0:e/a.median;
  const col=pct>=1?'var(--red)':pct>=.8?'var(--gold)':'var(--violet)';
  const lbl=indet?'no baseline yet — indeterminate':`ETA ${Math.min(99,Math.round(pct*100))}% · median ${dur(a.median)} of ${a.samples} runs`;
  return `<div class="row run"><div class="head"><span style="color:var(--gold)">●</span>
   <span class="tool">${esc(a.tool)}</span><span class="subj">${esc(a.subject)}</span>${bar(pct,indet,col)}
   <span class="meta">${dur(e)}</span><span class="meta">${esc(a.agent||'main')}</span></div>
   <div class="body" style="display:block"><div class="f">${esc(lbl)}<br>${esc(a.cwd||'')}</div></div></div>`}).join('')}
function renderCalls(){let cs=D.calls.filter(match);if(failOnly)cs=cs.filter(c=>c.err);
 document.getElementById('cnt').textContent=cs.length+' shown / '+D.calls.length+' kept';
 const el=document.getElementById('calls');
 if(!cs.length){el.innerHTML='<div class="empty">nothing matches</div>';return}
 el.innerHTML=cs.map(c=>{const ratio=c.median>0?Math.min(1,c.dur/(c.median*2)):0;
  const col=c.err?'var(--red)':(c.median&&c.dur>c.median*1.5)?'var(--gold)':'var(--grey)';
  const rate=c.dur>0&&c.bytes?byt(c.bytes/(c.dur/1000))+'/s':'';
  const files=(c.files||[]).map(f=>`<span>${esc(f)}</span>`).join('');
  return `<div class="row ${c.err?'fail':''} ${c.running?'run':''} ${open.has(c.id)?'open':''}" data-id="${esc(c.id)}">
  <div class="head" onclick="tog(this)"><span style="color:${c.err?'var(--red)':'var(--green)'}">${c.running?'●':c.err?'✗':'✓'}</span>
   <span class="tool">${esc(c.tool)}</span><span class="subj">${esc(c.subject)}</span>
   ${bar(ratio,false,col)}<span class="meta">${dur(c.dur)}</span><span class="meta">${byt(c.bytes)}</span></div>
  <div class="body"><div class="grid">
   <div class="f">cwd<b>${esc(c.cwd||'')}</b></div>
   <div class="f">agent<b>${esc(c.agent||'main')}</b></div>
   <div class="f">permission mode<b>${esc(c.pmode||'')}</b></div>
   <div class="f">duration<b>${dur(c.dur)}${c.median?' · median '+dur(c.median):''}</b></div>
   <div class="f">output<b>${byt(c.bytes)}${rate?' · '+rate:''}</b></div>
   <div class="f">exit<b>${c.code??'—'}</b></div>
   <div class="f">tool_use_id<b>${esc(c.id)}</b></div></div>
   ${files?`<div class="f">files touched</div><div class="files">${files}</div>`:''}
   <div class="blk"><h3>INPUT</h3>${copyBtn(c.input||'')}<pre>${esc(c.input)}</pre></div>
   ${c.response?`<div class="blk"><h3>OUTPUT</h3>${copyBtn(c.response)}<pre>${esc(c.response)}</pre></div>`:''}
  </div></div>`}).join('')}
function renderStats(){document.getElementById('secStats').style.display=showStats?'':'none';if(!showStats)return;
 document.getElementById('stats').innerHTML='<table><tr><th>SIGNATURE</th><th>CALLS</th><th>MEDIAN</th><th>P95</th><th>SLOWEST</th><th>FAILS</th><th>TOTAL</th></tr>'+
 D.stats.slice(0,40).map(s=>`<tr><td>${esc(s.sig)}</td><td class="n">${s.calls}</td><td class="n">${dur(s.median)}</td>
 <td class="n">${dur(s.p95)}</td><td class="n">${dur(s.max)}</td>
 <td class="n" style="color:${s.fails?'var(--red)':'inherit'}">${s.fails}</td><td class="n">${dur(s.total)}</td></tr>`).join('')+'</table>'}
function tog(h){const r=h.parentElement,id=r.dataset.id;r.classList.toggle('open');
 r.classList.contains('open')?open.add(id):open.delete(id);P('cp.open',JSON.stringify([...open]))}
function render(){document.getElementById('kpis').innerHTML=
 `<span>calls <b>${D.totals.calls}</b></span><span>failures <b style="color:${D.totals.fails?'var(--red)':'inherit'}">${D.totals.fails}</b></span>`+
 `<span>tool time <b>${dur(D.totals.time)}</b></span><span>running <b style="color:var(--gold)">${D.active.length}</b></span>`;
 renderRunning();renderStats();renderCalls();
 document.getElementById('gen').textContent='generated '+new Date(D.generated).toLocaleTimeString()}
render();setInterval(renderRunning,250);setInterval(()=>{if(auto)location.reload()},2000);
addEventListener('beforeunload',()=>P('cp.scroll',String(scrollY)));
addEventListener('load',()=>{const s=S('cp.scroll');if(s)scrollTo(0,+s)});
</script></body></html>
HTMLTAIL

write_page() {
  local payload; payload=$(build_payload)
  [ -n "$payload" ] || payload='{"generated":0,"active":[],"calls":[],"stats":[],"totals":{"calls":0,"fails":0,"time":0}}'
  { printf '%s' "$HEAD"; printf '%s' "$payload"; printf '%s' "$TAIL"; } > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"
}

write_page
if [ "$ONCE" = "1" ]; then printf '%s\n' "$OUT"; exit 0; fi

if [ "$NOOPEN" != "1" ]; then
  if command -v cmd.exe >/dev/null 2>&1; then cmd.exe /c start "" "$(cygpath -w "$OUT" 2>/dev/null || echo "$OUT")" >/dev/null 2>&1
  elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$OUT" >/dev/null 2>&1
  elif command -v open >/dev/null 2>&1; then open "$OUT" >/dev/null 2>&1
  fi
fi

echo "CmdPulse web inspector regenerating every ${INTERVAL}s"
echo "  page : $OUT"
echo "  stop : Ctrl+C"
while true; do sleep "$INTERVAL"; write_page || echo "regen failed"; done

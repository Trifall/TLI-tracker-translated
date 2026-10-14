# Season Update Runbook — Translating a New ETor Version

How to produce a new English translation release (e.g. `v1.4.0`) when the game/app ships a new
season. Written from the v1.2.0 update, revised after the v1.3.0 update (growth reports,
Shizuku/mobile recording, online charts, Shattered Star events, Traditional Chinese support).
Follow top to bottom.

> Current state: v1.3.0 is committed (`df79263`) but has **no GitHub Release yet** — the latest
> public release is still v1.2.0. So the next season release is probably v1.4.0; adjust version
> numbers below accordingly. This fork's `origin` is `Trifall/TLI-tracker-translated` and
> `upstream` is `Giboork/TLI-tracker-translated` (source of the v1.2.0 asar + this runbook).

---

## 0. How the translation actually works

ETor (易火-ETor) is an Electron shell that loads a **remote** web app
(`https://etor-beta.710421059.xyz/?t=<timestamp>`, see `build/obf-app/main.js`). The UI text is
Chinese. We don't modify the web app — we **inject a translation layer** locally:

- `build/obf-app/translations.json` — the dictionary: `{ "中文": "English" }`, grouped into
  sections. **All sections are flattened into one flat map at runtime**, so section names are just
  for organization — a key in any section is looked up globally. (28 sections, 4,447 entries as
  of v1.3.0: `gameContent` 2,238 + `ui` 727 + `season_ui` 620 + `season_update` 296 +
  `season_items` 144 + `typeLabels` 135 + `season_tiny` 95 + … — recount with the snippet in §10
  before writing release notes.)
- `build/obf-app/translate.js` — injected into every page. For each on-screen text node it:
  1. tries an **exact match** in the dictionary,
  2. applies hard-coded **regex patterns** for dynamic strings (counts, dates, `{placeholder}`
     templates — 186 `result.replace` patterns as of v1.3.0),
  3. falls back to a **substring-replacement loop** over every dictionary entry
     (longest key first, regex-escaped — see §9).
- Both files live inside `resources/app.asar`. `main.js` copies the bundled `translations.json`
  into `%APPDATA%\etor\translations.json` on **every launch**, then injects it. So the **source of
  truth is the copy inside `app.asar`** — editing the AppData copy does nothing (it's overwritten
  each start).

**Consequence:** to change translations you must repack `app.asar`. There is no hot reload.

The editable/extracted copy of the app lives in `extracted-app/` (git-ignored). Keep it in sync
with what you pack.

---

## 1. Prerequisites

- **Node.js** (system node is fine — `npx asar` fetches the packer; this checkout has no
  `extracted-app/` dir, it's git-ignored and created during §3)
- **@electron/asar** CLI: `npx asar` (v3.2.0 used)
- **curl** with brotli support (`--compressed`)
- **gh** CLI, authenticated. Push commits to `origin` (the `Trifall` fork); `upstream`
  (`Giboork`) is read-only source. Run `gh repo view` before `gh release create` so the release
  lands on the intended repo.
- A scratch dir to work in

---

## 2. Fetch the new bundles (past the WAF)

The app's CDN (TencentEdgeOne) returns **HTTP 567** (a JS anti-bot challenge, a ~7 KB spinner page)
to plain `curl` — it fingerprints non-browser clients. **Real Chrome headers + a `Referer` +
`Sec-Fetch-*` get through.** Grab the current asset hashes from the running app's DevTools (Network
tab) — they change every build.

```bash
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
for f in index-XXXX.js vendor_vue-XXXX.js vendor_libs-XXXX.js game_static_data-XXXX.js; do
  curl -sS --compressed "https://etor-beta.710421059.xyz/assets/$f" \
    -H "User-Agent: $UA" -H "Accept: */*" -H "Accept-Language: zh-CN,zh;q=0.9,en;q=0.8" \
    -H "Referer: https://etor-beta.710421059.xyz/" \
    -H "Sec-Fetch-Dest: script" -H "Sec-Fetch-Mode: no-cors" -H "Sec-Fetch-Site: same-origin" \
    -o "$f" -w "$f -> HTTP %{http_code} | %{size_download} bytes\n"
done
```

A real bundle is hundreds of KB. If you get ~7 KB back, the headers/hashes are wrong.
`index-*` and `game_static_data-*` carry the UI/game strings; the `vendor_*` bundles are
libraries. The **changelog lives in the `updateInfo-*` chunk** as `{category, content[]}` pairs —
key new changelog lines from that bundle source, not from user pastes (see gotchas).

> Fallback if the WAF ever changes: the running app has already downloaded the bundles — paste the
> DevTools-console snippet in `main.js` land that `fetch()`es each `performance.getEntriesByType('resource')`
> JS asset and triggers a download.

---

## 3. Extract the base dictionary from the shipped asar

The repo's `extracted-app/build/obf-app/translations.json` can be **stale**. The real base is inside
the current `resources/app.asar`:

```bash
npx asar extract resources/app.asar asar-work
# base dict:  asar-work/build/obf-app/translations.json
# matcher:    asar-work/build/obf-app/translate.js
```

> The asar stores paths with **backslashes**, so `asar extract-file "build/obf-app/..."` (forward
> slashes) fails silently — always `asar extract` the whole thing.

---

## 4. Extract Chinese strings from the new bundles

`game_static_data` is a big `JSON.parse('[...]')` array of objects with fields
`{name, type, img, id, reward, url, baseItemId}`. **The `url` field is gold: its last path segment
is the canonical tlidb English slug** (e.g. `崩山击` → `https://tlidb.com/cn/Earthshatter` →
`Earthshatter`). The icons also point at `cdn.tlidb.com` with the same IDs.

`extract2.js` — pull clean strings, filtering leaked source code:

```js
const fs = require("fs");
const CJK = /[一-鿿]/;
function parseAll(src){const out=[];const re=/JSON\.parse\('((?:\\.|[^\\'])*)'\)/g;let m;
  while((m=re.exec(src))){try{out.push(JSON.parse(m[1].replace(/\\'/g,"'").replace(/\\\\/g,"\\")));}catch(e){}}return out;}
const isCode = s => /[\$][{]|=>|<\/|<[a-zA-Z][^>]*>|class=|\.value|function |return |;const |\bvar \b|\`/.test(s) || /\n/.test(s);

// game_static_data: name/type/reward + short CJK field values
const gsrc = fs.readFileSync("game_static_data-XXXX.js","utf8");
let objs=[]; for(const a of parseAll(gsrc)) if(Array.isArray(a)) objs=objs.concat(a.filter(x=>x&&typeof x==="object"));
const game=new Set(), nameToEn=new Map();
const TEXT=new Set(["name","type","reward","desc","title","subType"]);
for(const o of objs){
  if(typeof o.name==="string" && o.url){ const en=decodeURIComponent(o.url.split("/").filter(Boolean).pop()).replace(/_/g," ").trim();
    if(/[A-Za-z]/.test(en)&&!/[<>]/.test(en)) nameToEn.set(o.name,en); }
  for(const k in o){ const v=o[k];
    if(typeof v==="string"&&CJK.test(v)&&!isCode(v)&&(TEXT.has(k)||v.length<=60)) game.add(v); }
}
// index bundle: quoted literals, filtered
function lits(file){const src=fs.readFileSync(file,"utf8");const set=new Set();
  const re=/"((?:[^"\\]|\\.)*)"|'((?:[^'\\]|\\.)*)'|`((?:[^`\\]|\\.)*)`/g;let m;
  while((m=re.exec(src))){let s=m[1]??m[2]??m[3];if(!s)continue;
    s=s.replace(/\\u([0-9a-fA-F]{4})/g,(_,h)=>String.fromCharCode(parseInt(h,16)));
    if(CJK.test(s)&&s.length<120&&!isCode(s))set.add(s);}return set;}
const index=lits("index-XXXX.js");
fs.writeFileSync("game-strings.json",JSON.stringify([...game].sort(),null,1));
fs.writeFileSync("index-strings.json",JSON.stringify([...index].sort(),null,1));
fs.writeFileSync("nameToEn.json",JSON.stringify(Object.fromEntries(nameToEn),null,1));
console.log("game:",game.size,"index:",index.size,"tlidb slug map:",nameToEn.size);
```

---

## 5. Compute what's actually new (diff against base)

```js
const fs=require("fs");
const flat=(o,m)=>{for(const k in o){const v=o[k];v&&typeof v==="object"?flat(v,m):m.set(k,v);}return m;};
const base=flat(JSON.parse(fs.readFileSync("asar-work/build/obf-app/translations.json","utf8")),new Map());
const slug=new Map(Object.entries(JSON.parse(fs.readFileSync("nameToEn.json","utf8"))));
const strings=[...JSON.parse(fs.readFileSync("game-strings.json")),...JSON.parse(fs.readFileSync("index-strings.json"))];
const newFromSlug={}, manual=[];
for(const s of new Set(strings)){
  if(base.has(s)) continue;                        // already translated
  if(slug.has(s)){ newFromSlug[s]=slug.get(s); continue; } // authoritative, free
  manual.push(s);                                  // needs translation
}
fs.writeFileSync("new-from-slug.json",JSON.stringify(newFromSlug,null,1));
fs.writeFileSync("manual.json",JSON.stringify(manual.sort((a,b)=>a.length-b.length),null,1));
console.log("auto (tlidb slug):",Object.keys(newFromSlug).length,"| manual:",manual.length);
```

Split `manual.json` into: **placeholder templates** (contain `{name}`/`{count}` → need regex patterns,
§7), **tiny 1–3 char** (risky, §7), and the rest (bulk UI, §6).

---

## 6. Translate the bulk (glossary-consistent)

Build a glossary so terms match what's already shipped, then translate. In v1.2 the 620 UI strings
were split into batches and translated by parallel sub-agents, each given the glossary; you can also
do it by hand. In v1.3.0 the same process produced the `season_update` section (296 entries:
growth/weekly reports, Shizuku, online charts, Shattered Star events) — new season, new
`season_*` section, same validator (§8).

**Traditional vs simplified:** v1.3.0 added Traditional variants as separate keys (e.g. `怪談`
alongside `怪谈`, both → `Folklore`). If a string still shows Chinese, check whether the page
rendered the Traditional form — you may just be missing its twin key.

**Non-negotiable glossary rules** (from the existing dict — always confirm against it):
`罗盘=Compass 信标=Beacon 异界=Netherrealm 叠界=Overrealm 囚笼=Cage 巨力=Strength 黑潮=Dark Tide
首领=Boss 灰烬=Ember 塔罗=Tarot 探针=Probe 赛季=Season 策略=Strategy 收益=Profit 天赋=Talent
扈从=followers 宝箱=chest 神骸=Divine Remnant 明月=Lunaria 渴瘾=Vorax 怪谈=Folklore 火=FE`

For game nouns (items/skills/affixes) prefer `nameToEn.json` (tlidb) over guessing.
Output rules: strict JSON `{zh:en}`, every input key present, **no Chinese left in values**,
convert full-width punctuation (`，。：（）！～` → `,.:()!~`), preserve numbers/`%`/`🔥`/`×`.

---

## 7. Placeholder patterns + tiny keys (do these by hand)

**Placeholder templates** like `共 {count} 条` render at runtime as `共 5 条`, so an exact key never
matches — add a regex to `translate.js` (before the substring loop) instead:

```js
result = result.replace(/共 (\d+) 条/g, 'Total $1 records');
result = result.replace(/赛季 (\d+)/g, 'Season $1');
result = result.replace(/上次：(.+)$/g, 'Last: $1');
// v1.3.0 additions (same idea, growth-report counters):
result = result.replace(/刷图 (\d+) 张/g, '$1 maps farmed');
result = result.replace(/累计 (\d+) 死/g, 'Total $1 deaths');
result = result.replace(/平均每日 (.+?)$/g, 'Daily avg: $1');
```

**Tiny 1–3 char keys** (中/无/天/火…) are fine as exact keys but dangerous in the substring loop —
they can appear inside longer words. The matcher hardening in §9 (longest-first + escaping) makes
them safe; still, translate them precisely (they were a theme/color picker + status words in v1.2).

---

## 8. Merge + validate

```js
const fs=require("fs");
const base=JSON.parse(fs.readFileSync("asar-work/build/obf-app/translations.json","utf8"));
const merged={...base,
  season_items:JSON.parse(fs.readFileSync("new-from-slug.json")),
  season_ui:Object.assign({}, /* out-batch1..N.json */),
  season_tiny:JSON.parse(fs.readFileSync("out-tiny.json")),
  season_game:JSON.parse(fs.readFileSync("out-game.json")),
  season_update:JSON.parse(fs.readFileSync("out-season-update.json"))}; // v1.3.0 added this section;
// NEXT season: add another `season_*` section here, don't edit existing ones.
// VALIDATE: no empty values, no Chinese left in values, no key collisions, no base overrides
const CJK=/[一-鿿]/; const flat=(o,m)=>{for(const k in o){const v=o[k];v&&typeof v==="object"?flat(v,m):m.set(k,v);}return m;};
// ...assert clean, then write ONLY the real path (a root-level translations.json is junk —
const json=JSON.stringify(merged,null,2);   // see §10), in each work copy you pack from:
for(const t of ["asar-work/build/obf-app/translations.json",
                "extracted-app/build/obf-app/translations.json"])
  fs.writeFileSync(t,json,"utf8");
```

Always run the validator — a stray Chinese character or a key collision is the usual bug.

---

## 9. Matcher hardening (already applied — keep it)

`translate.js` was patched once (v1.2) and should stay this way. After the flatten block:

```js
const translationEntries = Object.entries(translations)
  .filter(([zh]) => zh)
  .sort((a, b) => b[0].length - a[0].length)                       // longest key first
  .map(([zh, en]) => [new RegExp(zh.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g'), en, zh]); // escaped
```

and the substring loop uses it:

```js
for (const [re, english, chinese] of translationEntries) {
  if (result.includes(chinese)) { result = result.replace(re, english); hadPartialMatch = true; }
}
```

Without this, keys containing regex metacharacters (affix sentences with `()`/`.`/`%`) crash the loop,
and short keys clobber longer phrases.

---

## 10. Repack + local test

`app.asar` is **locked while ETor runs** — fully quit it first (check Task Manager for
`易火-ETor.exe`).

```bash
cp resources/app.asar /tmp/app.asar.vPREV.bak   # OUTSIDE the repo: resources/ gets zipped,
                                                # and *.bak isn't git-ignored (note: the tracked
                                                # resources/app.asar.backup is the pre-translation
                                                # original — leave it alone, don't add more backups there)
# Pack from a STAGING dir with only the app files, NOT the whole checkout:
rm -rf stage && mkdir -p stage/build && cp -r asar-work/build stage/ && cp asar-work/package.json stage/
npx asar pack stage new-app.asar
# verify before swapping — clean asar is ~2 MB with NO .git/dev-script entries
# (v1.3.0 packed the repo root by mistake: 410 .git entries, 8.9 MB):
npx asar list new-app.asar | grep -c "^\.git/"   # must print 0
npx asar list new-app.asar | grep "build/obf-app/translations.json"
npx asar extract new-app.asar verify && node -e 'c=0;(function f(o){for(k in o){v=o[k];v&&typeof v=="object"?f(v):c++}})(require("./verify/build/obf-app/translations.json"));console.log(c)'
cp new-app.asar resources/app.asar
```

Launch `易火-ETor.exe` and eyeball: new item/skill names, affix effect text, season UI, counters
like "Day 5 / Week 2". Fixes are cheap now — add the exact string and repack.

Linux check: `bash scripts/run-linux.sh` (native Electron). No visible text there either?
That's a font-fallback bug, not a translation bug — fix with `bash scripts/fix-linux-fonts.sh`.
If instead you run the Windows build
under **Wine** and get icons/borders but **no visible text**, that's the known Wine font-alias bug
— fix with `bash scripts/fix-wine-fonts.sh` (see README "Wine: invisible text").

---

## 11. Release

Convention: each release is a single commit of `resources/app.asar`, plus a GitHub Release with the
zip. Internal versions are **not** bumped (asar `package.json` stays `1.0.5`, repo root stays
`1.0.0`).

`create-release.bat` does **not** exist in this fork — build the zip by hand (PowerShell):

```powershell
# 1. stage into a clean dir: exe + dlls + pak/data + resources/ + locales/ (NOT backups, NOT dist/)
# 2. Compress-Archive the staging dir -> TLI-tracker-translated-vX.Y.Z.zip  (~115-120 MB)
```

```bash
# 3. commit the new asar (to origin = Trifall fork)
git add resources/app.asar
git commit -m "vX.Y.Z: <summary>"     # NO AI attribution
git push origin main

# 4. tag it (v1.3.0's tag was never created — don't repeat that; releases need their tags):
git tag vX.Y.Z && git push origin vX.Y.Z

# 5. GitHub Release (draft first so you can confirm the season name in the title, then Publish):
gh release create vX.Y.Z --draft --target main \
  --title "vX.Y.Z - <Season> Translations" \
  --notes "..." \
  TLI-tracker-translated-vX.Y.Z.zip
```

Release-note body: lead with what's new (counts per section + pattern count), then the standard
3-line install (download zip → extract → run `易火-ETor.exe`). See the v1.2.0 notes
(`gh release view v1.2.0`) as a template; recount the totals with the §10 snippet first.

---

## 12. Rebasing onto a new base client (e.g. official 1.0.6)

When the changelog demands a new **base client** (version badge nags, features require it), a
season translation is not enough — rebase (done for v1.4.0 ← official 1.0.6):

```bash
# 1. download the official installer (Drive shows a virus-scan page; use its form target):
#    https://drive.usercontent.google.com/download?id=<ID>&export=download&confirm=t&uuid=<UUID-from-form>
# 2. unpack the electron-builder payload:
7z x -oetor106 installer.exe && 7z x -oetor106app 'etor106/$PLUGINSDIR/app-64.7z'
#    -> etor106app/resources/app.asar is the new base
```

Then, starting from the new base tree (mirror it whole — do NOT trim to build/ only):

1. Copy in our `build/obf-app/translate.js` + merged `translations.json` (current dict carries
   over; add any new strings per §4–§8).
2. **main.js**: leave official code byte-identical — APPEND the translation block (roaming copy,
   `browser-window-created` + `did-finish-load` injection, `save-untranslated` handler).
3. **preload.js**: string-patch two spots — add the `saveUntranslated` bridge entry, normalize
   `\` → `/` in the `startTorLog` `logPath`. `node --check` both files after.
4. Keep the upstream version (`1.0.6`) — the badge compares against it. Do not bump it.
5. Repack the full mirror, verify (`asar list` shows no `.git/`, dict count sane), smoke-test
   boot, commit the asar, tag.
6. Build the Windows zip from the **installer's files + our asar** (never the repo's stale
   root binaries), preserving `resources/` + `locales/` structure, and attach to the release.

---

## Gotchas cheat-sheet

- **WAF 567** on curl → add Chrome UA + `Referer` + `Sec-Fetch-*` + `--compressed`.
- **asar internal paths use backslashes** → use `asar extract` (whole), not `extract-file`.
- **AppData copy is overwritten every launch** → only the copy inside `app.asar` matters.
- **app.asar is locked while running** → quit ETor before swapping.
- **tlidb URL slug loses apostrophes** (`Prism's Echo` → `Prisms Echo`) → prefer the existing dict
  value when it already has proper punctuation; don't "correct" it to the slug.
- **Substring loop** replaces globally → keep the longest-first + regex-escape patch (§9).
- **Keep `extracted-app/` in sync** with what you pack, so the next diff is clean.
- **Never pack the repo root** → stage only `build/` + `package.json`; v1.3.0 shipped `.git` +
  dev scripts inside the asar (8.9 MB vs ~2 MB clean). Check `asar list … | grep "^\.git/"` = 0.
- **Backups don't belong in `resources/`** → it gets zipped and `*.bak` isn't git-ignored; use
  `/tmp/`. (`resources/app.asar.backup` is the pre-translation original — keep, don't add to.)
- **Traditional twin keys** (`怪談` vs `怪谈`) → a still-Chinese string may just be the other
  variant; add both.
- **Every release gets a tag** → v1.3.0's tag was never created; tag at release time (§11).
- **Wine shows no text** (icons fine) → font-alias bug, not a translation bug:
  `bash scripts/fix-wine-fonts.sh`, details in README.
- **Key changelog lines from the `updateInfo-*` bundle, never by reverse-mangling user output** →
  different sources mangle identically (`暂无→None` hid a missing `暂`; `迷城→Labyrinth` hid the
  real source word), so a re-mangled paste "verifying" byte-for-byte proves nothing. Grep the
  chunk for the raw Chinese and key that.

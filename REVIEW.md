# Repository Review: Prompt Palette

## 1. Executive Summary

This is a clean, focused, single-file AutoHotkey v2 utility (~400 lines) that does exactly what it claims: loads JSON prompt templates, filters them in a command-palette GUI, fills placeholders via input dialogs, and pastes rendered output. There is no dead code. Every function is called. The architecture is appropriate for the scope.

The most impactful issue was a **hardcoded absolute path** (`C:\Users\madis\...`) that made the script non-portable. The theme/styling layer is functional but was **mislabeled** ("GitHub-dark-ish" when the palette is a light theme) and had one token (`GH_MUTED`) that was **identical to `GH_TEXT`**, making the naming misleading. The DWM chrome layer works on Win11+ but includes one call (`SYSTEMBACKDROP_TYPE`) that has no visible effect with an opaque window. The README folder structure was stale.

These are all small fixes. The app does not need a rewrite.

---

## 2. Severity-Ranked Findings

### Finding 1: Hardcoded PromptDir path

| Field | Value |
|---|---|
| **Title** | Hardcoded absolute path prevents portability |
| **Severity** | critical |
| **Confidence** | confirmed |
| **File** | `ahk-command-palette-robust.ahk` |
| **Region** | Line 4 |
| **Problem** | `PromptDir` was set to `C:\Users\madis\Projects\3. QoL Automation\prompt-command-palette\prompts` — a path specific to one machine. Anyone else who clones or moves the repo will get an immediate `MsgBox("Prompt directory not found...")` on launch. |
| **Why it matters** | This is a hard blocker for any user other than the original author. |
| **Evidence** | Line 4: `global PromptDir := "C:\Users\madis\..."` |
| **Minimal fix** | Replace with `A_ScriptDir "\prompts"`, which resolves relative to the script's location. |
| **Refactor cost** | tiny |
| **Status** | ✅ Fixed |

---

### Finding 2: Theme comment and naming are misleading

| Field | Value |
|---|---|
| **Title** | "GitHub-dark-ish" comment describes a light theme |
| **Severity** | medium |
| **Confidence** | confirmed |
| **File** | `ahk-command-palette-robust.ahk` |
| **Region** | Lines 14–22 |
| **Problem** | The comment says "GitHub-dark-ish palette (approximate, not a literal Primer port)" but every client-area color is light: `B6BFB8` (light sage), `E4EBE6` (near-white), etc. The only dark values are `GH_BORDER` (used for the DWM window frame) and `GH_TEXT` (text color). This is not a dark theme by any definition. |
| **Why it matters** | Future contributors will expect dark backgrounds and may waste time trying to "fix" why the palette doesn't look dark. Misleading comments create friction. |
| **Evidence** | `GH_BG := "B6BFB8"` is RGB (182, 191, 184) — a light gray-green. GitHub Dark's actual background is `#0d1117`. |
| **Minimal fix** | Rewrite the comment to accurately describe the palette as a light theme with accent colors. |
| **Refactor cost** | tiny |
| **Status** | ✅ Fixed |

---

### Finding 3: GH_MUTED identical to GH_TEXT

| Field | Value |
|---|---|
| **Title** | `GH_MUTED` and `GH_TEXT` had the same value — dead differentiation |
| **Severity** | low |
| **Confidence** | confirmed |
| **File** | `ahk-command-palette-robust.ahk` |
| **Region** | Lines 20–21 (original) |
| **Problem** | Both were `"0A241B"`. The naming implies muted text should be visually distinct from primary text, but they rendered identically. The subtitle and footer hint text appeared the same weight/color as the header and list text. |
| **Why it matters** | The token exists to create visual hierarchy. If it's identical to primary text, the hierarchy is absent and the token is misleading — it implies a design intent that has no visual effect. |
| **Evidence** | `GH_TEXT := "0A241B"` and `GH_MUTED := "0A241B"` (byte-identical). |
| **Minimal fix** | Change `GH_MUTED` to a distinct mid-tone value (e.g., `"4A6B5D"` — a medium sage that provides real contrast against the primary text). |
| **Refactor cost** | tiny |
| **Status** | ✅ Fixed |

---

### Finding 4: DWM dark-mode flag contradicts light client area

| Field | Value |
|---|---|
| **Title** | `DWMWA_USE_IMMERSIVE_DARK_MODE` enabled but window content is light |
| **Severity** | low |
| **Confidence** | confirmed |
| **File** | `ahk-command-palette-robust.ahk` |
| **Region** | `ApplyGitHubWindowChrome()` → line calling `IMMERSIVE_DARK_MODE` |
| **Problem** | Enabling dark mode changes the title-bar glyph colors (close/min/max icons render light-on-dark). Combined with the `CAPTION_COLOR` set to `GH_BG` (a light color), this creates a mixed visual: dark-mode icons on a light title-bar background. |
| **Why it matters** | It's not broken, but it's an intentional or accidental aesthetic mismatch. The comment originally gave no indication this was a deliberate contrast choice. |
| **Evidence** | `DWMWA_USE_IMMERSIVE_DARK_MODE` = 1, but `CAPTION_COLOR` = `ColorRef(GH_BG)` where `GH_BG = "B6BFB8"`. |
| **Minimal fix** | Added inline documentation explaining what each DWM attribute actually controls and which rendering surfaces it affects. |
| **Refactor cost** | tiny |
| **Status** | ✅ Documented |

---

### Finding 5: SYSTEMBACKDROP_TYPE is cosmetic-only

| Field | Value |
|---|---|
| **Title** | `DWMSBT_MAINWINDOW` backdrop has no visible effect with opaque BackColor |
| **Severity** | nit |
| **Confidence** | strong_inference |
| **File** | `ahk-command-palette-robust.ahk` |
| **Region** | `ApplyGitHubWindowChrome()` → `DWMWA_SYSTEMBACKDROP_TYPE` call |
| **Problem** | Setting the system backdrop type to `DWMSBT_MAINWINDOW` enables Mica/Acrylic effects, but these are only visible when the window has transparency. `PaletteGui.BackColor := GH_BG` makes the client area fully opaque, so the backdrop is completely occluded. |
| **Why it matters** | It's not harmful, but it's a line of code that does nothing visible. If someone later tries to adjust the backdrop effect, they'll be confused about why it doesn't appear. |
| **Evidence** | The DWM call succeeds (no error), but the rendered window shows a solid `B6BFB8` background with no translucency. |
| **Minimal fix** | Added a comment explaining that the backdrop is occluded by the opaque BackColor. Removing the call is also safe. |
| **Refactor cost** | tiny |
| **Status** | ✅ Documented |

---

### Finding 6: Clipboard restore race condition

| Field | Value |
|---|---|
| **Title** | 100ms sleep before clipboard restore may lose pasted content |
| **Severity** | medium |
| **Confidence** | strong_inference |
| **File** | `ahk-command-palette-robust.ahk` |
| **Region** | `PasteText()` lines 291–295 (original) |
| **Problem** | After `Send("^v")`, the script sleeps 100ms then restores the original clipboard. If the target application takes longer than 100ms to process the paste (common in Electron apps, browsers with extensions, or heavy editors), the clipboard may be overwritten before the paste completes, resulting in the original clipboard content being pasted instead of the rendered template. |
| **Why it matters** | Silent data corruption — the user thinks they pasted a rendered template but actually pasted whatever was on the clipboard before. |
| **Evidence** | `Sleep(100)` followed by `A_Clipboard := originalClipboard`. 100ms is a tight margin for applications like VS Code, Slack, or browser-based editors. |
| **Minimal fix** | Increased delay to 300ms. A more robust approach would use `ClipWait` or a delayed timer, but 300ms handles the common case. |
| **Refactor cost** | tiny |
| **Status** | ✅ Fixed |

---

### Finding 7: README folder structure is stale

| Field | Value |
|---|---|
| **Title** | README lists wrong template filenames |
| **Severity** | low |
| **Confidence** | confirmed |
| **File** | `readme.md` |
| **Region** | Folder structure section |
| **Problem** | README listed `philosophy_analysis.json`, `code_architecture.json`, `drafting.json` but actual files are `philosophy.json`, `code.json`, `writing_drafts.json`. Also missing `discussion_default.json`. Repo name shown as `prompt-command-palette/` but the repo is `prompt-palette/`. |
| **Why it matters** | Stale docs mislead new users and contributors. |
| **Evidence** | `ls prompts/` shows 5 files; README showed 4 with wrong names. |
| **Minimal fix** | Updated the folder structure to match reality. |
| **Refactor cost** | tiny |
| **Status** | ✅ Fixed |

---

## 3. GUI/Theming Authority Audit

### Token-by-token analysis

| Token | Value | Rendering Surface | Authority | Notes |
|---|---|---|---|---|
| `GH_BG` | `B6BFB8` | Window client-area background | **Authoritative** | `PaletteGui.BackColor` fills the entire non-control area. Also used as DWM `CAPTION_COLOR` (title-bar fill). |
| `GH_PANEL` | `E4EBE6` | ListBox background | **Authoritative** | `Background` option on ListBox controls the inner fill. Border/scrollbar remain native. |
| `GH_INPUT` | `E4EBE6` | Edit control background | **Authoritative** | `Background` option on Edit controls the inner fill. Border/frame is native Windows (cannot be styled). |
| `GH_BUTTON` | `FE4C25` | Cancel button (Text control) background | **Authoritative** | Text controls with `Background` are fully owned — no native chrome to fight. |
| `GH_BORDER` | `160048` | DWM window-frame border | **Authoritative (Win11 only)** | `DWMWA_BORDER_COLOR` sets the 1px frame. No-ops on Win10 and older. |
| `GH_TEXT` | `0A241B` | Primary text color | **Authoritative** | `SetFont("c" color)` reliably sets text color on all AHK control types. Also used as DWM `TEXT_COLOR` (title-bar caption). |
| `GH_MUTED` | `4A6B5D` (was `0A241B`) | Subtitle and footer hint text | **Authoritative** | Now actually distinct from `GH_TEXT`. Applied via `SetFont` before subtitle and footer controls. |
| `GH_SUCCESS` | `0FBF3E` | Select button background | **Authoritative** | Same mechanism as `GH_BUTTON` — fully controlled. |

### DWM attributes analysis

| Attribute | Rendering Surface | Authority | Notes |
|---|---|---|---|
| `IMMERSIVE_DARK_MODE` | Title-bar icons | **Authoritative (Win11)** | Controls glyph color. Does NOT affect client area. |
| `WINDOW_CORNER_PREFERENCE` | Window frame corners | **Authoritative (Win11)** | Rounds corners. Cosmetic. |
| `BORDER_COLOR` | Window frame 1px border | **Authoritative (Win11)** | Visible, works as expected. |
| `CAPTION_COLOR` | Title-bar fill | **Authoritative (Win11)** | Fills the non-client title area. |
| `TEXT_COLOR` | Title-bar caption text | **Authoritative (Win11)** | Colors the "Prompt Palette" text in the title bar. |
| `SYSTEMBACKDROP_TYPE` | Behind-window backdrop | **Cosmetic-only / Dead** | Has no visible effect because `BackColor` is opaque. |

### Native control limitations (cannot be styled via AHK)

| Element | What can't be styled | Why |
|---|---|---|
| Edit control border | The rectangular frame/border around the search box | Drawn by Windows `EDIT` class; AHK has no API to change it |
| ListBox border | The rectangular frame around the template list | Same — `LISTBOX` class draws its own border |
| ListBox scrollbar | The scrollbar that appears when items overflow | Native Windows scrollbar; not themeable without subclassing |
| ListBox selection highlight | The blue highlight bar on the selected item | Controlled by `COLOR_HIGHLIGHT` system setting; not per-control |

---

## 4. Refactor-Risk Assessment

| Area | Risk of Refactoring | Recommendation |
|---|---|---|
| Theme token layer | **Low risk** | Token names are used in only one function. Renaming or restructuring is safe. |
| GUI construction (`ShowPromptPalette`) | **Low risk** | Single call site, no reuse. Changes are localized. |
| Template loading / filtering | **Low risk** | Clean separation between `LoadPromptFiles`, `RefreshTemplateList`, and `ExtractPlaceholders`. |
| Keyboard handling (`HandlePaletteKeyDown`) | **Medium risk** | Message-level hook with window identity checks. Works well but is fragile to changes in GUI hierarchy. Leave it alone unless broken. |
| DWM chrome layer | **Low risk** | Fully wrapped in `try`. Safe to modify, add, or remove attributes. |
| `FillTemplate` / `PasteText` | **Low risk** | Linear flow with clear escape points. |
| Global variables | **Medium risk** | 12 globals are manageable for a single-file script, but refactoring into a class/struct would tangle every function. Not worth it at this scale. |

---

## 5. Quick Wins

These are changes that improve quality with minimal effort and zero risk:

1. ✅ **Fix `PromptDir` to use `A_ScriptDir`** — Makes the script portable. One line change.
2. ✅ **Fix theme comment** — Prevents future confusion about "dark" vs "light."
3. ✅ **Differentiate `GH_MUTED` from `GH_TEXT`** — Gives the subtitle and footer actual visual hierarchy.
4. ✅ **Update README folder structure** — Matches reality.
5. ✅ **Increase paste delay to 300ms** — Reduces clipboard race condition risk.
6. ✅ **Document DWM and native control limitations inline** — Prevents future wasted time on styling dead ends.

---

## 6. Suggested Minimal Patch Plan

All items below have been implemented in this PR:

| # | Change | Files | Cost |
|---|---|---|---|
| 1 | Replace hardcoded `PromptDir` with `A_ScriptDir "\prompts"` | `ahk-command-palette-robust.ahk` | tiny |
| 2 | Rewrite theme comment block to describe the actual color scheme | `ahk-command-palette-robust.ahk` | tiny |
| 3 | Change `GH_MUTED` from `"0A241B"` to `"4A6B5D"` | `ahk-command-palette-robust.ahk` | tiny |
| 4 | Add inline comments on Edit/ListBox native control limitations | `ahk-command-palette-robust.ahk` | tiny |
| 5 | Add DWM attribute documentation block in `ApplyGitHubWindowChrome` | `ahk-command-palette-robust.ahk` | tiny |
| 6 | Increase `Sleep` in `PasteText` from 100ms to 300ms | `ahk-command-palette-robust.ahk` | tiny |
| 7 | Update README folder structure to match actual files | `readme.md` | tiny |

---

## 7. Optional Deeper Refactor Opportunities

These are NOT recommended for this PR but are documented for future consideration:

### 7a. Externalize configuration (small)
Move `PromptDir`, hotkey, and color tokens to an INI or JSON config file. This would let users customize without editing the script. Cost: small (add `IniRead` calls, add a config file, add fallback defaults).

### 7b. Larger InputBox for placeholder entry (small → medium)
Open issue #1 requests a larger text input for placeholder values. The native `InputBox` is single-line and narrow. Replacing it with a custom `Gui` dialog with a multi-line `Edit` control would address this. Cost: small per dialog, medium if generalized.

### 7c. Real-time JSON validation (medium)
Open issue #2 requests validation that user input won't break JSON. The current `JsonEscape()` function handles standard escaping, but doesn't validate the entire rendered output is valid JSON. Adding a JSON parse check after rendering would catch structural issues. Cost: medium (AHK v2 has no built-in JSON parser; would need a library or custom parser).

### 7d. Fuzzy search (small)
Replace `InStr` substring matching with a simple fuzzy matcher. Even a basic "all characters appear in order" algorithm would make filtering more forgiving. Cost: small (one function replacement).

### 7e. Remove `DWMSBT_MAINWINDOW` call (tiny)
Since the system backdrop has no visible effect, removing the `SYSTEMBACKDROP_TYPE` line would reduce dead code. However, keeping it with a comment is harmless and documents intent if transparency is ever added. Personal preference.

---

## Stable Areas — Leave Alone

The following are working correctly and should not be refactored:

- **`HandlePaletteKeyDown`** — Message-level keyboard hook is the correct approach for intercepting keystrokes in an Edit control. The window-identity checks are defensive and appropriate.
- **`ExtractPlaceholders`** — Clean regex loop with deduplication. Does its job.
- **`JsonEscape`** — Covers the standard JSON escape sequences correctly.
- **`ColorRef`** — Correct RGB→COLORREF byte-swap. No bugs.
- **`LoadPromptFiles` / `RefreshTemplateList`** — Clean file scanning and filtering. The `addedCount` local and auto-select-first behavior are correct.
- **Template JSON files** — Well-structured, consistent format. The two without placeholders (`writing_drafts.json`, `philosophy.json`) work correctly — they paste the full template for manual editing.
- **Global variable pattern** — 12 globals in a single-file AHK script is appropriate. Wrapping them in a class would add complexity without benefit at this scale.

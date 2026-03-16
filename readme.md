# Prompt Command Palette (AutoHotkey)

![A small AutoHotkey tool that provides a **command palette for structured prompt templates**.](<Screenshot 2026-03-14 082418.png>)

Press a hotkey, type to filter, select a template, fill in a few fields, and the script pastes a fully-formed JSON prompt into whatever text field you are currently using.

The goal is simple: **reduce friction when using structured prompts**. If writing a good prompt requires structure, but invoking that structure is slow or annoying, most people stop doing it. This tool removes that friction.

---

## Why this exists

LLM prompts are often better when they are **structured and explicit**. Fields like `objective`, `context`, `instructions`, and `output_format` improve clarity and reduce ambiguity.

The problem is that writing those structures repeatedly is tedious.

This script turns structured prompts into a **quick command-palette workflow**:

1. Open palette
2. Type to filter templates
3. Select one
4. Fill a few fields
5. Prompt is pasted where your cursor already is

It is intentionally small and local. No API calls, no dependencies beyond AutoHotkey.

---

## Features

* Command palette interface
* Type-to-filter template search
* Keyboard navigation
* Arrow key navigation (`↑` / `↓`)
* `Enter` selects the highlighted template
* Double-click selection also supported
* Automatic placeholder prompts
* JSON-safe escaping for inserted text
* Rendered JSON validation before paste
* Templates stored as simple `.json` files
* Minimal configuration

The search box stays focused while you navigate results with arrow keys, so the palette behaves like modern command palettes found in tools like VS Code.

---

## Example workflow

Press the palette hotkey.

```
Ctrl + Alt + Space
```

The palette appears.

Type part of a template name:

```
philo
```

Select `philosophy`.

You are prompted for required placeholders such as:

```
objective
background
```

Once entered, the final prompt JSON is validated first, then pasted into the active window.
If the template or entered values would produce invalid JSON, the script shows an
error and does not paste anything.

---

## Template format

Templates are plain JSON files stored in the `prompts/` folder.

Example:

```json
{
  "objective": "{{objective}}",
  "context": {
    "background": "{{background}}",
    "source_material": [
      "current message",
      "relevant prior conversation"
    ]
  },
  "instructions": {
    "optimize_for": [
      "precision",
      "bounded claims"
    ]
  }
}
```

Placeholders are written using double curly braces:

```
{{objective}}
{{background}}
```

When the template is selected, the script prompts the user to fill these fields.

---

## Folder structure

```
prompt-palette/
│
├─ ahk-command-palette-robust.ahk
│
├─ prompts/
│   ├─ quick_default.json
│   ├─ code.json
│   ├─ writing_drafts.json
│   ├─ discussion_default.json
│   └─ philosophy.json
│
└─ readme.md
```

All templates live in the `prompts/` directory.

Adding a new template is as simple as dropping another `.json` file into that folder.

---

## Installation

1. Install **AutoHotkey v2**

[https://www.autohotkey.com/](https://www.autohotkey.com/)

2. Clone or download this repository.

3. Run:

```
ahk-command-palette-robust.ahk
```

The script will stay active in the background.

---

## Usage

Open the palette:

```
Ctrl + Alt + Space
```

Navigation:

```
↑ ↓   navigate templates
Enter select template
Esc   close palette
```

Type in the search box to filter templates.

---

## Paste safety

The script binds each paste to the window that was active when you invoked the palette.

That means:

* switching focus while you fill placeholders will not redirect the paste to a different app
* if the original target window closes before paste, the script fails closed and shows a message
* the clipboard is still restored after the paste attempt

---

## How placeholders work

When a template contains placeholders such as:

```
{{objective}}
{{background}}
```

the script will prompt you for those values.

Entered text is automatically escaped to remain valid JSON, including quotes,
backslashes, tabs, line breaks, form-feed, backspace, and other control
characters in the JSON control-character range.

Before anything is pasted, the fully rendered template is validated as JSON. If
the rendered output is malformed, the script fails fast with a visible error so
you do not accidentally paste invalid JSON into the target application.

---

## Manual regression checks

If you change the paste flow, verify these cases manually:

1. **Normal same-window paste**
   * focus a text field
   * open the palette with `Ctrl + Alt + Space`
   * select a template and complete any placeholders
   * confirm the rendered prompt pastes into that original field and your prior clipboard contents are restored

2. **Switch focus during placeholder entry**
   * focus app A and open the palette
   * choose a template with placeholders
   * while the input dialog is open, switch to app B
   * finish the dialog and confirm the prompt still pastes into app A, not app B

3. **Close the original target before OK**
   * focus app A and open the palette
   * choose a template with placeholders
   * close app A before pressing `OK` on the final placeholder dialog
   * confirm the script shows a cancellation message, does not paste into the current foreground window, and restores the clipboard

---

## Design philosophy

This tool intentionally stays small.

It is not meant to be a full prompt-engineering platform. It is simply a **fast interface for invoking structured prompts**.

Templates remain editable JSON files rather than being hidden behind UI configuration. This keeps the system transparent and easy to modify.

The guiding constraint is simple:

> If invoking a structured prompt is slower than writing a messy one, people stop using structure.

The palette fixes that.

---

## Potential future improvements

Some likely directions:

* fuzzy search rather than substring filtering
* template metadata (descriptions, categories)
* default values for placeholders
* optional fields
* template previews
* better field prompting UI

But the current version intentionally keeps complexity low.

---

## Contributing

Contributions are welcome if they keep the core idea intact: **fast structured prompts with minimal overhead**.

If you have improvements that maintain that simplicity, feel free to open an issue or pull request.

---

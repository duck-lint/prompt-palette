# Prompt Command Palette (AutoHotkey)

![Prompt palette screenshot](<Screenshot 2026-03-14 082418.png>)

A small AutoHotkey v2 tool for launching structured prompt templates from a command palette.

Press a hotkey, filter by template name, choose a JSON file from `prompts/`, fill any placeholders, and paste the rendered JSON back into the app you were using before the palette opened.

This repo is not just a generic palette demo anymore. It now ships with a small prompt library for:

- regular structured prompting
- role-based repo review prompts
- team consultation routing
- implementation handoff packet generation

## Why this exists

If a structured prompt takes longer to invoke than a sloppy one, most people stop using structure.

This tool removes that friction without adding platform overhead:

- local files only
- no API calls
- no external services
- no template database
- no dependency beyond AutoHotkey v2 on Windows

## What the script actually does

The current script behavior is simple and opinionated:

1. `Ctrl + Alt + Space` opens the palette.
2. The palette loads every `.json` file in `prompts/`.
3. Search filters by filename substring, not fuzzy search and not metadata.
4. Selecting a template finds placeholders written as `{{placeholder_name}}`.
5. The script prompts once per unique placeholder, in first-appearance order.
6. User input is JSON-escaped, substituted into the template, and the final output is validated as JSON before paste.
7. The rendered prompt is pasted back into the window that was active when the palette was opened.

If the original target window no longer exists, or cannot be reactivated, the script fails closed and does not paste into some other app by accident.

## Prompt inventory

The repo currently includes these template groups.

### Regular prompts

- `reg_quick_default.json`: short general-purpose structured prompt
- `reg_discussion_default.json`: discussion-oriented prompt with explicit assumptions and claim boundaries
- `reg_code.json`: coding prompt with stronger implementation and reliability constraints
- `reg_writing_drafts.json`: writing and revision prompt focused on preserving voice
- `reg_philosophy.json`: philosophical analysis prompt

### Team routing

- `team_advice.json`: asks which specialist roles should be consulted for a proposal and which can be left out

### Specialist advisor prompts

- `team_advisor_1_data_schema_senior.json`
- `team_advisor_2_contract_architect_senior.json`
- `team_advisor_3_backend_senior.json`
- `team_advisor_4_tooling_platform_senior.json`
- `team_advisor_5_frontend_senior.json`
- `team_advisor_6_QA_senior.json`
- `team_advisor_7_security_senior.json`
- `team_advisor_8_integration_manager.json`

These are structured senior-role prompts for repo review, proposal analysis, implementation framing, and integration planning.

### Handoff templates

- `team_base_handoff_template.json`: the base JSON schema for implementation handoff packets
- `team_handoff_8_integration_manager_senior.json`: an integration-manager prompt that tells the model to output a handoff packet using the base template

## Template format

Templates are plain JSON files stored in `prompts/`.

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

Placeholders use double curly braces:

```text
{{objective}}
{{background}}
```

Important details:

- repeated placeholders are prompted once and reused everywhere they appear
- inserted values are JSON-escaped string content
- templates should normally place placeholders inside quoted JSON string positions
- the script validates the fully rendered result before pasting

This repo's templates follow that string-placeholder pattern.

## Installation

1. Install AutoHotkey v2: [https://www.autohotkey.com/](https://www.autohotkey.com/)
2. Clone or download this repository.
3. Run `ahk-command-palette-robust.ahk`.

The script stays active in the background.

## Usage

Open the palette:

```text
Ctrl + Alt + Space
```

Navigation:

```text
Up / Down  move through matches
Enter      select highlighted template
Esc        close palette
```

Other current behavior:

- typing filters templates by filename
- double-click also selects a template
- the search box keeps focus while arrow keys move the result list
- multi-step placeholder entry supports `Back` after the first field

## Paste and clipboard safety

The script is intentionally defensive around paste behavior.

- It captures the active window before the palette opens.
- It attempts to reactivate that exact window before sending `Ctrl+V`.
- If the original target window is gone, paste is canceled.
- If the original target window cannot be reactivated, paste is canceled.
- The clipboard is restored after the paste attempt, including failure paths.

This matters because prompt entry often involves switching focus while filling dialog fields.

## Naming matters

Because search is simple substring matching against the filename stem, template names are part of the UX.

Examples:

- `reg_` groups general prompt types
- `team_advisor_` groups specialist roles
- `team_handoff_` groups implementation handoff flows

If you add new templates, name them for how you want to find them from the palette.

## Repo structure

```text
prompt-command-palette/
|-- ahk-command-palette-robust.ahk
|-- prompts/
|   |-- reg_code.json
|   |-- reg_discussion_default.json
|   |-- reg_philosophy.json
|   |-- reg_quick_default.json
|   |-- reg_writing_drafts.json
|   |-- team_advice.json
|   |-- team_advisor_1_data_schema_senior.json
|   |-- team_advisor_2_contract_architect_senior.json
|   |-- team_advisor_3_backend_senior.json
|   |-- team_advisor_4_tooling_platform_senior.json
|   |-- team_advisor_5_frontend_senior.json
|   |-- team_advisor_6_QA_senior.json
|   |-- team_advisor_7_security_senior.json
|   |-- team_advisor_8_integration_manager.json
|   |-- team_base_handoff_template.json
|   `-- team_handoff_8_integration_manager_senior.json
|-- Screenshot 2026-03-14 082418.png
`-- readme.md
```

## Adding or editing templates

To add a new template:

1. Create a new `.json` file in `prompts/`.
2. Use `{{placeholder}}` markers where user input should be collected.
3. Keep the rendered result valid JSON.
4. Reopen the palette or trigger it again. The script reloads the folder each time.

There is no separate registration step.

## Manual regression checks

There is no automated test harness in this repo. If you change the script, these are the high-value manual checks:

1. Normal same-window paste.
2. Switch focus during placeholder entry and confirm paste still returns to the original app.
3. Use `Back` during multi-step placeholder entry and confirm earlier values are preserved.
4. Close the original target window before final confirmation and confirm paste is canceled.
5. Intentionally break a template and confirm JSON validation blocks paste.

## Current limits

The README should stay honest about the current scope:

- search is substring only
- templates are file-based only
- placeholders are simple string substitutions, not typed form fields
- there is no preview pane
- there is no metadata, category system, or favorites
- validation is for rendered JSON, not semantic correctness of the prompt

That is a feature, not a bug. The repo stays small by keeping the contract explicit.

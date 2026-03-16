#Requires AutoHotkey v2.0
#SingleInstance Force

global PromptDir := A_ScriptDir "\prompts"
global PromptFiles := []
global PromptDisplayNames := []
global FilteredNames := []

global PaletteGui := 0
global PaletteHwnd := 0
global InvokingWindowHwnd := 0
global SearchEdit := 0
global TemplateList := 0

; Custom palette — light background, dark text, accent buttons.
; NOTE: Despite the DWM dark-mode chrome applied in ApplyGitHubWindowChrome(),
; the client-area colors below are a light theme. The dark-mode flag only
; affects the title-bar icons and window frame, not the client area.
global GH_BG := "B6BFB8"         ; window background (light sage)
global GH_PANEL := "E4EBE6"      ; elevated surface / listbox background
global GH_INPUT := "E4EBE6"      ; input field background (matches panel)
global GH_BUTTON := "FE4C25"     ; cancel / neutral button (orange-red)
global GH_BORDER := "160048"     ; DWM border color (dark indigo)
global GH_TEXT := "0A241B"       ; primary text (near-black green)
global GH_MUTED := "4A6B5D"      ; secondary / hint text (medium sage)
global GH_SUCCESS := "0FBF3E"    ; primary action button (bright green)

; Register a message-level key handler once.
; This is more reliable than context hotkeys for Edit controls inside a GUI.
OnMessage(0x100, HandlePaletteKeyDown) ; WM_KEYDOWN

; Hotkey: Ctrl+Alt+Space
^!Space::ShowPromptPalette()

ShowPromptPalette() {
    global PromptDir, PromptFiles, PaletteGui, PaletteHwnd, InvokingWindowHwnd, SearchEdit, TemplateList
    global GH_BG, GH_PANEL, GH_INPUT, GH_TEXT, GH_MUTED, GH_BUTTON, GH_SUCCESS

    if !DirExist(PromptDir) {
        MsgBox("Prompt directory not found:`n" PromptDir)
        return
    }

    LoadPromptFiles()

    if (PromptFiles.Length = 0) {
        MsgBox("No .json templates found in:`n" PromptDir)
        return
    }

    try {
        capturedHwnd := WinGetID("A")
    } catch {
        MsgBox("Unable to determine the active window. The prompt palette cannot be opened right now.")
        return
    }
    if (capturedHwnd = PaletteHwnd && InvokingWindowHwnd)
        capturedHwnd := InvokingWindowHwnd

    if IsObject(PaletteGui)
        ClosePalette()

    InvokingWindowHwnd := capturedHwnd

    PaletteGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox", "Prompt Palette")
    PaletteHwnd := PaletteGui.Hwnd
    PaletteGui.BackColor := GH_BG
    PaletteGui.MarginX := 16
    PaletteGui.MarginY := 14

    ; Header
    PaletteGui.SetFont("s11 w600 c" GH_TEXT, "Segoe UI")
    PaletteGui.AddText("xm ym", "Prompt palette")

    PaletteGui.SetFont("s9 w400 c" GH_MUTED, "Segoe UI")
    PaletteGui.AddText("xm y+4", "Search JSON templates and press Enter to paste.")

    ; Search field
    ; NOTE: Background and text color (c) work on Edit controls, but the
    ; control border/frame is drawn by Windows and cannot be styled via AHK.
    PaletteGui.SetFont("s10 w400 c" GH_TEXT, "Segoe UI")
    SearchEdit := PaletteGui.AddEdit(
        "xm y+10 w330 h32 vSearchBox Background" GH_INPUT " c" GH_TEXT
    )

    ; Results
    ; NOTE: ListBox background and text color are authoritative, but the
    ; control border and scrollbar remain native Windows styled.
    TemplateList := PaletteGui.AddListBox(
        "xm y+10 w330 r11 vTemplateList AltSubmit Background" GH_PANEL " c" GH_TEXT
    )

    RefreshTemplateList("")

    SearchEdit.OnEvent("Change", OnSearchChange)
    TemplateList.OnEvent("DoubleClick", OnTemplateActivate)

    ; Footer hint
    PaletteGui.SetFont("s9 w400 c" GH_MUTED, "Segoe UI")
    PaletteGui.AddText("xm y+10", "↑ ↓ move   Enter select   Esc cancel")

    ; Action row — uses Text controls as fake buttons.
    ; Background and text color are fully authoritative on static Text controls.
    PaletteGui.SetFont("s9 w600", "Segoe UI")
    SelectBtn := PaletteGui.AddText(
        "xm y+10 w112 h30 Center +0x200 Background" GH_SUCCESS " cFFFFFF",
        "Select"
    )
    SelectBtn.OnEvent("Click", OnSelectClick)

    CancelBtn := PaletteGui.AddText(
        "x+8 w112 h30 Center +0x200 Background" GH_BUTTON " c" GH_TEXT,
        "Cancel"
    )
    CancelBtn.OnEvent("Click", (*) => ClosePalette())

    PaletteGui.OnEvent("Escape", (*) => ClosePalette())
    PaletteGui.OnEvent("Close", (*) => ClosePalette())

    PaletteGui.Show("AutoSize Center")
    ApplyGitHubWindowChrome(PaletteHwnd)

    WinActivate("ahk_id " PaletteHwnd)
    try WinWaitActive("ahk_id " PaletteHwnd, , 1)

    SearchEdit.Focus()
}

ClosePalette() {
    global PaletteGui, PaletteHwnd, InvokingWindowHwnd, SearchEdit, TemplateList, FilteredNames

    if IsObject(PaletteGui) {
        try PaletteGui.Destroy()
    }

    PaletteGui := 0
    PaletteHwnd := 0
    InvokingWindowHwnd := 0
    SearchEdit := 0
    TemplateList := 0
    FilteredNames := []
}

LoadPromptFiles() {
    global PromptDir, PromptFiles, PromptDisplayNames

    PromptFiles := []
    PromptDisplayNames := []

    Loop Files, PromptDir "\*.json" {
        PromptFiles.Push(A_LoopFileFullPath)
        PromptDisplayNames.Push(RegExReplace(A_LoopFileName, "\.json$"))
    }
}

RefreshTemplateList(filterText) {
    global TemplateList, PromptDisplayNames, FilteredNames

    if !IsObject(TemplateList)
        return

    TemplateList.Delete()
    FilteredNames := []

    filter := Trim(StrLower(filterText))
    addedCount := 0

    for _, name in PromptDisplayNames {
        if (filter = "" || InStr(StrLower(name), filter)) {
            TemplateList.Add([name])
            FilteredNames.Push(name)
            addedCount += 1
        }
    }

    if (addedCount > 0)
        TemplateList.Choose(1)
}

OnSearchChange(ctrl, *) {
    RefreshTemplateList(ctrl.Text)
}

OnTemplateActivate(ctrl, *) {
    ActivateSelectedTemplate()
}

OnSelectClick(*) {
    ActivateSelectedTemplate()
}

MoveSelection(direction) {
    global TemplateList, FilteredNames, SearchEdit

    if !IsObject(TemplateList)
        return

    count := FilteredNames.Length
    if (count = 0)
        return

    currentIndex := TemplateList.Value
    if (currentIndex < 1)
        currentIndex := 1

    newIndex := currentIndex + direction
    if (newIndex < 1)
        newIndex := 1
    else if (newIndex > count)
        newIndex := count

    TemplateList.Choose(newIndex)

    ; Keep the command-palette feel: typing stays in the search box.
    if IsObject(SearchEdit)
        SearchEdit.Focus()
}

ActivateSelectedTemplate() {
    global TemplateList, PromptDir, FilteredNames, PaletteGui

    if !IsObject(TemplateList)
        return

    selectedIndex := TemplateList.Value
    if (selectedIndex < 1 || selectedIndex > FilteredNames.Length)
        return

    selectedName := FilteredNames[selectedIndex]
    templatePath := PromptDir "\" selectedName ".json"

    if !FileExist(templatePath) {
        MsgBox("Template not found:`n" templatePath)
        return
    }

    templateText := FileRead(templatePath, "UTF-8")
    rendered := FillTemplate(templateText)

    if (rendered = "")
        return

    ClosePalette()
    PasteText(rendered, targetHwnd)
}

FillTemplate(templateText) {
    global PaletteGui

    ; Hide palette so the prompt dialogs are visible.
    try PaletteGui.Hide()

    placeholders := ExtractPlaceholders(templateText)
    values := Map()

    for _, key in placeholders {
        result := ShowThemedInputDialog("Enter value for: " key, "Fill Template")

        if (result.Result != "OK") {
            try PaletteGui.Show()
            return ""
        }

        values[key] := JsonEscape(result.Value)
    }

    try PaletteGui.Show()

    return RenderTemplate(templateText, values)
}

RenderTemplate(templateText, values) {
    output := ""
    startPos := 1

    while RegExMatch(templateText, "\{\{([A-Za-z0-9_\-]+)\}\}", &match, startPos) {
        output .= SubStr(templateText, startPos, match.Pos - startPos)

        key := match[1]
        if values.Has(key)
            output .= values[key]
        else
            output .= "{{" key "}}"

        startPos := match.Pos + match.Len
    }

    return output . SubStr(templateText, startPos)
}

ExtractPlaceholders(text) {
    found := []
    seen := Map()
    startPos := 1

    while RegExMatch(text, "\{\{([A-Za-z0-9_\-]+)\}\}", &match, startPos) {
        key := match[1]
        if !seen.Has(key) {
            seen[key] := true
            found.Push(key)
        }
        startPos := match.Pos + match.Len
    }

    return found
}

JsonEscape(value) {
    escaped := ""
    length := StrLen(value)
    index := 1

    while (index <= length) {
        ch := SubStr(value, index, 1)
        code := Ord(ch)

        if (code = 0x0D) {
            if (index < length && Ord(SubStr(value, index + 1, 1)) = 0x0A)
                index += 1
            escaped .= "\n"
        } else if (code = 0x0A) {
            escaped .= "\n"
        } else {
            switch code {
                case 0x08:
                    escaped .= "\b"
                case 0x09:
                    escaped .= "\t"
                case 0x0C:
                    escaped .= "\f"
                default:
                    if (code = 0x5C)
                        escaped .= Chr(0x5C) Chr(0x5C)
                    else if (code = 0x22)
                        escaped .= Chr(0x5C) Chr(0x22)
                    else if (code < 0x20)
                        escaped .= Format("\u{:04x}", code)
                    else
                        escaped .= ch
            }
        }

        index += 1
    }

    return escaped
}

ValidateRenderedJson(text, &errorMessage) {
    state := {Text: text, Length: StrLen(text), Pos: 1}

    try {
        JsonSkipWhitespace(state)
        JsonParseValue(state)
        JsonSkipWhitespace(state)

        if (state.Pos <= state.Length)
            JsonThrowError(state, "Unexpected trailing characters")

        errorMessage := ""
        return true
    } catch err {
        errorMessage := err.Message
        return false
    }
}

JsonSkipWhitespace(state) {
    while (state.Pos <= state.Length) {
        code := Ord(SubStr(state.Text, state.Pos, 1))
        if (code = 0x20 || code = 0x09 || code = 0x0A || code = 0x0D)
            state.Pos += 1
        else
            break
    }
}

JsonParseValue(state) {
    if (state.Pos > state.Length)
        JsonThrowError(state, "Unexpected end of JSON input")

    code := Ord(SubStr(state.Text, state.Pos, 1))
    switch code {
        case 0x7B:
            JsonParseObject(state)
        case 0x5B:
            JsonParseArray(state)
        case 0x22:
            JsonParseString(state)
        case 0x74:
            JsonParseLiteral(state, "true")
        case 0x66:
            JsonParseLiteral(state, "false")
        case 0x6E:
            JsonParseLiteral(state, "null")
        default:
            JsonParseNumber(state)
    }
}

JsonParseObject(state) {
    state.Pos += 1
    JsonSkipWhitespace(state)

    if (state.Pos <= state.Length && SubStr(state.Text, state.Pos, 1) = "}") {
        state.Pos += 1
        return
    }

    loop {
        JsonSkipWhitespace(state)
        if (state.Pos > state.Length || Ord(SubStr(state.Text, state.Pos, 1)) != 0x22)
            JsonThrowError(state, "Expected object key string")

        JsonParseString(state)
        JsonSkipWhitespace(state)

        if (state.Pos > state.Length || SubStr(state.Text, state.Pos, 1) != ":")
            JsonThrowError(state, "Expected ':' after object key")

        state.Pos += 1
        JsonSkipWhitespace(state)
        JsonParseValue(state)
        JsonSkipWhitespace(state)

        if (state.Pos > state.Length)
            JsonThrowError(state, "Unterminated object")

        ch := SubStr(state.Text, state.Pos, 1)
        if (ch = "}") {
            state.Pos += 1
            return
        }
        if (ch != ",")
            JsonThrowError(state, "Expected ',' or '}' in object")

        state.Pos += 1
    }
}

JsonParseArray(state) {
    state.Pos += 1
    JsonSkipWhitespace(state)

    if (state.Pos <= state.Length && SubStr(state.Text, state.Pos, 1) = "]") {
        state.Pos += 1
        return
    }

    loop {
        JsonSkipWhitespace(state)
        JsonParseValue(state)
        JsonSkipWhitespace(state)

        if (state.Pos > state.Length)
            JsonThrowError(state, "Unterminated array")

        ch := SubStr(state.Text, state.Pos, 1)
        if (ch = "]") {
            state.Pos += 1
            return
        }
        if (ch != ",")
            JsonThrowError(state, "Expected ',' or ']' in array")

        state.Pos += 1
    }
}

JsonParseString(state) {
    if (state.Pos > state.Length || Ord(SubStr(state.Text, state.Pos, 1)) != 0x22)
        JsonThrowError(state, "Expected string")

    state.Pos += 1

    while (state.Pos <= state.Length) {
        ch := SubStr(state.Text, state.Pos, 1)
        code := Ord(ch)

        if (code = 0x22) {
            state.Pos += 1
            return
        }

        if (code < 0x20)
            JsonThrowError(state, "Unescaped control character in string")

        if (code = 0x5C) {
            state.Pos += 1
            if (state.Pos > state.Length)
                JsonThrowError(state, "Incomplete escape sequence")

            escCode := Ord(SubStr(state.Text, state.Pos, 1))
            if (escCode = 0x22 || escCode = 0x5C || escCode = 0x2F || escCode = 0x62
                || escCode = 0x66 || escCode = 0x6E || escCode = 0x72 || escCode = 0x74) {
                state.Pos += 1
                continue
            }

            if (escCode = 0x75) {
                if (state.Pos + 4 > state.Length)
                    JsonThrowError(state, "Incomplete unicode escape")

                hex := SubStr(state.Text, state.Pos + 1, 4)
                if !RegExMatch(hex, "^[0-9A-Fa-f]{4}$")
                    JsonThrowError(state, "Invalid unicode escape")

                state.Pos += 5
                continue
            }

            JsonThrowError(state, "Invalid escape sequence")
        }

        state.Pos += 1
    }

    JsonThrowError(state, "Unterminated string")
}

JsonParseNumber(state) {
    remaining := SubStr(state.Text, state.Pos)
    if !RegExMatch(remaining, "^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?", &match)
        JsonThrowError(state, "Expected JSON value")

    state.Pos += StrLen(match[0])
}

JsonParseLiteral(state, literal) {
    if (SubStr(state.Text, state.Pos, StrLen(literal)) != literal)
        JsonThrowError(state, "Expected '" literal "'")

    state.Pos += StrLen(literal)
}

JsonThrowError(state, message) {
    line := 1
    column := 1
    index := 1

    while (index < state.Pos) {
        code := Ord(SubStr(state.Text, index, 1))
        if (code = 0x0D) {
            if (index < state.Pos - 1 && Ord(SubStr(state.Text, index + 1, 1)) = 0x0A)
                index += 1
            line += 1
            column := 1
        } else if (code = 0x0A) {
            line += 1
            column := 1
        } else {
            column += 1
        }
        index += 1
    }

    excerptStart := Max(1, state.Pos - 20)
    excerpt := SubStr(state.Text, excerptStart, 40)
    excerpt := StrReplace(excerpt, "`r", "\r")
    excerpt := StrReplace(excerpt, "`n", "\n")

    throw Error(
        message
        " (line " line ", column " column ", position " state.Pos ").`n"
        "Near: " excerpt
    )
}

PasteText(text, targetHwnd) {
    clipSaved := ClipboardAll()
    A_Clipboard := text

    try {
        if !ClipWait(1) {
            MsgBox("Clipboard update failed.")
            return
        }

        if !targetHwnd || !WinExist("ahk_id " targetHwnd) {
            MsgBox("Paste canceled because the original target window is no longer available.")
            return
        }

        try WinActivate("ahk_id " targetHwnd)
        try WinWaitActive("ahk_id " targetHwnd, , 1)

        wasReactivated := false
        try {
            wasReactivated := (WinGetID("A") == targetHwnd)
        } catch {
            ; Treat any failure to query the active window as inability to reactivate.
            wasReactivated := false
        }

        if !wasReactivated {
            MsgBox("Paste canceled because the original target window could not be reactivated.")
            return
        }

        Send("^v")
        Sleep(300)  ; heuristic: allow target app to read clipboard before restoring.
                   ; 300ms handles most apps; very slow targets (Electron, etc.) may
                   ; need more. A timer-based restore would be more robust.
    } finally {
        A_Clipboard := clipSaved
    }
}

HandlePaletteKeyDown(wParam, lParam, msg, hwnd) {
    global PaletteHwnd, PaletteGui

    ; No palette, no interception.
    if !PaletteHwnd || !IsObject(PaletteGui)
        return

    ; Only intercept while the palette window is actually active.
    try activeHwnd := WinGetID("A")
    catch
        return

    if (activeHwnd != PaletteHwnd)
        return

    ; Only handle messages from controls inside our palette.
    rootHwnd := DllCall("GetAncestor", "ptr", hwnd, "uint", 2, "ptr") ; GA_ROOT = 2
    if (rootHwnd != PaletteHwnd)
        return

    ; VK_UP = 0x26, VK_DOWN = 0x28, VK_RETURN = 0x0D
    switch wParam {
        case 0x26:
            MoveSelection(-1)
            return 0
        case 0x28:
            MoveSelection(1)
            return 0
        case 0x0D:
            ActivateSelectedTemplate()
            return 0
    }
}

ShowThemedInputDialog(prompt, title := "Input") {
    global GH_BG, GH_INPUT, GH_TEXT, GH_BUTTON, GH_SUCCESS

    dialogResult := {Result: "Cancel", Value: ""}

    dlg := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox", title)
    dlg.BackColor := GH_BG
    dlg.MarginX := 16
    dlg.MarginY := 14

    dlg.SetFont("s10 w400 c" GH_TEXT, "Segoe UI")
    dlg.AddText("xm ym w300", prompt)

    dlg.SetFont("s10 w400 c" GH_TEXT, "Segoe UI")
    inputCtrl := dlg.AddEdit(
        "xm y+10 w300 h32 vInputValue Background" GH_INPUT " c" GH_TEXT
    )

    dlg.SetFont("s9 w600", "Segoe UI")
    okBtn := dlg.AddText(
        "xm y+12 w112 h30 Center +0x200 Background" GH_SUCCESS " cFFFFFF",
        "OK"
    )
    cancelBtn := dlg.AddText(
        "x+8 w112 h30 Center +0x200 Background" GH_BUTTON " c" GH_TEXT,
        "Cancel"
    )

    okBtn.OnEvent("Click", (*) => _SubmitDialog())
    cancelBtn.OnEvent("Click", (*) => _CancelDialog())
    dlg.OnEvent("Escape", (*) => _CancelDialog())
    dlg.OnEvent("Close", (*) => _CancelDialog())

    ; Submit on Enter from within the edit control.
    OnMessage(0x100, _DialogKeyHandler, 1)  ; WM_KEYDOWN

    dlg.Show("AutoSize Center")
    ApplyGitHubWindowChrome(dlg.Hwnd)
    inputCtrl.Focus()

    WinWaitClose("ahk_id " dlg.Hwnd)
    OnMessage(0x100, _DialogKeyHandler, 0)  ; remove dialog handler
    OnMessage(0x100, HandlePaletteKeyDown)  ; ensure palette handler is restored
    return dialogResult

    _SubmitDialog() {
        dialogResult.Result := "OK"
        dialogResult.Value := inputCtrl.Text
        dlg.Destroy()
    }

    _CancelDialog() {
        dialogResult.Result := "Cancel"
        dialogResult.Value := ""
        dlg.Destroy()
    }

    _DialogKeyHandler(wParam, lParam, msg, hwnd) {
        try activeHwnd := WinGetID("A")
        catch
            return
        if (activeHwnd != dlg.Hwnd) {
            rootHwnd := DllCall("GetAncestor", "ptr", hwnd, "uint", 2, "ptr")
            if (rootHwnd != dlg.Hwnd)
                return
        }
        if (wParam = 0x0D) {   ; VK_RETURN
            _SubmitDialog()
            return 0
        }
    }
}

ApplyGitHubWindowChrome(hwnd) {
    global GH_BG, GH_BORDER, GH_TEXT

    ; Win11-only polish (build 22000+). Silently no-ops on older Windows.
    ;
    ; What these actually control:
    ;   IMMERSIVE_DARK_MODE  → title-bar icon color & close/min/max glyphs
    ;   WINDOW_CORNER_PREF   → rounded vs square frame corners
    ;   BORDER_COLOR         → 1px window-frame border
    ;   CAPTION_COLOR        → title-bar fill behind the caption text
    ;   TEXT_COLOR            → title-bar caption text
    ;   SYSTEMBACKDROP_TYPE  → Mica/Acrylic backdrop (only visible when
    ;                          the window has transparency; opaque BackColor
    ;                          fully occludes it, so this is cosmetic-only here)
    ;
    ; None of these affect the client area, Edit, or ListBox controls.
    static DWMWA_USE_IMMERSIVE_DARK_MODE := 20
    static DWMWA_WINDOW_CORNER_PREFERENCE := 33
    static DWMWA_BORDER_COLOR := 34
    static DWMWA_CAPTION_COLOR := 35
    static DWMWA_TEXT_COLOR := 36
    static DWMWA_SYSTEMBACKDROP_TYPE := 38

    static DWMWCP_ROUND := 2
    static DWMSBT_MAINWINDOW := 2

    try SetDwmWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, 1)
    try SetDwmWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, DWMWCP_ROUND)
    try SetDwmWindowAttribute(hwnd, DWMWA_BORDER_COLOR, ColorRef(GH_BORDER))
    try SetDwmWindowAttribute(hwnd, DWMWA_CAPTION_COLOR, ColorRef(GH_BG))
    try SetDwmWindowAttribute(hwnd, DWMWA_TEXT_COLOR, ColorRef(GH_TEXT))
    try SetDwmWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, DWMSBT_MAINWINDOW)
}

SetDwmWindowAttribute(hwnd, attribute, value) {
    buffer := Buffer(4, 0)
    NumPut("int", value, buffer)

    return DllCall(
        "dwmapi\DwmSetWindowAttribute",
        "ptr", hwnd,
        "int", attribute,
        "ptr", buffer,
        "int", 4,
        "int"
    )
}

ColorRef(rgbHex) {
    rgb := "0x" RegExReplace(rgbHex, "^#")
    rgb += 0

    r := (rgb >> 16) & 0xFF
    g := (rgb >> 8) & 0xFF
    b := rgb & 0xFF

    ; COLORREF is 0x00BBGGRR
    return (b << 16) | (g << 8) | r
}

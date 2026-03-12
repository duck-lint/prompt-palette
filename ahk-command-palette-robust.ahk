#Requires AutoHotkey v2.0
#SingleInstance Force

global PromptDir := A_ScriptDir "\prompts"
global PromptFiles := []
global PromptDisplayNames := []
global FilteredNames := []
global PaletteGui := ""
global PaletteHwnd := 0
global SearchEdit := ""
global TemplateList := ""

; Register a message-level key handler once.
; This is more reliable than context hotkeys for Edit controls inside a GUI.
OnMessage(0x100, HandlePaletteKeyDown) ; WM_KEYDOWN

; Hotkey: Ctrl+Alt+Space
^!Space::ShowPromptPalette()

ShowPromptPalette() {
    global PaletteGui, PaletteHwnd, SearchEdit, TemplateList

    LoadPromptFiles()

    if !DirExist(PromptDir) {
        MsgBox("Prompt directory not found:`n" PromptDir)
        return
    }

    if PromptFiles.Length = 0 {
        MsgBox("No .json templates found in:`n" PromptDir)
        return
    }

    if IsObject(PaletteGui)
        ClosePalette()

    PaletteGui := Gui("+AlwaysOnTop -MaximizeBox -MinimizeBox", "Prompt Palette")
    PaletteHwnd := PaletteGui.Hwnd
    PaletteGui.SetFont("s10", "Segoe UI")

    PaletteGui.AddText("xm ym", "Search")
    SearchEdit := PaletteGui.AddEdit("xm w560 vSearchBox")
    TemplateList := PaletteGui.AddListBox("xm w560 r12 vTemplateList AltSubmit")

    RefreshTemplateList("")

    SearchEdit.OnEvent("Change", OnSearchChange)
    TemplateList.OnEvent("DoubleClick", OnTemplateActivate)

    SelectBtn := PaletteGui.AddButton("xm w120 Default", "Select")
    SelectBtn.OnEvent("Click", OnSelectClick)
    CancelBtn := PaletteGui.AddButton("x+10 w120", "Cancel")
    CancelBtn.OnEvent("Click", (*) => ClosePalette())

    PaletteGui.OnEvent("Escape", (*) => ClosePalette())
    PaletteGui.OnEvent("Close", (*) => ClosePalette())

    PaletteGui.Show("AutoSize Center")
    WinActivate("ahk_id " PaletteHwnd)
    try WinWaitActive("ahk_id " PaletteHwnd, , 1)
    SearchEdit.Focus()
}

ClosePalette() {
    global PaletteGui, PaletteHwnd, SearchEdit, TemplateList, FilteredNames

    if IsObject(PaletteGui) {
        try PaletteGui.Destroy()
    }

    PaletteGui := ""
    PaletteHwnd := 0
    SearchEdit := ""
    TemplateList := ""
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
    global TemplateList, PromptDir, FilteredNames

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
    PasteText(rendered)
}

FillTemplate(templateText) {
    global PaletteGui

    ; hide palette so prompts are visible
    try PaletteGui.Hide()

    placeholders := ExtractPlaceholders(templateText)
    values := Map()

    for _, key in placeholders {
        result := InputBox("Enter value for: " key, "Fill Template")

        if (result.Result != "OK") {
            try PaletteGui.Show()
            return ""
        }

        values[key] := JsonEscape(result.Value)
    }

    ; restore palette if needed
    try PaletteGui.Show()

    output := templateText
    for key, value in values {
        output := StrReplace(output, "{{" key "}}", value)
    }

    return output
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
    value := StrReplace(value, "\", "\\")
    value := StrReplace(value, "`r`n", "\n")
    value := StrReplace(value, "`n", "\n")
    value := StrReplace(value, "`r", "\n")
    value := StrReplace(value, '"', '\"')
    value := StrReplace(value, "`t", "\t")
    return value
}

PasteText(text) {
    originalClipboard := A_Clipboard
    A_Clipboard := text

    if !ClipWait(1) {
        MsgBox("Clipboard update failed.")
        return
    }

    Send("^v")
    Sleep(100)
    A_Clipboard := originalClipboard
}

HandlePaletteKeyDown(wParam, lParam, msg, hwnd) {
    global PaletteHwnd, PaletteGui, SearchEdit, TemplateList

    ; No palette, no interception.
    if !PaletteHwnd || !IsObject(PaletteGui)
        return

    ; Only intercept while the palette window is actually active.
    try activeHwnd := WinGetID("A")
    catch
        return

    if (activeHwnd != PaletteHwnd)
        return

    ; Determine whether the message came from a control inside our palette.
    ; This is stricter and more reliable than assuming active window alone.
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

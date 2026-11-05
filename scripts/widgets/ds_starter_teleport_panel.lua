-- Client-side teleport beacon panel (independent of the weapon).
-- The actual beacon data lives in the player's ds_starter_teleport component.
-- This widget only talks to the DSStarter* callbacks defined in modmain.

local Widget = GLOBAL.require("widgets/widget")
local Image = GLOBAL.require("widgets/image")
local Text = GLOBAL.require("widgets/text")
local TextEdit = GLOBAL.require("widgets/textedit")
local ImageButton = GLOBAL.require("widgets/imagebutton")

local L = GLOBAL.DSStarterL or function(en) return en end

-- Single-player uses GetPlayer() instead of a ThePlayer global.
local function GetThePlayer()
    if GLOBAL.GetPlayer ~= nil then
        return GLOBAL.GetPlayer()
    end
    return GLOBAL.rawget(GLOBAL, "ThePlayer")
end

local MAX_ROWS = 8
local ROW_START_Y = 170
local ROW_STEP = 46
local PANEL_WIDTH = 860
local PANEL_HEIGHT = 640

-- UTF-8 safe helpers: truncating by bytes can split a Chinese character
-- and show garbage in the list.
local function Utf8Length(str)
    local count = 0
    local i = 1
    while i <= #str do
        local b = str:byte(i)
        local len = 1
        if b >= 240 then
            len = 4
        elseif b >= 224 then
            len = 3
        elseif b >= 192 then
            len = 2
        end
        i = i + len
        count = count + 1
    end
    return count
end

local function Utf8Sub(str, max_chars)
    local count = 0
    local i = 1
    while i <= #str and count < max_chars do
        local b = str:byte(i)
        local len = 1
        if b >= 240 then
            len = 4
        elseif b >= 224 then
            len = 3
        elseif b >= 192 then
            len = 2
        end
        i = i + len
        count = count + 1
    end
    return str:sub(1, i - 1)
end

local function ShortenName(name)
    if Utf8Length(name) > 8 then
        return Utf8Sub(name, 8) .. "..."
    end
    return name
end

local function StyleButton(button)
    -- The normal button texture is dark, so use white text until the
    -- highlighted (lighter) texture takes over.
    button:SetTextColour(1, 1, 1, 1)
    button:SetTextFocusColour(0, 0, 0, 1)
    return button
end

local function MakeButton(text, x, y, fn, scale)
    local button = ImageButton(
        "images/ui.xml",
        "button_small.tex",
        "button_small_over.tex",
        "button_small_disabled.tex"
    )
    button:SetText(text)
    StyleButton(button)
    button:SetTextSize(32)
    button:SetScale(scale or 0.85, scale or 0.85, 1)
    button:SetPosition(x, y)
    button:SetOnClick(fn)
    return button
end

-- Long labels such as "Add Beacon" do not fit the small button texture,
-- so they get the wide variant instead of shrinking the text again.
local function MakeLongButton(text, x, y, fn, scale)
    local button = ImageButton(
        "images/ui.xml",
        "button_long.tex",
        "button_long_over.tex",
        "button_long_disabled.tex"
    )
    button:SetText(text)
    StyleButton(button)
    button:SetTextSize(32)
    button:SetScale(scale or 0.9, scale or 0.9, 1)
    button:SetPosition(x, y)
    button:SetOnClick(fn)
    return button
end

local function AddPanelBackground(self, width, height)
    local border = self:AddChild(Image("images/global.xml", "square.tex"))
    border:SetSize(width, height)
    border:SetTint(0.24, 0.17, 0.11, 0.96)

    local inner = self:AddChild(Image("images/global.xml", "square.tex"))
    inner:SetSize(width - 14, height - 14)
    inner:SetTint(0.055, 0.045, 0.035, 0.97)

    return inner
end

---------------------------------------------------------------------------
-- Rename dialog
---------------------------------------------------------------------------
local RenameDialog = Class(Widget, function(self, player, index, current_name)
    Widget._ctor(self, "RenameBeaconDialog")
    self:SetHAnchor(GLOBAL.ANCHOR_MIDDLE)
    self:SetVAnchor(GLOBAL.ANCHOR_MIDDLE)

    self.player = player
    self.index = index
    self.closed = false

    AddPanelBackground(self, 520, 280)

    local accent = self:AddChild(Image("images/global.xml", "square.tex"))
    accent:SetSize(490, 3)
    accent:SetPosition(0, 124)
    accent:SetTint(0.72, 0.55, 0.25, 1)

    self.title = self:AddChild(Text(
        GLOBAL.BUTTONFONT,
        32,
        L("Rename Beacon", "重命名信标")
    ))
    self.title:SetPosition(0, 96)
    self.title:SetColour(1, 0.88, 0.45, 1)

    self.edit_bg = self:AddChild(Image("images/global.xml", "square.tex"))
    self.edit_bg:SetSize(440, 56)
    self.edit_bg:SetPosition(0, 42)
    self.edit_bg:SetTint(0.12, 0.11, 0.09, 1)

    self.edit = self:AddChild(TextEdit(
        GLOBAL.BUTTONFONT,
        28,
        current_name or ""
    ))
    self.edit:SetPosition(0, 42)
    self.edit:SetRegionSize(416, 50)
    self.edit:SetHAlign(GLOBAL.ANCHOR_LEFT)
    self.edit:SetColour(1, 1, 1, 1)
    self.edit.edit_text_color = { 1, 1, 1, 1 }
    self.edit.idle_text_color = { 1, 1, 1, 1 }
    self.edit:SetTextLengthLimit(96)
    if self.edit.SetEditCursorColour ~= nil then
        self.edit:SetEditCursorColour(1, 1, 1, 1)
    end
    if self.edit.SetHelpTextEdit ~= nil then
        self.edit:SetHelpTextEdit("")
    end
    self.edit.OnTextEntered = function()
        self:Confirm()
    end

    local old_onraw = self.edit.OnRawKey
    self.edit.OnRawKey = function(edit, key, down)
        if down and key == GLOBAL.KEY_ESCAPE then
            self:Close()
            return true
        end
        return old_onraw(edit, key, down)
    end

    self.hint = self:AddChild(Text(
        GLOBAL.BUTTONFONT,
        20,
        L("Enter to confirm, Esc to cancel", "Enter 确认，Esc 取消")
    ))
    self.hint:SetPosition(0, 0)
    self.hint:SetColour(0.78, 0.78, 0.78, 1)

    self.cancel = self:AddChild(MakeButton(
        L("Cancel", "取消"),
        -105,
        -70,
        function()
            self:Close()
        end,
        1
    ))
    self.cancel:SetTextSize(28)

    self.ok = self:AddChild(MakeButton(
        L("OK", "确定"),
        105,
        -70,
        function()
            self:Confirm()
        end,
        1
    ))
    self.ok:SetTextSize(28)

    self:SetPosition(0, 20)
    player.HUD:AddChild(self)
    GLOBAL.DS_STARTER_RENAME_DIALOG = self

    self.uses_text_processor =
        GLOBAL.TheFrontEnd.SetForceProcessTextInput ~= nil

    if self.uses_text_processor then
        if self.edit.SetForceEdit ~= nil then
            self.edit:SetForceEdit(true)
        end
        self.edit:SetEditing(true)
    else
        self.edit:SetEditing(true)

        local pc = player.components.playercontroller
        self.pc_was_enabled = pc ~= nil
            and pc.IsEnabled ~= nil
            and pc:IsEnabled()
        if pc ~= nil and pc.Enable ~= nil then
            pc:Enable(false)
        end

        self.death_listener = function()
            self:Close()
        end
        player:ListenForEvent("death", self.death_listener)
    end

    self.death_check = player:DoPeriodicTask(0.5, function()
        if player:HasTag("playerghost") or player:HasTag("isdead") then
            self:Close()
        end
    end)
end)

function RenameDialog:Confirm()
    if self.closed then
        return
    end

    local name = ""
    if self.edit.GetLineEditString ~= nil then
        name = self.edit:GetLineEditString() or ""
    else
        name = self.edit:GetString() or ""
    end

    GLOBAL.DSStarterRenameBeacon(self.index, name)
    GLOBAL.DSStarterRequestBeacons()
    self:Close()
end

function RenameDialog:Close()
    if self.closed then
        return
    end
    self.closed = true

    if self.death_check ~= nil then
        self.death_check:Cancel()
        self.death_check = nil
    end

    if self.edit ~= nil then
        self.edit:SetEditing(false)
        if GLOBAL.TheFrontEnd.SetForceProcessTextInput ~= nil then
            GLOBAL.TheFrontEnd:SetForceProcessTextInput(false, self.edit)
        end
    end

    if GLOBAL.DS_STARTER_RENAME_DIALOG == self then
        GLOBAL.DS_STARTER_RENAME_DIALOG = false
    end

    if not self.uses_text_processor then
        if self.death_listener ~= nil then
            self.player:RemoveEventCallback("death", self.death_listener)
            self.death_listener = nil
        end

        local pc = self.player ~= nil
            and self.player.components.playercontroller
        if pc ~= nil and pc.Enable ~= nil
            and self.pc_was_enabled
            and not self.player:HasTag("playerghost")
        then
            pc:Enable(true)
        end
    end

    self:Kill()
end

---------------------------------------------------------------------------
-- Main panel
---------------------------------------------------------------------------
local TeleportPanel = Class(Widget, function(self, player)
    Widget._ctor(self, "TeleportBeaconPanel")
    self:SetHAnchor(GLOBAL.ANCHOR_MIDDLE)
    self:SetVAnchor(GLOBAL.ANCHOR_MIDDLE)

    self.player = player
    self.isopen = false
    self.page = 1

    AddPanelBackground(self, PANEL_WIDTH, PANEL_HEIGHT)

    local accent = self:AddChild(Image("images/global.xml", "square.tex"))
    accent:SetSize(PANEL_WIDTH - 24, 3)
    accent:SetPosition(0, 298)
    accent:SetTint(0.72, 0.55, 0.25, 1)

    self.title = self:AddChild(Text(
        GLOBAL.BUTTONFONT,
        42,
        L("Teleport Beacons", "传送信标")
    ))
    self.title:SetPosition(0, 266)
    self.title:SetColour(1, 0.88, 0.45, 1)

    self.subtitle = self:AddChild(Text(
        GLOBAL.BUTTONFONT,
        22,
        L(
            "Shift + Right Click to open · unlimited beacons",
            "Shift + 右键打开 · 信标数量不限"
        )
    ))
    self.subtitle:SetPosition(0, 226)
    self.subtitle:SetColour(0.82, 0.82, 0.82, 1)

    self.close = self:AddChild(MakeButton(
        L("Close", "关闭"),
        370,
        266,
        function()
            self:Close()
        end,
        0.9
    ))

    local header = self:AddChild(Image("images/global.xml", "square.tex"))
    header:SetSize(PANEL_WIDTH - 36, 1)
    header:SetPosition(0, 200)
    header:SetTint(0.38, 0.30, 0.20, 0.9)

    self.rows = {}
    for i = 1, MAX_ROWS do
        local row = {}
        local y = ROW_START_Y - (i - 1) * ROW_STEP

        row.bg = self:AddChild(Image("images/global.xml", "square.tex"))
        row.bg:SetSize(PANEL_WIDTH - 40, ROW_STEP - 6)
        row.bg:SetPosition(0, y)
        if i % 2 == 1 then
            row.bg:SetTint(0.10, 0.09, 0.075, 0.55)
        else
            row.bg:SetTint(0.075, 0.065, 0.055, 0.45)
        end

        row.label = self:AddChild(Text(GLOBAL.BUTTONFONT, 28, ""))
        row.label:SetPosition(-185, y)
        row.label:SetRegionSize(380, 40)
        row.label:SetHAlign(GLOBAL.ANCHOR_LEFT)
        row.label:SetColour(0.92, 0.92, 0.92, 1)

        row.rename = self:AddChild(MakeButton(
            L("Name", "改名"),
            70,
            y,
            function()
                if row.beacon_index ~= nil then
                    GLOBAL.DSStarterOpenRenameDialog(row.beacon_index)
                end
            end,
            0.9
        ))

        row.teleport = self:AddChild(MakeButton(
            L("Go", "传送"),
            175,
            y,
            function()
                if row.beacon_index ~= nil then
                    GLOBAL.DSStarterTeleportBeacon(row.beacon_index)
                    self:Close()
                end
            end,
            0.9
        ))

        row.remove = self:AddChild(MakeButton(
            L("Del", "删除"),
            280,
            y,
            function()
                if row.beacon_index ~= nil then
                    GLOBAL.DSStarterRemoveBeacon(row.beacon_index)
                    GLOBAL.DSStarterRequestBeacons()
                end
            end,
            0.9
        ))

        row.up = self:AddChild(MakeButton(
            L("Up", "上"),
            378,
            y + 11,
            function()
                if row.beacon_index ~= nil then
                    GLOBAL.DSStarterMoveBeacon(row.beacon_index, -1)
                    GLOBAL.DSStarterRequestBeacons()
                end
            end,
            0.5
        ))
        row.up:SetTextSize(42)

        row.down = self:AddChild(MakeButton(
            L("Down", "下"),
            378,
            y - 11,
            function()
                if row.beacon_index ~= nil then
                    GLOBAL.DSStarterMoveBeacon(row.beacon_index, 1)
                    GLOBAL.DSStarterRequestBeacons()
                end
            end,
            0.5
        ))
        row.down:SetTextSize(42)

        self.rows[i] = row
    end

    self.add = self:AddChild(MakeLongButton(
        L("Add Beacon", "添加信标"),
        0,
        -207,
        function()
            GLOBAL.DSStarterAddBeacon()
            self.page = 99999
            GLOBAL.DSStarterRequestBeacons()
        end,
        0.8
    ))
    self.add:SetTextSize(34)

    self.add_hint = self:AddChild(Text(
        GLOBAL.BUTTONFONT,
        20,
        L("Adds at your current position", "在当前位置添加")
    ))
    self.add_hint:SetPosition(0, -252)
    self.add_hint:SetColour(0.78, 0.78, 0.78, 1)

    self.prev = self:AddChild(MakeButton(
        L("Prev", "上一页"),
        -150,
        -290,
        function()
            self:SetPage(self.page - 1)
        end,
        0.9
    ))

    self.next = self:AddChild(MakeButton(
        L("Next", "下一页"),
        150,
        -290,
        function()
            self:SetPage(self.page + 1)
        end,
        0.9
    ))

    self.page_text = self:AddChild(Text(
        GLOBAL.BUTTONFONT,
        28,
        ""
    ))
    self.page_text:SetPosition(0, -290)
    self.page_text:SetColour(0.9, 0.9, 0.9, 1)

    self:Refresh()
    self:Hide()
end)

function TeleportPanel:SetPage(page)
    self.page = math.max(1, page or 1)
    self:Refresh()
end

function TeleportPanel:Refresh()
    local beacons = GLOBAL.DSStarterGetBeacons() or {}
    local count = #beacons
    local page_count = math.max(1, math.ceil(count / MAX_ROWS))

    if self.page > page_count then
        self.page = page_count
    end
    if self.page < 1 then
        self.page = 1
    end

    local start_index = (self.page - 1) * MAX_ROWS

    for i = 1, MAX_ROWS do
        local row = self.rows[i]
        local absolute_index = start_index + i
        local beacon = beacons[absolute_index]
        if beacon ~= nil then
            row.beacon_index = absolute_index

            local display_name = beacon.name or ""
            if display_name == "" then
                display_name = string.format(
                    L("Beacon %d", "信标 %d"),
                    absolute_index
                )
            else
                display_name = ShortenName(display_name)
            end

            row.label:SetString(string.format(
                "%s  (%.0f, %.0f)",
                display_name,
                beacon.x,
                beacon.z
            ))
            row.bg:Show()
            row.label:Show()
            row.rename:Show()
            row.teleport:Show()
            row.remove:Show()
            row.up:Show()
            row.down:Show()
            if absolute_index <= 1 then
                row.up:Hide()
            end
            if absolute_index >= count then
                row.down:Hide()
            end
        else
            row.beacon_index = nil
            row.bg:Hide()
            row.label:Hide()
            row.rename:Hide()
            row.teleport:Hide()
            row.remove:Hide()
            row.up:Hide()
            row.down:Hide()
        end
    end

    if self.page_text ~= nil then
        self.page_text:SetString(string.format(
            L("Page %d/%d", "第 %d/%d 页"),
            self.page,
            page_count
        ))
    end
end

function TeleportPanel:Open()
    self.isopen = true
    self:Show()
    GLOBAL.DSStarterRequestBeacons()
    self:Refresh()
end

function TeleportPanel:Close()
    self.isopen = false
    self:Hide()
end

function TeleportPanel:Toggle()
    if self.isopen then
        self:Close()
    else
        self:Open()
    end
end

GLOBAL.DSStarterCreateTeleportPanel = function(player)
    return TeleportPanel(player)
end

GLOBAL.DSStarterOpenRenameDialog = function(index)
    local player = GetThePlayer()
    if player == nil or player.HUD == nil then
        return
    end

    local existing = GLOBAL.DS_STARTER_RENAME_DIALOG
    if existing ~= nil and existing ~= false then
        existing:Close()
    end

    local beacons = GLOBAL.DSStarterGetBeacons() or {}
    local beacon = beacons[index]
    local current_name = ""
    if beacon ~= nil then
        current_name = beacon.name or ""
        if current_name == "" then
            current_name = string.format(
                L("Beacon %d", "信标 %d"),
                index
            )
        end
    end

    RenameDialog(player, index, current_name)
end

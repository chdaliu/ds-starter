-- Small status panel for the work queue.  It reads the player's
-- ds_starter_workqueue component and hides itself when the queue is idle.

local Widget = GLOBAL.require("widgets/widget")
local Text = GLOBAL.require("widgets/text")
local Image = GLOBAL.require("widgets/image")

local L = GLOBAL.DSStarterL or function(en, zh)
    return en
end

local WorkQueueHUD = Class(Widget, function(self, player)
    Widget._ctor(self, "WorkQueueHUD")

    self.player = player
    -- Middle/top anchoring is unambiguous in the single-player HUD.
    -- -450 puts the panel near the top-left without clipping its left edge.
    self:SetHAnchor(GLOBAL.ANCHOR_MIDDLE)
    self:SetVAnchor(GLOBAL.ANCHOR_TOP)
    self:SetPosition(-450, -140)
    self:SetScale(0.9, 0.9, 1)
    self:SetClickable(false)

    self.bg = self:AddChild(Image("images/global.xml", "square.tex"))
    self.bg:SetSize(330, 96)
    self.bg:SetTint(0.03, 0.025, 0.02, 0.62)
    self.bg:SetClickable(false)

    self.accent = self:AddChild(Image("images/global.xml", "square.tex"))
    self.accent:SetSize(330, 2)
    self.accent:SetPosition(0, 46)
    self.accent:SetTint(0.72, 0.55, 0.25, 1)
    self.accent:SetClickable(false)

    self.title = self:AddChild(Text(GLOBAL.BUTTONFONT, 19, ""))
    self.title:SetPosition(0, 28)
    self.title:SetHAlign(GLOBAL.ANCHOR_LEFT)
    self.title:SetRegionSize(300, 26)
    self.title:SetColour(1, 0.88, 0.45, 1)

    self.current = self:AddChild(Text(GLOBAL.BUTTONFONT, 18, ""))
    self.current:SetPosition(0, 2)
    self.current:SetHAlign(GLOBAL.ANCHOR_LEFT)
    self.current:SetRegionSize(300, 24)
    self.current:SetColour(0.95, 0.95, 0.95, 1)

    self.next = self:AddChild(Text(GLOBAL.BUTTONFONT, 16, ""))
    self.next:SetPosition(0, -22)
    self.next:SetHAlign(GLOBAL.ANCHOR_LEFT)
    self.next:SetRegionSize(300, 22)
    self.next:SetColour(0.75, 0.75, 0.75, 1)

    self.title:SetClickable(false)
    self.current:SetClickable(false)
    self.next:SetClickable(false)

    self:StartUpdating()
    self:Hide()
end)

function WorkQueueHUD:OnUpdate(dt)
    if self.player == nil or not self.player:IsValid() then
        self:Hide()
        return
    end
    local queue = self.player ~= nil
        and self.player.components.ds_starter_workqueue
        or nil
    if queue == nil then
        self:Hide()
        return
    end

    local status = queue:GetStatus()
    if not status.running then
        self:Hide()
        return
    end

    self:Show()
    local total = status.total or 0
    self.title:SetString(string.format(
        L("Work Queue  (%d)", "工作队列  (%d)"),
        total
    ))
    self.current:SetString(string.format(
        L("Now: %s", "当前：%s"),
        status.current or L("Waiting", "等待")
    ))

    local next_text = L("Next: ", "后续：")
    local parts = {}
    for i = 2, math.min(#status.lines, 4) do
        parts[#parts + 1] = status.lines[i]
    end
    if #parts == 0 then
        next_text = next_text .. L("none", "无")
    else
        next_text = next_text .. table.concat(parts, ", ")
    end
    self.next:SetString(next_text)
end

GLOBAL.DSStarterCreateWorkQueueHUD = function(player)
    return WorkQueueHUD(player)
end

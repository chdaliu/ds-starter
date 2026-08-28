-- 8x8 container UI for the Sacrificial Altar.

local InvSlot = GLOBAL.require("widgets/invslot")
local Image = GLOBAL.require("widgets/image")
local Text = GLOBAL.require("widgets/text")
local ItemTile = GLOBAL.require("widgets/itemtile")

local PREFAB = "ds_starter_altar"
local SLOT_COUNT = 64
local COLS = 8
local ROWS = 8
local SPACING = 48
local SLOT_SCALE = 0.7

local function IsChinese()
    local code = nil
    if GLOBAL.LOC ~= nil and GLOBAL.LOC.GetLocaleCode ~= nil then
        local ok, value = GLOBAL.pcall(GLOBAL.LOC.GetLocaleCode)
        if ok then
            code = value
        end
    end
    if code == nil and GLOBAL.LanguageTranslator ~= nil then
        code = GLOBAL.LanguageTranslator.defaultlang
    end
    if code == nil then
        return false
    end
    code = string.lower(tostring(code))
    return code == "zh" or code == "zhr" or code == "zht"
        or code == "ch" or code == "chs"
        or string.sub(code, 1, 2) == "zh"
end

local IS_ZH = IsChinese()
local TITLE = IS_ZH and "献祭祭坛" or "Sacrificial Altar"
local HINT = IS_ZH
    and "放入宝石/护符提升效果，取出会降低"
    or "Store gems/amulets to gain effects; remove to reduce"
local DESTROY_HINT = IS_ZH
    and "摧毁时先掉落全部物品，再返还半数材料"
    or "Destroying drops all stored items, then refunds half the recipe"

local function AddPanelBackground(self)
    local border = self:AddChild(Image("images/global.xml", "square.tex"))
    border:SetSize(560, 540)
    border:SetTint(0.24, 0.17, 0.11, 0.96)

    local inner = self:AddChild(Image("images/global.xml", "square.tex"))
    inner:SetSize(546, 526)
    inner:SetTint(0.055, 0.045, 0.035, 0.97)

    local accent = self:AddChild(Image("images/global.xml", "square.tex"))
    accent:SetSize(520, 3)
    accent:SetPosition(0, 238)
    accent:SetTint(0.72, 0.55, 0.25, 1)

    self._panel_children = { border, inner, accent }
end

local function OpenAltar(self, container, doer)
    self:Close()

    local component = container.components.container
    if component == nil then
        return
    end

    self.container = container
    self.owner = doer or self.owner
    self.isopen = true
    self.altar_open = true
    self.slotsperrow = COLS
    self:SetScale(1, 1, 1)
    self:SetPosition(0, 0, 0)

    if self.bganim ~= nil then
        self.bganim:Hide()
    end
    if self.bgimage ~= nil then
        self.bgimage:Hide()
    end

    AddPanelBackground(self)

    self.title = self:AddChild(Text(GLOBAL.BUTTONFONT, 26, TITLE))
    self.title:SetPosition(0, 212)
    self.title:SetColour(1, 0.88, 0.45, 1)

    self.hint = self:AddChild(Text(GLOBAL.BUTTONFONT, 13, HINT))
    self.hint:SetPosition(0, 188)
    self.hint:SetColour(0.72, 0.72, 0.72, 1)

    self.destroy_hint = self:AddChild(Text(
        GLOBAL.BUTTONFONT, 12, DESTROY_HINT
    ))
    self.destroy_hint:SetPosition(0, -236)
    self.destroy_hint:SetColour(0.62, 0.62, 0.62, 1)

    self:Show()
    self:StartUpdating()

    self.onitemlosefn = function(inst, data)
        self:OnItemLose(data)
    end
    self.inst:ListenForEvent("itemlose", self.onitemlosefn, container)

    self.onitemgetfn = function(inst, data)
        self:OnItemGet(data)
    end
    self.inst:ListenForEvent("itemget", self.onitemgetfn, container)

    local left = -(COLS - 1) * SPACING / 2
    local top = (ROWS - 1) * SPACING / 2 - 8

    local slots = {}
    for row = 0, ROWS - 1 do
        for col = 0, COLS - 1 do
            local index = row * COLS + col + 1
            local slot = self:AddChild(InvSlot(
                index,
                "images/hud.xml",
                "inv_slot.tex",
                self.owner,
                component
            ))
            local x = left + col * SPACING
            slot:SetPosition(x, top - row * SPACING, 0)
            slot:SetScale(SLOT_SCALE, SLOT_SCALE, SLOT_SCALE)
            slot.side_align_tip = 160 - x
            slots[index] = slot

            local item = component:GetItemInSlot(index)
            if item ~= nil then
                slot:SetTile(ItemTile(item))
            end
        end
    end

    self.inv = {}
    for i = 1, SLOT_COUNT do
        self.inv[i] = slots[i]
    end
end

AddClassPostConstruct("widgets/containerwidget", function(self)
    local old_open = self.Open
    function self:Open(container, doer)
        if container ~= nil and container.prefab == PREFAB then
            return OpenAltar(self, container, doer)
        end
        return old_open(self, container, doer)
    end

    local function KillCustomWidgets(self)
        if self.title ~= nil then
            self.title:Kill()
            self.title = nil
        end
        if self.hint ~= nil then
            self.hint:Kill()
            self.hint = nil
        end
        if self.destroy_hint ~= nil then
            self.destroy_hint:Kill()
            self.destroy_hint = nil
        end
        if self._panel_children ~= nil then
            for _, child in ipairs(self._panel_children) do
                child:Kill()
            end
            self._panel_children = nil
        end
    end

    local old_close = self.Close
    function self:Close(dont_close_container)
        if self.altar_closing then
            return
        end

        if not self.altar_open then
            return old_close(self, dont_close_container)
        end

        self.altar_open = false
        self.altar_closing = true
        self.isopen = false
        self:StopUpdating()

        local container = self.container

        if container ~= nil then
            if self.onitemlosefn ~= nil then
                self.inst:RemoveEventCallback(
                    "itemlose", self.onitemlosefn, container
                )
                self.onitemlosefn = nil
            end
            if self.onitemgetfn ~= nil then
                self.inst:RemoveEventCallback(
                    "itemget", self.onitemgetfn, container
                )
                self.onitemgetfn = nil
            end
        end

        KillCustomWidgets(self)

        for _, slot in pairs(self.inv) do
            slot:Kill()
        end
        self.inv = {}
        self.container = nil

        if container ~= nil
            and container.components.container ~= nil
            and not dont_close_container
        then
            container.components.container:Close()
        end

        self.altar_closing = false
    end
end)

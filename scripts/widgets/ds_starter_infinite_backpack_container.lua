local InvSlot = GLOBAL.require("widgets/invslot")
local ImageButton = GLOBAL.require("widgets/imagebutton")
local Text = GLOBAL.require("widgets/text")
local ItemTile = GLOBAL.require("widgets/itemtile")

local PREFAB = "ds_starter_infinite_backpack"
local MAX_PER_PAGE = 120
local MAX_PAGES = 9
local SLOT_SPACING = 52
local SLOT_SCALE = 0.75

-- Follow the game language for the paging controls.
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
local PAGE_FORMAT = IS_ZH and "第 %d/%d 页" or "Page %d/%d"
local PREV_TEXT = IS_ZH and "上一页" or "Prev"
local NEXT_TEXT = IS_ZH and "下一页" or "Next"

-- Work out a grid that fits above the main inventory bar. The number of
-- slots per page adapts to the screen, capped at 240.
local function ComputeLayout()
    -- Don't Starve lays out UI in a 1280x720 design space. GetScreenSize
    -- returns physical pixels on Retina displays, so use the design size and
    -- compensate for the HUD scale that the container root applies.
    local sw, sh = 1280, 720

    local hud_scale = 1
    if GLOBAL.TheFrontEnd ~= nil
        and GLOBAL.TheFrontEnd.GetHUDScale ~= nil
    then
        hud_scale = GLOBAL.TheFrontEnd:GetHUDScale() or 1
    end
    if hud_scale <= 0 then
        hud_scale = 1
    end

    sw = sw / hud_scale
    sh = sh / hud_scale
    local top_margin = 60 / hud_scale
    local bottom_margin = 215 / hud_scale
    local controls_space = 95 / hud_scale

    local avail_w = sw - 100 / hud_scale
    local avail_h = sh - top_margin - bottom_margin - controls_space

    local max_cols = math.max(6, math.min(24, math.floor(avail_w / SLOT_SPACING)))
    local max_rows = math.max(4, math.min(12, math.floor(avail_h / SLOT_SPACING)))
    local target = math.min(MAX_PER_PAGE, max_cols * max_rows)
    local area_aspect = avail_w / math.max(1, avail_h)

    -- Pick a column/row split whose grid aspect ratio best matches the
    -- available screen area, preferring a full last row.
    local cols, rows = nil, nil
    local best_score = nil
    for c = 1, max_cols do
        if target % c == 0 then
            local r = target / c
            if r >= 1 and r <= max_rows then
                local grid_aspect = (c - 1) / math.max(1, r - 1)
                local score = math.abs(grid_aspect - area_aspect)
                if best_score == nil or score < best_score then
                    best_score = score
                    cols = c
                    rows = r
                end
            end
        end
    end

    if cols == nil then
        cols = max_cols
        rows = math.ceil(target / cols)
        if rows > max_rows then
            rows = max_rows
            cols = math.ceil(target / rows)
        end
    end

    local per_page = math.min(MAX_PER_PAGE, cols * rows)
    rows = math.ceil(per_page / cols)

    local grid_w = (cols - 1) * SLOT_SPACING
    local grid_h = (rows - 1) * SLOT_SPACING

    -- Center the whole panel on screen. If the paging controls would reach
    -- into the main inventory bar, shift the whole panel up just enough.
    local top = grid_h / 2
    local bottom = -grid_h / 2
    local band_bottom = -sh / 2 + bottom_margin
    local panel_bottom = bottom - 55 - 30
    if panel_bottom < band_bottom then
        local shift = band_bottom - panel_bottom
        top = top + shift
        bottom = bottom + shift
    end

    return {
        cols = cols,
        rows = rows,
        per_page = per_page,
        grid_w = grid_w,
        grid_h = grid_h,
        top = top,
        bottom = bottom,
        button_y = bottom - 55,
        hud_scale = hud_scale,
    }
end

local function GetContainerComponent(self)
    if self.container == nil then
        return nil
    end
    return self.container.components.container
end

local function CountItemsInRange(component, first_slot, last_slot)
    local count = 0
    for slot in pairs(component.slots or {}) do
        if slot >= first_slot and slot <= last_slot then
            count = count + 1
        end
    end
    return count
end

-- Pages are unlocked dynamically: one page, plus another page whenever the
-- last page holds more than half of its slots.
local function ComputePageCount(self)
    local component = GetContainerComponent(self)
    if component == nil then
        return 1
    end

    local per_page = self.items_per_page or MAX_PER_PAGE
    local max_slot = 0
    for slot in pairs(component.slots or {}) do
        if slot > max_slot then
            max_slot = slot
        end
    end

    local pages = math.max(1, math.ceil(max_slot / per_page))
    pages = math.min(pages, MAX_PAGES)

    local last_start = (pages - 1) * per_page + 1
    local used = CountItemsInRange(
        component,
        last_start,
        last_start + per_page - 1
    )
    if used > per_page / 2 and pages < MAX_PAGES then
        pages = pages + 1
    end

    return math.min(pages, MAX_PAGES)
end

local function RefreshPage(self)
    local component = GetContainerComponent(self)
    if component == nil then
        return
    end

    for num, slot in pairs(self.inv or {}) do
        local item = component:GetItemInSlot(num)
        if item ~= nil then
            slot:SetTile(ItemTile(item))
        else
            slot:SetTile(nil)
        end
    end
end

local function UpdatePageDisplay(self)
    self.page_count = ComputePageCount(self)
    if self.page > self.page_count then
        self.page = self.page_count
    end
    if self.page < 1 then
        self.page = 1
    end
    if self.page_text ~= nil then
        self.page_text:SetString(string.format(
            PAGE_FORMAT,
            self.page,
            self.page_count
        ))
    end
end

local function SetPage(self, page)
    if self.page_slots == nil then
        return
    end

    UpdatePageDisplay(self)
    page = math.max(1, math.min(self.page_count, page or 1))
    self.page = page
    self.inv = {}

    local per_page = self.items_per_page or MAX_PER_PAGE
    for i, slot in ipairs(self.page_slots) do
        local num = (page - 1) * per_page + i
        slot.num = num
        self.inv[num] = slot
    end

    UpdatePageDisplay(self)
    RefreshPage(self)
end

local function OpenInfiniteBackpack(self, container, doer)
    self:Close()

    local component = container.components.container
    if component == nil then
        return
    end

    self.container = container
    self.owner = doer or self.owner
    self.isopen = true
    self:SetScale(1, 1, 1)

    local layout = ComputeLayout()
    self.items_per_page = layout.per_page
    self.page_count = 1
    self.page = 1
    self.page_slots = {}
    self.inv = {}

    -- The stock backpack art cannot fit this grid.
    if self.bganim ~= nil then
        self.bganim:Hide()
    end
    if self.bgimage ~= nil then
        self.bgimage:Hide()
    end

    local Image = GLOBAL.require("widgets/image")
    local bg_top = layout.top + 34
    local bg_bottom = layout.button_y - 30
    local bg_height = bg_top - bg_bottom
    local bg_width = math.max(layout.grid_w + 80, bg_height * 16 / 9)
    self.grid_bg = self:AddChild(Image("images/ui.xml", "bg_plain.tex"))
    self.grid_bg:SetSize(bg_width, bg_height)
    self.grid_bg:SetTint(0.72, 0.6, 0.46, 1)
    self.grid_bg:SetPosition(0, (bg_top + bg_bottom) / 2, 0)
    self.grid_bg:MoveToBack()

    self:Show()
    self:StartUpdating()

    self.onitemlosefn = function(inst, data)
        self:OnItemLose(data)
        UpdatePageDisplay(self)
    end
    self.inst:ListenForEvent("itemlose", self.onitemlosefn, container)

    self.onitemgetfn = function(inst, data)
        self:OnItemGet(data)
        UpdatePageDisplay(self)
    end
    self.inst:ListenForEvent("itemget", self.onitemgetfn, container)

    local left = -(layout.cols - 1) * SLOT_SPACING / 2
    for row = 0, layout.rows - 1 do
        for col = 0, layout.cols - 1 do
            local index = row * layout.cols + col + 1
            if index > layout.per_page then
                break
            end

            local slot = self:AddChild(InvSlot(
                index,
                "images/hud.xml",
                "inv_slot.tex",
                self.owner,
                component
            ))
            slot:SetPosition(
                left + col * SLOT_SPACING,
                layout.top - row * SLOT_SPACING,
                0
            )
            slot:SetScale(SLOT_SCALE, SLOT_SCALE, SLOT_SCALE)
            slot.Highlight = function(s)
                if not s.big then
                    s:ScaleTo(
                        SLOT_SCALE,
                        SLOT_SCALE * 1.3,
                        0.125
                    )
                    s.big = true
                end
            end
            slot.DeHighlight = function(s)
                if s.big then
                    s:ScaleTo(
                        SLOT_SCALE * 1.3,
                        SLOT_SCALE,
                        0.25
                    )
                    s.big = false
                end
            end
            self.page_slots[index] = slot
        end
    end

    local prev = self:AddChild(ImageButton(
        "images/ui.xml",
        "button_small.tex",
        "button_small_over.tex",
        "button_small_disabled.tex"
    ))
    prev:SetText(PREV_TEXT)
    prev:SetTextSize(20)
    prev:SetPosition(-120, layout.button_y, 0)
    prev:SetOnClick(function()
        SetPage(self, self.page > 1 and self.page - 1 or self.page_count)
    end)

    local next = self:AddChild(ImageButton(
        "images/ui.xml",
        "button_small.tex",
        "button_small_over.tex",
        "button_small_disabled.tex"
    ))
    next:SetText(NEXT_TEXT)
    next:SetTextSize(20)
    next:SetPosition(120, layout.button_y, 0)
    next:SetOnClick(function()
        SetPage(self, self.page < self.page_count and self.page + 1 or 1)
    end)

    self.page_buttons = { prev, next }
    self.page_text = self:AddChild(Text(
        GLOBAL.BUTTONFONT,
        20,
        ""
    ))
    self.page_text:SetPosition(0, layout.button_y, 0)
    self.page_text:SetColour(1, 1, 1, 1)

    SetPage(self, 1)
end

AddClassPostConstruct("widgets/containerwidget", function(self)
    local old_open = self.Open
    function self:Open(container, doer)
        if container ~= nil and container.prefab == PREFAB then
            return OpenInfiniteBackpack(self, container, doer)
        end
        return old_open(self, container, doer)
    end

    local old_close = self.Close
    function self:Close(dont_close_container)
        if self.page_buttons ~= nil then
            for _, button in ipairs(self.page_buttons) do
                button:Kill()
            end
            self.page_buttons = nil
        end
        if self.page_text ~= nil then
            self.page_text:Kill()
            self.page_text = nil
        end
        if self.grid_bg ~= nil then
            self.grid_bg:Kill()
            self.grid_bg = nil
        end
        self.page_slots = nil
        self.page = nil
        return old_close(self, dont_close_container)
    end
end)

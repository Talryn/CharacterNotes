local MAJOR, MINOR = "LibDropDownExtension-1.0", 5
assert(LibStub, MAJOR .. " requires LibStub")

---@type LibDropDownExtension?, number?
local Lib, LibPrevMinor = LibStub:NewLibrary(MAJOR, MINOR) ---@diagnostic disable-line: assign-type-mismatch
if not Lib then return end

-- Globals defined with their types

local CloseMenus = CloseMenus ---@type fun()
local DropDownList1 = DropDownList1 ---@type LibDropDownExtension_DropDownListPolyfill
local DropDownList2 = DropDownList2 ---@type LibDropDownExtension_DropDownListPolyfill
local DropDownList3 = DropDownList3 ---@type LibDropDownExtension_DropDownListPolyfill
local GameFontDisableSmallLeft = GameFontDisableSmallLeft ---@type FontObject
local GameFontHighlightSmallLeft = GameFontHighlightSmallLeft ---@type FontObject
local GameFontNormalSmallLeft = GameFontNormalSmallLeft ---@type FontObject
local GameTooltip = GameTooltip ---@type GameTooltip
local GameTooltip_AddColoredLine = GameTooltip_AddColoredLine ---@type fun(tooltip: GameTooltip, text: string?, color: ColorMixin?, wrap: boolean?, leftOffset: number?)
local GameTooltip_AddInstructionLine = GameTooltip_AddInstructionLine ---@type fun(tooltip: GameTooltip, text: string?, wrap: boolean?, leftOffset: number?)
local GameTooltip_AddNormalLine = GameTooltip_AddNormalLine ---@type fun(tooltip: GameTooltip, text: string?, wrap: boolean?, leftOffset: number?)
local GameTooltip_SetTitle = GameTooltip_SetTitle ---@type fun(tooltip: GameTooltip, text: string?)
local HIGHLIGHT_FONT_COLOR = HIGHLIGHT_FONT_COLOR ---@type ColorMixin
local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR ---@type ColorMixin
local RED_FONT_COLOR = RED_FONT_COLOR ---@type ColorMixin
local UIDROPDOWNMENU_MAXBUTTONS = UIDROPDOWNMENU_MAXBUTTONS ---@type number
local UIDropDownMenuButton_OpenColorPicker = UIDropDownMenuButton_OpenColorPicker ---@type fun(button: LibDropDownExtension_CustomDropDownButton)

-- Documentation block for easy code folding

do

    ---@alias LibDropDownExtension_Event "OnShow"|"OnHide"

    ---@alias LibDropDownExtension_DropDownListPolyfill_Which
    ---|"ARENAENEMY"
    ---|"BATTLEPET"
    ---|"BN_FRIEND"
    ---|"BN_FRIEND_OFFLINE"
    ---|"BOSS"
    ---|"CHAT_ROSTER"
    ---|"COMMUNITIES_COMMUNITY"
    ---|"COMMUNITIES_GUILD_MEMBER"
    ---|"COMMUNITIES_MEMBER"
    ---|"COMMUNITIES_WOW_MEMBER"
    ---|"ENEMY_PLAYER"
    ---|"FOCUS"
    ---|"FRIEND"
    ---|"FRIEND_OFFLINE"
    ---|"GLUE_FRIEND"
    ---|"GLUE_FRIEND_OFFLINE"
    ---|"GLUE_PARTY_MEMBER"
    ---|"GUILD"
    ---|"GUILDS_GUILD"
    ---|"GUILD_OFFLINE"
    ---|"OTHERBATTLEPET"
    ---|"OTHERPET"
    ---|"PARTY"
    ---|"PET"
    ---|"PLAYER"
    ---|"PVP_SCOREBOARD"
    ---|"RAF_RECRUIT"
    ---|"RAID"
    ---|"RAID_PLAYER"
    ---|"RAID_TARGET_ICON"
    ---|"SELF"
    ---|"TARGET"
    ---|"VEHICLE"
    ---|"WORLD_STATE_SCORE"

    ---@alias LibDropDownExtension_OptionFunc fun(button: LibDropDownExtension_CustomDropDownButton, arg1: any, arg2: any, checked?: boolean)

    ---@alias LibDropDownExtension_OptionCheckedFunc fun(self: LibDropDownExtension_CustomDropDownButton): boolean?

    ---@alias LibDropDownExtension_OptionSwatchFunc fun(self: LibDropDownExtension_CustomDropDownButton): any

    ---@alias LibDropDownExtension_OptionSwatchOpacityFunc fun(self: LibDropDownExtension_CustomDropDownButton): any

    ---@alias LibDropDownExtension_OptionSwatchCancelFunc fun(self: LibDropDownExtension_CustomDropDownButton): any

    ---@generic T
    ---@alias LibDropDownExtension_CallbackFunc<T> fun(dropdown: LibDropDownExtension_DropDownList, event: LibDropDownExtension_Event, options: LibDropDownExtension_Option[], level: number, data?: T): LibDropDownExtension_Option[]|boolean|nil

    ---@generic T
    ---@alias LibDropDownExtension_RegisterEventFunc<T> fun(self: LibDropDownExtension, events: LibDropDownExtension_Event|string, func: LibDropDownExtension_CallbackFunc<T>, levels?: number|boolean, data?: T): boolean

    ---@alias LibDropDownExtension_UnregisterEventFunc fun(self: LibDropDownExtension, events: LibDropDownExtension_Event|string, func: LibDropDownExtension_CallbackFunc<table>, levels?: number|boolean): boolean

    ---@class LibDropDownExtension
    ---@field public _callbacks LibDropDownExtension_Callback[]
    ---@field public _cdropdowns table<LibDropDownExtension_DropDownListPolyfill, LibDropDownExtension_DropDownList>
    ---@field public _cdropdownLists LibDropDownExtension_CustomDropDownList[]
    ---@field public _separatorTable LibDropDownExtension_Option[]
    ---@field public _hooked table<LibDropDownExtension_DropDownListPolyfill, boolean>
    ---@field public _Broadcast fun(self: LibDropDownExtension, event: LibDropDownExtension_Event, dropdown: LibDropDownExtension_DropDownListPolyfill)
    ---@field public Option table<string, LibDropDownExtension_Option> `LibDropDownExtension.Option.Separator` `LibDropDownExtension.Option.Space`
    ---@field public RegisterEvent LibDropDownExtension_RegisterEventFunc<table> `LibDropDownExtension:RegisterEvent(events, func[, levels[, data]])` where func is later called as `func(dropdown, event, options, level, data)` and the return boolean if true will append the options to the dropdown, otherwise false will ignore appending our options to the dropdown.
    ---@field public UnregisterEvent LibDropDownExtension_UnregisterEventFunc `LibDropDownExtension:UnregisterEvent(events, func[, levels])`

    ---@class LibDropDownExtension_OptionExtraInfo
    ---@field public customCheckIconAtlas string?
    ---@field public customUncheckIconAtlas string?
    ---@field public customCheckIconTexture (string|number)?
    ---@field public customUncheckIconTexture (string|number)?

    ---@class LibDropDownExtension_OptionIconInfo
    ---@field public tCoordLeft number
    ---@field public tCoordRight number
    ---@field public tCoordTop number
    ---@field public tCoordBottom number
    ---@field public tSizeX number
    ---@field public tSizeY number
    ---@field public tFitDropDownSizeX boolean
    ---@field public disablecolor? string

    ---@class LibDropDownExtension_OptionSeparatorInfo : LibDropDownExtension_OptionExtraInfo
    ---@field public hasArrow boolean?
    ---@field public dist number?
    ---@field public isTitle boolean?
    ---@field public isUninteractable boolean?
    ---@field public notCheckable boolean?
    ---@field public iconOnly boolean?
    ---@field public icon (string|number)?
    ---@field public tCoordLeft number?
    ---@field public tCoordRight number?
    ---@field public tCoordTop number?
    ---@field public tCoordBottom number?
    ---@field public tSizeX number?
    ---@field public tSizeY number?
    ---@field public tFitDropDownSizeX boolean?
    ---@field public iconInfo LibDropDownExtension_OptionIconInfo?

    ---@class LibDropDownExtension_Option : LibDropDownExtension_OptionSeparatorInfo, LibDropDownExtension_OptionIconInfo
    ---@field public text string @The text of the button
    ---@field public value any @The value that UIDROPDOWNMENU_MENU_VALUE is set to when the button is clicked
    ---@field public func LibDropDownExtension_OptionFunc? @The function that is called when you click the button. Called as `func(button, option.arg1, option.arg2, option.checkedEval)`
    ---@field public checked (boolean|LibDropDownExtension_OptionCheckedFunc)? @Check the button if true or function returns true
    ---@field public checkedEval boolean? @The final value of the checked state (in case a function and such, use this in your click handler)
    ---@field public isNotRadio boolean? @Check the button uses radial image if false check box image if true
    ---@field public isTitle boolean? @If it's a title the button is disabled and the font color is set to yellow
    ---@field public disabled boolean? @Disable the button and show an invisible button that still traps the mouseover event so menu doesn't time out
    ---@field public tooltipWhileDisabled boolean? @Show the tooltip, even when the button is disabled.
    ---@field public hasArrow boolean? @Show the expand arrow for multilevel menus
    ---@field public arrowXOffset number? @Number of pixels to shift the button's icon to the left or right (positive numbers shift right, negative numbers shift left).
    ---@field public hasColorSwatch boolean? @Show color swatch or not, for color selection
    ---@field public r? number @Red color value of the color swatch [1-255]
    ---@field public g? number @Green color value of the color swatch [1-255]
    ---@field public b? number @Blue color value of the color swatch [1-255]
    ---@field public colorCode string? @"|cAARRGGBB" embedded hex value of the button text color. Only used when button is enabled
    ---@field public swatchFunc LibDropDownExtension_OptionSwatchFunc? @Function called by the color picker on color change
    ---@field public hasOpacity boolean? @Show the opacity slider on the colorpicker frame
    ---@field public opacity number? @Percentatge of the opacity, 1.0 is fully shown, 0 is transparent [0.0-1.0]
    ---@field public opacityFunc LibDropDownExtension_OptionSwatchOpacityFunc? @Function called by the opacity slider when you change its value
    ---@field public cancelFunc LibDropDownExtension_OptionSwatchCancelFunc? @Function called by the colorpicker when you click the cancel button (it takes the previous values as its argument)
    ---@field public notClickable boolean? @Disable the button and color the font white
    ---@field public notCheckable boolean? @Shrink the size of the buttons and don't display a check box
    ---@field public owner Frame? @Dropdown frame that "owns" the current dropdownlist
    ---@field public keepShownOnClick boolean? @Don't hide the dropdownlist after a button is clicked
    ---@field public tooltipTitle string? @Title of the tooltip shown on mouseover
    ---@field public tooltipText string? @Text of the tooltip shown on mouseover
    ---@field public tooltipOnButton boolean? @Show the tooltip attached to the button instead of as a Newbie tooltip.
    ---@field public noTooltipWhileEnabled boolean?
    ---@field public justifyH string? @Justify button text like "LEFT", "CENTER", "RIGHT"
    ---@field public arg1 any @This is the first argument used by .func
    ---@field public arg2 any @This is the second argument used by .func
    ---@field public fontObject FontObject? @font object replacement for Normal and Highlight
    ---@field public noClickSound boolean? @Set to 1 to suppress the sound when clicking the button. The sound only plays if .func is set.
    ---@field public menuList LibDropDownExtension_Option[]? @This contains an array of info tables to be displayed as a child menu
    ---@field public menuListDisplayMode "MENU"? @If menuList is set, show the sub drop down with an override display mode.
    ---@field public padding number? @Number of pixels to pad the text on the right side
    ---@field public leftPadding number? @Number of pixels to pad the button on the left side
    ---@field public minWidth number? @Minimum width for this line
    ---@field public customFrame Frame? @Allows this button to be a completely custom frame, should inherit from UIDropDownCustomMenuEntryTemplate and override appropriate methods.
    ---@field public icon (string|number)? @An icon for the button.
    ---@field public mouseOverIcon (string|number)? @An override icon when a button is moused over.

    ---@class LibDropDownExtension_Callback
    ---@field public events table<LibDropDownExtension_Event, number|boolean>
    ---@field public func LibDropDownExtension_CallbackFunc<table>
    ---@field public options LibDropDownExtension_Option[]
    ---@field public data table

    ---@class LibDropDownExtension_DropDownMenuPolyfill : Button
    ---@field public which LibDropDownExtension_DropDownListPolyfill_Which|string
    ---@field public unit string
    ---@field public name string?
    ---@field public userData any?
    ---@field public server string?
    ---@field public accountInfo BNetAccountInfo?
    ---@field public isMobile boolean?

    ---@class LibDropDownExtension_DropDownList : LibDropDownExtension_DropDownMenuPolyfill
    ---@field public options LibDropDownExtension_Option[]
    ---@field public buttons LibDropDownExtension_CustomDropDownButton[]

    ---@class LibDropDownExtension_DropDownListPolyfill : Button
    ---@field public dropdown LibDropDownExtension_DropDownList
    ---@field public maxWidth number
    ---@field public numButtons number
    ---@field public shouldRefresh boolean
    ---@field public parent LibDropDownExtension_DropDownListPolyfill?
    ---@field public hideBackdrops boolean?

    ---@class LibDropDownExtension_CustomDropDownButton_IconTexture : TextureBase
    ---@field public tFitDropDownSizeX boolean?

    ---@class LibDropDownExtension_CustomDropDownButton_InvisibleButton : Button

    ---@class LibDropDownExtension_CustomDropDownButton_ExpandArrow : Button

    ---@class LibDropDownExtension_CustomDropDownButton_ColorSwatch : Button

    ---@class LibDropDownExtension_CustomDropDownButton : Button
    ---@field public option LibDropDownExtension_Option
    ---@field public order number
    ---@field public invisibleButton LibDropDownExtension_CustomDropDownButton_InvisibleButton
    ---@field public highlight TextureBase
    ---@field public normalText FontString
    ---@field public iconTexture LibDropDownExtension_CustomDropDownButton_IconTexture
    ---@field public expandArrow LibDropDownExtension_CustomDropDownButton_ExpandArrow
    ---@field public check TextureBase
    ---@field public uncheck TextureBase
    ---@field public colorSwatch LibDropDownExtension_CustomDropDownButton_ColorSwatch
    ---@field public colorSwatchNormalTexture TextureBase
    ---@field public mouseOverIcon string?
    ---@field public tooltipOnButton boolean?
    ---@field public tooltipTitle string?
    ---@field public tooltipWhileDisabled boolean?
    ---@field public tooltipInstruction string?
    ---@field public tooltipText string?
    ---@field public tooltipWarning string?
    ---@field public colorSwatchBg TextureBase?

    ---@class LibDropDownExtension_CustomDropDownList : LibDropDownExtension_DropDownList, LibDropDownExtension_DropDownListPolyfill

end

Lib._callbacks = Lib._callbacks or {}
local callbacks = Lib._callbacks

Lib._cdropdowns = Lib._cdropdowns or {}
local cdropdowns = Lib._cdropdowns

Lib._cdropdownLists = Lib._cdropdownLists or {}
local cdropdownLists = Lib._cdropdownLists

-- Implement the first custom dropdown list frame.
if not cdropdownLists[1] then
    local cdropdownList = CreateFrame("Button", "LibDropDownExtensionCustomDropDownList1", UIParent, "UIDropDownListTemplate") ---@class LibDropDownExtension_CustomDropDownList
    cdropdownList.options = {} ---@type LibDropDownExtension_Option[]
    cdropdownList.buttons = {} ---@type LibDropDownExtension_CustomDropDownButton[]
    cdropdownList.Backdrop = _G[format("%sBackdrop", cdropdownList:GetName())] ---@type Region
    cdropdownList.MenuBackdrop = _G[format("%sMenuBackdrop", cdropdownList:GetName())] ---@type Region
    cdropdownList:SetToplevel(true)
    cdropdownList:SetFrameStrata("FULLSCREEN_DIALOG")
    cdropdownList:SetClampedToScreen(true)
    cdropdownList:SetSize(180, 20)
    cdropdownList:Hide()
    cdropdownList:SetScript("OnUpdate", nil)
    cdropdownList:SetScript("OnShow", nil)
    cdropdownList:SetScript("OnHide", nil)
    cdropdownLists[1] = cdropdownList
end

-- There are a bit of cyclic dependencies so we need to define this on top and implement it on the bottom.
---@type fun(self: LibDropDownExtension_CustomDropDownButton, level: number)
local CustomDropDownToggleMenu

-- Sanitizes the input so it only returns the list back if it's a custom dropdown list.
---@param cdropdown LibDropDownExtension_DropDownList
---@return LibDropDownExtension_CustomDropDownList? dropDownList
local function IsCustomDropDownList(cdropdown)
    for _, list in ipairs(cdropdownLists)  do
        if list == cdropdown then
            return list
        end
    end
end

-- Safely close the dropdown list without causing taint complications, hence why we don't call the defined global.
-- This also supports our custom dropdown list implementation.
---@param target (LibDropDownExtension_DropDownList|LibDropDownExtension_DropDownListPolyfill|number)?
local function CloseDropDownMenus(target)
    if type(target) == "number" then
        target = _G[format("DropDownList%d", target)] ---@type LibDropDownExtension_DropDownListPolyfill
    end
    if type(target) == "table" then
        target:Hide()
    end
    for _, cdropdownList in ipairs(cdropdownLists) do
        cdropdownList:Hide()
    end
end

-- Evaluate a option `checked` value to a `boolean`.
---@param self LibDropDownExtension_CustomDropDownButton
---@return boolean? isChecked
local function CustomDropDownButtonIsChecked(self)
    local option = self.option
    local checked ---@type boolean?
    if type(option.checked) == "function" then
        checked = option.checked(self)
    else
        checked = not not option.checked
    end
    return checked
end

---@param self LibDropDownExtension_CustomDropDownButton
local function CustomDropDownButton_OnClick(self)
    local option = self.option
    if not option then
        return
    end
    ---@diagnostic disable-next-line: assign-type-mismatch
    local cdropdown = self:GetParent() ---@type LibDropDownExtension_DropDownList|LibDropDownExtension_CustomDropDownList
    local checked = CustomDropDownButtonIsChecked(self)
    if option.keepShownOnClick and not option.notCheckable then
        if checked then
            checked = false
            self.check:Hide()
            self.uncheck:Show()
        else
            checked = true
            self.check:Show()
            self.uncheck:Hide()
        end
    end
    if type(option.checkedEval) ~= "function" then
        option.checkedEval = checked
    end
    if type(option.func) == "function" then
        option.func(self, option.arg1, option.arg2, checked)
    end
    if not option.noClickSound then
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
    end
    if option.keepShownOnClick then
        return
    end
    local dropDownList = IsCustomDropDownList(cdropdown)
    if dropDownList then
        CloseDropDownMenus(dropDownList.parent)
        return
    end
    ---@type LibDropDownExtension_DropDownListPolyfill
    local parent = cdropdown:GetParent() ---@diagnostic disable-line: assign-type-mismatch
    CloseDropDownMenus(parent)
end

---@param self LibDropDownExtension_CustomDropDownButton
local function CustomDropDownButton_OnEnter(self)
    local option = self.option
    if not option then
        return
    end
    ---@diagnostic disable-next-line: assign-type-mismatch
    local cdropdown = self:GetParent() ---@type LibDropDownExtension_DropDownList|LibDropDownExtension_CustomDropDownList
    if option.hasArrow then
        local level = cdropdown:GetID() + 1
        local listFrame = _G[format("DropDownList%d", level)]
        if not listFrame or not listFrame:IsShown() or select(2, listFrame:GetPoint(1)) ~= self then
            CustomDropDownToggleMenu(self, level)
        end
    elseif not IsCustomDropDownList(cdropdown) then
        CloseDropDownMenus(cdropdown:GetID() + 1)
    end
    self.highlight:Show()
    local shownTooltip
    if self.normalText:IsTruncated() then
        if not shownTooltip then
            shownTooltip = true
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip_SetTitle(GameTooltip, self.normalText:GetText())
        else
            GameTooltip:AddLine(self.normalText:GetText(), 1, 1, 1, false)
        end
        GameTooltip:Show()
    end
    if option.tooltipTitle and not option.noTooltipWhileEnabled then
        if option.tooltipOnButton then
            if not shownTooltip then
                shownTooltip = true
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip_SetTitle(GameTooltip, option.tooltipTitle)
            else
                GameTooltip:AddLine(option.tooltipTitle, 1, 1, 1, false)
            end
            if option.tooltipText then
                GameTooltip_AddNormalLine(GameTooltip, option.tooltipText, true)
            end
            GameTooltip:Show()
        end
    end
    if option.mouseOverIcon then
        self.iconTexture:SetTexture(self.mouseOverIcon)
        self.iconTexture:Show()
    end
end

---@param self LibDropDownExtension_CustomDropDownButton
local function CustomDropDownButton_OnLeave(self)
    self.highlight:Hide()
    GameTooltip:Hide()
    local option = self.option
    if not option.mouseOverIcon then
        return
    end
    if option.icon then
        self.iconTexture:SetTexture(option.icon)
    else
        self.iconTexture:Hide()
    end
end

---@param self LibDropDownExtension_CustomDropDownButton
local function CustomDropDownButton_OnEnable(self)
    self.invisibleButton:Hide()
end

---@param self LibDropDownExtension_CustomDropDownButton
local function CustomDropDownButton_OnDisable(self)
    self.invisibleButton:Show()
end

---@param self LibDropDownExtension_CustomDropDownButton_InvisibleButton
local function CustomDropDownButton_InvisibleButton_OnEnter(self)
    ---@diagnostic disable-next-line: assign-type-mismatch
    local button = self:GetParent() ---@type LibDropDownExtension_CustomDropDownButton
    ---@diagnostic disable-next-line: assign-type-mismatch
    local cdropdown = button:GetParent() ---@type LibDropDownExtension_DropDownList
    CloseDropDownMenus(cdropdown:GetID() + 1)
    if not button.tooltipOnButton or (not button.tooltipTitle and not button.tooltipWhileDisabled) then
        return
    end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip_SetTitle(GameTooltip, button.tooltipTitle)
    if button.tooltipInstruction then
        GameTooltip_AddInstructionLine(GameTooltip, button.tooltipInstruction)
    end
    if button.tooltipText then
        GameTooltip_AddNormalLine(GameTooltip, button.tooltipText, true)
    end
    if button.tooltipWarning then
        GameTooltip_AddColoredLine(GameTooltip, button.tooltipWarning, RED_FONT_COLOR, true)
    end
    GameTooltip:Show()
end

---@param self LibDropDownExtension_CustomDropDownButton_InvisibleButton
local function CustomDropDownButton_InvisibleButton_OnLeave(self)
    GameTooltip:Hide()
end

---@param self LibDropDownExtension_CustomDropDownButton_ExpandArrow
local function CustomDropDownButton_ExpandArrow_OnMouseDown(self)
    ---@diagnostic disable-next-line: assign-type-mismatch
    local button = self:GetParent() ---@type LibDropDownExtension_CustomDropDownButton
    if not button:IsEnabled() then
        return
    end
    ---@diagnostic disable-next-line: assign-type-mismatch
    local cdropdown = button:GetParent() ---@type LibDropDownExtension_DropDownList
    local level = cdropdown:GetID() + 1
    CustomDropDownToggleMenu(button, level)
end

---@param self LibDropDownExtension_CustomDropDownButton_ExpandArrow
local function CustomDropDownButton_ExpandArrow_OnEnter(self)
    ---@diagnostic disable-next-line: assign-type-mismatch
    local button = self:GetParent() ---@type LibDropDownExtension_CustomDropDownButton
    ---@diagnostic disable-next-line: assign-type-mismatch
    local cdropdown = button:GetParent() ---@type LibDropDownExtension_DropDownList
    local level = cdropdown:GetID() + 1
    CloseDropDownMenus(level)
    if not button:IsEnabled() then
        return
    end
    local listFrame = _G[format("DropDownList%d", level)]
    if not listFrame or not listFrame:IsShown() or self ~= select(2, listFrame:GetPoint(1)) then
        CustomDropDownToggleMenu(button, level)
    end
end

---@param self LibDropDownExtension_CustomDropDownButton_ColorSwatch
local function CustomDropDownButton_ColorSwatch_OnClick(self)
    ---@diagnostic disable-next-line: assign-type-mismatch
    local button = self:GetParent() ---@type LibDropDownExtension_CustomDropDownButton
    CloseMenus()
    UIDropDownMenuButton_OpenColorPicker(button)
end

---@param self LibDropDownExtension_CustomDropDownButton_ColorSwatch
local function CustomDropDownButton_ColorSwatch_OnEnter(self)
    ---@diagnostic disable-next-line: assign-type-mismatch
    local button = self:GetParent() ---@type LibDropDownExtension_CustomDropDownButton
    ---@diagnostic disable-next-line: assign-type-mismatch
    local cdropdown = button:GetParent() ---@type LibDropDownExtension_DropDownList
    CloseDropDownMenus(cdropdown:GetID() + 1)
    button.colorSwatchBg:SetVertexColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
end

---@param self LibDropDownExtension_CustomDropDownButton_ColorSwatch
local function CustomDropDownButton_ColorSwatch_OnLeave(self)
    ---@diagnostic disable-next-line: assign-type-mismatch
    local button = self:GetParent() ---@type LibDropDownExtension_CustomDropDownButton
    button.colorSwatchBg:SetVertexColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
end

---@param self Region
---@param buttonID "LeftButton"|"RightButton"|"MiddleButton"|"Button4"|"Button5"
---@param event WowEvent
local function HandlesGlobalMouseEvent(self, buttonID, event)
    return event == "GLOBAL_MOUSE_DOWN" and buttonID == "LeftButton"
end

---@param cdropdown LibDropDownExtension_DropDownList|LibDropDownExtension_DropDownListPolyfill
---@param existingButton LibDropDownExtension_CustomDropDownButton?
---@return LibDropDownExtension_CustomDropDownButton button
local function NewCustomDropDownButton(cdropdown, existingButton)
    local index = #cdropdown.buttons + 1
    local button = existingButton or CreateFrame("Button", format("%s%s%d", cdropdown:GetName(), "CustomButton", index), cdropdown, "UIDropDownMenuButtonTemplate") ---@class LibDropDownExtension_CustomDropDownButton
    button.order = nil
    button.option = nil
    button.HandlesGlobalMouseEvent = HandlesGlobalMouseEvent
    button:SetID(index)
    button:SetFrameLevel(cdropdown:GetFrameLevel() + 2)
    button:SetScript("OnClick", CustomDropDownButton_OnClick)
    button:SetScript("OnEnter", CustomDropDownButton_OnEnter)
    button:SetScript("OnLeave", CustomDropDownButton_OnLeave)
    button:SetScript("OnEnable", CustomDropDownButton_OnEnable)
    button:SetScript("OnDisable", CustomDropDownButton_OnDisable)
    local buttonName = button:GetName()
    button.invisibleButton = _G[buttonName .. "InvisibleButton"]
    button.invisibleButton:SetScript("OnEnter", CustomDropDownButton_InvisibleButton_OnEnter)
    button.invisibleButton:SetScript("OnLeave", CustomDropDownButton_InvisibleButton_OnLeave)
    button.highlight = _G[buttonName .. "Highlight"]
    button.normalText = _G[buttonName .. "NormalText"]
    button.normalText:ClearAllPoints()
    button.normalText:SetPoint("LEFT")
    button.normalText:SetPoint("RIGHT")
    button.normalText:SetWordWrap(false)
    button.normalText:SetNonSpaceWrap(false)
    button.iconTexture = _G[buttonName .. "Icon"]
    button.expandArrow = _G[buttonName .. "ExpandArrow"]
    button.expandArrow:SetScript("OnMouseDown", CustomDropDownButton_ExpandArrow_OnMouseDown)
    button.expandArrow:SetScript("OnEnter", CustomDropDownButton_ExpandArrow_OnEnter)
    button.check = _G[buttonName .. "Check"]
    button.uncheck = _G[buttonName .. "UnCheck"]
    button.colorSwatch = _G[buttonName .. "ColorSwatch"]
    button.colorSwatchBg = _G[buttonName .. "ColorSwatchSwatchBg"]
    button.colorSwatchNormalTexture = _G[buttonName .. "ColorSwatchNormalTexture"]
    button.colorSwatch:SetScript("OnClick", CustomDropDownButton_ColorSwatch_OnClick)
    button.colorSwatch:SetScript("OnEnter", CustomDropDownButton_ColorSwatch_OnEnter)
    button.colorSwatch:SetScript("OnLeave", CustomDropDownButton_ColorSwatch_OnLeave)
    return button
end

---@param option LibDropDownExtension_Option
---@param isCustomDropDownList? boolean
---@return LibDropDownExtension_Option sanitizedOption
local function SanitizeCustomDropDownButtonOptions(option, isCustomDropDownList)
    if option.notCheckable == nil then
        option.notCheckable = true
    end
    if isCustomDropDownList then
        option.hasArrow = false
    end
    return option
end

---@param cdropdown LibDropDownExtension_DropDownList
local function CustomDropDown_OnShow(cdropdown)
    ---@type LibDropDownExtension_DropDownListPolyfill
    local parent = cdropdown:GetParent() ---@diagnostic disable-line: assign-type-mismatch
    local maxWidth = parent.maxWidth
    local width, height = parent:GetWidth(), 32
    for i = 1, #cdropdown.buttons do
        local button = cdropdown.buttons[i]
        if button:IsShown() then
            button:SetWidth(maxWidth)
            height = height + button:GetHeight()
        end
    end
    cdropdown:SetHeight(height)
end

---@param widget Region
local function Hide(widget)
    widget:SetAlpha(0)
    widget:Hide()
    widget.Show = widget.Hide
end

---@param dropdown LibDropDownExtension_DropDownListPolyfill
local function NewCustomDropDown(dropdown)
    local cdropdown = CreateFrame("Button", "LibDropDownExtensionCustomDropDown_" .. tostring(dropdown), dropdown, "UIDropDownListTemplate") ---@class LibDropDownExtension_DropDownList
    cdropdown.HandlesGlobalMouseEvent = HandlesGlobalMouseEvent
    cdropdown:SetID(dropdown:GetID())
    cdropdown.options = {}
    cdropdown.buttons = {}
    do
        local cdropdownName = cdropdown:GetName()
        Hide(_G[cdropdownName .. "Backdrop"])
        Hide(_G[cdropdownName .. "MenuBackdrop"])
        cdropdown:SetFrameStrata(dropdown:GetFrameStrata())
        cdropdown:SetFrameLevel(dropdown:GetFrameLevel() + 1)
        cdropdown:SetScript("OnClick", nil)
        cdropdown:SetScript("OnUpdate", nil)
        cdropdown:SetScript("OnShow", CustomDropDown_OnShow)
        cdropdown:SetScript("OnHide", nil)
        for i = 1, UIDROPDOWNMENU_MAXBUTTONS do
            ---@type LibDropDownExtension_CustomDropDownButton
            local button = _G[cdropdown:GetName() .. "Button" .. i]
            if not button then
                break
            end
            button = NewCustomDropDownButton(cdropdown, button)
            cdropdown.buttons[i] = button
        end
    end
    return cdropdown
end

---@param a LibDropDownExtension_CustomDropDownButton
---@param b LibDropDownExtension_CustomDropDownButton
local function SortDropDownButtons(a, b)
    return a.order < b.order
end

---@param cdropdown LibDropDownExtension_DropDownList
local function ClearDropDown(cdropdown)
    for i = 1, #cdropdown.buttons do
        local button = cdropdown.buttons[i]
        button.option = nil
    end
    table.wipe(cdropdown.options)
end

---@param cdropdown LibDropDownExtension_DropDownList
---@param options LibDropDownExtension_Option[]
---@param orderOffset number
local function AppendDropDown(cdropdown, options, orderOffset)
    ---@type table<LibDropDownExtension_CustomDropDownButton, boolean?>
    local available = {}
    for i = 1, #cdropdown.buttons do
        local button = cdropdown.buttons[i]
        if not button.option then
            available[button] = true
        end
    end
    for i = 1, #options do
        local option = options[i]
        ---@type LibDropDownExtension_CustomDropDownButton
        local button = next(available)
        if not button then
            button = NewCustomDropDownButton(cdropdown)
            cdropdown.buttons[#cdropdown.buttons + 1] = button
        else
            available[button] = nil
        end
        button.order = orderOffset + i
        button.option = SanitizeCustomDropDownButtonOptions(option)
        cdropdown.options[#cdropdown.options + 1] = button.option
    end
end

---@param button LibDropDownExtension_CustomDropDownButton
local function RefreshButton(button)
    local option = button.option

    local icon = button.iconTexture
    local invisibleButton = button.invisibleButton

    button:SetDisabledFontObject(GameFontDisableSmallLeft)
    button:Enable()
    invisibleButton:Hide()

    if option.notClickable then
        option.disabled = true
        button:SetDisabledFontObject(GameFontHighlightSmallLeft)
    end

    if option.isTitle then
        option.disabled = true
        button:SetDisabledFontObject(GameFontNormalSmallLeft)
    end

    if option.disabled then
        button:Disable()
        invisibleButton:Show()
        option.colorCode = nil
    end

    if option.disablecolor then
        option.colorCode = option.disablecolor
    end

    if option.text then

        if option.colorCode then
            button:SetText(option.colorCode .. option.text .. "|r")
        else
            button:SetText(option.text)
        end

        if option.icon or option.mouseOverIcon then
            icon:ClearAllPoints()
            icon:SetPoint("RIGHT")
            icon:SetSize(16, 16)
            icon:SetTexture(option.icon or option.mouseOverIcon)
            if option.tCoordLeft then
                icon:SetTexCoord(option.tCoordLeft, option.tCoordRight, option.tCoordTop, option.tCoordBottom)
            else
                icon:SetTexCoord(0, 1, 0, 1)
            end
            icon:Show()
        else
            icon:Hide()
        end

        if option.fontObject then
            button:SetNormalFontObject(option.fontObject)
            button:SetHighlightFontObject(option.fontObject)
        else
            button:SetNormalFontObject(GameFontHighlightSmallLeft)
            button:SetHighlightFontObject(GameFontHighlightSmallLeft)
        end

    else
        button:SetText("")
        icon:Hide()
    end

    if option.iconInfo then
        icon.tFitDropDownSizeX = option.iconInfo.tFitDropDownSizeX
    else
        icon.tFitDropDownSizeX = nil
    end

    if option.iconOnly and option.icon then
        icon:ClearAllPoints()
        icon:SetPoint("LEFT")
        icon:SetWidth(option.iconInfo and option.iconInfo.tSizeX or 16)
        icon:SetHeight(option.iconInfo and option.iconInfo.tSizeY or 16)
        icon:SetTexture(option.icon)
        if option.iconInfo and option.iconInfo.tCoordLeft then
            icon:SetTexCoord(option.iconInfo.tCoordLeft, option.iconInfo.tCoordRight, option.iconInfo.tCoordTop, option.iconInfo.tCoordBottom)
        else
            icon:SetTexCoord(0, 1, 0, 1)
        end
        icon:Show()
    end

    local expandArrow = button.expandArrow
    expandArrow:SetPoint("RIGHT", option.arrowXOffset or 0, 0)
    expandArrow:SetShown(option.hasArrow)
    expandArrow:SetEnabled(not option.disabled)

    if option.iconOnly then
        icon:SetPoint("LEFT")
        icon:SetPoint("RIGHT", -5, 0)
    end

    --[=[
    local xPos = 5
    local displayInfo = button.normalText ---@type FontString|DropDownIconTexture
    if option.iconOnly then
        displayInfo = icon
    end

    displayInfo:ClearAllPoints()

    if option.notCheckable then
        if option.justifyH and option.justifyH == "CENTER" then
            displayInfo:SetPoint("CENTER", button, "CENTER", -7, 0)
        else
            displayInfo:SetPoint("LEFT", button, "LEFT", 0, 0)
        end
        xPos = xPos + 10
    else
        displayInfo:SetPoint("LEFT", button, "LEFT", 20, 0)
        xPos = xPos + 12
    end

    local frame = UIDROPDOWNMENU_OPEN_MENU
    if frame and frame.displayMode == "MENU" then
        if not option.notCheckable then
            xPos = xPos - 6
        end
    end

    frame = frame or UIDROPDOWNMENU_INIT_MENU
    if option.leftPadding then
        xPos = xPos + option.leftPadding
    end

    displayInfo:SetPoint("TOPLEFT", button, "TOPLEFT", xPos, 0)
    --]=]

    if not option.notCheckable then

        local check = button.check
        local uncheck = button.uncheck

        if option.disabled then
            check:SetDesaturated(true)
            check:SetAlpha(0.5)
            uncheck:SetDesaturated(true)
            uncheck:SetAlpha(0.5)
        else
            check:SetDesaturated(false)
            check:SetAlpha(1)
            uncheck:SetDesaturated(false)
            uncheck:SetAlpha(1)
        end

        if option.customCheckIconAtlas or option.customCheckIconTexture then
            check:SetTexCoord(0, 1, 0, 1)
            uncheck:SetTexCoord(0, 1, 0, 1)
            if option.customCheckIconAtlas then
                check:SetAtlas(option.customCheckIconAtlas)
                uncheck:SetAtlas(option.customUncheckIconAtlas or option.customCheckIconAtlas or "")
            else
                check:SetTexture(option.customCheckIconTexture)
                uncheck:SetTexture(option.customUncheckIconTexture or option.customCheckIconTexture)
            end
        elseif option.isNotRadio then
            check:SetTexCoord(0, 0.5, 0, 0.5)
            check:SetTexture("Interface\\Common\\UI-DropDownRadioChecks")
            uncheck:SetTexCoord(0.5, 1, 0, 0.5)
            uncheck:SetTexture("Interface\\Common\\UI-DropDownRadioChecks")
        else
            check:SetTexCoord(0, 0.5, 0.5, 1)
            check:SetTexture("Interface\\Common\\UI-DropDownRadioChecks")
            uncheck:SetTexCoord(0.5, 1, 0.5, 1)
            uncheck:SetTexture("Interface\\Common\\UI-DropDownRadioChecks")
        end
        local checked = CustomDropDownButtonIsChecked(button)
        if checked then
            button:LockHighlight()
            check:Show()
            uncheck:Hide()
        else
            button:UnlockHighlight()
            check:Hide()
            uncheck:Show()
        end

    else
        button.check:Hide()
        button.uncheck:Hide()
    end

    local colorSwatch = button.colorSwatch
    if option.hasColorSwatch then
        button.colorSwatchNormalTexture:SetVertexColor(option.r, option.g, option.b)
        colorSwatch:Show()
    else
        colorSwatch:Hide()
    end
end

---@param cdropdown LibDropDownExtension_DropDownList
local function RefreshButtons(cdropdown)
    local lastButton ---@type LibDropDownExtension_CustomDropDownButton?
    for i = 1, #cdropdown.buttons do
        local button = cdropdown.buttons[i]
        if not button.option then
            button.order = 1000000
        end
    end
    table.sort(cdropdown.buttons, SortDropDownButtons)
    for i = 1, #cdropdown.buttons do
        local button = cdropdown.buttons[i]
        if button.option then
            button:ClearAllPoints()
            if lastButton then
                button:SetPoint("TOPLEFT", lastButton, "BOTTOMLEFT", 0, 0)
            else
                button:SetPoint("TOPLEFT", cdropdown, "TOPLEFT", 15, -17)
            end
            RefreshButton(button)
            button:Show()
            lastButton = button
        else
            button:Hide()
        end
    end
    local numOptions = #cdropdown.options
    if numOptions > 0 then
        ---@type LibDropDownExtension_DropDownListPolyfill
        local parent = cdropdown:GetParent() ---@diagnostic disable-line: assign-type-mismatch
        parent:SetHeight(parent:GetHeight() + 16 * numOptions)
        cdropdown:ClearAllPoints()
        cdropdown:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
        cdropdown:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
        cdropdown:Show()
    else
        cdropdown:Hide()
    end
end

---@param dropdown LibDropDownExtension_DropDownListPolyfill
local function GetCustomDropDown(dropdown)
    local cdropdown = cdropdowns[dropdown]
    if not cdropdown then
        cdropdown = NewCustomDropDown(dropdown)
        cdropdowns[dropdown] = cdropdown
    end
    return cdropdown
end

---@param option LibDropDownExtension_Option
local function IsOptionValid(option)
    return type(option) == "table"
end

---@param options1 LibDropDownExtension_Option[]
---@param options2 LibDropDownExtension_Option[]
local function CopyOptions(options1, options2)
    table.wipe(options2)
    local index = 0
    for i = 1, #options1 do
        local option = options1[i]
        if IsOptionValid(option) then
            index = index + 1
            options2[index] = option
        end
    end
end

---@param options LibDropDownExtension_Option[]
local function RemoveInvalidOptions(options)
    for i = #options, 1, -1 do
        local option = options[i]
        if not IsOptionValid(option) then
            table.remove(options, i)
        end
    end
end

---@param self LibDropDownExtension_CustomDropDownButton
---@param level number
function CustomDropDownToggleMenu(self, level)
    local option = self.option
    local menuList = option.menuList
    if type(menuList) ~= "table" then
        return
    end
    local numButtons = #menuList
    if numButtons == 0 then
        return
    end
    local clevelMax = #cdropdownLists
    local clevel = level - 1
    clevel = (clevel < 1 and 1) or (clevel > clevelMax and clevelMax or clevel)
    local cdropdownList = cdropdownLists[clevel]
    cdropdownList.numButtons = numButtons
    cdropdownList:Hide()
    ---@diagnostic disable-next-line: assign-type-mismatch
    local cdropdown = self:GetParent() ---@type LibDropDownExtension_DropDownList|LibDropDownExtension_CustomDropDownList
    ---@type LibDropDownExtension_DropDownListPolyfill
    local parent = cdropdown:GetParent() ---@diagnostic disable-line: assign-type-mismatch
    if parent.hideBackdrops then
        cdropdownList.Backdrop:Hide()
        cdropdownList.MenuBackdrop:Hide()
    elseif not option.menuListDisplayMode or option.menuListDisplayMode == "MENU" then
        cdropdownList.Backdrop:Hide()
        cdropdownList.MenuBackdrop:Show()
    else
        cdropdownList.Backdrop:Show()
        cdropdownList.MenuBackdrop:Hide()
    end
    cdropdownList.parent = parent
    local width = 20
    local height = 20
    for index, menuListOption in ipairs(menuList) do
        local button = cdropdownList.buttons[index]
        if not button then
            button = NewCustomDropDownButton(cdropdownList)
            cdropdownList.buttons[index] = button
        end
        if index > 1 then
            button:SetPoint("TOPLEFT", cdropdownList.buttons[index - 1], "BOTTOMLEFT", 0, 0)
        else
            button:SetPoint("TOPLEFT", cdropdownList, "TOPLEFT", 10, -10)
        end
        button.order = index
        button.option = SanitizeCustomDropDownButtonOptions(menuListOption, true)
        cdropdownList.options[index] = button.option
        RefreshButton(button)
        button:Show()
        width = max(width, button:GetWidth())
        height = height + button:GetHeight()
    end
    for index = numButtons + 1, #cdropdownList.buttons do
        cdropdownList.options[index] = nil
        local button = cdropdownList.buttons[index]
        button:Hide()
    end
    cdropdownList:SetSize(width + 20, height)
    local xOffset = 0
    local yOffset = 14
    local point = "TOPLEFT"
    local relativePoint = "TOPRIGHT"
    cdropdownList:ClearAllPoints()
    cdropdownList:SetPoint(point, self, relativePoint, xOffset, yOffset)
    cdropdownList:Show()
    local x, y = cdropdownList:GetCenter()
    local offscreenY = y - cdropdownList:GetHeight()/2
    local offscreenX = cdropdownList:GetRight() > GetScreenWidth()
    if not offscreenY and not offscreenX then
        return
    end
    if offscreenY and offscreenX then
        point = gsub(point, "TOP(.*)", "BOTTOM%1")
        point = gsub(point, "(.*)LEFT", "%1RIGHT")
        relativePoint = gsub(relativePoint, "TOP(.*)", "BOTTOM%1")
        relativePoint = gsub(relativePoint, "(.*)RIGHT", "%1LEFT")
        xOffset = -11
        yOffset = -14
    elseif offscreenY then
        point = gsub(point, "TOP(.*)", "BOTTOM%1")
        relativePoint = gsub(relativePoint, "TOP(.*)", "BOTTOM%1")
        xOffset = 0
        yOffset = -14
    elseif offscreenX then
        point = gsub(point, "(.*)LEFT", "%1RIGHT")
        relativePoint = gsub(relativePoint, "(.*)RIGHT", "%1LEFT")
        xOffset = -11
        yOffset = 14
    end
    cdropdownList:ClearAllPoints()
    cdropdownList:SetPoint(point, self, relativePoint, xOffset, yOffset)
end

---@param event LibDropDownExtension_Event
---@param dropdown LibDropDownExtension_DropDownListPolyfill
function Lib:_Broadcast(event, dropdown)
    local level = dropdown:GetID()
    local cdropdown = GetCustomDropDown(dropdown)
    local shownSeparator ---@type boolean?
    ClearDropDown(cdropdown)
    for _, cdropdownList in ipairs(cdropdownLists) do
        cdropdownList:Hide()
    end
    for i = 1, #callbacks do
        local callback = callbacks[i]
        local callbackLevel = callback.events[event]
        if callbackLevel == true or callbackLevel == level then
            local status, retval = pcall(callback.func, dropdown.dropdown, event, callback.options, level, callback.data)
            if status and retval then
                if not shownSeparator and callback.options[1] then
                    shownSeparator = true
                    AppendDropDown(cdropdown, Lib._separatorTable, 0)
                end
                if type(retval) == "table" and retval ~= callback.options then
                    CopyOptions(retval, callback.options)
                else
                    RemoveInvalidOptions(callback.options)
                end
                AppendDropDown(cdropdown, callback.options, i * 100)
            end
        end
    end
    RefreshButtons(cdropdown)
end

---@param func LibDropDownExtension_CallbackFunc
---@return LibDropDownExtension_Callback?, number?
local function GetCallbackForFunc(func)
    for i = 1, #callbacks do
        local callback = callbacks[i]
        if callback.func == func then
            return callback, i
        end
    end
end

---@param self LibDropDownExtension_DropDownListPolyfill
local function DropDown_OnShow(self)
    Lib:_Broadcast("OnShow", self)
end

---@param self LibDropDownExtension_DropDownListPolyfill
local function DropDown_OnHide(self)
    Lib:_Broadcast("OnHide", self)
end

Lib._hooked = Lib._hooked or {}

for i = 1, 3 do
    local dropDownList = _G[format("DropDownList%d", i)] ---@type LibDropDownExtension_DropDownListPolyfill?
    if dropDownList and not Lib._hooked[dropDownList] then
        Lib._hooked[dropDownList] = true
        dropDownList:HookScript("OnShow", DropDown_OnShow)
        dropDownList:HookScript("OnHide", DropDown_OnHide)
    end
end

Lib.Option = Lib.Option or {}

Lib.Option.Separator = Lib.Option.Separator or {
    hasArrow = false,
    dist = 0,
    isTitle = true,
    isUninteractable = true,
    notCheckable = true,
    iconOnly = true,
    icon = "Interface\\Common\\UI-TooltipDivider-Transparent",
    tCoordLeft = 0,
    tCoordRight = 1,
    tCoordTop = 0,
    tCoordBottom = 1,
    tSizeX = 0,
    tSizeY = 8,
    tFitDropDownSizeX = true,
    iconInfo = {
        tCoordLeft = 0,
        tCoordRight = 1,
        tCoordTop = 0,
        tCoordBottom = 1,
        tSizeX = 0,
        tSizeY = 8,
        tFitDropDownSizeX = true
    }
}

Lib.Option.Space = Lib.Option.Space or {
    hasArrow = false,
    dist = 0,
    isTitle = true,
    isUninteractable = true,
    notCheckable = true
}

Lib._separatorTable = Lib._separatorTable or { Lib.Option.Separator }

---@generic T
---@param events LibDropDownExtension_Event|string
---@param func LibDropDownExtension_CallbackFunc
---@param levels (number|boolean)?
---@param data T?
---@return boolean success
function Lib:RegisterEvent(events, func, levels, data)
    assert(type(events) == "string" and type(func) == "function", "LibDropDownExtension:RegisterEvent(events, func[, levels][, data]) requires events to be a string and func a function. levels is an optional number 1, 2 or nil for any level.")
    local callback = GetCallbackForFunc(func)
    for _, event in ipairs({strsplit(" ", events)}) do
        if not callback then
            ---@type LibDropDownExtension_Callback
            callback = {
                events = {},
                func = func,
                options = {},
                data = type(data) == "table" and data or {},
            }
            callbacks[#callbacks + 1] = callback
        end
        callback.events[event] = levels or true
    end
    return callback ~= nil
end

---@param events LibDropDownExtension_Event|string
---@param func LibDropDownExtension_CallbackFunc
---@param levels (number|boolean)?
---@return boolean success
function Lib:UnregisterEvent(events, func, levels)
    assert(type(events) == "string" and type(func) == "function", "LibDropDownExtension:UnregisterEvent(events, func) requires events to be a string and func a function.")
    local callback, index = GetCallbackForFunc(func)
    if not callback then
        return false
    end
    for _, event in ipairs({strsplit(" ", events)}) do
        callback.events[event] = levels
    end
    if not next(callback.events) then
        table.remove(callbacks, index)
    end
    return true
end

--[=[

print(..., MAJOR, LibPrevMinor, "->", MINOR)

-- This is just to illustrate that you can create a custom table with structure and pass it along, and re-use it on each event.
-- You could also just deference this particular example code and just directly access `data#` variables, so it really depends
-- on your own code and use-case what the best approach is for you.

local data1 = { test1 = "One" } ---@class MyCustomDropDownTestData1
local data2 = { test2 = "Two" } ---@class MyCustomDropDownTestData2
local data3 = { test3 = "Three" } ---@class MyCustomDropDownTestData3

-- This will show its option on any dropdown list.

---@type LibDropDownExtension_Callback<MyCustomDropDownTestData1>
local function func1(dropdown, event, options, level, data)
    if event == "OnShow" then
        options[1] = { text = format("%s showns on all levels (random %d)", data.test1, random(1, 100)), tooltipOnButton = true, tooltipTitle = "Custom Tooltip Title", tooltipText = "Custom Tooltip Text" }
        return true
    else
        wipe(options)
    end
end

-- This will show its option on the first level only, but if the dropdown `which` also matches another criteria,
-- the additional option will be added for the player, a target player, and a target npc unit frame dropdowns.

---@type LibDropDownExtension_Callback<MyCustomDropDownTestData2>
local function func2(dropdown, event, options, level, data)
    if event == "OnShow" then
        options[1] = { text = format("%s showns on level %d (random %d)", data.test2, level, random(1, 100)) }
        local function func(button) print(button.option.text) end
        options[2] = { text = "Additional options", hasArrow = true, menuList = { { text = "Sub option 1", func = func }, { text = "Sub option 2", func = func }, { text = "Sub option 3", keepShownOnClick = true, func = func } } }
        if level == 1 then
            if dropdown.which == "SELF" then
                options[3] = { text = "It's you!", colorCode = "|cff55FFFF", keepShownOnClick = true }
            elseif dropdown.which == "PLAYER" then
                options[3] = { text = dropdown.name, colorCode = "|cff55FF55" }
            elseif dropdown.which == "TARGET" then
                options[3] = { text = dropdown.name, colorCode = "|cffFFFF55" }
            end
        end
        return true
    else
        wipe(options)
    end
end

-- This will show its option on the second level only, and if the dropdown `which` is yourself and the target marker menu,
-- it will display an additional flavored option.

---@type LibDropDownExtension_Callback<MyCustomDropDownTestData3>
local function func3(dropdown, event, options, level, data)
    if event == "OnShow" then
        options[1] = { text = format("%s showns on level %d (random %d)", data.test3, level, random(1, 100)) }
        if level == 2 and dropdown.which == "SELF" and UIDROPDOWNMENU_MENU_VALUE == 1 then ---@diagnostic disable-line: undefined-global
            options[2] = { text = "Put a star on yourself!" }
        end
        return true
    else
        wipe(options)
    end
end

-- This is how you register the functions to the various levels and pass their special data storage table.

Lib:RegisterEvent("OnShow OnHide", func1, true, data1)
Lib:RegisterEvent("OnShow OnHide", func2, 1, data2)
Lib:RegisterEvent("OnShow OnHide", func3, 2, data3)

--]=]

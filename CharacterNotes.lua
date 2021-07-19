local _G = getfenv(0)
local ADDON_NAME, addon = ...
addon.addonName = "CharacterNotes"

local string = _G.string
local table = _G.table
local math = _G.math
local pairs = _G.pairs
local ipairs = _G.ipairs
local select = _G.select
local LibStub = _G.LibStub

local wrap = addon.wrap
local Colors = addon.Colors
local ColumnIds = addon.ColumnIds
local ColorObjs = addon.ColorObjs
local GetRatingColor = addon.GetRatingColor
local GetRatingColorObj = addon.GetRatingColorObj
local GetRatingImage = addon.GetRatingImage

local CharacterNotes = LibStub("AceAddon-3.0"):NewAddon(addon.addonName, "AceConsole-3.0", "AceHook-3.0", "AceEvent-3.0", "AceTimer-3.0")

local ADDON_VERSION = "@project-version@"

local NotesDB = addon.NotesDB

-- Local versions for performance
local tinsert, tremove, tconcat = table.insert, table.remove, table.concat
local sub = string.sub
local wipe = _G.wipe

local L = LibStub("AceLocale-3.0"):GetLocale(addon.addonName, true)
local AGU = LibStub("AceGUI-3.0")
local LibDeformat = LibStub("LibDeformat-3.0")
local LDB = LibStub("LibDataBroker-1.1")
local icon = LibStub("LibDBIcon-1.0")
local LSM = _G.LibStub:GetLibrary("LibSharedMedia-3.0")
local LibAlts = LibStub("LibAlts-1.0")

-- String formats
addon.Formats = {
  chatNote = "%s%s: "..Colors.White.."%s".."|r",
  chatNoteWithMain = "%s%s (%s): "..Colors.White.."%s".."|r",
  tooltipNote = "%s"..L["Note: "]..Colors.White.."%s".."|r",
  tooltipNoteWithMain = "%s"..L["Note"].." (%s): "..Colors.White.."%s".."|r",
  nameRating = "%s%s".."|r",
  nameWithMainRating = "%s%s (%s)".."|r",
}
local Formats = addon.Formats

local CharNoteTooltip = nil

local defaults = {
	profile = {
		minimap = {
			hide = true,
		},
		verbose = true,
		debug = false,
		fontFace = "Friz Quadrata TT",
		fontSize = 12,
		fontFlags = {
			OUTLINE = true,
			THICKOUTLINE = false,
			MONOCHROME = false
		},
		mouseoverHighlighting = true,
		showNotesOnWho = true,
		showNotesOnLogon = true,
		showNotesInTooltips = true,
		noteLinksInChat = true,
		useLibAlts = true,
		addMenuItems = false,
		wrapTooltip = true,
		wrapTooltipLength = 50,
		notesForRaidMembers = false,
		notesForPartyMembers = false,
		lock_main_window = false,
		remember_main_pos = true,
		notes_window_x = 0,
		notes_window_y = 0,
		remember_tooltip_pos = true,
		lock_tooltip = false,
		note_tooltip_x = nil,
		note_tooltip_y = nil,
		exportUseName = true,
		exportUseNote = true,
		exportUseRating = true,
		exportEscape = true,
		importOverwrite = false,
    	multilineNotes = false,
    	uiModifications = {
			["unitMenusEdit"] = true,
			["LFGLeaderTooltip"] = true,
			["LFGApplicantTooltip"] = true,
			["LFGGroupMenuEditNote"] = true,
			["GuildRosterTooltip"] = true,
			["CommunitiesTooltip"] = true,
			["ignoreTooltips"] = true,
    	}
	},
	realm = {
	    notes = {},
	    ratings = {}
	}
}

local noteLDB = nil
local notesFrame = nil
local editNoteFrame = nil
local confirmDeleteFrame = nil
local notesData = {}
local previousGroup = {}
local playerName = _G.GetUnitName("player", true)

function CharacterNotes:ShowOptions()
	_G.InterfaceOptionsFrame_OpenToCategory(self.optionsFrame.Main)
end

function CharacterNotes:OnProfileChange()
  addon.db = self.db
end

addon.fontFlags = {}
function CharacterNotes:GetFontSettings()
	wipe(addon.fontFlags)
	for k, v in pairs(addon.db.profile.fontFlags) do
			if v then tinsert(addon.fontFlags, k) end
	end
	local font = LSM:Fetch("font", addon.db.profile.fontFace)
	return font, addon.db.profile.fontSize, tconcat(addon.fontFlags, ",")
end
addon.GetFontSettings = CharacterNotes.GetFontSettings

function CharacterNotes:OnInitialize()
    -- Called when the addon is loaded
    self.db = LibStub("AceDB-3.0"):New("CharacterNotesDB", defaults, "Default")

  self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChange")
  self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChange")
  self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChange")
  addon.db = self.db

	NotesDB:OnInitialize(self)

	-- Migrate the names for patch 5.4
	self:RemoveSpacesFromRealm()

	-- Build the table data for the Notes window
	self:BuildTableData()

  -- Register the options table
  --LibStub("AceConfig-3.0"):RegisterOptionsTable("CharacterNotes", self:GetOptions())
	--self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(
	--    "CharacterNotes", ADDON_NAME)

  -- Register the options table
  local displayName = _G.GetAddOnMetadata(ADDON_NAME, "Title")
	self.options = self:GetOptions()
  LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(displayName, self.options)
  self.optionsFrame = {}
  local ACD = LibStub("AceConfigDialog-3.0")
	self.optionsFrame.Main = ACD:AddToBlizOptions(
	    displayName, displayName, nil, "core")
	self.optionsFrame.Notes = ACD:AddToBlizOptions(
	    displayName, L["Import/Export"], displayName, "export")

	self:RegisterChatCommand("setnote", "SetNoteHandler")
	self:RegisterChatCommand("delnote", "DelNoteHandler")
	self:RegisterChatCommand("setrating", "SetRatingHandler")
	self:RegisterChatCommand("delrating", "DelRatingHandler")
	self:RegisterChatCommand("getnote", "GetNoteHandler")
	self:RegisterChatCommand("editnote", "EditNoteHandler")
	self:RegisterChatCommand("notes", "NotesHandler")
	self:RegisterChatCommand("notesoptions", "NotesOptionsHandler")
	self:RegisterChatCommand("searchnote", "NotesHandler")
	self:RegisterChatCommand("notesexport", "NotesExportHandler")
	self:RegisterChatCommand("notesimport", "NotesImportHandler")
	self:RegisterChatCommand("notesdbcheck", "NotesDBCheckHandler")

	-- Create the LDB launcher
	noteLDB = LDB:NewDataObject("CharacterNotes",{
		type = "launcher",
		icon = "Interface\\Icons\\INV_Misc_Note_06.blp",
		OnClick = function(clickedframe, button)
    		if button == "RightButton" then
    			local optionsFrame = _G.InterfaceOptionsFrame

    			if optionsFrame:IsVisible() then
    				optionsFrame:Hide()
    			else
    			    self:HideNotesWindow()
    				self:ShowOptions()
    			end
    		elseif button == "LeftButton" then
    			if self:IsNotesVisible() then
    				self:HideNotesWindow()
    			else
        			local optionsFrame = _G.InterfaceOptionsFrame
    			    optionsFrame:Hide()
    				self:NotesHandler("")
    			end
            end
		end,
		OnTooltipShow = function(tooltip)
			if tooltip and tooltip.AddLine then
				tooltip:AddLine(Colors.Green .. L["Character Notes"].." "..ADDON_VERSION)
				tooltip:AddLine(Colors.Yellow .. L["Left click"] .. " " .. Colors.White
					.. L["to open/close the window"])
				tooltip:AddLine(Colors.Yellow .. L["Right click"] .. " " .. Colors.White
					.. L["to open/close the configuration."])
			end
		end
	})
	icon:Register("CharacterNotesLDB", noteLDB, self.db.profile.minimap)

	if not CharNoteTooltip then
	    self:CreateCharNoteTooltip()
    end

	-- Hook any new temporary windows
	self:SecureHook("FCF_SetTemporaryWindowType")
	self:SecureHook("FCF_Close")

  self:EnableInterfaceModifications()
end

function CharacterNotes:CreateCharNoteTooltip()
    CharNoteTooltip = _G.CreateFrame("GameTooltip", "CharNoteTooltip", _G.UIParent, "GameTooltipTemplate")
    CharNoteTooltip:SetOwner(_G.WorldFrame, "ANCHOR_NONE")
	CharNoteTooltip:SetFrameStrata("DIALOG")
    CharNoteTooltip:SetSize(100,100)
    CharNoteTooltip:SetPadding(16,0)
    if self.db.profile.remember_tooltip_pos == false or self.db.profile.tooltip_x == nil or self.db.profile.tooltip_y == nil then
        CharNoteTooltip:SetPoint("TOPLEFT", "ChatFrame1", "TOPRIGHT", 20, 0)
    else
        CharNoteTooltip:SetPoint("CENTER", _G.UIParent, "CENTER", self.db.profile.tooltip_x, self.db.profile.tooltip_y)
    end
	CharNoteTooltip:EnableMouse(true)
	CharNoteTooltip:SetToplevel(true)
    CharNoteTooltip:SetMovable(true)
    _G.GameTooltip_OnLoad(CharNoteTooltip)
    CharNoteTooltip:SetUserPlaced(false)

	CharNoteTooltip:RegisterForDrag("LeftButton")
	CharNoteTooltip:SetScript("OnDragStart", function(self)
	    if not CharacterNotes.db.profile.lock_tooltip then
		    self:StartMoving()
		end
	end)
	CharNoteTooltip:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local scale = self:GetEffectiveScale() / _G.UIParent:GetEffectiveScale()
		local x, y = self:GetCenter()
		x, y = x * scale, y * scale
		x = x - _G.GetScreenWidth()/2
		y = y - _G.GetScreenHeight()/2
		x = x / self:GetScale()
		y = y / self:GetScale()
		CharacterNotes.db.profile.tooltip_x, CharacterNotes.db.profile.tooltip_y = x, y
		self:SetUserPlaced(false);
	end)

	local closebutton = _G.CreateFrame("Button", "CharNoteTooltipCloseButton", CharNoteTooltip)
	closebutton:SetSize(32,32)
	closebutton:SetPoint("TOPRIGHT", 1, 0)

	closebutton:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
	closebutton:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
	closebutton:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")

	closebutton:SetScript("OnClick", function(self)
	    _G.HideUIPanel(CharNoteTooltip)
	end)
end

function CharacterNotes:FCF_SetTemporaryWindowType(chatFrame, chatType, chatTarget)
	if chatFrame and not self:IsHooked(chatFrame, "AddMessage") then
	    self:RawHook(chatFrame, "AddMessage", true)
    end
end

function CharacterNotes:FCF_Close(frame, fallback)
    if frame and self:IsHooked(frame, "AddMessage") then
        self:Unhook(frame, "AddMessage")
    end
end

function CharacterNotes:SetNoteHandler(input)
	if input and #input > 0 then
		local name, note = input:match("^(%S+) *(.*)")

		if name and name:upper() == "%T" then
			if _G.UnitExists("target") and _G.UnitIsPlayer("target") then
				local target = _G.GetUnitName("target", true)
				if target and #target > 0 then
					name = target
				end
			end
		end

		name = NotesDB:FormatUnitName(name)
		if note and #note > 0 then
			NotesDB:SetNote(name, note)
			if self.db.profile.verbose == true then
				local strFormat = L["Set note for %s: %s"]
				self:Print(strFormat:format(name, note))
			end
		else
			self:Print(L["You must supply a note."])
		end
	end
end

function CharacterNotes:DelNoteHandler(input)
	local name, note = nil, nil
	if input and #input > 0 then
		name, note = input:match("^(%S+) *(.*)")
	else
		if _G.UnitExists("target") and _G.UnitIsPlayer("target") then
			local target = _G.GetUnitName("target", true)
			if target and #target > 0 then
				name = target
			end
		end
	end

	if name and #name > 0 then
		name = NotesDB:FormatUnitName(name)
		NotesDB:DeleteNote(name)
		if self.db.profile.verbose == true then
			local strFormat = L["Deleted note for %s"]
			self:Print(strFormat:format(name))
		end
	end
end

function CharacterNotes:SetRatingHandler(input)
	if input and #input > 0 then
		local name, rating = input:match("^(%S+) *(.*)")

		if name and name:upper() == "%T" then
			if _G.UnitExists("target") and _G.UnitIsPlayer("target") then
				local target = _G.GetUnitName("target", true)
				if target and #target > 0 then
					name = target
				end
			end
		end

		if name and #name and rating and #rating > 0 then
			name = NotesDB:FormatUnitName(name)
			NotesDB:SetRating(name, tonumber(rating))
			if self.db.profile.verbose == true then
				local strFormat = L["Set rating for %s: %d"]
				self:Print(strFormat:format(name, tonumber(rating)))
			end
		else
			self:Print(L["You must supply a rating (-1, 0, 1)."])
		end
	end
end

function CharacterNotes:DelRatingHandler(input)
	local name, note = nil, nil
	if input and #input > 0 then
		name, note = input:match("^(%S+) *(.*)")
	else
		if _G.UnitExists("target") and _G.UnitIsPlayer("target") then
			local target = _G.GetUnitName("target", true)
			if target and #target > 0 then
				name = target
			end
		end
	end

	if name and #name > 0 then
		name = NotesDB:FormatUnitName(name)
		NotesDB:DeleteRating(name)
		if self.db.profile.verbose == true then
			local strFormat = L["Deleted rating for %s"]
			self:Print(strFormat:format(name))
		end
	end
end

function CharacterNotes:UpdateNote(name, note)
	local found = false
	for i, v in ipairs(notesData) do
		if v[ColumnIds.Name] == name then
			notesData[i][ColumnIds.Note] = note
			found = true
		end
	end

	if found == false then
		tinsert(notesData, {
		    [ColumnIds.Rating] = (NotesDB:GetRating(name) or 0),
		    [ColumnIds.Name] = name,
		    [ColumnIds.Note] = note})
	end

	-- If the Notes window is shown then we need to update it
	if notesFrame:IsVisible() then
		notesFrame.table:SortData()
	end
end

function CharacterNotes:UpdateRating(name, rating)
	local found = false
	for i, v in ipairs(notesData) do
		if v[ColumnIds.Name] == name then
			notesData[i][ColumnIds.Rating] = rating
			found = true
		end
	end

	if found == false then
		tinsert(notesData, {
		    [ColumnIds.Rating] = rating,
		    [ColumnIds.Name] = name,
		    [ColumnIds.Note] = NotesDB:GetNote(name)})
	end

	-- If the Notes window is shown then we need to update it
	if notesFrame:IsVisible() then
		notesFrame.table:SortData()
	end
end

function CharacterNotes:RemoveNote(name)
	for i, v in ipairs(notesData) do
		if v[ColumnIds.Name] == name then
		    tremove(notesData, i)
		end
	end

	-- If the Notes window is shown then we need to update it
	if notesFrame:IsVisible() then
		notesFrame.table:SortData()
	end
end

function CharacterNotes:RemoveRating(name)
	for i, v in ipairs(notesData) do
		if v[ColumnIds.Name] == name then
		    if v[ColumnIds.Note] == nil then
			    tremove(notesData, i)
            else
                v[ColumnIds.Rating] = 0
            end
		end
	end

	-- If the Notes window is shown then we need to update it
	if notesFrame:IsVisible() then
		notesFrame.table:SortData()
	end
end

function CharacterNotes:GetNoteHandler(input)
	if input and #input > 0 then
		local name, note = input:match("^(%S+) *(.*)")
		name = NotesDB:FormatUnitName(name)

        local note, rating, main, nameFound = NotesDB:GetInfoForNameOrMain(name)

		if note then
		    if main and #main > 0 then
			    self:Print(Formats.chatNoteWithMain:format(
			        GetRatingColor(rating), name, nameFound, note or ""))
	        else
			    self:Print(Formats.chatNote:format(
			        GetRatingColor(rating), nameFound, note or ""))
			end
		else
			self:Print(L["No note found for "]..name)
		end
	end
end

function CharacterNotes:NotesExportHandler(input)
    self:ShowNotesExportFrame()
end

function CharacterNotes:NotesImportHandler(input)
    self:ShowNotesImportFrame()
end

function CharacterNotes:UpdateMouseoverHighlighting(enabled)
    if notesFrame and notesFrame.table then
        local table = notesFrame.table
        if enabled then
    	    table:RegisterEvents(table.DefaultEvents)
        else
        	table:RegisterEvents({
        		["OnEnter"] = function (rowFrame, cellFrame, data, cols, row, realrow, column, table, ...)
        			return true;
        		end,
        		["OnLeave"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, ...)
        			return true;
        		end
        	})
        end
    end
end

local function escapeField(value, escapeChar)
    local strFmt = "%s%s%s"
    local doubleEscape = escapeChar..escapeChar
    if escapeChar and escapeChar ~= "" then
        local escapedStr = value:gsub(escapeChar, doubleEscape)
        return strFmt:format(escapeChar, escapedStr, escapeChar)
    else
        return value
    end
end

local notesExportBuffer = {}
function CharacterNotes:GenerateNotesExport()
    local notesExportText = ""

    local delimiter = ","
    local fields = {}
    local quote = ""
    local rating
    if self.db.profile.exportEscape == true then
        quote = "\""
    end

    for name, note in pairs(self.db.realm.notes) do
        wipe(fields)
        if self.db.profile.exportUseName == true then
            tinsert(fields, escapeField(name, quote))
        end
        if self.db.profile.exportUseNote == true then
            tinsert(fields, escapeField(note, quote))
        end
        if self.db.profile.exportUseRating == true then
            rating = (NotesDB:GetRating(name) or 0)
            tinsert(fields, rating)
        end

        local line = tconcat(fields, delimiter)
        tinsert(notesExportBuffer, line)
    end

    -- Add a blank line so a final new line is added
    tinsert(notesExportBuffer, "")
    notesExportText = tconcat(notesExportBuffer, "\n")
    wipe(notesExportBuffer)
    return notesExportText
end

function CharacterNotes:ShowNotesExportFrame()
    if addon.NotesExportFrame then return end

	local frame = AGU:Create("Frame")
	frame:SetTitle(L["Notes Export"])
	frame:SetWidth(650)
	frame:SetHeight(400)
    frame:SetLayout("Flow")
	frame:SetCallback("OnClose", function(widget)
		widget:ReleaseChildren()
		widget:Release()
		addon.NotesExportFrame = nil
	end)

    addon.NotesExportFrame = frame

    local multiline = AGU:Create("MultiLineEditBox")
    multiline:SetLabel(L["NotesExport_ExportLabel"])
    multiline:SetNumLines(10)
    multiline:SetMaxLetters(0)
    multiline:SetFullWidth(true)
    multiline:DisableButton(true)
    frame:AddChild(multiline)
    frame.multiline = multiline

    local fieldsHeading =  AGU:Create("Heading")
    fieldsHeading:SetText(L["Fields to Export"])
    fieldsHeading:SetFullWidth(true)
    frame:AddChild(fieldsHeading)

    local nameOption = AGU:Create("CheckBox")
    nameOption:SetLabel(L["Character Name"])
    nameOption:SetCallback("OnValueChanged",
        function(widget, event, value)
            self.db.profile.exportUseName = value
        end
    )
    nameOption:SetValue(self.db.profile.exportUseName)
    frame:AddChild(nameOption)

    local noteOption = AGU:Create("CheckBox")
    noteOption:SetLabel(L["Note"])
    noteOption:SetCallback("OnValueChanged",
        function(widget, event, value)
            self.db.profile.exportUseNote = value
        end
    )
    noteOption:SetValue(self.db.profile.exportUseNote)
    frame:AddChild(noteOption)

    local ratingOption = AGU:Create("CheckBox")
    ratingOption:SetLabel(L["Rating"])
    ratingOption:SetCallback("OnValueChanged",
        function(widget, event, value)
            self.db.profile.exportUseRating = value
        end
    )
    ratingOption:SetValue(self.db.profile.exportUseRating)
    frame:AddChild(ratingOption)

    local optionsHeading = AGU:Create("Heading")
    optionsHeading:SetText(L["Options"])
    optionsHeading:SetFullWidth(true)
    frame:AddChild(optionsHeading)

    local escapeOption = AGU:Create("CheckBox")
    escapeOption:SetLabel(L["NotesExport_Escape"])
    escapeOption:SetCallback("OnValueChanged",
        function(widget, event, value)
            self.db.profile.exportEscape = value
        end
    )
    escapeOption:SetValue(self.db.profile.exportEscape)
    frame:AddChild(escapeOption)

    local spacer = AGU:Create("Label")
    spacer:SetText(" ")
    spacer:SetFullWidth(true)
    frame:AddChild(spacer)

    local exportButton = AGU:Create("Button")
    exportButton:SetText(L["Export"])
    exportButton:SetCallback("OnClick",
        function(widget)
            local notesExportText = CharacterNotes:GenerateNotesExport(
                self.db.profile.exportUseName,
                self.db.profile.exportUseNotes,
                self.db.profile.exportUseRating
            )
            frame.multiline:SetText(notesExportText)
        end)
    frame:AddChild(exportButton)

end

function CharacterNotes:CreateNotesFrame()
	local noteswindow = _G.CreateFrame("Frame", "CharacterNotesWindow", _G.UIParent, BackdropTemplateMixin and "BackdropTemplate")
	noteswindow:SetFrameStrata("DIALOG")
	noteswindow:SetToplevel(true)
	noteswindow:SetWidth(630)
	noteswindow:SetHeight(430)
	if self.db.profile.remember_main_pos then
    	noteswindow:SetPoint("CENTER", _G.UIParent, "CENTER",
    	    self.db.profile.notes_window_x, self.db.profile.notes_window_y)
    else
    	noteswindow:SetPoint("CENTER", _G.UIParent)
    end
	noteswindow:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
	    edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true,
		tileSize=32, edgeSize=32, insets={left=11, right=12, top=12, bottom=11}})

	local ScrollingTable = LibStub("ScrollingTable");

	local cols = {}
    cols[ColumnIds.Rating] = {
		["name"] = L["RATING_COLUMN_NAME"],
		["width"] = 15,
		["colorargs"] = nil,
		["bgcolor"] = {
			["r"] = 0.0,
			["g"] = 0.0,
			["b"] = 0.0,
			["a"] = 1.0
		},
		["sortnext"] = ColumnIds.Name,
	  	["DoCellUpdate"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, self, ...)
	  	    if fShow then
						if not cellFrame.rating then
							cellFrame.rating = cellFrame:CreateTexture(nil, "BACKGROUND")
							cellFrame.rating:SetAllPoints()
						end

		        local image = GetRatingImage(data[realrow][ColumnIds.Rating])
		        if image and #image > 0 then
							cellFrame.rating:SetTexture(image)
		        else
							cellFrame.rating:SetTexture(nil)
						end
		    end
	  	end,
    }
	cols[ColumnIds.Name] = {
		["name"] = L["Character Name"],
		["width"] = 150,
		["align"] = "LEFT",
		["color"] = function(data, cols, realrow, column, table)
		    return GetRatingColorObj(data[realrow][ColumnIds.Rating])
	    end,
		["colorargs"] = nil,
		["bgcolor"] = {
			["r"] = 0.0,
			["g"] = 0.0,
			["b"] = 0.0,
			["a"] = 1.0
		},
		["defaultsort"] = "dsc",
		["sort"] = "dsc",
		["DoCellUpdate"] = nil,
	}
	cols[ColumnIds.Note] = {
		["name"] = L["Note"],
		["width"] = 400,
		["align"] = "LEFT",
		["color"] = {
			["r"] = 1.0,
			["g"] = 1.0,
			["b"] = 1.0,
			["a"] = 1.0
		},
		["colorargs"] = nil,
		["bgcolor"] = {
			["r"] = 0.0,
			["g"] = 0.0,
			["b"] = 0.0,
			["a"] = 1.0
		},
		["sortnext"] = ColumnIds.Name,
		["DoCellUpdate"] = nil,
	}

	local table = ScrollingTable:CreateST(cols, 15, nil, nil, noteswindow);

	local font, fh, fflags = addon.GetFontSettings()

	local headertext = noteswindow:CreateFontString("CN_Notes_HeaderText", "OVERLAY")
	headertext:SetFont(font, fh + 4, fflags)
	headertext:SetPoint("TOP", noteswindow, "TOP", 0, -20)
	headertext:SetText(L["Character Notes"])

	local searchterm = _G.CreateFrame("EditBox", nil, noteswindow, "InputBoxTemplate")
	searchterm:SetFontObject(_G.ChatFontNormal)
	searchterm:SetWidth(300)
	searchterm:SetHeight(35)
	searchterm:SetPoint("TOPLEFT", noteswindow, "TOPLEFT", 25, -50)
	searchterm:SetScript("OnShow", function(this) this:SetFocus() end)
	searchterm:SetScript("OnEnterPressed", function(this) this:GetParent().table:SortData() end)
	searchterm:SetScript("OnEscapePressed",
	    function(this)
	        this:SetText("")
	        this:GetParent():Hide()
	    end)

	table.frame:SetPoint("TOP", searchterm, "BOTTOM", 0, -20)
	table.frame:SetPoint("LEFT", noteswindow, "LEFT", 20, 0)

	local searchbutton = _G.CreateFrame("Button", nil, noteswindow, "UIPanelButtonTemplate")
	searchbutton:SetText(L["Search"])
	searchbutton:SetWidth(100)
	searchbutton:SetHeight(20)
	searchbutton:SetPoint("LEFT", searchterm, "RIGHT", 10, 0)
	searchbutton:SetScript("OnClick", function(this) this:GetParent().table:SortData() end)

	local clearbutton = _G.CreateFrame("Button", nil, noteswindow, "UIPanelButtonTemplate")
	clearbutton:SetText(L["Clear"])
	clearbutton:SetWidth(100)
	clearbutton:SetHeight(20)
	clearbutton:SetPoint("LEFT", searchbutton, "RIGHT", 10, 0)
	clearbutton:SetScript("OnClick",
	    function(this)
	        searchterm:SetText("")
	        this:GetParent().table:SortData()
	    end)

	local closebutton = _G.CreateFrame("Button", nil, noteswindow, "UIPanelButtonTemplate")
	closebutton:SetText(L["Close"])
	closebutton:SetWidth(90)
	closebutton:SetHeight(20)
	closebutton:SetPoint("BOTTOM", noteswindow, "BOTTOM", 0, 20)
	closebutton:SetScript("OnClick", function(this) this:GetParent():Hide(); end)

	local deletebutton = _G.CreateFrame("Button", nil, noteswindow, "UIPanelButtonTemplate")
	deletebutton:SetText(L["Delete"])
	deletebutton:SetWidth(90)
	deletebutton:SetHeight(20)
	deletebutton:SetPoint("BOTTOM", noteswindow, "BOTTOM", -60, 70)
	deletebutton:SetScript("OnClick",
		function(this)
		    local frame = this:GetParent()
			if frame.table:GetSelection() then
				local row = frame.table:GetRow(frame.table:GetSelection())
				if row and row[ColumnIds.Name] and #row[ColumnIds.Name] > 0 then
					confirmDeleteFrame.charname:SetText(row[ColumnIds.Name])
					confirmDeleteFrame:Show()
					confirmDeleteFrame:Raise()
				end
			end
		end)

	local editbutton = _G.CreateFrame("Button", nil, noteswindow, "UIPanelButtonTemplate")
	editbutton:SetText(L["Edit"])
	editbutton:SetWidth(90)
	editbutton:SetHeight(20)
	editbutton:SetPoint("BOTTOM", noteswindow, "BOTTOM", 60, 70)
	editbutton:SetScript("OnClick",
		function(this)
		    local frame = this:GetParent()
			if frame.table:GetSelection() then
				local row = frame.table:GetRow(frame.table:GetSelection())
				if row and row[ColumnIds.Name] and #row[ColumnIds.Name] > 0 then
					self:EditNoteHandler(row[ColumnIds.Name])
				end
			end
		end)

	noteswindow.table = table
	noteswindow.searchterm = searchterm

    if self.db.profile.mouseoverHighlighting then
	    table:RegisterEvents(table.DefaultEvents)
	else
    	table:RegisterEvents({
    		["OnEnter"] = function (rowFrame, cellFrame, data, cols, row, realrow, column, table, ...)
    			return true;
    		end,
    		["OnLeave"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, table, ...)
    			return true;
    		end
    	})
    end

	table:EnableSelection(true)
	table:SetData(notesData, true)
	table:SetFilter(
		function(self, row)
			local searchterm = searchterm:GetText():lower()
			if searchterm and #searchterm > 0 then
				local term = searchterm:lower()
				if row[ColumnIds.Name]:lower():find(term) or row[ColumnIds.Note]:lower():find(term) then
					return true
				end

				return false
			else
				return true
			end
		end
	)

    noteswindow.lock = self.db.profile.lock_main_window

    noteswindow:SetMovable(true)
    noteswindow:RegisterForDrag("LeftButton")
    noteswindow:SetScript("OnDragStart",
        function(self,button)
			if not self.lock then
            	self:StartMoving()
			end
        end)
    noteswindow:SetScript("OnDragStop",
        function(self)
            self:StopMovingOrSizing()
			if CharacterNotes.db.profile.remember_main_pos then
    			local scale = self:GetEffectiveScale() / _G.UIParent:GetEffectiveScale()
    			local x, y = self:GetCenter()
    			x, y = x * scale, y * scale
    			x = x - _G.GetScreenWidth()/2
    			y = y - _G.GetScreenHeight()/2
    			x = x / self:GetScale()
    			y = y / self:GetScale()
    			CharacterNotes.db.profile.notes_window_x,
    			    CharacterNotes.db.profile.notes_window_y = x, y
    			self:SetUserPlaced(false);
            end
        end)
    noteswindow:EnableMouse(true)
	noteswindow:Hide()
	return noteswindow
end

function CharacterNotes:NotesHandler(input)
	if input and #input > 0 then
		notesFrame.searchterm:SetText(input)
	else
		notesFrame.searchterm:SetText("")
	end

	notesFrame.table:SortData()
	notesFrame:Show()
	notesFrame:Raise()
end

local function splitWords(str)
  local w = {}
  local function helper(word) table.insert(w, word) return nil end
  str:gsub("(%w+)", helper)
  return w
end

function CharacterNotes:NotesOptionsHandler(input)
	if input and #input > 0 then
		local cmds = splitWords(input)
        if cmds[1] and cmds[1] == "debug" then
			if cmds[2] and cmds[2] == "on" then
				self.db.profile.debug = true
	            self:Print("Debugging on.  Use '/notesoptions debug off' to disable.")
		    elseif cmds[2] and cmds[2] == "off" then
				self.db.profile.debug = false
	            self:Print("Debugging off.")
			else
				self:Print("Debugging is "..(self.db.profile.debug and "on." or "off."))
			end
		end
	else
		self:ShowOptions()
	end
end

function CharacterNotes:NotesDBCheckHandler(input)
    for name, note in pairs(self.db.realm.notes) do
        if name then
            if name ~= NotesDB:FormatUnitName(name) then
                self:Print("Name "..name.." doesn't match the formatted name.")
            end
        else
            self:Print("Found a note with a nil name value. ["..note or "nil".."]")
        end
    end

    self:Print("Note DB Check finished.")
end

function CharacterNotes:CreateConfirmDeleteFrame()
	local font, fh, fflags = addon.GetFontSettings()
	local deletewindow = _G.CreateFrame("Frame", "CharacterNotesConfirmDeleteWindow", _G.UIParent, BackdropTemplateMixin and "BackdropTemplate")
	deletewindow:SetFrameStrata("DIALOG")
	deletewindow:SetToplevel(true)
	deletewindow:SetWidth(400)
	deletewindow:SetHeight(200)
	deletewindow:SetPoint("CENTER", _G.UIParent)
	deletewindow:SetBackdrop(
		{bgFile="Interface\\ChatFrame\\ChatFrameBackground",
	    edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true,
		tileSize=32, edgeSize=32, insets={left=11, right=12, top=12, bottom=11}})
	deletewindow:SetBackdropColor(0,0,0,1)

	local headertext = deletewindow:CreateFontString("CN_Confirm_HeaderText", "OVERLAY")
	headertext:SetFont(font, fh + 4, fflags)
	headertext:SetPoint("TOP", deletewindow, "TOP", 0, -20)
	headertext:SetText(L["Delete Note"])

	local warningtext = deletewindow:CreateFontString("CN_Confirm_WarningText", "OVERLAY")
	warningtext:SetFont(font, fh, fflags)
	warningtext:SetPoint("TOP", headertext, "TOP", 0, -40)
	warningtext:SetText(L["Are you sure you wish to delete the note for:"])

	local charname = deletewindow:CreateFontString("CN_Confirm_CharName", "OVERLAY")
	charname:SetFont(font, fh, fflags)
	charname:SetPoint("BOTTOM", warningtext, "BOTTOM", 0, -40)
	charname:SetFont(charname:GetFont(), 14)
	charname:SetTextColor(1.0,1.0,1.0,1)

	local deletebutton = _G.CreateFrame("Button", nil, deletewindow, "UIPanelButtonTemplate")
	deletebutton:SetText(L["Delete"])
	deletebutton:SetWidth(100)
	deletebutton:SetHeight(20)
	deletebutton:SetPoint("BOTTOM", deletewindow, "BOTTOM", -60, 20)
	deletebutton:SetScript("OnClick",
	    function(this)
	        NotesDB:DeleteNote(charname:GetText())
	        this:GetParent():Hide()
	    end)

	local cancelbutton = _G.CreateFrame("Button", nil, deletewindow, "UIPanelButtonTemplate")
	cancelbutton:SetText(L["Cancel"])
	cancelbutton:SetWidth(100)
	cancelbutton:SetHeight(20)
	cancelbutton:SetPoint("BOTTOM", deletewindow, "BOTTOM", 60, 20)
	cancelbutton:SetScript("OnClick", function(this) this:GetParent():Hide(); end)

	deletewindow.charname = charname

    deletewindow:SetMovable(true)
    deletewindow:RegisterForDrag("LeftButton")
    deletewindow:SetScript("OnDragStart",
        function(this,button)
        	this:StartMoving()
        end)
    deletewindow:SetScript("OnDragStop",
        function(this)
            this:StopMovingOrSizing()
        end)
    deletewindow:EnableMouse(true)

	deletewindow:Hide()

	return deletewindow
end

function CharacterNotes:CreateEditNoteFrame()
	local font, fh, fflags = addon.GetFontSettings()
	local editwindow = _G.CreateFrame("Frame", "CharacterNotesEditWindow", _G.UIParent, BackdropTemplateMixin and "BackdropTemplate")
	editwindow:SetFrameStrata("DIALOG")
	editwindow:SetToplevel(true)
	editwindow:SetWidth(400)
	editwindow:SetHeight(280)
	editwindow:SetPoint("CENTER", _G.UIParent)
	editwindow:SetBackdrop(
		{bgFile="Interface\\ChatFrame\\ChatFrameBackground",
	    edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true,
		tileSize=32, edgeSize=32, insets={left=11, right=12, top=12, bottom=11}})
	editwindow:SetBackdropColor(0,0,0,1)

	local savebutton = _G.CreateFrame("Button", nil, editwindow, "UIPanelButtonTemplate")
	savebutton:SetText(L["Save"])
	savebutton:SetWidth(100)
	savebutton:SetHeight(20)
	savebutton:SetPoint("BOTTOM", editwindow, "BOTTOM", -60, 20)
	savebutton:SetScript("OnClick",
	    function(this)
	        local frame = this:GetParent()
	        local rating = _G.UIDropDownMenu_GetSelectedValue(editwindow.ratingDropdown)
	        self:SaveEditNote(frame.charname:GetText(),frame.editbox:GetText(), rating)
	        frame:Hide()
	    end)

	local cancelbutton = _G.CreateFrame("Button", nil, editwindow, "UIPanelButtonTemplate")
	cancelbutton:SetText(L["Cancel"])
	cancelbutton:SetWidth(100)
	cancelbutton:SetHeight(20)
	cancelbutton:SetPoint("BOTTOM", editwindow, "BOTTOM", 60, 20)
	cancelbutton:SetScript("OnClick", function(this) this:GetParent():Hide(); end)

	local headertext = editwindow:CreateFontString("CN_HeaderText", "OVERLAY")
	headertext:SetFont(font, fh + 4, fflags)
	headertext:SetPoint("TOP", editwindow, "TOP", 0, -20)
	headertext:SetText(L["Edit Note"])

	local charname = editwindow:CreateFontString("CN_CharName", "OVERLAY")
	charname:SetPoint("BOTTOM", headertext, "BOTTOM", 0, -40)
	charname:SetFont(font, fh, fflags)
	charname:SetTextColor(1.0,1.0,1.0,1)

	local ratingLabel = editwindow:CreateFontString("CN_RatingLabel", "OVERLAY")
	ratingLabel:SetFont(font, fh, fflags)
	ratingLabel:SetPoint("TOP", charname, "BOTTOM", 0, -30)
	ratingLabel:SetPoint("LEFT", editwindow, "LEFT", 20, 0)
	ratingLabel:SetTextColor(1.0,1.0,1.0,1)
    ratingLabel:SetText(L["Rating"]..":")

    local ratingDropdown = _G.CreateFrame("Button", "CN_RatingDropDown", editwindow, "UIDropDownMenuTemplate")
    ratingDropdown:ClearAllPoints()
    ratingDropdown:SetPoint("TOPLEFT", ratingLabel, "TOPRIGHT", 7, 5)
    ratingDropdown:Show()
    _G.UIDropDownMenu_Initialize(ratingDropdown, function(self, level)
        local info = nil
        for i = -1, 1 do
            info = _G.UIDropDownMenu_CreateInfo()
            local ratingInfo = addon.RatingOptions[i]
            info.text = ratingInfo.title
            info.value = i
            info.colorCode = ratingInfo.color
            info.func = function(self)
                _G.UIDropDownMenu_SetSelectedValue(ratingDropdown, self.value)
            end
            _G.UIDropDownMenu_AddButton(info, level)
        end
    end)
    _G.UIDropDownMenu_SetWidth(ratingDropdown, 100);
    _G.UIDropDownMenu_SetButtonWidth(ratingDropdown, 124)
    _G.UIDropDownMenu_SetSelectedValue(ratingDropdown, 0)
    _G.UIDropDownMenu_JustifyText(ratingDropdown, "LEFT")

    local editBoxContainer = _G.CreateFrame("Frame", nil, editwindow, BackdropTemplateMixin and "BackdropTemplate")
    editBoxContainer:SetPoint("TOPLEFT", editwindow, "TOPLEFT", 20, -150)
    editBoxContainer:SetPoint("BOTTOMRIGHT", editwindow, "BOTTOMRIGHT", -40, 50)
	editBoxContainer:SetBackdrop(
		{bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
	    edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", tile=true,
		tileSize=16, edgeSize=16, insets={left=4, right=3, top=4, bottom=3}})
	editBoxContainer:SetBackdropColor(0,0,0,0.9)

    local scrollArea = _G.CreateFrame("ScrollFrame", "CN_EditNote_EditScroll", editwindow, "UIPanelScrollFrameTemplate")
    scrollArea:SetPoint("TOPLEFT", editBoxContainer, "TOPLEFT", 6, -6)
    scrollArea:SetPoint("BOTTOMRIGHT", editBoxContainer, "BOTTOMRIGHT", -6, 6)

	local editbox = _G.CreateFrame("EditBox", "CN_EditNote_EditBox", editwindow)
	editbox:SetFontObject(_G.ChatFontNormal)
	editbox:SetMultiLine(true)
	editbox:SetAutoFocus(true)
	editbox:SetWidth(300)
	editbox:SetHeight(5*14)
	editbox:SetMaxLetters(0)
	editbox:SetScript("OnShow", function(this) editbox:SetFocus() end)

  if not self.db.profile.multilineNotes then
	   editbox:SetScript("OnEnterPressed",
	    function(this)
	        local frame = this:GetParent():GetParent()
	        local rating = _G.UIDropDownMenu_GetSelectedValue(editwindow.ratingDropdown)
	        self:SaveEditNote(frame.charname:GetText(),frame.editbox:GetText(),rating)
	        frame:Hide()
	    end)
  end

	editbox:SetScript("OnEscapePressed",
	    function(this)
	        this:SetText("")
	        this:GetParent():GetParent():Hide()
	    end)
	editbox.scrollArea = scrollArea
    editbox:SetScript("OnCursorChanged", function(self, _, y, _, cursorHeight)
    	self, y = self.scrollArea, -y
    	local offset = self:GetVerticalScroll()
    	if y < offset then
    		self:SetVerticalScroll(y)
    	else
    		y = y + cursorHeight - self:GetHeight()
    		if y > offset then
    			self:SetVerticalScroll(y)
    		end
    	end
    end)
    scrollArea:SetScrollChild(editbox)

	editwindow.charname = charname
	editwindow.editbox = editbox
	editwindow.ratingDropdown = ratingDropdown

    editwindow:SetMovable(true)
    editwindow:RegisterForDrag("LeftButton")
    editwindow:SetScript("OnDragStart",
        function(this,button)
        	this:StartMoving()
        end)
    editwindow:SetScript("OnDragStop",
        function(this)
            this:StopMovingOrSizing()
        end)
    editwindow:EnableMouse(true)

	editwindow:Hide()

	return editwindow
end

local EditNoteFrame = nil
function CharacterNotes:ShowEditNoteFrame(name, note)
    if EditNoteFrame then return end

    local frame = AGU:Create("Frame")
    frame:SetTitle(L["Edit Note"])
    frame:SetWidth(400)
    frame:SetHeight(250)
    frame:SetLayout("Flow")
	frame:SetCallback("OnClose", function(widget)
		widget:ReleaseChildren()
		widget:Release()
		EditNoteFrame = nil
	end)
    EditNoteFrame = frame

    local text =  AGU:Create("Label")
    text:SetText(name)
    text:SetFont(_G.GameFontNormalLarge:GetFont())
    text.label:SetJustifyH("CENTER")
    text:SetFullWidth(true)
    text:SetCallback("OnRelease",
        function(widget)
            widget.label:SetJustifyH("LEFT")
        end
    )
    frame:AddChild(text)

    local spacer = AGU:Create("Label")
    spacer:SetFullWidth(true)
    spacer:SetText(" ")
    frame:AddChild(spacer)

    local editbox = AGU:Create("MultiLineEditBox")
    editbox:SetFullWidth(true)
    editbox:SetText(note)
    editbox:SetLabel(L["Note"])
    editbox:SetNumLines(5)
    editbox:SetMaxLetters(0)
    editbox:SetFocus()
    editbox.editBox:HighlightText()
	editbox:SetCallback("OnEnterPressed", function(widget, event, noteText)
        CharacterNotes:SaveEditNote(name, noteText)
    end)
    frame:AddChild(editbox)

end

function CharacterNotes:EditNoteHandler(input)
	local name = nil
	if input and #input > 0 then
		name = input
	else
		if _G.UnitExists("target") and _G.UnitIsPlayer("target") then
			local target = _G.GetUnitName("target", true)
			if target and #target > 0 then
				name = target
			end
		end
	end

	if name and #name > 0 then
		name = NotesDB:FormatUnitName(name)

		local charNote, nameFound = NotesDB:GetNote(name)
		local rating = NotesDB:GetRating(nameFound) or 0

		local editwindow = editNoteFrame
		editwindow.charname:SetText(charNote and nameFound or name)
		editwindow.editbox:SetText(charNote or "")

		editwindow:Show()
		editwindow:Raise()

		_G.UIDropDownMenu_SetSelectedValue(editwindow.ratingDropdown, rating)
        local ratingInfo = addon.RatingOptions[rating]
        if ratingInfo and ratingInfo.title and ratingInfo.color then
		    _G.UIDropDownMenu_SetText(editwindow.ratingDropdown, ratingInfo.color..ratingInfo.title.."|r")
        end
	end
end

function CharacterNotes:SaveEditNote(name, note, rating)
	if name and #name > 0 and note and #note > 0 then
		NotesDB:SetNote(name, note)

        if rating then
            NotesDB:SetRating(name, rating)
        end
	end

	local editwindow = editNoteFrame

	editwindow.charname:SetText("")
	editwindow.editbox:SetText("")
end

function CharacterNotes:OnEnable()
	NotesDB:OnEnable()

    -- Hook the game tooltip so we can add character Notes
    self:HookScript(_G.GameTooltip, "OnTooltipSetUnit")

	-- Hook the friends frame tooltip
	--self:HookScript("FriendsFrameTooltip_Show")

	-- Register to receive the chat messages to watch for logons and who requests
	self:RegisterEvent("CHAT_MSG_SYSTEM")

  -- Register for party and raid roster updates
  self:RegisterEvent("GROUP_ROSTER_UPDATE")

	-- Create the Notes frame for later use
	notesFrame = self:CreateNotesFrame()
  self.notesFrame = notesFrame

	-- Create the Edit Note frame to use later
	editNoteFrame = self:CreateEditNoteFrame()

	-- Create the Confirm Delete frame for later use
	confirmDeleteFrame = self:CreateConfirmDeleteFrame()

  -- Enable note links
  self:EnableNoteLinks()

	playerName = _G.GetUnitName("player", true)
end

function CharacterNotes:EnableNoteLinks()
    if self.db.profile.noteLinksInChat then
        -- Hook SetItemRef to create our own hyperlinks
        if not self:IsHooked(nil, "SetItemRef") then
    	    self:RawHook(nil, "SetItemRef", true)
        end
    	-- Hook SetHyperlink so we can redirect charnote links
        if not self:IsHooked(_G.ItemRefTooltip, "SetHyperlink") then
    	    self:RawHook(_G.ItemRefTooltip, "SetHyperlink", true)
        end
        -- Hook chat frames so we can edit the messages
        self:HookChatFrames()
    end
end

function CharacterNotes:DisableNoteLinks()
	self:Unhook(nil, "SetItemRef")
	self:Unhook(_G.ItemRefTooltip, "SetHyperlink")
  self:UnhookChatFrames()
end

function CharacterNotes:OnDisable()
    -- Called when the addon is disabled
	self:UnregisterEvent("CHAT_MSG_SYSTEM")
 	self:UnregisterEvent("GROUP_ROSTER_UPDATE")
end

function CharacterNotes:SetItemRef(link, text, button, ...)
	if link and link:match("^charnote:") then
		local name = sub(link, 10)
		name = NotesDB:FormatUnitName(name)
		local note, nameFound = NotesDB:GetNote(name)
		-- Display a link
        _G.ShowUIPanel(CharNoteTooltip)
        if (not CharNoteTooltip:IsVisible()) then
            CharNoteTooltip:SetOwner(_G.UIParent, "ANCHOR_PRESERVE")
        end
        CharNoteTooltip:ClearLines()
        CharNoteTooltip:AddLine(nameFound, 1, 1, 0)
        CharNoteTooltip:AddLine(note or "", 1, 1, 1, true)
        CharNoteTooltip:SetBackdropBorderColor(1, 1, 1, 1)
        CharNoteTooltip:Show()
		return nil
	end
	return self.hooks.SetItemRef(link, text, button, ...)
end

function CharacterNotes:SetHyperlink(frame, link, ...)
  if link and link:match("^charnote:") then return end
  return self.hooks[frame].SetHyperlink(frame, link, ...)
end

function CharacterNotes:IsNotesVisible()
	if notesFrame then
		return notesFrame:IsVisible()
	end
end

function CharacterNotes:HideNotesWindow()
	if notesFrame then
		notesFrame:Hide()
	end
end

function CharacterNotes:BuildTableData()
	local key, value = nil, nil
	for key, value in pairs(self.db.realm.notes) do
		tinsert(notesData, {
	     [ColumnIds.Rating] = (NotesDB:GetRating(key) or 0),
	     [ColumnIds.Name] = key,
	     [ColumnIds.Note] = value
     })
	end
end

function CharacterNotes:OnTooltipSetUnit(tooltip, ...)
    if self.db.profile.showNotesInTooltips == false then return end

    local main
    local name, unitid = tooltip:GetUnit()
    local note, rating, nameFound

	-- If the unit exists and is a player then check if there is a note for it.
    if _G.UnitExists(unitid) and _G.UnitIsPlayer(unitid) then
		    -- Get the unit's name including the realm name
		    name = _G.GetUnitName(unitid, true) or name
        note, rating, main, nameFound = NotesDB:GetInfoForNameOrMain(name)

        if note then
    			if self.db.profile.wrapTooltip == true then
    			    note = wrap(note,self.db.profile.wrapTooltipLength,"    ","", 4)
    			end

          if main and #main > 0 then
      	    tooltip:AddLine(Formats.tooltipNoteWithMain:format(
      	        GetRatingColor(rating), nameFound, note))
        	else
        	    tooltip:AddLine(
        	        Formats.tooltipNote:format(GetRatingColor(rating), note),
        	            1, 1, 1, not self.db.profile.wrapTooltip)
    	    end
        end
    end
end

function CharacterNotes:GetFriendNote(friendName)
    local numFriends = C_FriendList.GetNumFriends()
    if numFriends > 0 then
        for i = 1, numFriends do
            local name, level, class, area, connected, status, note =
				C_FriendList.GetFriendInfoByIndex(i)
            if friendName == name then
                return note
            end
        end
    end

	return ""
end

function CharacterNotes:DisplayNote(name, type)
    local main
    name = NotesDB:FormatUnitName(name)

    local note, rating, main, nameFound = NotesDB:GetInfoForNameOrMain(name)
  	if note then
  	    if main and #main > 0 then
  		    self:Print(Formats.chatNoteWithMain:format(
  		        GetRatingColor(rating), name, nameFound, note))
          else
  		    self:Print(Formats.chatNote:format(
  		        GetRatingColor(rating), nameFound, note))
  		end
  	end
end

function CharacterNotes:HookChatFrames()
    for i = 1, _G.NUM_CHAT_WINDOWS do
        local chatFrame = _G["ChatFrame" .. i]
        if chatFrame ~= _G.COMBATLOG then
            if not self:IsHooked(chatFrame, "AddMessage") then
                self:RawHook(chatFrame, "AddMessage", true)
            end
        end
    end
end

function CharacterNotes:UnhookChatFrames()
    for i = 1, _G.NUM_CHAT_WINDOWS do
        local chatFrame = _G["ChatFrame" .. i]
        if chatFrame ~= _G.COMBATLOG then
            self:Unhook(chatFrame, "AddMessage")
        end
    end
end

local noteLinkFmt = "%s|Hcharnote:%s|h[%s]|h|r"
function CharacterNotes:CreateNoteLink(name, text)
    local rating = self.db.realm.ratings[name]
    return noteLinkFmt:format(GetRatingColor(rating), name, text)
end

local function AddNoteForChat(message, name)
    if name and #name > 0 then
        local note, nameFound = NotesDB:GetNote(name)
        if note and #note > 0 then
            local messageFmt = "%s %s"
            return messageFmt:format(message, CharacterNotes:CreateNoteLink(nameFound,"note"))
        end
    end

    return message
end

function CharacterNotes:AddMessage(frame, text, r, g, b, id, ...)
    if text and _G.type(text) == "string" and self.db.profile.noteLinksInChat == true then
        -- If no charnotes are present then insert one.
        if text:find("|Hcharnote:") == nil then
            text = text:gsub("(|Hplayer:([^:]+).-|h.-|h)", AddNoteForChat)
        end
    end
    return self.hooks[frame].AddMessage(frame, text, r, g, b, id, ...)
end

function CharacterNotes:CHAT_MSG_SYSTEM(event, message)
	local name, type

    if self.db.profile.showNotesOnWho == true then
	    name = LibDeformat(message, _G.WHO_LIST_FORMAT)
	    type = "WHO"
    end

	if not name and self.db.profile.showNotesOnWho == true then
	    name = LibDeformat(message, _G.WHO_LIST_GUILD_FORMAT)
	    type = "WHO"
	end

	if not name and self.db.profile.showNotesOnLogon == true then
	    name = LibDeformat(message, _G.ERR_FRIEND_ONLINE_SS)
	    type = "LOGON"
	end

	if name then
		self:ScheduleTimer("DisplayNote", 0.1, name, type)
	end
end

function CharacterNotes:ProcessGroupRosterUpdate()
	local groupType = "party"
	local numMembers = 0

	numMembers = _G.GetNumGroupMembers()
	if _G.IsInRaid() then
		groupType = "raid"
	end

	if groupType == "raid" then
		if self.db.profile.notesForRaidMembers ~= true then return end
	else
		if self.db.profile.notesForPartyMembers ~= true then return end
	end

    if numMembers == 0 then
        -- Left a group
        wipe(previousGroup)
    else
        local currentGroup = {}
        local name

        for i = 1, numMembers do
            name = _G.GetUnitName(groupType..i, true)
            if name then
                currentGroup[name] = true

                if name ~= playerName and not previousGroup[name] == true then
                    --if self.db.profile.debug then
                    --    self:Print(name.." joined the group.")
                    --end
                    self:DisplayNote(name)
                end
            end
        end

        -- Set previous group to the current group
        wipe(previousGroup)
        for name in pairs(currentGroup) do
            previousGroup[name] = true
        end
	end
end

-- Patch 5.4 will change the formatting of names with realms appended.
-- Remove the spaces surrounding the dash between the name and realm.
function CharacterNotes:RemoveSpacesFromRealm()
	if not self.db.realm.removedSpacesFromRealm then
		-- Find notes to be updated.
		local check
		local noteCount = 0
		local invalidNotes = {}
		for name, note in pairs(self.db.realm.notes) do
			check = name:gmatch("[ ][-][ ]")
			if check and check() then
				noteCount = noteCount + 1
				invalidNotes[name] = note
			end
		end
		if self.db.profile.verbose then
			local fmt = "Found %d notes with realm names to update."
			self:Print(fmt:format(noteCount))
		end
		local ratingCount = 0
		local invalidRatings = {}
		for name, rating in pairs(self.db.realm.ratings) do
			check = name:gmatch("[ ][-][ ]")
			if check and check() then
				ratingCount = ratingCount + 1
				invalidRatings[name] = rating
			end
		end
		if self.db.profile.verbose then
			local fmt = "Found %d ratings with realm names to update."
			self:Print(fmt:format(ratingCount))
		end

		if noteCount > 0 then
			-- Backup the notes to be safe.
			self.db.realm.oldNotes = {}
			for name, note in pairs(self.db.realm.notes) do
				self.db.realm.oldNotes[name] = note
			end
			-- Update notes.
			for name, note in pairs(invalidNotes) do
				local newName = name:gsub("[ ][-][ ]", "-", 1)
				self.db.realm.notes[name] = nil
				self.db.realm.notes[newName] = note
			end
		end

		if ratingCount > 0 then
			-- Backup the ratings to be safe.
			self.db.realm.oldRatings = {}
			for name, rating in pairs(self.db.realm.ratings) do
				self.db.realm.oldRatings[name] = rating
			end
			-- Update ratings.
			for name, rating in pairs(invalidRatings) do
				local newName = name:gsub("[ ][-][ ]", "-", 1)
				self.db.realm.ratings[name] = nil
				self.db.realm.ratings[newName] = rating
			end
		end

		self.db.realm.removedSpacesFromRealm = true
	end
end

function CharacterNotes:RAID_ROSTER_UPDATE(event, message)
	self:ProcessGroupRosterUpdate()
end

function CharacterNotes:PARTY_MEMBERS_CHANGED(event, message)
	self:ProcessGroupRosterUpdate()
end

function CharacterNotes:GROUP_ROSTER_UPDATE(event, message)
	self:ProcessGroupRosterUpdate()
end

local _G = getfenv(0)

local string = _G.string
local table = _G.table
local math = _G.math
local pairs = _G.pairs
local ipairs = _G.ipairs
local select = _G.select
local LibStub = _G.LibStub

local CharacterNotes = LibStub("AceAddon-3.0"):NewAddon("CharacterNotes", "AceConsole-3.0", "AceHook-3.0", "AceEvent-3.0", "AceTimer-3.0")

local ADDON_NAME = ...
local ADDON_VERSION = "@project-version@"

local CURRENT_BUILD, CURRENT_INTERNAL, 
    CURRENT_BUILD_DATE, CURRENT_UI_VERSION = GetBuildInfo()

-- Local versions for performance
local tinsert, tremove, tconcat = table.insert, table.remove, table.concat
local sub = string.sub
local wipe = _G.wipe

local DEBUG = false

local L = LibStub("AceLocale-3.0"):GetLocale("CharacterNotes", true)
local AGU = LibStub("AceGUI-3.0")
local LibDeformat = LibStub("LibDeformat-3.0")
local LDB = LibStub("LibDataBroker-1.1")
local icon = LibStub("LibDBIcon-1.0")
local LibAlts = LibStub("LibAlts-1.0")

local GREEN =  "|cff00ff00"
local YELLOW = "|cffffff00"
local RED =    "|cffff0000"
local BLUE =   "|cff0198e1"
local ORANGE = "|cffff9933"
local WHITE =  "|cffffffff"

local CharNoteTooltip = nil

-- Functions defined at the end of the file.
local wrap
local formatCharName

-- String formats
local chatNoteFormat = "%s%s: "..WHITE.."%s".."|r"
local chatNoteWithMainFormat = "%s%s (%s): "..WHITE.."%s".."|r"
local tooltipNoteFormat = "%s"..L["Note: "]..WHITE.."%s".."|r"
local tooltipNoteWithMainFormat = "%s"..L["Note"].." (%s): "..WHITE.."%s".."|r"

local defaults = {
	profile = {
		minimap = {
			hide = true,
		},
		verbose = true,
		mouseoverHighlighting = true,
		showNotesOnWho = true,
		showNotesOnLogon = true,
		showNotesInTooltips = true,
		noteLinksInChat = true,
		useLibAlts = true,
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
	},
	realm = {
	    notes = {},
	    ratings = {}
	}
}

local options
local noteLDB = nil
local notesFrame = nil
local editNoteFrame = nil
local confirmDeleteFrame = nil
local notesData = {}
local previousGroup = {}
local playerName = _G.GetUnitName("player", true)

local RATING_COL = 1
local NAME_COL = 2
local NOTE_COL = 3

local RED_COLOR    = {["r"] = 1, ["g"] = 0, ["b"] = 0, ["a"] = 1}
local YELLOW_COLOR = {["r"] = 1, ["g"] = 1, ["b"] = 0, ["a"] = 1}
local GREEN_COLOR  = {["r"] = 0, ["g"] = 1, ["b"] = 0, ["a"] = 1}

local RATING_OPTIONS = {
    [-1] = {"Negative", RED, RED_COLOR, "Interface\\RAIDFRAME\\ReadyCheck-NotReady.blp"},
    [0] = {"Neutral", YELLOW, YELLOW_COLOR, ""},
    [1] = {"Positive", GREEN, GREEN_COLOR, "Interface\\RAIDFRAME\\ReadyCheck-Ready.blp"},
}

local function GetRatingColor(rating)
    local color = YELLOW
    if rating ~= nil and rating >= -1 and rating <= 1 then
        local ratingInfo = RATING_OPTIONS[rating]
        if ratingInfo and ratingInfo[2] then
            color = ratingInfo[2]
        end
    end
    return color
end

local function GetRatingColorObj(rating)
    local color = YELLOW_COLOR
    if rating ~= nil and rating >= -1 and rating <= 1 then
        local ratingInfo = RATING_OPTIONS[rating]
        if ratingInfo and ratingInfo[3] then
            color = ratingInfo[3]
        end
    end
    return color
end

local function GetRatingImage(rating)
    local image = ""
    if rating ~= nil and rating >= -1 and rating <= 1 then
        local ratingInfo = RATING_OPTIONS[rating]
        if ratingInfo and ratingInfo[4] then
            image = ratingInfo[4]
        end
    end
    return image
end

function CharacterNotes:GetOptions()
    if not options then
        options = {
            name = ADDON_NAME,
            type = 'group',
            args = {
                core = {
                    order = 1,
                    name = "General Options",
                    type = "group",
                    args = {
                		headerGeneralOptions = {
                			order = 0,
                			type = "header",
                			name = "General Options",
                		},
                	    minimap = {
                            name = L["Minimap Button"],
                            desc = L["Toggle the minimap button"],
                            type = "toggle",
                            set = function(info,val)
                                	-- Reverse the value since the stored value is to hide it
                                    self.db.profile.minimap.hide = not val
                                	if self.db.profile.minimap.hide then
                                		icon:Hide("CharacterNotesLDB")
                                	else
                                		icon:Show("CharacterNotesLDB")
                                	end
                                  end,
                            get = function(info)
                        	        -- Reverse the value since the stored value is to hide it
                                    return not self.db.profile.minimap.hide
                                  end,
                			order = 10
                        },
                	    useLibAlts = {
                            name = L["Use LibAlts Data"],
                            desc = L["Toggles the use of LibAlts data if present.  If present and no note is found for a character, the note for the main will be shown if found."],
                            type = "toggle",
                            set = function(info, val) self.db.profile.useLibAlts = val end,
                            get = function(info) return self.db.profile.useLibAlts end,
                			order = 20
                        },
                	    mouseoverHighlighting = {
                            name = L["Mouseover Highlighting"],
                            desc = L["Toggles mouseover highlighting for tables."],
                            type = "toggle",
                            set = function(info, val)
                                    self.db.profile.mouseoverHighlighting = val
                                    self:UpdateMouseoverHighlighting(val)
                                end,
                            get = function(info)
                                    return self.db.profile.mouseoverHighlighting
                                end,
                			order = 30
                        },
                	    verbose = {
                            name = L["Verbose"],
                            desc = L["Toggles the display of informational messages"],
                            type = "toggle",
                            set = function(info, val) self.db.profile.verbose = val end,
                            get = function(info) return self.db.profile.verbose end,
                			order = 40
                        },
                        headerNoteDisplay = {
                			order = 100,
                			type = "header",
                			name = L["Note Display"],
                        },
                	    noteLinksInChat = {
                            name = L["Note Links"],
                            desc = L["NoteLinks_OptionDesc"],
                            type = "toggle",
                            set = function(info, val)
                                    self.db.profile.noteLinksInChat = val
                                    if val then
                                        self:EnableNoteLinks()
                                    else
                                        self:DisableNoteLinks()
                                    end
                                end,
                            get = function(info) return self.db.profile.noteLinksInChat end,
                			order = 110
                        },
                	    showNotesOnWho = {
                            name = L["Show notes with who results"],
                            desc = L["Toggles showing notes for /who results in the chat window."],
                            type = "toggle",
                            set = function(info, val) self.db.profile.showNotesOnWho = val end,
                            get = function(info) return self.db.profile.showNotesOnWho end,
                			order = 120
                        },
                	    showNotesOnLogon = {
                            name = L["Show notes at logon"],
                            desc = L["Toggles showing notes when a friend or guild memeber logs on."],
                            type = "toggle",
                            set = function(info, val) self.db.profile.showNotesOnLogon = val end,
                            get = function(info) return self.db.profile.showNotesOnLogon end,
                			order = 130
                        },
                        headerNoteLinks = {
                			order = 150,
                			type = "header",
                			name = L["Note Links"],
                        },
                        lock_note_tooltip = {
                            name = L["Lock"],
                            desc = L["LockNoteTooltip_OptionDesc"],
                            type = "toggle",
                            set = function(info,val)
                                self.db.profile.lock_tooltip = val
                            end,
                            get = function(info) return self.db.profile.lock_tooltip end,
                			order = 160
                        },
                        remember_tooltip_pos = {
                            name = L["Remember Position"],
                            desc = L["RememberPositionNoteTooltip_OptionDesc"],
                            type = "toggle",
                            set = function(info,val) self.db.profile.remember_tooltip_pos = val end,
                            get = function(info) return self.db.profile.remember_tooltip_pos end,
                			order = 170
                        },
                		headerTooltipOptions = {
                			order = 200,
                			type = "header",
                			name = L["Tooltip Options"],
                		},
                	    showNotesInTooltips = {
                            name = L["Show notes in tooltips"],
                            desc = L["Toggles showing notes in unit tooltips."],
                            type = "toggle",
                            set = function(info, val) self.db.profile.showNotesInTooltips = val end,
                            get = function(info) return self.db.profile.showNotesInTooltips end,
                			order = 210
                        },
                        wrapTooltip = {
                            name = L["Wrap Tooltips"],
                            desc = L["Wrap notes in tooltips at the specified line length.  Subsequent lines are indented."],
                            type = "toggle",
                            set = function(info,val) self.db.profile.wrapTooltip = val end,
                            get = function(info) return self.db.profile.wrapTooltip end,
                			order = 220
                        },
                        wrapTooltipLength = {
                            name = L["Tooltip Wrap Length"],
                            desc = L["Maximum line length for a tooltip"],
                            type = "range",
                			min = 20,
                			max = 80,
                			step = 1,
                            set = function(info,val) self.db.profile.wrapTooltipLength = val end,
                            get = function(info) return self.db.profile.wrapTooltipLength end,
                			order = 230
                        },
                		headerMainWindow = {
                			order = 300,
                			type = "header",
                			name = L["Notes Window"],
                		},
                        lock_main_window = {
                            name = L["Lock"],
                            desc = L["Lock_OptionDesc"],
                            type = "toggle",
                            set = function(info,val)
                                self.db.profile.lock_main_window = val
                                notesFrame.lock = val
                            end,
                            get = function(info) return self.db.profile.lock_main_window end,
                			order = 310
                        },
                        remember_main_pos = {
                            name = L["Remember Position"],
                            desc = L["RememberPosition_OptionDesc"],
                            type = "toggle",
                            set = function(info,val) self.db.profile.remember_main_pos = val end,
                            get = function(info) return self.db.profile.remember_main_pos end,
                			order = 320
                        },
                		headerPartyRaid = {
                			order = 400,
                			type = "header",
                			name = L["Notes for Party and Raid Members"],
                		},
                        descNotesGroup = {
                            order = 410,
                            type = "description",
                            name = L["These options control if notes are displayed in the chat window for any members who have a note.  Notes are shown when joining a raid or a new member joins."]
                        },
                        notesForPartyMembers = {
                            name = L["Party Members"],
                            desc = L["Toggles displaying notes for party members."],
                            type = "toggle",
                            set = function(info,val) self.db.profile.notesForPartyMembers = val end,
                            get = function(info) return self.db.profile.notesForPartyMembers end,
                			order = 420
                        },
                        notesForRaidMembers = {
                            name = L["Raid Members"],
                            desc = L["Toggles displaying notes for raid members."],
                            type = "toggle",
                            set = function(info,val) self.db.profile.notesForRaidMembers = val end,
                            get = function(info) return self.db.profile.notesForRaidMembers end,
                			order = 430
                        }
                    }
                },
                export = {
                    order = 2,
                    name = L["Import/Export"],
                    type = "group",
                    args = {
                		headerExport = {
                			order = 100,
                			type = "header",
                			name = L["Export"],
                		},
                        guildExportButton = {
                            name = L["Notes Export"],
                            desc = L["NotesExport_OptionDesc"],
                            type = "execute",
                            width = "normal",
                            func = function()
                            	local optionsFrame = _G.InterfaceOptionsFrame
                                optionsFrame:Hide()
                                self:NotesExportHandler("")
                            end,
                			order = 110
                        },
                		headerImport = {
                			order = 200,
                			type = "header",
                			name = L["Import"],
                		},
                        guildImportButton = {
                            name = L["Notes Import"],
                            desc = L["NotesImport_OptionDesc"],
                            type = "execute",
                            width = "normal",
                            disabled = true,
                            func = function()
                            	local optionsFrame = _G.InterfaceOptionsFrame
                                optionsFrame:Hide()
                                self:NotesImportHandler("")
                            end,
                			order = 210
                        },
                    }
                }
            }
        }
    end

    return options
end

function CharacterNotes:ShowOptions()
	_G.InterfaceOptionsFrame_OpenToCategory(self.optionsFrame.Main)
end

function CharacterNotes:OnInitialize()
    -- Called when the addon is loaded
    self.db = LibStub("AceDB-3.0"):New("CharacterNotesDB", defaults, "Default")

	-- Build the table data for the Notes window
	self:BuildTableData()

    -- Register the options table
    --LibStub("AceConfig-3.0"):RegisterOptionsTable("CharacterNotes", self:GetOptions())
	--self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(
	--    "CharacterNotes", ADDON_NAME)

    -- Register the options table
    local displayName = _G.GetAddOnMetadata(ADDON_NAME, "Title")
	local options = self:GetOptions()
    LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(displayName, options)
    self.optionsFrame = {}
    local ACD = LibStub("AceConfigDialog-3.0")
	self.optionsFrame.Main = ACD:AddToBlizOptions(
	    displayName, displayName, nil, "core")
	self.optionsFrame.Notes = ACD:AddToBlizOptions(
	    displayName, L["Import/Export"], displayName, "export")

	self:RegisterChatCommand("setnote", "SetNoteHandler")
	self:RegisterChatCommand("delnote", "DelNoteHandler")
	self:RegisterChatCommand("delrating", "DelRatingHandler")
	self:RegisterChatCommand("getnote", "GetNoteHandler")
	self:RegisterChatCommand("editnote", "EditNoteHandler")
	self:RegisterChatCommand("notes", "NotesHandler")
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
				tooltip:AddLine(GREEN .. L["Character Notes"].." "..ADDON_VERSION)
				tooltip:AddLine(YELLOW .. L["Left click"] .. " " .. WHITE
					.. L["to open/close the window"])
				tooltip:AddLine(YELLOW .. L["Right click"] .. " " .. WHITE
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
end

function CharacterNotes:CreateCharNoteTooltip()
    CharNoteTooltip = _G.CreateFrame("GameTooltip", "CharNoteTooltip", _G.UIParent, "GameTooltipTemplate")
    CharNoteTooltip:SetOwner(_G.WorldFrame, "ANCHOR_NONE")
	CharNoteTooltip:SetFrameStrata("DIALOG")
    CharNoteTooltip:SetSize(100,100)
    CharNoteTooltip:SetPadding(16)
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
		name = formatCharName(name)
		if note and #note > 0 then
			self:SetNote(name, note)
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
		name = formatCharName(name)
		self:DeleteNote(name)
		if self.db.profile.verbose == true then
			local strFormat = L["Deleted note for %s"]
			self:Print(strFormat:format(name))
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
		name = formatCharName(name)
		self:DeleteRating(name)
		if self.db.profile.verbose == true then
			local strFormat = L["Deleted rating for %s"]
			self:Print(strFormat:format(name))
		end
	end	
end

function CharacterNotes:GetNoteHandler(input)
	if input and #input > 0 then
		local name, note = input:match("^(%S+) *(.*)")
		name = formatCharName(name)

        local note, rating, main = self:GetInfoForNameOrMain(name)

		if note then
		    if main and #main > 0 then
			    self:Print(chatNoteWithMainFormat:format(
			        GetRatingColor(rating), name, main, note or ""))
	        else
			    self:Print(chatNoteFormat:format(
			        GetRatingColor(rating), name, note or ""))
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
            rating = (self:GetRating(name) or 0)
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

local NotesImportFrame = nil
function CharacterNotes:ShowNotesImportFrame()
    if NotesImportFrame then return end

	local frame = AGU:Create("Frame")
	frame:SetTitle(L["Notes Import"])
	frame:SetWidth(650)
	frame:SetHeight(400)
    frame:SetLayout("Flow")
	frame:SetCallback("OnClose", function(widget)
		widget:ReleaseChildren()
		widget:Release()
		NotesImportFrame = nil
	end)

    NotesImportFrame = frame

    local multiline = AGU:Create("MultiLineEditBox")
    multiline:SetLabel(L["NotesImport_ImportLabel"])
    multiline:SetNumLines(10)
    multiline:SetMaxLetters(0)
    multiline:SetFullWidth(true)
    multiline:DisableButton(true)
    frame:AddChild(multiline)
    frame.multiline = multiline

    local spacer = AGU:Create("Label")
    spacer:SetText(" ")
    spacer:SetFullWidth(true)
    frame:AddChild(spacer)

    local importButton = AGU:Create("Button")
    importButton:SetText(L["Import"])
    importButton:SetCallback("OnClick",
        function(widget)
            CharacterNotes:ImportNotesFromText(
                NotesImportFrame.multiline:GetText())
        end)
    frame:AddChild(importButton)
end

function CharacterNotes:ImportNotesFromText(importData)

end

local NotesExportFrame = nil
function CharacterNotes:ShowNotesExportFrame()
    if NotesExportFrame then return end

	local frame = AGU:Create("Frame")
	frame:SetTitle(L["Notes Export"])
	frame:SetWidth(650)
	frame:SetHeight(400)
    frame:SetLayout("Flow")
	frame:SetCallback("OnClose", function(widget)
		widget:ReleaseChildren()
		widget:Release()
		NotesExportFrame = nil
	end)

    NotesExportFrame = frame

    local multiline = AGU:Create("MultiLineEditBox")
    multiline:SetLabel(L["NotesExport_ExportLabel"])
    multiline:SetNumLines(10)
    multiline:SetMaxLetters(0)
    multiline:SetFullWidth(true)
    multiline:DisableButton(true)
    frame:AddChild(multiline)
    frame.multiline = multiline

    local fieldsHeading =  AGU:Create("Heading")
    fieldsHeading:SetText("Fields to Export")
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
    optionsHeading:SetText("Options")
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
	local noteswindow = _G.CreateFrame("Frame", "CharacterNotesWindow", _G.UIParent)
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

    local RATING_COL = 1
    local NAME_COL = 2
    local NOTE_COL = 3

	local cols = {}
    cols[RATING_COL] = {
		["name"] = L["RATING_COLUMN_NAME"],
		["width"] = 15,
		["colorargs"] = nil,
		["bgcolor"] = {
			["r"] = 0.0,
			["g"] = 0.0,
			["b"] = 0.0,
			["a"] = 1.0
		},
		["sortnext"] = NAME_COL,
	  	["DoCellUpdate"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, self, ...)
	  	    if fShow then 
		        local image = GetRatingImage(data[realrow][RATING_COL])
		        if image and #image > 0 then
		            cellFrame:SetBackdrop( { bgFile = image } )
		        else
		            cellFrame:SetBackdrop(nil)
	            end
		    end
	  	end,
    }
	cols[NAME_COL] = {
		["name"] = L["Character Name"],
		["width"] = 150,
		["align"] = "LEFT",
		["color"] = function(data, cols, realrow, column, table)
		    return GetRatingColorObj(data[realrow][RATING_COL])
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
	cols[NOTE_COL] = {
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
		["sortnext"] = NAME_COL,
		["DoCellUpdate"] = nil,
	}

	local table = ScrollingTable:CreateST(cols, 15, nil, nil, noteswindow);

	local headertext = noteswindow:CreateFontString("PN_Notes_HeaderText", noteswindow, "GameFontNormalLarge")
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
				if row and row[NAME_COL] and #row[NAME_COL] > 0 then
					confirmDeleteFrame.charname:SetText(row[NAME_COL])
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
				if row and row[NAME_COL] and #row[NAME_COL] > 0 then
					self:EditNoteHandler(row[NAME_COL])
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
				if row[NAME_COL]:lower():find(term) or row[NOTE_COL]:lower():find(term) then
					return true
				end

				return false
			else
				return true
			end
		end
	)

    noteswindow.lock = self.db.profile.lock_main_window
    
    noteswindow:SetMovable()
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

function CharacterNotes:NotesDBCheckHandler(input)
    for name, note in pairs(self.db.realm.notes) do
        if name then
            if name ~= formatCharName(name) then
                self:Print("Name "..name.." doesn't match the formatted name.")
            end
        else
            self:Print("Found a note with a nil name value. ["..note or "nil".."]")
        end
    end
    
    self:Print("Note DB Check finished.")
end

function CharacterNotes:CreateConfirmDeleteFrame()
	local deletewindow = _G.CreateFrame("Frame", "CharacterNotesConfirmDeleteWindow", _G.UIParent)
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

	local headertext = deletewindow:CreateFontString("CN_Confirm_HeaderText", deletewindow, "GameFontNormalLarge")
	headertext:SetPoint("TOP", deletewindow, "TOP", 0, -20)
	headertext:SetText(L["Delete Note"])

	local warningtext = deletewindow:CreateFontString("CN_Confirm_WarningText", deletewindow, "GameFontNormalLarge")
	warningtext:SetPoint("TOP", headertext, "TOP", 0, -40)
	warningtext:SetText(L["Are you sure you wish to delete the note for:"])

	local charname = deletewindow:CreateFontString("CN_Confirm_CharName", deletewindow, "GameFontNormal")
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
	        self:DeleteNote(charname:GetText())
	        this:GetParent():Hide()
	    end)

	local cancelbutton = _G.CreateFrame("Button", nil, deletewindow, "UIPanelButtonTemplate")
	cancelbutton:SetText(L["Cancel"])
	cancelbutton:SetWidth(100)
	cancelbutton:SetHeight(20)
	cancelbutton:SetPoint("BOTTOM", deletewindow, "BOTTOM", 60, 20)
	cancelbutton:SetScript("OnClick", function(this) this:GetParent():Hide(); end)

	deletewindow.charname = charname

    deletewindow:SetMovable()
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
	local editwindow = _G.CreateFrame("Frame", "CharacterNotesEditWindow", _G.UIParent)
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

	local headertext = editwindow:CreateFontString("CN_HeaderText", editwindow, "GameFontNormalLarge")
	headertext:SetPoint("TOP", editwindow, "TOP", 0, -20)
	headertext:SetText(L["Edit Note"])

	local charname = editwindow:CreateFontString("CN_CharName", editwindow, "GameFontNormal")
	charname:SetPoint("BOTTOM", headertext, "BOTTOM", 0, -40)
	charname:SetFont(charname:GetFont(), 14)
	charname:SetTextColor(1.0,1.0,1.0,1)

	local ratingLabel = editwindow:CreateFontString("CN_RatingLabel", editwindow, "GameFontNormal")
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
            local ratingInfo = RATING_OPTIONS[i]
            info.text = ratingInfo[1]
            info.value = i
            info.colorCode = ratingInfo[2]
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

    local editBoxContainer = _G.CreateFrame("Frame", nil, editwindow)
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
	editbox:SetScript("OnEnterPressed",
	    function(this)
	        local frame = this:GetParent():GetParent()
	        local rating = _G.UIDropDownMenu_GetSelectedValue(editwindow.ratingDropdown)
	        self:SaveEditNote(frame.charname:GetText(),frame.editbox:GetText(),rating)
	        frame:Hide()
	    end)
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

    editwindow:SetMovable()
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
		name = formatCharName(name)
		
		local charNote = self:GetNote(name) or ""
		local rating = self:GetRating(name) or 0

		local editwindow = editNoteFrame
		editwindow.charname:SetText(name)
		editwindow.editbox:SetText(charNote)

		editwindow:Show()
		editwindow:Raise()

		_G.UIDropDownMenu_SetSelectedValue(editwindow.ratingDropdown, rating)
        local ratingInfo = RATING_OPTIONS[rating]
        if ratingInfo and ratingInfo[1] and ratingInfo[2] then
		    _G.UIDropDownMenu_SetText(editwindow.ratingDropdown, ratingInfo[2]..ratingInfo[1].."|r")
        end
	end	
end

function CharacterNotes:SaveEditNote(name, note, rating)
	if name and #name > 0 and note and #note > 0 then
		self:SetNote(name, note)

        if rating then
            self:SetRating(name, rating)
        end
	end

	local editwindow = editNoteFrame

	editwindow.charname:SetText("")
	editwindow.editbox:SetText("")
end

function CharacterNotes:OnEnable()
    -- Hook the game tooltip so we can add character Notes
    self:HookScript(_G.GameTooltip, "OnTooltipSetUnit")

	-- Hook the friends frame tooltip
	--self:HookScript("FriendsFrameTooltip_Show")

	-- Register to receive the chat messages to watch for logons and who requests
	self:RegisterEvent("CHAT_MSG_SYSTEM")

    -- Register for party and raid roster updates
	if CURRENT_UI_VERSION >= 50000 then
   		self:RegisterEvent("GROUP_ROSTER_UPDATE")
	else
		self:RegisterEvent("RAID_ROSTER_UPDATE")
   		self:RegisterEvent("PARTY_MEMBERS_CHANGED")
	end
	-- Create the Notes frame for later use
	notesFrame = self:CreateNotesFrame()
	
	-- Create the Edit Note frame to use later
	editNoteFrame = self:CreateEditNoteFrame()
	
	-- Create the Confirm Delete frame for later use
	confirmDeleteFrame = self:CreateConfirmDeleteFrame()
	
	-- Add the Edit Note menu item on unit frames
	self:AddEditNoteMenuItem()

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
	if CURRENT_UI_VERSION >= 50000 then
   		self:UnregisterEvent("GROUP_ROSTER_UPDATE")
	else
		self:UnregisterEvent("RAID_ROSTER_UPDATE")
   		self:UnregisterEvent("PARTY_MEMBERS_CHANGED")
	end
	
	-- Remove the menu items
	self:RemoveEditNoteMenuItem()
end

function CharacterNotes:SetItemRef(link, text, button, ...)
	if link and link:match("^charnote:") then
		local name = sub(link, 10)
		name = formatCharName(name)
		local note = self:GetNote(name) or ""
		-- Display a link
        _G.ShowUIPanel(CharNoteTooltip)
        if (not CharNoteTooltip:IsVisible()) then
            CharNoteTooltip:SetOwner(_G.UIParent, "ANCHOR_PRESERVE")
        end
        CharNoteTooltip:ClearLines()
        CharNoteTooltip:AddLine(name, 1, 1, 0)
        CharNoteTooltip:AddLine(note, 1, 1, 1, true)
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

function CharacterNotes:AddEditNoteMenuItem()
	_G.UnitPopupButtons["EDIT_NOTE"] = {text = L["Edit Note"], dist = 0}

	self:SecureHook("UnitPopup_OnClick", "EditNoteMenuClick")

	tinsert(_G.UnitPopupMenus["PLAYER"], (#_G.UnitPopupMenus["PLAYER"])-1, "EDIT_NOTE")
	tinsert(_G.UnitPopupMenus["PARTY"], (#_G.UnitPopupMenus["PARTY"])-1, "EDIT_NOTE")
	tinsert(_G.UnitPopupMenus["FRIEND"], (#_G.UnitPopupMenus["FRIEND"])-1, "EDIT_NOTE")
	tinsert(_G.UnitPopupMenus["FRIEND_OFFLINE"], (#_G.UnitPopupMenus["FRIEND_OFFLINE"])-1, "EDIT_NOTE")
	tinsert(_G.UnitPopupMenus["RAID_PLAYER"], (#_G.UnitPopupMenus["RAID_PLAYER"])-1, "EDIT_NOTE")
end

function CharacterNotes:RemoveEditNoteMenuItem()
	_G.UnitPopupButtons["EDIT_NOTE"] = nil

	self:unhook("UnitPopup_OnClick")
end

function CharacterNotes:EditNoteMenuClick(self)
	local menu = _G.UIDROPDOWNMENU_INIT_MENU
	local button = self.value
	if button == "EDIT_NOTE" then
		local fullname = nil
		local name = menu.name
		local server = menu.server
		if server and #server > 0 then
			local strFormat = "%s - %s"
			fullname = strFormat:format(name, server)
		else
			fullname = name
		end

		CharacterNotes:EditNoteHandler(fullname)
	end
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
		    [RATING_COL] = (self:GetRating(key) or 0), 
		    [NAME_COL] = key, 
		    [NOTE_COL] = value})
	end
end

function CharacterNotes:SetNote(name, note)
	if self.db.realm.notes and name then
	    name = formatCharName(name)
		self.db.realm.notes[name] = note;

		local found = false
		for i, v in ipairs(notesData) do
			if v[NAME_COL] == name then
				notesData[i][NOTE_COL] = note
				found = true
			end
		end
		
		if found == false then
			tinsert(notesData, {
			    [RATING_COL] = (self:GetRating(name) or 0),
			    [NAME_COL] = name, 
			    [NOTE_COL] = note})
		end

		-- If the Notes window is shown then we need to update it
		if notesFrame:IsVisible() then
			notesFrame.table:SortData()
		end
	end
end

function CharacterNotes:SetRating(name, rating)
	if self.db.realm.ratings and name and rating >= -1 and rating <= 1 then
	    name = formatCharName(name)
		self.db.realm.ratings[name] = rating

		local found = false
		for i, v in ipairs(notesData) do
			if v[NAME_COL] == name then
				notesData[i][RATING_COL] = rating
				found = true
			end
		end
		
		if found == false then
			tinsert(notesData, {
			    [RATING_COL] = rating, 
			    [NAME_COL] = name, 
			    [NOTE_COL] = self:GetNote(name)})
		end

		-- If the Notes window is shown then we need to update it
		if notesFrame:IsVisible() then
			notesFrame.table:SortData()
		end
    end
end

function CharacterNotes:GetNote(name)
	if self.db.realm.notes and name then
	    name = formatCharName(name)
		return self.db.realm.notes[name]
	end
end

function CharacterNotes:GetRating(name)
	if self.db.realm.ratings and name then
	    name = formatCharName(name)
		return self.db.realm.ratings[name]
	end
end

function CharacterNotes:DeleteNote(name)
	if self.db.realm.notes and name then
        -- Delete both the note and the rating.
		self.db.realm.notes[name] = nil;
		self.db.realm.ratings[name] = nil;
		
		for i, v in ipairs(notesData) do
			if v[NAME_COL] == name then
			    tremove(notesData, i)
			end
		end
		
		-- If the Notes window is shown then we need to update it
		if notesFrame:IsVisible() then
			notesFrame.table:SortData()
		end
	end
end

function CharacterNotes:DeleteRating(name)
	if self.db.realm.ratings and name then
		self.db.realm.ratings[name] = nil;
		
		for i, v in ipairs(notesData) do
			if v[NAME_COL] == name then
			    if v[NOTE_COL] == nil then
				    tremove(notesData, i)
                else
                    v[RATING_COL] = 0
                end
			end
		end
		
		-- If the Notes window is shown then we need to update it
		if notesFrame:IsVisible() then
			notesFrame.table:SortData()
		end
	end
end

function CharacterNotes:GetInfoForNameOrMain(name)
    local note = self:GetNote(name)
    local rating = self:GetRating(name)
    local main = nil
    -- If there is no note then check if this character has a main 
    -- and if so if there is a note for that character.
    if not note then
        if self.db.profile.useLibAlts == true and LibAlts and LibAlts.GetMain then
            main = LibAlts:GetMain(name)
            if main and #main > 0 then
                main = formatCharName(main)
                note = self:GetNote(main)
                rating = self:GetRating(main)
            end
        end
    end
    
    return note, rating, main
end

function CharacterNotes:OnTooltipSetUnit(tooltip, ...)
    if self.db.profile.showNotesInTooltips == false then return end

    local main
    local name, unitid = tooltip:GetUnit()
    local note, rating

	-- If the unit exists and is a player then check if there is a note for it.
    if _G.UnitExists(unitid) and _G.UnitIsPlayer(unitid) then
		-- Get the unit's name including the realm name
		name = _G.GetUnitName(unitid, true) or name
        note, rating, main = self:GetInfoForNameOrMain(name)

        if note then
			if self.db.profile.wrapTooltip == true then
			    note = wrap(note,self.db.profile.wrapTooltipLength,"    ","", 4)
			end

            if main and #main > 0 then
        	    tooltip:AddLine(tooltipNoteWithMainFormat:format(
        	        GetRatingColor(rating), main, note))
        	else
        	    tooltip:AddLine(
        	        tooltipNoteFormat:format(GetRatingColor(rating), note), 
        	            1, 1, 1, not self.db.profile.wrapTooltip)
    	    end
        end
    end
end

function CharacterNotes:GetFriendNote(friendName)
    local numFriends = _G.GetNumFriends()
    if numFriends > 0 then
        for i = 1, numFriends do
            local name, level, class, area, connected, status, note = 
				_G.GetFriendInfo(i)
            if friendName == name then
                return note
            end
        end
    end

	return ""
end

function CharacterNotes:DisplayNote(name, type)
    local main
    name = formatCharName(name)
    
    local note, rating, main = self:GetInfoForNameOrMain(name)
	if note then
	    if main and #main > 0 then
		    self:Print(chatNoteWithMainFormat:format(
		        GetRatingColor(rating), name, main, note))	        
        else
		    self:Print(chatNoteFormat:format(
		        GetRatingColor(rating), name, note))
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
        local note = CharacterNotes:GetNote(name)
        if note and #note > 0 then
            local messageFmt = "%s %s"
            return messageFmt:format(message, CharacterNotes:CreateNoteLink(name,"note"))
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

local function GetGroupTypeAndNumber()
	local numRaid = _G.GetNumRaidMembers()
	if numRaid > 0 then
		return "raid", numRaid
	else
		return "party", _G.GetNumPartyMembers()
	end
end

function CharacterNotes:ProcessGroupRosterUpdate()
	local groupType = "party"
	local numMembers = 0

	if CURRENT_UI_VERSION >= 50000 then
		numMembers = _G.GetNumGroupMembers()
		if _G.IsInRaid() then
			groupType = "raid"
		end
	else
		groupType, numMembers = GetGroupTypeAndNumber()
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
                    if DEBUG == true then
                        self:Print(name.." joined the group.")
                    end
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

function CharacterNotes:RAID_ROSTER_UPDATE(event, message)
	self:ProcessGroupRosterUpdate()
end

function CharacterNotes:PARTY_MEMBERS_CHANGED(event, message)
	self:ProcessGroupRosterUpdate()
end

function CharacterNotes:GROUP_ROSTER_UPDATE(event, message)
	self:ProcessGroupRosterUpdate()
end

function formatCharName(name)
    local MULTIBYTE_FIRST_CHAR = "^([\192-\255]?%a?[\128-\191]*)"
    if not name then return "" end
    
    -- Change the string up to a - to lower case.
    -- Limiting it in case a server name is present in the name.
    name = name:gsub("^([^%-]+)", string.lower)
    -- Change the first character to uppercase accounting for multibyte characters.
    name = name:gsub(MULTIBYTE_FIRST_CHAR, string.upper, 1)
    return name
end

function wrap(str, limit, indent, indent1,offset)
	indent = indent or ""
	indent1 = indent1 or indent
	limit = limit or 72
	offset = offset or 0
	local here = 1-#indent1-offset
	return indent1..str:gsub("(%s+)()(%S+)()",
						function(sp, st, word, fi)
							if fi-here > limit then
								here = st - #indent
								return "\n"..indent..word
							end
						end)
end

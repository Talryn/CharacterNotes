CharacterNotes = LibStub("AceAddon-3.0"):NewAddon("CharacterNotes", "AceConsole-3.0", "AceHook-3.0", "AceEvent-3.0", "AceTimer-3.0")

local ADDON_NAME = ...
local ADDON_VERSION = "@project-version@"

-- Local versions for performance
local tinsert, tremove = table.insert, table.remove
local pairs, ipairs = pairs, ipairs

local DEBUG = false

local L = LibStub("AceLocale-3.0"):GetLocale("CharacterNotes", true)
local LibDeformat = LibStub("LibDeformat-3.0")
local LDB = LibStub("LibDataBroker-1.1")
local icon = LibStub("LibDBIcon-1.0")
local LibAlts = LibStub("LibAlts-1.0")

local GREEN = "|cff00ff00"
local YELLOW = "|cffffff00"
local BLUE = "|cff0198e1"
local ORANGE = "|cffff9933"
local WHITE = "|cffffffff"

-- Functions defined at the end of the file.
local wrap
local formatCharName

-- String formats
local chatNoteFormat = YELLOW.."%s: "..WHITE.."%s"
local chatNoteWithMainFormat = YELLOW.."%s (%s): "..WHITE.."%s"
local tooltipNoteFormat = YELLOW..L["Note: "]..WHITE.."%s"
local tooltipNoteWithMainFormat = YELLOW..L["Note"].." (%s): "..WHITE.."%s"

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
		useLibAlts = true,
		wrapTooltip = true,
		wrapTooltipLength = 50,
		notesForRaidMembers = false,
		notesForPartyMembers = false
	},
	realm = {
	    notes = {}
	}
}

local options
local noteLDB = nil
local notesFrame = nil
local editNoteFrame = nil
local confirmDeleteFrame = nil
local notesData = {}
local previousRaid = {}
local previousParty = {}

function CharacterNotes:GetOptions()
    if not options then
        options = {
            name = ADDON_NAME,
            type = 'group',
            args = {
        		displayheader = {
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
        	    showNotesOnWho = {
                    name = L["Show notes with who results"],
                    desc = L["Toggles showing notes for /who results in the chat window."],
                    type = "toggle",
                    set = function(info, val) self.db.profile.showNotesOnWho = val end,
                    get = function(info) return self.db.profile.showNotesOnWho end,
        			order = 20
                },
        	    showNotesOnLogon = {
                    name = L["Show notes at logon"],
                    desc = L["Toggles showing notes when a friend or guild memeber logs on."],
                    type = "toggle",
                    set = function(info, val) self.db.profile.showNotesOnLogon = val end,
                    get = function(info) return self.db.profile.showNotesOnLogon end,
        			order = 30
                },
        	    useLibAlts = {
                    name = L["Use LibAlts Data"],
                    desc = L["Toggles the use of LibAlts data if present.  If present and no note is found for a character, the note for the main will be shown if found."],
                    type = "toggle",
                    set = function(info, val) self.db.profile.useLibAlts = val end,
                    get = function(info) return self.db.profile.useLibAlts end,
        			order = 40
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
        			order = 50
                },
        	    verbose = {
                    name = L["Verbose"],
                    desc = L["Toggles the display of informational messages"],
                    type = "toggle",
                    set = function(info, val) self.db.profile.verbose = val end,
                    get = function(info) return self.db.profile.verbose end,
        			order = 60
                },
        		displayheader = {
        			order = 100,
        			type = "header",
        			name = L["Tooltip Options"],
        		},
        	    showNotesInTooltips = {
                    name = L["Show notes in tooltips"],
                    desc = L["Toggles showing notes in unit tooltips."],
                    type = "toggle",
                    set = function(info, val) self.db.profile.showNotesInTooltips = val end,
                    get = function(info) return self.db.profile.showNotesInTooltips end,
        			order = 110
                },
                wrapTooltip = {
                    name = L["Wrap Tooltips"],
                    desc = L["Wrap notes in tooltips at the specified line length.  Subsequent lines are indented."],
                    type = "toggle",
                    set = function(info,val) self.db.profile.wrapTooltip = val end,
                    get = function(info) return self.db.profile.wrapTooltip end,
        			order = 120
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
        			order = 130
                },
        		displayheader2 = {
        			order = 200,
        			type = "header",
        			name = L["Notes for Party and Raid Members"],
        		},
                descNotesGroup = {
                    order = 210,
                    type = "description",
                    name = L["These options control if notes are displayed in the chat window for any members who have a note.  Notes are shown when joining a raid or a new member joins."]
                },
                notesForPartyMembers = {
                    name = L["Party Members"],
                    desc = L["Toggles displaying notes for party members."],
                    type = "toggle",
                    set = function(info,val) self.db.profile.notesForPartyMembers = val end,
                    get = function(info) return self.db.profile.notesForPartyMembers end,
        			order = 220
                },
                notesForRaidMembers = {
                    name = L["Raid Members"],
                    desc = L["Toggles displaying notes for raid members."],
                    type = "toggle",
                    set = function(info,val) self.db.profile.notesForRaidMembers = val end,
                    get = function(info) return self.db.profile.notesForRaidMembers end,
        			order = 230
                }
            }
        }
    end

    return options
end

function CharacterNotes:OnInitialize()
    -- Called when the addon is loaded
    self.db = LibStub("AceDB-3.0"):New("CharacterNotesDB", defaults, "Default")

	-- Build the table data for the Notes window
	self:BuildTableData()

    -- Register the options table
    LibStub("AceConfig-3.0"):RegisterOptionsTable("CharacterNotes", self:GetOptions())
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(
	    "CharacterNotes", ADDON_NAME)

	self:RegisterChatCommand("setnote", "SetNoteHandler")
	self:RegisterChatCommand("delnote", "DelNoteHandler")
	self:RegisterChatCommand("getnote", "GetNoteHandler")
	self:RegisterChatCommand("editnote", "EditNoteHandler")
	self:RegisterChatCommand("notes", "NotesHandler")
	self:RegisterChatCommand("searchnote", "NotesHandler")
	self:RegisterChatCommand("notesdbcheck", "NotesDBCheckHandler")

	-- Create the LDB launcher
	noteLDB = LDB:NewDataObject("CharacterNotes",{
		type = "launcher",
		icon = "Interface\\Icons\\INV_Misc_Note_06.blp",
		OnClick = function(clickedframe, button)
    		if button == "RightButton" then
    			local optionsFrame = InterfaceOptionsFrame

    			if optionsFrame:IsVisible() then
    				optionsFrame:Hide()
    			else
    				InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
    			end
    		elseif button == "LeftButton" then
    			if self:IsNotesVisible() then
    				self:HideNotesWindow()
    			else
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
		if UnitExists("target") and UnitIsPlayer("target") then
			local target = GetUnitName("target", true)
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

function CharacterNotes:GetNoteHandler(input)
	if input and #input > 0 then
		local name, note = input:match("^(%S+) *(.*)")
		name = formatCharName(name)
		note = self:GetNote(name)

        local main
        if not note then
            if self.db.profile.useLibAlts == true and LibAlts and LibAlts.GetMain then
                main = LibAlts:GetMain(name)
                if main and #main > 0 then
                    main = formatCharName(main)
                    note = self:GetNote(main)
                end
            end
        end
        
		if note then
		    if main and #main > 0 then
			    self:Print(chatNoteWithMainFormat:format(name, main, note or ""))
	        else
			    self:Print(chatNoteFormat:format(name, note or ""))
			end
		else
			self:Print(L["No note found for "]..name)
		end
	end	
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

function CharacterNotes:CreateNotesFrame()
	local noteswindow = CreateFrame("Frame", "CharacterNotesWindow", UIParent)
	noteswindow:SetFrameStrata("DIALOG")
	noteswindow:SetToplevel(true)
	noteswindow:SetWidth(630)
	noteswindow:SetHeight(430)
	noteswindow:SetPoint("CENTER", UIParent)
	noteswindow:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", 
	    edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true,
		tileSize=32, edgeSize=32, insets={left=11, right=12, top=12, bottom=11}})

	local ScrollingTable = LibStub("ScrollingTable");

	local cols = {}
	cols[1] = {
		["name"] = L["Character Name"],
		["width"] = 150,
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
		["defaultsort"] = "dsc",
		["sort"] = "dsc",
		["DoCellUpdate"] = nil,
	}
	cols[2] = {
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
		["DoCellUpdate"] = nil,
	}

	local table = ScrollingTable:CreateST(cols, 15, nil, nil, noteswindow);

	local headertext = noteswindow:CreateFontString("PN_Notes_HeaderText", noteswindow, "GameFontNormalLarge")
	headertext:SetPoint("TOP", noteswindow, "TOP", 0, -20)
	headertext:SetText(L["Character Notes"])

	local searchterm = CreateFrame("EditBox", nil, noteswindow, "InputBoxTemplate")
	searchterm:SetFontObject(ChatFontNormal)
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

	local searchbutton = CreateFrame("Button", nil, noteswindow, "UIPanelButtonTemplate")
	searchbutton:SetText(L["Search"])
	searchbutton:SetWidth(100)
	searchbutton:SetHeight(20)
	searchbutton:SetPoint("LEFT", searchterm, "RIGHT", 10, 0)
	searchbutton:SetScript("OnClick", function(this) this:GetParent().table:SortData() end)

	local clearbutton = CreateFrame("Button", nil, noteswindow, "UIPanelButtonTemplate")
	clearbutton:SetText(L["Clear"])
	clearbutton:SetWidth(100)
	clearbutton:SetHeight(20)
	clearbutton:SetPoint("LEFT", searchbutton, "RIGHT", 10, 0)
	clearbutton:SetScript("OnClick",
	    function(this)
	        searchterm:SetText("")
	        this:GetParent().table:SortData()
	    end)

	local closebutton = CreateFrame("Button", nil, noteswindow, "UIPanelButtonTemplate")
	closebutton:SetText(L["Close"])
	closebutton:SetWidth(90)
	closebutton:SetHeight(20)
	closebutton:SetPoint("BOTTOM", noteswindow, "BOTTOM", 0, 20)
	closebutton:SetScript("OnClick", function(this) this:GetParent():Hide(); end)

	local deletebutton = CreateFrame("Button", nil, noteswindow, "UIPanelButtonTemplate")
	deletebutton:SetText(L["Delete"])
	deletebutton:SetWidth(90)
	deletebutton:SetHeight(20)
	deletebutton:SetPoint("BOTTOM", noteswindow, "BOTTOM", -60, 70)
	deletebutton:SetScript("OnClick", 
		function(this)
		    local frame = this:GetParent()
			if frame.table:GetSelection() then
				local row = frame.table:GetRow(frame.table:GetSelection())
				if row[1] and #row[1] > 0 then
					confirmDeleteFrame.charname:SetText(row[1])
					confirmDeleteFrame:Show()
				end
			end
		end)

	local editbutton = CreateFrame("Button", nil, noteswindow, "UIPanelButtonTemplate")
	editbutton:SetText(L["Edit"])
	editbutton:SetWidth(90)
	editbutton:SetHeight(20)
	editbutton:SetPoint("BOTTOM", noteswindow, "BOTTOM", 60, 70)
	editbutton:SetScript("OnClick", 
		function(this)
		    local frame = this:GetParent()
			if frame.table:GetSelection() then
				local row = frame.table:GetRow(frame.table:GetSelection())
				if row[1] and #row[1] > 0 then
					self:EditNoteHandler(row[1])
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
				if row[1]:lower():find(term) or row[2]:lower():find(term) then
					return true
				end

				return false
			else
				return true
			end
		end
	)
	
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
	local deletewindow = CreateFrame("Frame", "CharacterNotesConfirmDeleteWindow", UIParent)
	deletewindow:SetFrameStrata("DIALOG")
	deletewindow:SetToplevel(true)
	deletewindow:SetWidth(400)
	deletewindow:SetHeight(200)
	deletewindow:SetPoint("CENTER", UIParent)
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

	local deletebutton = CreateFrame("Button", nil, deletewindow, "UIPanelButtonTemplate")
	deletebutton:SetText(L["Delete"])
	deletebutton:SetWidth(100)
	deletebutton:SetHeight(20)
	deletebutton:SetPoint("BOTTOM", deletewindow, "BOTTOM", -60, 20)
	deletebutton:SetScript("OnClick",
	    function(this)
	        self:DeleteNote(charname:GetText())
	        this:GetParent():Hide()
	    end)

	local cancelbutton = CreateFrame("Button", nil, deletewindow, "UIPanelButtonTemplate")
	cancelbutton:SetText(L["Cancel"])
	cancelbutton:SetWidth(100)
	cancelbutton:SetHeight(20)
	cancelbutton:SetPoint("BOTTOM", deletewindow, "BOTTOM", 60, 20)
	cancelbutton:SetScript("OnClick", function(this) this:GetParent():Hide(); end)

	deletewindow.charname = charname

	deletewindow:Hide()

	return deletewindow
end

function CharacterNotes:CreateEditNoteFrame()
	local editwindow = CreateFrame("Frame", "CharacterNotesEditWindow", UIParent)
	editwindow:SetFrameStrata("DIALOG")
	editwindow:SetToplevel(true)
	editwindow:SetWidth(400)
	editwindow:SetHeight(200)
	editwindow:SetPoint("CENTER", UIParent)
	editwindow:SetBackdrop(
		{bgFile="Interface\\ChatFrame\\ChatFrameBackground", 
	    edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true,
		tileSize=32, edgeSize=32, insets={left=11, right=12, top=12, bottom=11}})
	editwindow:SetBackdropColor(0,0,0,1)
		
	local editbox = CreateFrame("EditBox", nil, editwindow, "InputBoxTemplate")
	editbox:SetFontObject(ChatFontNormal)
	editbox:SetWidth(300)
	editbox:SetHeight(35)
	editbox:SetPoint("CENTER", editwindow)
	editbox:SetScript("OnShow", function(this) editbox:SetFocus() end)
	editbox:SetScript("OnEnterPressed",
	    function(this)
	        local frame = this:GetParent()
	        self:SaveEditNote(frame.charname:GetText(),frame.editbox:GetText())
	        frame:Hide()
	    end)
	editbox:SetScript("OnEscapePressed",
	    function(this)
	        this:SetText("")
	        this:GetParent():Hide()
	    end)

	local savebutton = CreateFrame("Button", nil, editwindow, "UIPanelButtonTemplate")
	savebutton:SetText(L["Save"])
	savebutton:SetWidth(100)
	savebutton:SetHeight(20)
	savebutton:SetPoint("BOTTOM", editwindow, "BOTTOM", -60, 20)
	savebutton:SetScript("OnClick",
	    function(this)
	        local frame = this:GetParent()
	        self:SaveEditNote(frame.charname:GetText(),frame.editbox:GetText())
	        frame:Hide()
	    end)

	local cancelbutton = CreateFrame("Button", nil, editwindow, "UIPanelButtonTemplate")
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

	editwindow.charname = charname
	editwindow.editbox = editbox

	editwindow:Hide()

	return editwindow
end

function CharacterNotes:EditNoteHandler(input)
	local name = nil
	if input and #input > 0 then
		name = input
	else
		if UnitExists("target") and UnitIsPlayer("target") then
			local target = GetUnitName("target", true)
			if target and #target > 0 then
				name = target
			end
		end
	end
	
	if name and #name > 0 then
		name = formatCharName(name)
		
		local charNote = self:GetNote(name) or ""

		local editwindow = editNoteFrame
		editwindow.charname:SetText(name)
		editwindow.editbox:SetText(charNote)

		editwindow:Show()
	end	
end

function CharacterNotes:SaveEditNote(name, note)
	if name and #name > 0 and note and #note > 0 then
		self:SetNote(name, note)
	end

	local editwindow = editNoteFrame

	editwindow.charname:SetText("")
	editwindow.editbox:SetText("")
end

function CharacterNotes:OnEnable()
    -- Called when the addon is enabled

    -- Hook the game tooltip so we can add character Notes
    self:HookScript(GameTooltip, "OnTooltipSetUnit")

	-- Hook the friends frame tooltip
	--self:HookScript("FriendsFrameTooltip_Show")

	-- Register to receive the chat messages to watch for logons and who requests
	self:RegisterEvent("CHAT_MSG_SYSTEM")

    -- Register for party and raid roster updates
    self:RegisterEvent("RAID_ROSTER_UPDATE")
    self:RegisterEvent("PARTY_MEMBERS_CHANGED")

	-- Create the Notes frame for later use
	notesFrame = self:CreateNotesFrame()
	
	-- Create the Edit Note frame to use later
	editNoteFrame = self:CreateEditNoteFrame()
	
	-- Create the Confirm Delete frame for later use
	confirmDeleteFrame = self:CreateConfirmDeleteFrame()
	
	-- Add the Edit Note menu item on unit frames
	self:AddEditNoteMenuItem()
end

function CharacterNotes:OnDisable()
    -- Called when the addon is disabled
	self:UnregisterEvent("CHAT_MSG_SYSTEM")
	
	-- Remove the menu items
	self:RemoveEditNoteMenuItem()
end

function CharacterNotes:AddEditNoteMenuItem()
	UnitPopupButtons["EDIT_NOTE"] = {text = L["Edit Note"], dist = 0}

	self:SecureHook("UnitPopup_OnClick", "EditNoteMenuClick")

	tinsert(UnitPopupMenus["PLAYER"], (#UnitPopupMenus["PLAYER"])-1, "EDIT_NOTE")
	tinsert(UnitPopupMenus["PARTY"], (#UnitPopupMenus["PARTY"])-1, "EDIT_NOTE")
	tinsert(UnitPopupMenus["RAID_PLAYER"], (#UnitPopupMenus["RAID_PLAYER"])-1, "EDIT_NOTE")
end

function CharacterNotes:RemoveEditNoteMenuItem()
	UnitPopupButtons["EDIT_NOTE"] = nil

	self:unhook("UnitPopup_OnClick")
end

function CharacterNotes:EditNoteMenuClick(self)
	local menu = UIDROPDOWNMENU_INIT_MENU
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
		tinsert(notesData, {key, value})
	end
end

function CharacterNotes:SetNote(name, note)
	if self.db.realm.notes and name then
	    name = formatCharName(name)
		self.db.realm.notes[name] = note;
		
		local found = false
		for i, v in ipairs(notesData) do
			if v[1] == name then
				notesData[i][2] = note
				found = true
			end
		end
		
		if found == false then
			tinsert(notesData, {name, note})
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

function CharacterNotes:DeleteNote(name)
	if self.db.realm.notes and name then
		self.db.realm.notes[name] = nil;
		
		for i, v in ipairs(notesData) do
			if v[1] == name then
				tremove(notesData, i)
			end
		end
		
		-- If the Notes window is shown then we need to update it
		if notesFrame:IsVisible() then
			notesFrame.table:SortData()
		end
	end
end

function CharacterNotes:OnTooltipSetUnit(tooltip, ...)
    if self.db.profile.showNotesInTooltips == false then return end

    local main
    local name, unitid = tooltip:GetUnit()

	-- If the unit exists and is a player then check if there is a note for it.
    if UnitExists(unitid) and UnitIsPlayer(unitid) then
		-- Get the unit's name including the realm name
		name = GetUnitName(unitid, true) or name
        note = self:GetNote(name)
        -- If there is no note then check if this character has a main 
        -- and if so if there is a note for that character.
        if not note then
            if self.db.profile.useLibAlts == true and LibAlts and LibAlts.GetMain then
                main = LibAlts:GetMain(name)
                if main and #main > 0 then
                    main = formatCharName(main)
                    note = self:GetNote(main)
                end
            end
        end

        if note then
			if self.db.profile.wrapTooltip == true then
			    note = wrap(note,self.db.profile.wrapTooltipLength,"    ","", 4)
			end

            if main and #main > 0 then
        	    tooltip:AddLine(tooltipNoteWithMainFormat:format(main, note))
        	else
        	    tooltip:AddLine(tooltipNoteFormat:format(note), 
        	        1, 1, 1, not self.db.profile.wrapTooltip)
    	    end
        end
    end
end

function CharacterNotes:GetFriendNote(friendName)
    numFriends = GetNumFriends()
    if numFriends > 0 then
        for i = 1, numFriends do
            name, level, class, area, connected, status, note = GetFriendInfo(i)
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
	local note = self:GetNote(name)
	if not note then
	    if self.db.profile.useLibAlts == true and LibAlts and LibAlts.GetMain then
            main = formatCharName(LibAlts:GetMain(name))
            if main and #main > 0 then
                note = self:GetNote(main)
            end
        end
    end

	if note then
	    if main and #main > 0 then
		    self:Print(chatNoteWithMainFormat:format(name, main, note))	        
        else
		    self:Print(chatNoteFormat:format(name, note))
		end
	end
end

function CharacterNotes:CHAT_MSG_SYSTEM(event, message)
	local name, type

    if self.db.profile.showNotesOnWho == true then
	    name = LibDeformat(message, WHO_LIST_FORMAT)
	    type = "WHO"
    end

	if not name and self.db.profile.showNotesOnWho == true then 
	    name = LibDeformat(message, WHO_LIST_GUILD_FORMAT)
	    type = "WHO"
	end

	if not name and self.db.profile.showNotesOnLogon == true then
	    name = LibDeformat(message, ERR_FRIEND_ONLINE_SS)
	    type = "LOGON"
	end

	if name then
		self:ScheduleTimer("DisplayNote", 0.1, name, type)
	end
end

function CharacterNotes:RAID_ROSTER_UPDATE(event, message)
    if GetNumRaidMembers() == 0 then
        -- Left a raid
        wipe(previousRaid)
    else
        if self.db.profile.notesForRaidMembers == true then
            local currentRaid = {}
            local name

            for i = 1, GetNumRaidMembers() do
                name = GetUnitName("raid"..i, true)
                if name then
                    currentRaid[name] = true

                    if not previousRaid[name] == true then
                        if DEBUG == true then
                            self:Print(name.." joined the raid.")
                        end
                        self:DisplayNote(name)
                    end
                end
            end

            -- Set previous raid to the current raid
            wipe(previousRaid)
            for name in pairs(currentRaid) do
                previousRaid[name] = true
            end
        end
    end
end

function CharacterNotes:PARTY_MEMBERS_CHANGED(event, message)
    -- If in a raid then don't worry about this event.
    if GetNumRaidMembers() > 0 then return end
        
    if GetNumPartyMembers() == 0 then
        -- Left a party
        wipe(previousParty)
    else
        if self.db.profile.notesForPartyMembers == true then
            local currentParty = {}
            local name

            for i = 1, GetNumPartyMembers() do
                name = GetUnitName("party"..i, true)
                if name then
                    currentParty[name] = true

                    if not previousParty[name] == true then
                        if DEBUG == true then
                            self:Print(name.." joined the party.")
                        end
                        self:DisplayNote(name)
                    end
                end
            end

            -- Set previous party to the current party
            wipe(previousParty)
            for name in pairs(currentParty) do
                previousParty[name] = true
            end
        end
    end
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

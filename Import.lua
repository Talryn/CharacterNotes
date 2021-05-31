local _G = getfenv(0)
local ADDON_NAME, addon = ...
local NotesDB = addon.NotesDB
local CharacterNotes = _G.LibStub("AceAddon-3.0"):GetAddon(addon.addonName)
local L = LibStub("AceLocale-3.0"):GetLocale(addon.addonName, true)
local AGU = LibStub("AceGUI-3.0")

local separator = ","

local ColumnIds = addon.ColumnIds
local ColorObjs = addon.ColorObjs
local GetRatingColor = addon.GetRatingColor
local GetRatingColorObj = addon.GetRatingColorObj
local GetRatingImage = addon.GetRatingImage

addon.importData = {}

function CharacterNotes:ShowNotesImportFrame()
    if addon.NotesImportFrame then return end

	local frame = AGU:Create("Frame")
	frame:SetTitle(L["Notes Import"])
	frame:SetWidth(650)
	frame:SetHeight(400)
    frame:SetLayout("Flow")
	frame:SetCallback("OnClose", function(widget)
		widget:ReleaseChildren()
		widget:Release()
		addon.NotesImportFrame = nil
	end)

    addon.NotesImportFrame = frame

    local multiline = AGU:Create("MultiLineEditBox")
    multiline:SetLabel(L["NotesImport_ImportLabel"])
    multiline:SetNumLines(15)
    multiline:SetMaxLetters(0)
    multiline:SetFullWidth(true)
    multiline:DisableButton(true)
    frame:AddChild(multiline)
    frame.multiline = multiline

    local spacer = AGU:Create("Label")
    spacer:SetText(" ")
    spacer:SetFullWidth(true)
    frame:AddChild(spacer)

    local overwriteOption = AGU:Create("CheckBox")
    overwriteOption:SetLabel(L["Overwrite Existing"])
    overwriteOption:SetCallback("OnValueChanged",
        function(widget, event, value)
            self.db.profile.importOverwrite = value
        end
    )
    overwriteOption:SetValue(self.db.profile.importOverwrite)
    frame:AddChild(overwriteOption)

    local disclaimer = AGU:Create("Label")
    disclaimer:SetText(L["ImportDisclaimer"])
    disclaimer:SetColor(1, 0, 0)
    disclaimer:SetFullWidth(true)
    frame:AddChild(disclaimer)

    local spacer2 = AGU:Create("Label")
    spacer2:SetText(" ")
    spacer2:SetFullWidth(true)
    frame:AddChild(spacer2)

    local importButton = AGU:Create("Button")
    importButton:SetText(L["Preview"])
    importButton:SetCallback("OnClick",
        function(widget)
            CharacterNotes:ImportNotesFromText(
                frame.multiline:GetText(), 
                self.db.profile.importOverwrite
            )
            frame:Hide()
        end)
    frame:AddChild(importButton)
end

local function ParseFields(fields)
    local name, note, rating
    if #fields == 3 then
        if _G.type(fields[1]) == "string" and 
            _G.type(fields[2]) == "string" and 
            _G.type(fields[3] == "number") then
            name = fields[1]
            note = fields[2]
            rating = fields[3]
        end
    end
    return name, note, rating
end

local function ParseCSV(text, sep)
    local entries = {}
	local res = {}
	local pos = 1
	sep = sep or ','
	while true do
		local c = string.sub(text, pos, pos)
		if c == "" then break end
        if c == '\r' or c == '\n' then
            if #res > 0 then
                table.insert(entries, res)
                res = {}
            end
            pos = pos + 1
		elseif c == '"' then
			-- quoted value (ignore separator within)
			local txt = ""
			repeat
				local startp, endp = string.find(text, '^%b""', pos)
				txt = txt..string.sub(text, startp + 1, endp - 1)
				pos = endp + 1
				c = string.sub(text, pos, pos)
				if c == '"' then txt = txt..'"' end 
				-- check first char AFTER quoted string, if it is another
				-- quoted string without separator, then append it
				-- this is the way to "escape" the quote char in a quote. example:
				--   value1,"blub""blip""boing",value3  will result in blub"blip"boing  for the middle
			until c ~= '"'
			table.insert(res, txt)
			assert(c == sep or c == "" or c == '\r' or c == '\n')
			pos = pos + 1
		else	
			-- no quotes used, just look for the first separator or EOL
			local startp, endp = string.find(text, sep, pos)
            local starteol, endeol = string.find(text, '[\r\n]+', pos)
            -- If there is a separator before the EOL
			if startp and not (starteol and starteol < startp) then
				table.insert(res, string.sub(text, pos, startp - 1))
				pos = endp + 1
			else
				-- no separator found, use EOL if found
                if starteol then
                    table.insert(res, string.sub(text, pos, starteol - 1))
                    pos = starteol
                else
                    table.insert(res, string.sub(text, pos))
                    break
                end
			end 
		end
	end
    if #res > 0 then
        table.insert(entries, res)
    end
	return entries
end

function CharacterNotes:ImportNotes(importData, overwrite)
    local imported = 0
    for i, fields in _G.pairs(importData) do
        local name = fields[ColumnIds.Name]
        local note = fields[ColumnIds.Note]
        local rating = fields[ColumnIds.Rating]
        if name and note and rating then
            local exists = NotesDB:GetNote(name) ~= nil
            if not exists or overwrite then
                NotesDB:SetNote(name, note)
                local ratingValue = _G.tonumber(rating)
                if ratingValue then
                    NotesDB:SetRating(name, ratingValue)
                end
                imported = imported + 1
            end
        end
    end
    local importFmt = L["ImportResult"]
    self:Print(importFmt:format(imported))
end

function CharacterNotes:CreateImportPreview()
    if addon.ImportPreview then return end

    local frame = _G.CreateFrame("Frame", "CharacterNotesImportPreview", _G.UIParent, BackdropTemplateMixin and "BackdropTemplate")
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetWidth(630)
	frame:SetHeight(430)
	if self.db.profile.remember_main_pos then
    	frame:SetPoint("CENTER", _G.UIParent, "CENTER",
    	    self.db.profile.notes_window_x, self.db.profile.notes_window_y)
    else
    	frame:SetPoint("CENTER", _G.UIParent)
    end
	frame:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
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

	local table = ScrollingTable:CreateST(cols, 15, nil, nil, frame);

	local font, fh, fflags = addon.GetFontSettings()

	local headertext = frame:CreateFontString("CN_Import_HeaderText", "OVERLAY")
	headertext:SetFont(font, fh + 4, fflags)
	headertext:SetPoint("TOP", frame, "TOP", 0, -20)
	headertext:SetText(L["Import"])

	local searchterm = _G.CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
	searchterm:SetFontObject(_G.ChatFontNormal)
	searchterm:SetWidth(300)
	searchterm:SetHeight(35)
	searchterm:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, -50)
	searchterm:SetScript("OnShow", function(this) this:SetFocus() end)
	searchterm:SetScript("OnEnterPressed", function(this) this:GetParent().table:SortData() end)
	searchterm:SetScript("OnEscapePressed",
	    function(this)
	        this:SetText("")
	        this:GetParent():Hide()
	    end)

	table.frame:SetPoint("TOP", searchterm, "BOTTOM", 0, -20)
	table.frame:SetPoint("LEFT", frame, "LEFT", 20, 0)

    local searchbutton = _G.CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	searchbutton:SetText(L["Search"])
	searchbutton:SetWidth(100)
	searchbutton:SetHeight(20)
	searchbutton:SetPoint("LEFT", searchterm, "RIGHT", 10, 0)
	searchbutton:SetScript("OnClick", function(this) this:GetParent().table:SortData() end)

	local clearbutton = _G.CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	clearbutton:SetText(L["Clear"])
	clearbutton:SetWidth(100)
	clearbutton:SetHeight(20)
	clearbutton:SetPoint("LEFT", searchbutton, "RIGHT", 10, 0)
	clearbutton:SetScript("OnClick",
	    function(this)
	        searchterm:SetText("")
	        this:GetParent().table:SortData()
	    end)

	local importbutton = _G.CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	importbutton:SetText(L["Import"])
	importbutton:SetWidth(90)
	importbutton:SetHeight(20)
	importbutton:SetPoint("BOTTOM", frame, "BOTTOM", -60, 20)
	importbutton:SetScript("OnClick",
		function(this)
            CharacterNotes:ImportNotes(addon.importData, self.db.profile.importOverwrite)
            this:GetParent():Hide()
		end)

	local closebutton = _G.CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	closebutton:SetText(L["Close"])
	closebutton:SetWidth(90)
	closebutton:SetHeight(20)
	closebutton:SetPoint("BOTTOM", frame, "BOTTOM", 60, 20)
	closebutton:SetScript("OnClick", function(this) this:GetParent():Hide(); end)

    local statstext = frame:CreateFontString("CN_Import_StatsText", "OVERLAY")
	statstext:SetFont(font, fh, fflags)
	statstext:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 60)
	statstext:SetText("")

	frame.table = table
    table:SetData(addon.importData, true)
	frame.searchterm = searchterm
    frame.statstext = statstext

	table:EnableSelection(true)
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

    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart",
        function(self,button)
			if not self.lock then
            	self:StartMoving()
			end
        end)
        frame:SetScript("OnDragStop",
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
    frame:EnableMouse(true)
    frame:Hide()
	addon.ImportPreview = frame
end

function CharacterNotes:ShowImportPreview(total, valid, existing, toImport)
    self:CreateImportPreview()

    local statsFmt = L["ImportStats"]
    local stats = statsFmt:format(toImport, total, valid, existing)

    local importPreview = addon.ImportPreview
    importPreview.statstext:SetText(stats or "")
    importPreview:Show()
    importPreview.table:SortData()
	importPreview:Show()
	importPreview:Raise()
end

function CharacterNotes:ImportNotesFromText(importText, overwrite)
    local valid = 0
    local total = 0
    local existing = 0
    local toImport = 0

    table.wipe(addon.importData)

    local entries = ParseCSV(importText, separator)
    for i, fields in _G.pairs(entries) do
        local name, note, rating = ParseFields(fields)
        if name and note and rating then
            valid = valid + 1
            local exists = NotesDB:GetNote(name) ~= nil
            if exists then
                existing = existing + 1
            end
            if not exists or overwrite then
                table.insert(addon.importData, {
                    [ColumnIds.Rating] = _G.tonumber(rating) or 0,
                    [ColumnIds.Name] = name,
                    [ColumnIds.Note] = note})
                toImport = toImport + 1
            end
        end
        total = total + 1
    end

    self:ShowImportPreview(total, valid, existing, toImport)
end

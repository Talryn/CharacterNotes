local _G = getfenv(0)
local ADDON_NAME, addon = ...

local pairs = _G.pairs
local ipairs = _G.ipairs
local type = _G.type

local wrap = addon.wrap
local Colors = addon.Colors
local Formats = addon.Formats
local GetRatingColor = addon.GetRatingColor

local NotesDB = addon.NotesDB
local CharacterNotes = _G.LibStub("AceAddon-3.0"):GetAddon(addon.addonName)
local L = LibStub("AceLocale-3.0"):GetLocale(addon.addonName, true)

function addon.GetMouseFocusFrame()
	if _G.GetMouseFocus then
		return _G.GetMouseFocus()
	elseif _G.GetMouseFoci then
		return _G.GetMouseFoci()
	end
end

local ScrollBoxUtil = {}
function ScrollBoxUtil:OnViewFramesChanged(scrollBox, callback)
	if not scrollBox then return end
	if scrollBox.buttons then
		callback(scrollBox.buttons, scrollBox)
		return
	end
	if scrollBox.RegisterCallback then
		local frames = scrollBox:GetFrames()
		if frames and frames[1] then
			callback(frames, scrollBox)
		end
		scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnUpdate, function()
			callback(scrollBox:GetFrames(), scrollBox)
		end)
		return
	end
end

function ScrollBoxUtil:OnViewScrollChanged(scrollBox, callback)
	if not scrollBox then return end
	local function wrappedCallback()
		callback(scrollBox)
	end
	if scrollBox.update then
		hooksecurefunc(scrollBox, "update", wrappedCallback)
		return
	end
	if scrollBox.RegisterCallback then
		scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnScroll, wrappedCallback)
		return
	end
end

local hooked = {}
local function HookAllFrames(frames, functions)
	for _, frame in ipairs(frames) do
		hooked[frame] = hooked[frame] or {}
		local hook = hooked[frame]
		for script, func in pairs(functions) do
			hook[script] = hook[script] or {}
			local fnHook = hook[script]
			if not fnHook[func] then
				frame:HookScript(script, func)
				fnHook[func] = true
			end
		end
	end
end

function CharacterNotes:EnableInterfaceModifications()
  if addon.Retail then
    if self.db.profile.uiModifications["LFGLeaderTooltip"] then
      hooksecurefunc("LFGListUtil_SetSearchEntryTooltip",
        CharacterNotes.LFGListUtil_SetSearchEntryTooltip)
    end
    if self.db.profile.uiModifications["LFGGroupMenuEditNote"] then
      --hooksecurefunc("EasyMenu_Initialize", CharacterNotes.EasyMenu_Initialize)
    end
	CharacterNotes:EnableModule("LFGApplicantTooltip")
	CharacterNotes:EnableModule("GuildTooltip")
	CharacterNotes:EnableModule("CommunitiesTooltip")
  end

  -- Works for all versions
  CharacterNotes:EnableModule("UnitPopupMenus")
  CharacterNotes:EnableModule("IgnoreTooltip")
end

function CharacterNotes.LFGListUtil_SetSearchEntryTooltip(tooltip, resultID, autoAcceptOption)
	local searchResultInfo = C_LFGList.GetSearchResultInfo(resultID);
  local leader = searchResultInfo.leaderName
	local note, rating, main, nameFound = NotesDB:GetInfoForNameOrMain(leader)

	if note then
		tooltip:AddLine(" ")

		if addon.db.profile.wrapTooltip == true then
			note = wrap(note, addon.db.profile.wrapTooltipLength, "    ", "", 4)
		end

		if main and #main > 0 then
      tooltip:AddLine(Formats.nameWithMainRating:format(GetRatingColor(rating), main, leader))
      tooltip:AddLine(note, 1, 1, 1)
		else
      tooltip:AddLine(Formats.nameRating:format(GetRatingColor(rating), nameFound))
      tooltip:AddLine(note, 1, 1, 1)
		end

		tooltip:Show()
	end
end

do
	local module = CharacterNotes:NewModule("LFGApplicantTooltip")
	module.enabled = false
	local activeEntry = {}

	local OnEnter, OnLeave

	local function IsEnabled()
    	if not addon.Retail then
      		return false
    	end
    	return addon.db.profile.uiModifications.LFGApplicantTooltip
	end

	local hooked = {}
	local function HookFrames(frames)
		if not frames then return end
		for _, frame in pairs(frames) do
			if not hooked[frame] then
				frame:HookScript("OnEnter", OnEnter)
				frame:HookScript("OnLeave", OnLeave)
				hooked[frame] = true
			end
		end
	end

	function OnEnter(self)
        local entry = C_LFGList.GetActiveEntryInfo()
        if entry then
            activeEntry.activityID = entry.activityID
        end
        if not activeEntry.activityID or not IsEnabled() then
            return
        end

		if self.applicantID and self.Members then
			HookFrames(self.Members)
			return
		elseif self.memberIdx then
			local id = self:GetParent().applicantID
			local name = C_LFGList.GetApplicantMemberInfo(id, self.memberIdx)
			local note, rating, main, nameFound = NotesDB:GetInfoForNameOrMain(name)

			if note then
				GameTooltip:AddLine(" ")
				if addon.db.profile.wrapTooltip == true then
					note = wrap(note, addon.db.profile.wrapTooltipLength, "    ", "", 4)
				end
				if main and #main > 0 then
					GameTooltip:AddLine(Formats.tooltipNoteWithMain:format(GetRatingColor(rating), nameFound, note))
				else
					GameTooltip:AddLine(Formats.tooltipNote:format(GetRatingColor(rating), note))
				end
				GameTooltip:Show()
			end
		end
	end

	function OnLeave(self)
		GameTooltip:Hide()
	end

	local function OnScroll(self)
    	if not IsEnabled() then return end
		GameTooltip:Hide()
		local frame = addon.GetMouseFocusFrame()
		pcall(frame, "OnEnter")
	end

	function module:Setup()
    	if not IsEnabled() then return end
		if self.enabled then return end

		local hooks = { ["OnEnter"] = OnEnter, ["OnLeave"] = OnLeave }
        ScrollBoxUtil:OnViewFramesChanged(_G.LFGListFrame.SearchPanel.ScrollBox, function(frames) HookAllFrames(frames, hooks) end)
        ScrollBoxUtil:OnViewScrollChanged(_G.LFGListFrame.SearchPanel.ScrollBox, OnScroll)
        ScrollBoxUtil:OnViewFramesChanged(_G.LFGListFrame.ApplicationViewer.ScrollBox, function(frames) HookAllFrames(frames, hooks) end)
        ScrollBoxUtil:OnViewScrollChanged(_G.LFGListFrame.ApplicationViewer.ScrollBox, OnScroll)

		self.enabled = true
	end

	function module:OnEnable()
		self:Setup()
	end
end

function CharacterNotes.EasyMenu_Initialize(frame, level, menuList)
	local isLFGAdded = false

	if _G.getn(menuList) > 3 and menuList[3].text == LFG_LIST_REPORT_GROUP_FOR then
		local leaderName = menuList[2].arg1

		for k, v in _G.pairs(menuList) do
			if v.text == L["Edit Note for Leader"] then
				isLFGAdded = true
				return
			end
		end

		if not isLFGAdded then
			UIDropDownMenu_AddButton({
				text = L["Edit Note for Leader"],
				func = function(_, leaderName)
					CharacterNotes:EditNoteHandler(leaderName)
				end,
				arg1 = leaderName,
				notCheckable = true,
				disabled = nil,
				colorCode = GREEN,
				}, 1)
		end
	end
end

do
	local module = CharacterNotes:NewModule("GuildTooltip")
	module.enabled = false

	local function IsEnabled()
    	if not addon.Retail then
      		return false
    	end
    	return addon.db.profile.uiModifications.GuildRosterTooltip
	end

	local function OnEnter(self)
	    if not IsEnabled() then return end
    	if not self.guildIndex then return end
    	local name = _G.GetGuildRosterInfo(self.guildIndex)
		local note, rating, main, nameFound = NotesDB:GetInfoForNameOrMain(name)
		if note then
			GameTooltip:AddLine(" ")

			if addon.db.profile.wrapTooltip == true then
				note = wrap(note, addon.db.profile.wrapTooltipLength, "    ", "", 4)
			end

			if main and #main > 0 then
				GameTooltip:AddLine(Formats.tooltipNoteWithMain:format(GetRatingColor(rating), nameFound, note))
			else
				GameTooltip:AddLine(Formats.tooltipNote:format(GetRatingColor(rating), note))
			end

			GameTooltip:Show()
		end
	end

	local function OnLeave(self)
	    if not IsEnabled() then return end
    	if not self.guildIndex then return end
    	GameTooltip:Hide()
	end

	local function OnScroll()
    	if not IsEnabled() then return end
		GameTooltip:Hide()
		pcall(addon.GetMouseFocusFrame(), "OnEnter")
	end

	function module:Setup()
		if not IsEnabled() or self.enabled then return end
		if not _G.GuildFrame then
			-- If enabled, keep trying until the guild frame is loaded.
			C_Timer.After(1, function()
				self:Setup()
			end)
			return
		end
		local hooks = { ["OnEnter"] = OnEnter, ["OnLeave"] = OnLeave }
		ScrollBoxUtil:OnViewFramesChanged(_G.GuildRosterContainer, function(frames) HookAllFrames(frames, hooks) end)
		ScrollBoxUtil:OnViewScrollChanged(_G.GuildRosterContainer, OnScroll)
		self.enabled = true
	end

	function module:OnEnable()
		self:Setup()
	end
end

function AddNoteToTooltip(tooltip, name, anchor)
	local spacer = true
	local anchorPoint = anchor or "ANCHOR_LEFT"
	local note, rating, main, nameFound = NotesDB:GetInfoForNameOrMain(name)
	if note then
		if tooltip:GetOwner() == nil then
			tooltip:SetOwner(self, anchorPoint)
		elseif spacer then
			tooltip:AddLine(" ")
		end

		if addon.db.profile.wrapTooltip == true then
	    	note = wrap(note, addon.db.profile.wrapTooltipLength, "    ", "", 4)
		end

		if main and #main > 0 then
			tooltip:AddLine(Formats.tooltipNoteWithMain:format(GetRatingColor(rating), nameFound, note))
		else
			tooltip:AddLine(Formats.tooltipNote:format(GetRatingColor(rating), note))
		end

    	tooltip:Show()
	end
end

do
	local module = CharacterNotes:NewModule("CommunitiesTooltip")
	module.enabled = false

	local function IsEnabled()
    	if not addon.Retail then
      		return false
    	end
    	return addon.db.profile.uiModifications.CommunitiesTooltip
	end

	local function IsCharacter(clubType)
		return clubType and (clubType == Enum.ClubType.Guild or
			clubType == Enum.ClubType.Character)
	end

	local function OnEnter(self)
	    if not IsEnabled() then return end
		local name
    	if type(self.GetMemberInfo) == "function" then
    		local info = self:GetMemberInfo()
			if not IsCharacter(info.clubType) then return end
    		name = info.name
    	elseif type(self.cardInfo) == "table" then
      		name = self.cardInfo.guildLeader
    	else
      		return
    	end
		if not name then return end

		local note, rating, main, nameFound = NotesDB:GetInfoForNameOrMain(name)
		if note then
			if GameTooltip:GetOwner() == nil then
				GameTooltip:SetOwner(self, "ANCHOR_LEFT")
			else
				GameTooltip:AddLine(" ")
			end

			if addon.db.profile.wrapTooltip == true then
				note = wrap(note, addon.db.profile.wrapTooltipLength, "    ", "", 4)
			end

			if main and #main > 0 then
				GameTooltip:AddLine(Formats.tooltipNoteWithMain:format(GetRatingColor(rating), nameFound, note))
			else
				GameTooltip:AddLine(Formats.tooltipNote:format(GetRatingColor(rating), note))
			end

			GameTooltip:Show()
		end
	end

	local function OnLeave(self)
	    if not IsEnabled() then return end
    	if not self.guildIndex then return end
    	GameTooltip:Hide()
  	end

	local function OnScroll()
	    if not IsEnabled() then return end
		GameTooltip:Hide()
		pcall(addon.GetMouseFocusFrame(), "OnEnter")
	end

	local hooked = {}
	local function HookFrames(frames)
		if not frames then return end
		for _, frame in pairs(frames) do
			if not hooked[frame] then
				frame:HookScript("OnEnter", OnEnter)
				frame:HookScript("OnLeave", OnLeave)
        		if type(frame.OnEnter) == "function" then hooksecurefunc(frame, "OnEnter", OnEnter) end
        		if type(frame.OnLeave) == "function" then hooksecurefunc(frame, "OnLeave", OnLeave) end
				hooked[frame] = true
			end
		end
	end

	local function OnRefreshLayout()
	    if not IsEnabled() then return end
		HookFrames(_G.ClubFinderGuildFinderFrame.GuildCards.Cards)
        HookFrames(_G.ClubFinderGuildFinderFrame.PendingGuildCards.Cards)
        HookFrames(_G.ClubFinderCommunityAndGuildFinderFrame.GuildCards.Cards)
        HookFrames(_G.ClubFinderCommunityAndGuildFinderFrame.PendingGuildCards.Cards)
		return true
	end

	function module:Setup()
    	if not IsEnabled() then return end
		if self.enabled then return end
		if not (_G.CommunitiesFrame and _G.ClubFinderGuildFinderFrame and _G.ClubFinderCommunityAndGuildFinderFrame) then
			-- If enabled, keep trying until the guild frame is loaded.
			C_Timer.After(1, function()
				self:Setup()
			end)
			return
		end

        ScrollBoxUtil:OnViewFramesChanged(_G.CommunitiesFrame.MemberList.ListScrollFrame or _G.CommunitiesFrame.MemberList.ScrollBox, HookFrames)
        ScrollBoxUtil:OnViewScrollChanged(_G.CommunitiesFrame.MemberList.ListScrollFrame or _G.CommunitiesFrame.MemberList.ScrollBox, OnScroll)
        ScrollBoxUtil:OnViewFramesChanged(_G.ClubFinderGuildFinderFrame.CommunityCards.ListScrollFrame or _G.ClubFinderGuildFinderFrame.CommunityCards.ScrollBox, HookFrames)
        ScrollBoxUtil:OnViewScrollChanged(_G.ClubFinderGuildFinderFrame.CommunityCards.ListScrollFrame or _G.ClubFinderGuildFinderFrame.CommunityCards.ScrollBox, OnScroll)
        ScrollBoxUtil:OnViewFramesChanged(_G.ClubFinderGuildFinderFrame.PendingCommunityCards.ListScrollFrame or _G.ClubFinderGuildFinderFrame.PendingCommunityCards.ScrollBox, HookFrames)
        ScrollBoxUtil:OnViewScrollChanged(_G.ClubFinderGuildFinderFrame.PendingCommunityCards.ListScrollFrame or _G.ClubFinderGuildFinderFrame.PendingCommunityCards.ScrollBox, OnScroll)
        ScrollBoxUtil:OnViewFramesChanged(_G.ClubFinderCommunityAndGuildFinderFrame.CommunityCards.ListScrollFrame or _G.ClubFinderCommunityAndGuildFinderFrame.CommunityCards.ScrollBox, HookFrames)
        ScrollBoxUtil:OnViewScrollChanged(_G.ClubFinderCommunityAndGuildFinderFrame.CommunityCards.ListScrollFrame or _G.ClubFinderCommunityAndGuildFinderFrame.CommunityCards.ScrollBox, OnScroll)
        ScrollBoxUtil:OnViewFramesChanged(_G.ClubFinderCommunityAndGuildFinderFrame.PendingCommunityCards.ListScrollFrame or _G.ClubFinderCommunityAndGuildFinderFrame.PendingCommunityCards.ScrollBox, HookFrames)
        ScrollBoxUtil:OnViewScrollChanged(_G.ClubFinderCommunityAndGuildFinderFrame.PendingCommunityCards.ListScrollFrame or _G.ClubFinderCommunityAndGuildFinderFrame.PendingCommunityCards.ScrollBox, OnScroll)
        hooksecurefunc(_G.ClubFinderGuildFinderFrame.GuildCards, "RefreshLayout", OnRefreshLayout)
        hooksecurefunc(_G.ClubFinderGuildFinderFrame.PendingGuildCards, "RefreshLayout", OnRefreshLayout)
        hooksecurefunc(_G.ClubFinderCommunityAndGuildFinderFrame.GuildCards, "RefreshLayout", OnRefreshLayout)
        hooksecurefunc(_G.ClubFinderCommunityAndGuildFinderFrame.PendingGuildCards, "RefreshLayout", OnRefreshLayout)
		self.enabled = true
	end

	function module:OnEnable()
		self:Setup()
	end
end

function addon.GetNameFromPlayerLink(playerLink)
	if not _G.LinkUtil or not _G.ExtractLinkData then return nil end
	local linkString, linkText = _G.LinkUtil.SplitLink(playerLink)
	local linkType, linkData = _G.ExtractLinkData(linkString)
	if linkType == "player" then
		return linkData
	elseif linkType == "BNplayer" then
		local _, bnetIDAccount = _G.strsplit(":", linkData)
		if bnetIDAccount then
			local bnetID = _G.tonumber(bnetIDAccount)
			if bnetID then
				return addon.GetNameForBNetFriend(bnetID)
			end
		end
	end
end

function addon.GetNameForBNetFriend(bnetIDAccount)
	if not C_BattleNet then return nil end
	local index = _G.BNGetFriendIndex(bnetIDAccount)
	if not index then return nil end
	for i = 1, C_BattleNet.GetFriendNumGameAccounts(index), 1 do
		local accountInfo = C_BattleNet.GetFriendGameAccountInfo(index, i)
		if accountInfo and accountInfo.clientProgram == BNET_CLIENT_WOW and (not accountInfo.wowProjectID or accountInfo.wowProjectID ~= WOW_PROJECT_CLASSIC) then
			if accountInfo.realmName then
				accountInfo.characterName = accountInfo.characterName .. "-" .. accountInfo.realmName:gsub("%s+", "")
			end
			return accountInfo.characterName
		end
	end
	return nil
end

do
	local module = CharacterNotes:NewModule("UnitPopupMenus")
	module.enabled = false

	local function IsEnabled()
    	return addon.db.profile.uiModifications.unitMenusEdit
  	end

	local dropDownTypes = {
        ARENAENEMY = true,
        BN_FRIEND = true,
        CHAT_ROSTER = true,
        COMMUNITIES_GUILD_MEMBER = true,
        COMMUNITIES_WOW_MEMBER = true,
        FOCUS = true,
        FRIEND = true,
        GUILD = true,
        GUILD_OFFLINE = true,
        PARTY = true,
        PLAYER = true,
        RAID = true,
        RAID_PLAYER = true,
        SELF = true,
        TARGET = true,
        WORLD_STATE_SCORE = true
    }

	local function IsUnitDropDown(dropdown)
		return type(dropdown.which) == "string" and dropDownTypes[dropdown.which]
	end

	local function GetName(dropdown)
		local unit = dropdown.unit
		if _G.UnitExists(unit) and _G.UnitIsPlayer(unit) then
			return _G.GetUnitName(unit, true)
		end
		if dropdown.bnetIDAccount then
			local name = addon.GetNameForBNetFriend(dropdown.bnetIDAccount)
			if name then return name end
		end
		if dropdown.menuList then
            for _, whisperButton in ipairs(dropdown.menuList) do
                if whisperButton and (whisperButton.text == _G.WHISPER_LEADER or whisperButton.text == _G.WHISPER) then
                    if whisperButton.arg1 then
						return whisperButton.arg1
					end
                end
            end
        end
		if dropdown.quickJoinButton or dropdown.quickJoinMember then
			local memberInfo = dropdown.quickJoinMember or quickJoinButton.Members[1]
			if memberInfo.playerLink then
				local name = addon.GetNameFromPlayerLink(memberInfo.playerLink)
				if name then return name end
			end
		end
		if dropdown.name and not dropdown.bnetIDAccount then
			local name = NotesDB:FormatNameWithRealm(dropdown.name, dropdown.server)
			if name then return name end
		end
		return nil
	end

	local function OnToggle(dropdown, event, options, level, data)
		if not addon.db.profile.uiModifications.unitMenusEdit then return end
        if event == "OnShow" then
            if not IsUnitDropDown(dropdown) then return end
            local name = GetName(dropdown)
            if not name then return end
			module.name = name

			local added = false
			for key, unitOption in pairs(data.unitOptionsLookup) do
				local found = false
				for _, option in ipairs(options) do
					if option.text == key then
						found = true
						break
					end
				end
				if not found then
					_G.table.insert(options, unitOption)
					added = true
				end
			end

			if added then
                return true
            end
        elseif event == "OnHide" then
			_G.wipe(options)
			return true
        end
    end

    ---@type LibDropDownExtension
    local LibDropDownExtension = LibStub and LibStub:GetLibrary("LibDropDownExtension-1.0", true)

	function module:HasMenu()
		return Menu and Menu.ModifyMenu
	end

	function module:MenuHandler(owner, rootDescription, contextData)
		rootDescription:CreateDivider();
		rootDescription:CreateTitle(addon.addonTitle);
		rootDescription:CreateButton(L["Edit Note"], function()
			DevTools_Dump(contextData)
			local name = NotesDB:FormatNameWithRealm(contextData.name, contextData.server)
			if name then
				CharacterNotes:EditNoteHandler(name)
			end
		end)
	end

	function module:AddItemsWithMenu()
		if not self:HasMenu() then return end

		-- Find via /run Menu.PrintOpenMenuTags()
		local menuTags = {
			["MENU_UNIT_PLAYER"] = true,
			["MENU_UNIT_FRIEND"] = true,
			--["MENU_CHAT_FRAME_CHANNEL"] = true,
			["MENU_UNIT_COMMUNITIES_GUILD_MEMBER"] = true,
			["MENU_UNIT_COMMUNITIES_MEMBER"] = true,
			["MENU_LFG_FRAME_SEARCH_ENTRY"] = true,
		}

		for tag, enabled in pairs(menuTags) do
			Menu.ModifyMenu(tag, GenerateClosure(self.MenuHandler, self))
		end
	end

	function module:AddItemsWithDDE()
		if not LibDropDownExtension then return end

		self.unitOptions = {
			{
				text = L["Edit Note"],
				func = function()
					CharacterNotes:EditNoteHandler(module.name)
				end
			}
		}

		self.unitOptionsLookup = {}
		for _, option in ipairs(self.unitOptions) do
			self.unitOptionsLookup[option.text] = option
		end

		LibDropDownExtension:RegisterEvent("OnShow OnHide", OnToggle, 1, self)
	end

	function module:Setup()
		if not IsEnabled() then return end

		if self:HasMenu() then
			self:AddItemsWithMenu()
		else
			self:AddItemsWithDDE()
		end
		self.enabled = true
	end

	function module:OnEnable()
		self:Setup()
	end
end

do
	local module = CharacterNotes:NewModule("IgnoreTooltip")
	module.enabled = false

	local function IsEnabled()
    	return addon.db.profile.uiModifications.ignoreTooltips
  	end

	local function IgnoreButtonEnter(self, ...)
		local label = self.name
		if not label then return end
		if _G.type(label.GetText) ~= "function" then 
			return
		end

		local name = label:GetText()
		if not name then return end

		local note, rating, main, nameFound = NotesDB:GetInfoForNameOrMain(name)
		if note then
			if GameTooltip:GetOwner() == nil then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:AddLine(nameFound or name)
				GameTooltip:AddLine(" ")
			else
				GameTooltip:AddLine(" ")
			end

			if addon.db.profile.wrapTooltip == true then
				note = wrap(note, addon.db.profile.wrapTooltipLength, "    ", "", 4)
			end

			if main and #main > 0 then
				GameTooltip:AddLine(Formats.tooltipNoteWithMain:format(GetRatingColor(rating), nameFound, note))
			else
				GameTooltip:AddLine(Formats.tooltipNote:format(GetRatingColor(rating), note))
			end

			GameTooltip:Show()
		end
	end

	local function IgnoreButtonLeave(self, ...)
		GameTooltip:Hide()
	end

	local ignoreFrame = _G.IgnoreListFrameScrollFrame
	local function getButton(index)
		if ignoreFrame then
			local buttons = ignoreFrame.buttons
			return buttons[index]
		else
			return _G["FriendsFrameIgnoreButton"..index]
		end
	end

	function module:Setup()
		if not IsEnabled() then return end

		for index = 1, IGNORES_TO_DISPLAY do
			local button = getButton(index)
			if button then
				button:HookScript("OnEnter", IgnoreButtonEnter)
				button:HookScript("OnLeave", IgnoreButtonLeave)
			end
		end	
	end

	function module:OnEnable()
		self:Setup()
	end
end
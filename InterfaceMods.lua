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

function CharacterNotes:EnableInterfaceModifications()
  if not addon.Classic then
    if self.db.profile.uiModifications["LFGLeaderTooltip"] then
      hooksecurefunc("LFGListUtil_SetSearchEntryTooltip",
        CharacterNotes.LFGListUtil_SetSearchEntryTooltip)
    end
    if self.db.profile.uiModifications["LFGApplicantTooltip"] then
      hooksecurefunc("LFGListApplicationViewer_UpdateResults",
        CharacterNotes.LFGListApplicationViewer_UpdateResults)
    end
    if addon.db.profile.addMenuItems and self.db.profile.uiModifications["LFGGroupMenuEditNote"] then
      hooksecurefunc("EasyMenu_Initialize", CharacterNotes.EasyMenu_Initialize)
    end
	CharacterNotes:EnableModule("GuildTooltip")
	CharacterNotes:EnableModule("CommunitiesTooltip")
  end
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

-- LFG applicant tooltip
local function OnLeaveHideTooltip(self)
	GameTooltip:Hide()
end

local applicantHooked = {}
function CharacterNotes.LFGListApplicationViewer_UpdateResults(self)
	for _, button in ipairs(self.ScrollFrame.buttons) do
		if button.applicantID and button.Members then
			for _, member in ipairs(button.Members) do
				if not applicantHooked[member] then
					applicantHooked[member] = true
					member:HookScript("OnEnter", function()
						local name = C_LFGList.GetApplicantMemberInfo(button.applicantID, 1)
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

					end)
					member:HookScript("OnLeave", OnLeaveHideTooltip)
				end
			end
		end
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
		pcall(_G.GetMouseFocus(), "OnEnter")
	end

  local function IsEnabled()
    return addon.db.profile.uiModifications.GuildRosterTooltip
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
		for _, button in pairs(_G.GuildRosterContainer.buttons) do
			button:HookScript("OnEnter", OnEnter)
			button:HookScript("OnLeave", OnLeave)
		end
		hooksecurefunc(_G.GuildRosterContainer, "update", OnScroll)
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
		pcall(_G.GetMouseFocus(), "OnEnter")
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
		HookFrames(_G.CommunitiesFrame.MemberList.ListScrollFrame.buttons)
    HookFrames(_G.ClubFinderGuildFinderFrame.CommunityCards.ListScrollFrame.buttons)
    HookFrames(_G.ClubFinderGuildFinderFrame.PendingCommunityCards.ListScrollFrame.buttons)
    HookFrames(_G.ClubFinderGuildFinderFrame.GuildCards.Cards)
    HookFrames(_G.ClubFinderGuildFinderFrame.PendingGuildCards.Cards)
    HookFrames(_G.ClubFinderCommunityAndGuildFinderFrame.CommunityCards.ListScrollFrame.buttons)
    HookFrames(_G.ClubFinderCommunityAndGuildFinderFrame.PendingCommunityCards.ListScrollFrame.buttons)
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

    hooksecurefunc(_G.CommunitiesFrame.MemberList, "RefreshLayout", OnRefreshLayout)
    hooksecurefunc(_G.CommunitiesFrame.MemberList, "Update", OnScroll)
    hooksecurefunc(_G.ClubFinderGuildFinderFrame.CommunityCards, "RefreshLayout", OnRefreshLayout)
    hooksecurefunc(_G.ClubFinderGuildFinderFrame.CommunityCards.ListScrollFrame, "update", OnScroll)
    hooksecurefunc(_G.ClubFinderGuildFinderFrame.PendingCommunityCards, "RefreshLayout", OnRefreshLayout)
    hooksecurefunc(_G.ClubFinderGuildFinderFrame.PendingCommunityCards.ListScrollFrame, "update", OnScroll)
    hooksecurefunc(_G.ClubFinderGuildFinderFrame.GuildCards, "RefreshLayout", OnRefreshLayout)
    hooksecurefunc(_G.ClubFinderGuildFinderFrame.PendingGuildCards, "RefreshLayout", OnRefreshLayout)
    hooksecurefunc(_G.ClubFinderCommunityAndGuildFinderFrame.CommunityCards, "RefreshLayout", OnRefreshLayout)
    hooksecurefunc(_G.ClubFinderCommunityAndGuildFinderFrame.CommunityCards.ListScrollFrame, "update", OnScroll)
    hooksecurefunc(_G.ClubFinderCommunityAndGuildFinderFrame.PendingCommunityCards, "RefreshLayout", OnRefreshLayout)
    hooksecurefunc(_G.ClubFinderCommunityAndGuildFinderFrame.PendingCommunityCards.ListScrollFrame, "update", OnScroll)
    hooksecurefunc(_G.ClubFinderCommunityAndGuildFinderFrame.GuildCards, "RefreshLayout", OnRefreshLayout)
    hooksecurefunc(_G.ClubFinderCommunityAndGuildFinderFrame.PendingGuildCards, "RefreshLayout", OnRefreshLayout)
		self.enabled = true
	end

	function module:OnEnable()
		self:Setup()
	end
end

local _G = getfenv(0)
local ADDON_NAME, addon = ...

local ipairs = _G.ipairs

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

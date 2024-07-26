local _G = getfenv(0)
local ADDON_NAME, addon = ...

-- Try to remove the Git hash at the end, otherwise return the passed in value.
local function cleanupVersion(version)
	local iter = string.gmatch(version, "(.*)-[a-z0-9]+$")
	if iter then
		local ver = iter()
		if ver and #ver >= 3 then
			return ver
		end
	end
	return version
end

local function versionInRange(version, start, finish)
  if _G.type(version) ~= "number" then return false end
  local start = start or 0
  local finish = finish or 100000000
  if _G.type(start) ~= "number" or _G.type(finish) ~= "number" then return false end
  return version >= start and version < finish
end

addon.addonTitle = _G.GetAddOnMetadata(ADDON_NAME,"Title")
addon.addonVersion = cleanupVersion("@project-version@")

addon.CURRENT_BUILD, addon.CURRENT_INTERNAL,
  addon.CURRENT_BUILD_DATE, addon.CURRENT_UI_VERSION = _G.GetBuildInfo()
addon.Classic = versionInRange(addon.CURRENT_UI_VERSION, 0, 20000)
addon.TBC = versionInRange(addon.CURRENT_UI_VERSION, 20000, 30000)
addon.Retail = versionInRange(addon.CURRENT_UI_VERSION, 90000)
addon.DF = versionInRange(addon.CURRENT_UI_VERSION, 100000)
addon.TWW = versionInRange(addon.CURRENT_UI_VERSION, 110000)

addon.Colors = {
  Green =  "|cff00ff00",
  Yellow = "|cffffff00",
  Red =    "|cffff0000",
  Blue =   "|cff0198e1",
  Orange = "|cffff9933",
  White =  "|cffffffff",
}
local Colors = addon.Colors

addon.ColorObjs = {
  Red    = {["r"] = 1, ["g"] = 0, ["b"] = 0, ["a"] = 1},
  Yellow = {["r"] = 1, ["g"] = 1, ["b"] = 0, ["a"] = 1},
  Green  = {["r"] = 0, ["g"] = 1, ["b"] = 0, ["a"] = 1},
}
local ColorObjs = addon.ColorObjs

addon.ColumnIds = {
  Rating = 1,
  Name = 2,
  Note = 3,
}

addon.RatingOptions = {
    [-1] = {
      title = "Negative",
      color = Colors.Red,
      colorObj = ColorObjs.Red,
      image = "Interface\\RAIDFRAME\\ReadyCheck-NotReady.blp"
    },
    [0] = {
      title = "Neutral",
      color = Colors.Yellow,
      colorObj = ColorObjs.Yellow,
      image = ""
    },
    [1] = {
      title = "Positive",
      color = Colors.Green,
      colorObj = ColorObjs.Green,
      image = "Interface\\RAIDFRAME\\ReadyCheck-Ready.blp"
    },
}

function addon.GetRatingColor(rating)
    local color = Colors.Yellow
    if rating ~= nil and rating >= -1 and rating <= 1 then
        local ratingInfo = addon.RatingOptions[rating]
        if ratingInfo and ratingInfo.color then
            color = ratingInfo.color
        end
    end
    return color
end

function addon.GetRatingColorObj(rating)
    local color = ColorObjs.Yellow
    if rating ~= nil and rating >= -1 and rating <= 1 then
        local ratingInfo = addon.RatingOptions[rating]
        if ratingInfo and ratingInfo.colorObj then
            color = ratingInfo.colorObj
        end
    end
    return color
end

function addon.GetRatingImage(rating)
    local image = ""
    if rating ~= nil and rating >= -1 and rating <= 1 then
        local ratingInfo = addon.RatingOptions[rating]
        if ratingInfo and ratingInfo.image then
            image = ratingInfo.image
        end
    end
    return image
end

function addon.wrap(str, limit, indent, indent1,offset)
	indent = indent or ""
	indent1 = indent1 or indent
	limit = limit or 72
	offset = offset or 0
	local here = 1 - #indent1 - offset
	return indent1..str:gsub("(%s+)()(%S+)()",
		function(sp, st, word, fi)
			if fi-here > limit then
				here = st - #indent
				return "\n"..indent..word
			end
		end)
end

function addon.IsGameOptionsVisible()
	local optionsFrame = _G.SettingsPanel or _G.InterfaceOptionsFrame
    return optionsFrame and optionsFrame:IsVisible() or false
end

function addon.ShowGameOptions()
	local optionsFrame = _G.SettingsPanel or _G.InterfaceOptionsFrame
    optionsFrame:Show()
end

function addon.HideGameOptions()
	local optionsFrame = _G.SettingsPanel or _G.InterfaceOptionsFrame
	if _G.SettingsPanel then
		if not _G.UnitAffectingCombat("player") then
			_G.HideUIPanel(optionsFrame)
		end
	else
		optionsFrame:Hide()
	end
end

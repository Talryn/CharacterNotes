local _G = getfenv(0)
local ADDON_NAME, addon = ...

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

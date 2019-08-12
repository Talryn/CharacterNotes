local _G = getfenv(0)
local ADDON_NAME, AddonData = ...

local NotesDB = {}
AddonData.NotesDB = NotesDB

-- Use local versions of standard LUA items for performance
local string = _G.string
local table = _G.table
local pairs = _G.pairs
local ipairs = _G.ipairs
local select = _G.select
local tinsert, tremove, tContains = tinsert, tremove, tContains
local unpack, next = _G.unpack, _G.next
local wipe = _G.wipe

local LibAlts = LibStub("LibAlts-1.0")

NotesDB.playerRealm = nil
NotesDB.playerRealmAbbr = nil

local realmNames = {
    ["Aeriepeak"] = "AeriePeak",
    ["Altarofstorms"] = "AltarofStorms",
    ["Alteracmountains"] = "AlteracMountains",
    ["Aman'thul"] = "Aman'Thul",
    ["Argentdawn"] = "ArgentDawn",
    ["Azjolnerub"] = "AzjolNerub",
    ["Blackdragonflight"] = "BlackDragonflight",
    ["Blackwaterraiders"] = "BlackwaterRaiders",
    ["Blackwinglair"] = "BlackwingLair",
    ["Blade'sedge"] = "Blade'sEdge",
    ["Bleedinghollow"] = "BleedingHollow",
    ["Bloodfurnace"] = "BloodFurnace",
    ["Bloodsailbuccaneers"] = "BloodsailBuccaneers",
    ["Boreantundra"] = "BoreanTundra",
    ["Burningblade"] = "BurningBlade",
    ["Burninglegion"] = "BurningLegion",
    ["Cenarioncircle"] = "CenarionCircle",
    ["Darkiron"] = "DarkIron",
	["Darkmoonfaire"] = "DarkmoonFaire",
    ["Dath'remar"] = "Dath'Remar",
    ["Demonsoul"] = "DemonSoul",
    ["Drak'tharon"] = "Drak'Tharon",
    ["Earthenring"] = "EarthenRing",
    ["Echoisles"] = "EchoIsles",
    ["Eldre'thalas"] = "Eldre'Thalas",
    ["Emeralddream"] = "EmeraldDream",
    ["Grizzlyhills"] = "GrizzlyHills",
    ["Jubei'thos"] = "Jubei'Thos",
    ["Kel'thuzad"] = "Kel'Thuzad",
    ["Khazmodan"] = "KhazModan",
    ["Kirintor"] = "KirinTor",
    ["Kultiras"] = "KulTiras",
    ["Laughingskull"] = "LaughingSkull",
    ["Lightning'sblade"] = "Lightning'sBlade",
    ["Mal'ganis"] = "Mal'Ganis",
    ["Mok'nathal"] = "Mok'Nathal",
    ["Moonguard"] = "MoonGuard",
    ["Quel'thalas"] = "Quel'Thalas",
    ["Scarletcrusade"] = "ScarletCrusade",
    ["Shadowcouncil"] = "ShadowCouncil",
    ["Shatteredhalls"] = "ShatteredHalls",
    ["Shatteredhand"] = "ShatteredHand",
    ["Silverhand"] = "SilverHand",
    ["Sistersofelune"] = "SistersofElune",
    ["Steamwheedlecartel"] = "SteamwheedleCartel",
    ["Theforgottencoast"] = "TheForgottenCoast",
    ["Thescryers"] = "TheScryers",
    ["Theunderbog"] = "TheUnderbog",
    ["Theventureco"] = "TheVentureCo",
    ["Thoriumbrotherhood"] = "ThoriumBrotherhood",
    ["Tolbarad"] = "TolBarad",
    ["Twistingnether"] = "TwistingNether",
    ["Wyrmrestaccord"] = "WyrmrestAccord",
}

local MULTIBYTE_FIRST_CHAR = "^([\192-\255]?%a?[\128-\191]*)"

--- Returns a name formatted in title case (i.e., first character upper case, the rest lower).
-- @name :TitleCase
-- @param name The name to be converted.
-- @return string The converted name.
function NotesDB:TitleCase(name)
    if not name then return "" end
    if #name == 0 then return "" end
	name = name:lower()
    return name:gsub(MULTIBYTE_FIRST_CHAR, string.upper, 1)
end

function NotesDB:GetProperRealmName(realm)
	if not realm then return end
	realm = self:TitleCase(realm:gsub("[ -]", ""))
	return realmNames[realm] or realm
end

function NotesDB:FormatNameWithRealm(name, realm, relative)
	if not name then return end
	name = self:TitleCase(name)
	realm = self:GetProperRealmName(realm)
	if relative and realm and realm == self.playerRealmAbbr then
		return name
	elseif realm and #realm > 0 then
		return name.."-"..realm
	else
		return name
	end
end

function NotesDB:FormatRealmName(realm)
	-- Spaces are removed.
	-- Dashes are removed. (e.g., Azjol-Nerub)
	-- Apostrophe / single quotes are not removed.
	if not realm then return end
	return realm:gsub("[ -]", "")
end

function NotesDB:HasRealm(name)
	if not name then return end
	local matches = name:gmatch("[-]")
	return matches and matches()
end

function NotesDB:ParseName(name)
	if not name then return end
	local matches = name:gmatch("([^%-]+)")
	if matches then
		local nameOnly = matches()
		local realm = matches()
		return nameOnly, realm
	end
	return nil
end

function NotesDB:FormatUnitName(name, relative)
	local nameOnly, realm = self:ParseName(name)
	return self:FormatNameWithRealm(nameOnly, realm, relative)
end

function NotesDB:FormatUnitList(sep, relative, ...)
	local str = ""
	local first = true
	local v
	for i = 1, select('#', ...), 1 do
		v = select(i, ...)
		if v and #v > 0 then
			if not first then str = str .. sep end
			str = str .. self:FormatUnitName(v, relative)
			if first then first = false end
		end
	end
	return str
end

function NotesDB:GetAlternateName(name)
	local nameOnly, realm = self:ParseName(name)
	return realm and self:TitleCase(nameOnly) or
		self:FormatNameWithRealm(self:TitleCase(nameOnly), self.playerRealmAbbr)
end

function NotesDB:GetNote(name)
	if self.db.realm.notes and name then
		local nameFound = self:FormatUnitName(name)
		local note = self.db.realm.notes[nameFound]
		if not note then
			local altName = self:GetAlternateName(name)
			note = self.db.realm.notes[altName]
			if note then nameFound = altName end
		end
		return note, nameFound
	end
end

function NotesDB:GetRating(name)
	if self.db.realm.ratings and name then
		local nameFound = self:FormatUnitName(name)
		local rating = self.db.realm.ratings[nameFound]
		if not rating then
			local altName = self:GetAlternateName(name)
			rating = self.db.realm.ratings[altName]
			if rating then nameFound = altName end
		end
		return rating, nameFound

	end
end

function NotesDB:SetNote(name, note)
	if self.db.realm.notes and name then
	    name = self:FormatUnitName(name)
		self.db.realm.notes[name] = note

		if self.CharacterNotes and self.CharacterNotes.UpdateNote then
			self.CharacterNotes:UpdateNote(name, note)
		end
	end
end

function NotesDB:SetRating(name, rating)
	if self.db.realm.ratings and name and rating >= -1 and rating <= 1 then
	    name = self:FormatUnitName(name)
		self.db.realm.ratings[name] = rating

		if self.CharacterNotes and self.CharacterNotes.UpdateRating then
			self.CharacterNotes:UpdateRating(name, rating)
		end
    end
end

function NotesDB:DeleteNote(name)
	if self.db.realm.notes and name then
	    name = self:FormatUnitName(name)

        -- Delete both the note and the rating.
		self.db.realm.notes[name] = nil
		self.db.realm.ratings[name] = nil

		if self.CharacterNotes and self.CharacterNotes.RemoveNote then
			self.CharacterNotes:RemoveNote(name)
		end
	end
end

function NotesDB:DeleteRating(name)
	if self.db.realm.ratings and name then
	    name = self:FormatUnitName(name)
		self.db.realm.ratings[name] = nil

		if self.CharacterNotes and self.CharacterNotes.RemoveRating then
			self.CharacterNotes:RemoveRating(name)
		end
	end
end

function NotesDB:GetInfoForNameOrMain(name)
	name = self:FormatUnitName(name)
    local note, nameFound = self:GetNote(name)
    local rating = self:GetRating(nameFound)
    local main = nil
    -- If there is no note then check if this character has a main
    -- and if so if there is a note for that character.
    if not note then
        if self.db.profile.useLibAlts == true and LibAlts and LibAlts.GetMain then
            main = LibAlts:GetMain(name)
            if main and #main > 0 then
                main = self:FormatUnitName(main)
                note, nameFound = self:GetNote(main)
                rating = self:GetRating(nameFound)
			else
	            main = LibAlts:GetMain(self:GetAlternateName(name))
	            if main and #main > 0 then
	                main = self:FormatUnitName(main)
	                note, nameFound = self:GetNote(main)
	                rating = self:GetRating(nameFound)
				end
            end
        end
    end

    return note, rating, main, nameFound
end

function NotesDB:OnInitialize(CharacterNotes)
	self.CharacterNotes = CharacterNotes
	self.db = CharacterNotes.db
	self.playerRealm = _G.GetRealmName()
	self.playerRealmAbbr = self:FormatRealmName(self.playerRealm)
end

function NotesDB:OnEnable()
end

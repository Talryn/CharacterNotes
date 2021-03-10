local _G = getfenv(0)
local ADDON_NAME, addon = ...

local CharacterNotes = LibStub("AceAddon-3.0"):GetAddon(addon.addonName)
local L = LibStub("AceLocale-3.0"):GetLocale(addon.addonName, true)
local icon = LibStub("LibDBIcon-1.0")

function CharacterNotes:GetOptions()
  if not self.options then
    options = {
      name = ADDON_NAME,
      type = 'group',
      args = {
        core = {
          order = 1,
          name = L["General Options"],
          type = "group",
          args = {
      		headerGeneralOptions = {
      			order = 0,
      			type = "header",
      			name = L["General Options"],
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
            multilineNotes = {
                  name = L["Multiline Notes"],
                  desc = L["MultilineNotes_OptionDesc"],
                  type = "toggle",
                  set = function(info, val) self.db.profile.multilineNotes = val end,
                  get = function(info) return self.db.profile.multilineNotes end,
      			order = 50
              },
      	    addMenuItems = {
                  name = L["Add Menu Items"],
                  desc = L["AddMenuItems_OptionDesc"],
                  type = "toggle",
                  set = function(info, val) self.db.profile.addMenuItems = val end,
                  get = function(info) return self.db.profile.addMenuItems end,
      			order = 60
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
                      self.notesFrame.lock = val
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
          },
          headerInterfaceMods = {
      			order = 500,
      			type = "header",
      			name = L["Interface Modifications"],
      		},
          interfaceModGroupDesc = {
            order = 501,
            type = "description",
            name = L["InterfaceModifications_Desc"],
          },
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

  -- Add in the relevant interface modification options.
  local intModOpts = self:InterfaceModsOptions()
  for k, v in _G.pairs(intModOpts) do
    options.args.core.args[k] = v
  end

  return options
end

function CharacterNotes:InterfaceModsOptions()
  local baseOrder = 500

  -- Options for all versions
  local allOptions = {}

  -- Options for current retail version.
  local currentOptions = {
    lfgLeaderTooltip = {
        name = L["LFG Leader Tooltip"],
        desc = L["LFGLeaderTooltip_Opt"],
        type = "toggle",
        set = function(info,val) self.db.profile.uiModifications.LFGLeaderTooltip = val end,
        get = function(info) return self.db.profile.uiModifications.LFGLeaderTooltip end,
        order = baseOrder + 10
    },
    lfgApplicantTooltip = {
        name = L["LFG Applicant Tooltip"],
        desc = L["LFGApplicantTooltip_Opt"],
        type = "toggle",
        set = function(info,val) self.db.profile.uiModifications.LFGApplicantTooltip = val end,
        get = function(info) return self.db.profile.uiModifications.LFGApplicantTooltip end,
        order = baseOrder + 20
    },
    lfgGroupMenuEditNote = {
        name = L["LFG Group Menu-Edit Note"],
        desc = L["LFGGroupMenuEditNote_Opt"],
        type = "toggle",
        set = function(info,val) self.db.profile.uiModifications.LFGGroupMenuEditNote = val end,
        get = function(info) return self.db.profile.uiModifications.LFGGroupMenuEditNote end,
        order = baseOrder + 30
    },
  }

  -- Options for Classic only.
  local classicOptions = {
  }

  local options = allOptions

  if not addon.Classic then
    for k, v in _G.pairs(currentOptions) do
      options[k] = v
    end
  end

  if addon.Classic then
    for k, v in _G.pairs(classicOptions) do
      options[k] = v
    end
  end

  return options
end

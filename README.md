
## Overview

Character Notes is a World of Warcraft addon that allows you to set and manage notes on other player's characters. Notes are stored per realm so notes are shared across your characters on a realm. Notes can be set on any character name. The notes are simple and generic and are not tied to a friend, an ignored character, etc.

Notes are displayed:

* When that character logs on
* When you do a /who on that character
* In unit tooltips
* Optionally as a hyperlink in chat
* From a command line interface
* From a GUI interface 

Notes can be set and managed:

* By right-clicking on a unit frame
* Right clicking a name in chat or in the friends list
* From a command line interface
* From a GUI interface
* LDB launcher to bring up the GUI interface
* Minimap button to bring up the GUI interface 

## Additional Features

Character Notes can use LibAlts to get main-alt information. If no note is found for a character but one is found for the main of that character, it will display the note for the main.

Notes can be stored for characters not from your server but you'll need to use /editnote or the "Edit Note" menu item due to the spaces in the name (from the server name added at the end).

Note Links will add a hyperlink in chat next to any player name that you have set a note for. Clicking the "note" link will display the note in a tooltip.

## Command-line options

    /notes - Brings up the GUI
    /searchnote <search term> - Brings up the GUI. Optional search term allows filtering the list of notes.
    /setnote <name> <note> Sets a note for the character name specified.
    /delnote <name> Deletes the note for the character name specified.
    /getnote <name> Prints the note for the character name specified.
    /editnote <name> Brings up a window to edit the note for the name specified or your target if no name if specified. 
    /setrating <name> <rating> Sets the rating for a note. (Rating: -1 = Negative, 0 = Neutral, 1 = Positive)
    /notesexport Brings up the notes export window.
    /notesimport Brings up the notes import window.

## Import / Export

Via the interface options or command line you can initiate an export or import of notes.

Exported notes can be used in spreadsheets, other applications, or imported into this
addon.  The export is in the comma-separated value (CSV) format.  If you choose to Escape values, it will put double quotes around text fields.

You can also import notes into the addon.  **This feature can result in data loss.**  Backup
your data (the Saved Variables) before importing in case you need to restore your data if
anything goes wrong.  You can find the file at `<WoW-Folder>\<flavor>\WTF\Account\<account>\Saved Variables\CharacterNotes.lua`.  Flavor is the game type such as `_retail_` or `_classic_`.

In order to import notes from this addon, when you export you **must** select all fields and turn on `Escape?` values.  Any spaces or newlines in a note will cause issues and possible corrupt the import.  Escaping the values will preserve the data.

A preview window shows what will be imported giving you a chance to verify the data
looks correct.  By default the addon will not overwrite existing data.  If you wish to overwrite existing notes, then toggle the Overwrite Existing option.
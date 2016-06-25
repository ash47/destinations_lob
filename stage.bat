:: -- Compile the scripts --
::call compile.bat

:: -- Stage source2 binaries --

:: Cleanup the old copy of it
rmdir /S /Q "loz"

:: Create directory structure
mkdir "loz"
mkdir "loz\game"
mkdir "loz\content"
::mkdir "dota\game\resource"
::mkdir "dota\game\scripts\npc"
::mkdir "dota\game\maps"

:: Link the maps
mklink /D /J "loz\game\maps" "maps"
mklink /D /J "loz\content\maps" "src\maps"

mkdir "loz\game\panorama"
::mkdir "loz\game\panorama\localization"
mklink /D /J "loz\game\panorama\localization" "src\localization"

:: Hard link info files
mklink /H "loz\game\addoninfo.txt" "src\addoninfo.txt"

:: Hard link top level scripts
mklink /D /J "loz\game\scripts" "src\scripts"
::mklink /H "dota\game\scripts\custom_events.txt" "src\scripts\custom_events.txt"
::mklink /H "dota\game\scripts\stat_collection.kv" "src\scripts\stat_collection.kv"
::mklink /H "dota\game\scripts\custom_net_tables.txt" "src\scripts\custom_net_tables.txt"

:: Hard link the panorama source code
mklink /D /J "loz\content\panorama" "src\panorama"

:: Hard link NPC scripts
::mklink /H "dota\game\scripts\npc\activelist.txt" "src\scripts\npc\activelist.txt"
::mklink /H "dota\game\scripts\npc\herolist.txt" "src\scripts\npc\herolist.txt"
::mklink /H "dota\game\scripts\npc\npc_units_custom.txt" "script_generator\BIN\npc_units_custom.txt"
::mklink /H "dota\game\scripts\npc\npc_items_custom.txt" "src\scripts\npc\npc_items_custom.txt"

:: Link script folders
::mklink /D /J "dota\game\scripts\vscripts" "src\scripts\vscripts\"
::mklink /D /J "dota\game\scripts\kv" "src\scripts\kv"
::mklink /D /J "dota\game\scripts\abilities" "src\scripts\abilities"
::mklink /D /J "dota\game\scripts\game_sounds" "src\scripts\game_sounds"

:: Link particle folder


:: Link resource folders
::mklink /D /J "dota\game\resource\flash3" "src\resource\flash3"
::mklink /D /J "dota\game\resource\overviews" "src\resource\overviews"

:: Hard link generated scripts
::mklink /H "dota\game\resource\addon_english.txt" "script_generator\BIN\addon_english_token.txt"
::mklink /H "dota\game\panorama\localization\addon_english.txt" "script_generator\BIN\addon_english.txt"

::mklink /H "dota\game\resource\addon_schinese.txt" "script_generator\BIN\addon_schinese_token.txt"
::mklink /H "dota\game\panorama\localization\addon_schinese.txt" "script_generator\BIN\addon_schinese.txt"

::mklink /H "dota\game\panorama\localization\addon_english.txt" "script_generator\BIN\addon_english.txt"
::mklink /H "dota\game\panorama\localization\addon_russian.txt" "script_generator\BIN\addon_russian.txt"

::mklink /H "dota\game\scripts\npc\npc_abilities_override.txt" "src\scripts\npc\npc_abilities_override.txt"
::mklink /H "dota\game\scripts\npc\npc_abilities_custom.txt" "src\scripts\npc\npc_abilities_custom.txt"
::mklink /H "dota\game\scripts\npc\npc_heroes_custom.txt" "script_generator\BIN\npc_heroes_custom.txt"

:: Hard link materials folder
mklink /D /J "loz\content\materials" "src\materials"
mklink /D /J "loz\content\models" "src\models"
mklink /D /J "loz\content\particles" "src\particles"
mklink /D /J "loz\content\soundevents" "src\soundevents"

:: Hard link maps
::mklink /H "dota\game\maps\dota_pvp.vpk" "maps\dota_pvp.vpk"
::mklink /H "dota\game\maps\dota_pvp_tiled.vpk" "maps\dota_pvp_tiled.vpk"


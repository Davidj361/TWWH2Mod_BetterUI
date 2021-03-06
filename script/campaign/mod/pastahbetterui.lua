--  Copyright (C) 2020 David Jatczak <david.j.361@gmail.com>
--  
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.

--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.

--  You should have received a copy of the GNU General Public License
--  along with this program.  If not, see <https://www.gnu.org/licenses/>.


--[[
TODO LIST
* Minimize intervention diplomacy
* Add load game button in battles
* Able to move camera during end turn
* WASD in diplomacy
* Make overlay colours better in campaign
* Shortcut keys for browsing notifications
* Fix skip dialogues where audio actually plays with skip


* Attitude Stuff:
   * Tooltips for minimize button and faction attitude overlay
   * Button for toggling all attitudes in your faction panel
   
Suggestions
* Settlement list similar to diplomacy screen, making it easier to jump around
   * Has more info

* "The delay when you craft something as dawii and the crafting screen pops back up after (feels kinda janky to me)"
"Idk what I expect from that but it feels somewhat odd not being able to skip the animation and having the crafting interface disappear and reappear" 
   
* Game Bug: Camera doesn't follow the AI faction after this faction initiates diplomacy with you
--]]




------------
-- Variables
------------

local ModName = "Pastah's BetterUI"
local Prefix = "PastahBetterUi"
local LogFile = "pastah.log" -- Used for Log and LogUic
local FirstWrite = true
-- UIC handles
local root
local layout
local faction_panel
-- Things to disable when toggling diplomacy panel \/
local minDiploJankyButtons = {
   missionsButton,
   factionsButton,
   financeButton,
   intrigueButton,
   generalButton,
   eventsButton,
}
-- This is outside because it needs recursion
local unitsList
-- Things to disable /\
-- UIC handles
local restartButton
local attitudeContainer
local diplo -- Diplomacy Drop Down UIC
local minDiplo -- button for minimize diplomacy : UIC
local smallBar -- Frame for the minDiplo button
local minDiploToggle = false -- toggle state of the button
local lastClickTime = 0 -- last time for double click
local attitudeIcons = {
   veryPositive = "ui/PastahBetterUI/icon_status_attitude_very_positive_24px.png",
   positive = "ui/PastahBetterUI/icon_status_attitude_positive_24px.png",
   neutral = "ui/PastahBetterUI/icon_status_attitude_neutral_24px.png",
   negative = "ui/PastahBetterUI/icon_status_attitude_negative_24px.png",
   veryNegative = "ui/PastahBetterUI/icon_status_attitude_very_negative_24px.png"
}
local selectedFaction
local selectedFactionEvent = "ScriptEvent_"..Prefix.."_SelectedFaction"
local listeners = {} -- Event listeners
local comps = {} -- A collection of UIC/components
-- Listeners to not cleanup if not cleanAll
local dontClean = {}
-- Attitude hover data for diplomacy screen
local hoverAttitude = {
   faction = nil,
   listener = nil, -- for passing MouseOn events to original button
   others = {},
}
-- For easily disabling vanilla buttons
local Components = require("uic/components")
local clock = os.clock
package.path = package.path .. ";script/campaign/mod/includes/?.lua"
local factionsTableDB = require("factions_table")
local inspect = require("inspect")
--local csv = require("csv")
--local ftcsv = require('ftcsv')
--local tsv = require("tsv")




------------
-- Functions
------------

function sleep(n)  -- seconds
   local t0 = clock()
   while clock() - t0 <= n do end
end


local function Log(text)
   -- Clear log file
   if FirstWrite then
	  local file = io.open(LogFile, "w")
	  file:write()
	  file:close()
	  FirstWrite = false
   end

   if type(text) == "string" then
	  local file = io.open(LogFile, "a")
	  file:write(text.."\n")
	  file:close()
   end
end


-- Stolen from output_uicomponent()
local function LogUic(uic, omit_children)
   if not is_uicomponent(uic) then
	  Log("ERROR: output_uicomponent() called but supplied object [" .. tostring(uic) .. "] is not a ui component")
	  return
   end
   
   -- not sure how this can happen, but it does ...
   if not pcall(function() Log("uicomponent " .. tostring(uic:Id()) .. ":") end) then
	  Log("output_uicomponent() called but supplied component seems to not be valid, so aborting")
	  return
   end
   
   Log("")
   Log("path from root:\t\t" .. uicomponent_to_str(uic))
   
   local pos_x, pos_y = uic:Position()
   local size_x, size_y = uic:Bounds()

   Log("position on screen:\t" .. tostring(pos_x) .. ", " .. tostring(pos_y))
   Log("size:\t\t\t" .. tostring(size_x) .. ", " .. tostring(size_y))
   Log("state:\t\t" .. tostring(uic:CurrentState()))
   Log("visible:\t\t" .. tostring(uic:Visible()))
   Log("priority:\t\t" .. tostring(uic:Priority()))
   
   if not omit_children then
	  Log("children:")
	  
	  for i = 0, uic:ChildCount() - 1 do
		 local child = UIComponent(uic:Find(i))
		 
		 Log(tostring(i) .. ": " .. child:Id())
	  end
   end

   Log("")
end


local function mypcall(func)
   local function errFunc(err)
	  Log("Error in "..ModName..":")
	  Log(err)
	  Log(debug.traceback())
   end
   return function(context)
	  local function f()
		 func(context)
	  end
	  local ok,err = xpcall(f, errFunc)
   end
end


local function recurseFind(uic, search)
   if not is_uicomponent(uic) then
	  return false
   end
   local ret = uic:Find(search)
   if ret then
	  return UIComponent(ret)
   end
   for i = 0, uic:ChildCount() - 1 do
	  ret = recurseFind(uic:Find(i), search)
	  if is_uicomponent(ret) then
		 return ret
	  end
   end
   return false
end


-- A mapping template function
-- search is the UIC ID
-- invert is whether to match or not match, then apply func
local function mapUic(uic, func, search, invert)
   if not is_uicomponent(uic) then
	  return
   end
   if invert then
	  if not search or (search and uic:Id() ~= search) then
		 func(uic)
	  end
   else
	  if not search or (search and uic:Id() == search) then
		 func(uic)
	  end
   end
   for i = 0, uic:ChildCount() - 1 do
	  mapUic( UIComponent(uic:Find(i)), func, search )
   end
end


local function mydebug()
   Log("-----------------------------------------------------")
   LogUic(root)
   Log("minDiploToggle: "..tostring(minDiploToggle))
   Log("-----------------------------------------------------")
end

local function LogComps()
   Log("------------------------------")
   Log("Logging comps table")
   for k,v in pairs(comps) do
	  Log("k: "..k..", v: ")
	  LogUic(v)
   end
   Log("Logging comps End")
   Log("------------------------------")
end


-- Hook functions so we can create a list of listeners and components for cleanup later
-- First argument indicates whether to clean event listener if diplomacy panel is closed
local function addListener(...)
   local firstArg = arg[1]
   if is_boolean(firstArg) and firstArg then
	  dontClean[ arg[2] ] = true
	  table.remove(arg,1)
   end
   listeners[ arg[1] ] = true
   return core:add_listener(unpack(arg))
end

local function createComp(...)
   local slf = arg[1]
   table.remove(arg,1)
   if comps[arg[1]] then return end -- Already exists?
   local ret = UIComponent(slf:CreateComponent(unpack(arg)))
   comps[ret:Id()] = ret
   return ret
end

local function newButton(...)
   if comps[arg[1]] then return end -- Already exists?
   local ret = Button.new(unpack(arg))
   comps[ret.uic:Id()] = ret.uic
   return ret
end


local function copyComp(...)
   local slf = arg[1]
   table.remove(arg,1)
   if comps[arg[1]] then return end -- Already exists?
   local ret = UIComponent(slf:CopyComponent(unpack(arg)))
   comps[ret:Id()] = ret
   return ret
end


-- faction2 is giving attitude
-- faction is receiving attitude
local function getAttitudeIcon(faction, faction2)
   local attitude = faction2:diplomatic_attitude_towards(faction:name())
   -- This is guessed
   -- Very Positive (50, infinity)
   -- Positive (15, 50]
   -- Neutral [-15, 15]
   -- Negative [-50, -15)
   -- Very Negative (-infinity, -50)
   local ret
   if attitude < -50 then
	  ret = attitudeIcons.veryNegative
   elseif attitude < -15 then
	  ret = attitudeIcons.negative
   elseif attitude <= 15 then
	  ret = attitudeIcons.neutral
   elseif attitude <= 50 then
	  ret = attitudeIcons.positive
   elseif attitude > 50 then
	  ret = attitudeIcons.veryPositive
   end
   return ret
end


local function getFactionFromImage(uic)
   local image = uic:GetImagePath()
   --ui\flags\wh_main_emp_empire_separatists/mon_24.png
   local factionName = image:sub(10):match("(.*)/")
   local faction = cm:get_faction(factionName)
   -- Check faction's table for proper faction
   if not faction then
	  -- Have to change image to match with factionsTableDB
	  -- Looks like: ui\\flags\\wh_main_brt_artois
	  -- Ours: ui\flags\wh_dlc03_bst_beastmen_rebels/mon_24.png
	  local flags_path = image:match("(.*)/")
	  local tooltip = uic:GetTooltipText()
	  local screenName = tooltip:match("(.*) %- Click to show on map$")
	  for k,v in pairs(factionsTableDB) do
		 --if v.flags_path == image and v.screen_name == screenName then
		 if v.flags_path == flags_path then
			if not k:match(".*_(%w*(qb)%w*)") and not k:match(".*_(%w*(ally)%w*)") then
			   factionName = k
			end
		 end
	  end
   end
   faction = cm:get_faction(factionName)

   if not faction then
	  error(ModName..": couldn't find faction on MouseOn for 'flag'.\nImage was: "..image.."\nFaction: "..factionName)
   end
   return faction
end


function hoverAttitude:generateMain(uic, faction)
   -- faction2 = getFactionFromImage(faction2)
   local faction2 = selectedFaction
   if not faction or not faction2 then return end -- If either faction is invalid
   self:generateComps(uic, faction, faction2)
end


-- Creates 2 attitude icons
-- Top is how faction feels towards faction2
-- Bottom is how faction2 feels towards faction
function hoverAttitude:generateComps(uic, faction, faction2)
   local names = { "pastahhoverattitude", "pastahhoverattitude2" } -- helps make it unique
   local factions = { faction, faction2 }
   local Y = { -1, 1 }

   for i,name in ipairs(names) do
	  local comp
	  if (uic:Id() == "attitude") then
		 comp = UIComponent( uic:CreateComponent(name, "ui/templates/custom_image") )
	  else
		 comp = UIComponent( attitudeContainer:CreateComponent(name, "ui/templates/custom_image") )
	  end
	  local arrow = UIComponent( comp:CreateComponent("arrow", "ui/templates/custom_image") )
	  -- Apparently you need to set state and set visible with custom_image
	  comp:SetState("custom_state_1")
	  comp:SetVisible(true)
	  comp:Resize(20,20)
	  arrow:SetState("custom_state_1")
	  arrow:SetVisible(true)
	  arrow:Resize(10,10)

	  local icon
	  local playerFaction = cm:get_faction(cm:get_local_faction(true))
	  if faction == faction2 or factions[(i+1)%2+1] == playerFaction then
		 icon = "ui/skins/default/icon_status_attitude_neutral_24px.png"
	  else
		 icon = getAttitudeIcon(factions[i%2+1], factions[(i+1)%2+1])
	  end
	  comp:SetImagePath(icon)
	  if i == 1 then
		 arrow:SetImagePath("UI/PastahBetterUI/arrow_right.png")
	  else
		 arrow:SetImagePath("UI/PastahBetterUI/arrow_left.png")
	  end
	  local yOffset = 2
	  local xOffset = 2
	  local x, y = uic:Position()
	  if (uic:Id() == "attitude") then
		 xOffset = 20
		 comp:MoveTo(x + xOffset, y + Y[i]*8 + yOffset)
	  elseif (uic:Id() == "button_faction") then
		 xOffset = 2*uic:Width()/3
		 yOffset = uic:Height()/3
		 comp:MoveTo(x + xOffset, y + Y[i]*8 + yOffset)
	  else
		 -- It's a flag
		 comp:MoveTo(x + xOffset, y + Y[i]*10 + yOffset)
	  end
	  x, y = comp:Position()
	  arrow:MoveTo(x + 14, y + 5)
	  if uic:Id() ~= "attitude" then
		 -- Needs unique names because of hash table others
		 self.others[name.."_"..tostring(uic:Address())] = comp
	  end
   end
end


function hoverAttitude:generateRows()
   --root > diplomacy_dropdown > faction_panel > sortable_list_factions > list_clip > list_box > faction_row_entry_wh_dlc03_bst_beastmen_chaos
   mapUic(faction_panel, mypcall(
			 function(var)
				local factionName = var:Id():match("^faction_row_entry_(.*)")
				if not factionName then return end
				local faction = cm:get_faction(factionName)
				local attitudeIcon = find_uicomponent(var, "attitude")
				local faction = cm:get_faction(factionName)
				hoverAttitude:generateMain(attitudeIcon, faction)
			 end))
end


function hoverAttitude:generateFactionButton(faction2)
   local uic = find_uicomponent(diplo, "faction_right_status_panel", "button_faction")
   local faction = getFactionFromImage(uic)
   if not faction or not faction2 then return end -- If either faction is invalid
   self:generateComps(uic, faction, faction2)
end


function hoverAttitude:generateOthers(faction2)
   -- Left Panel root > diplomacy_dropdown > faction_left_status_panel > diplomatic_relations > list > icon_at_war > enemies > flag
   -- Right Panel root > diplomacy_dropdown > faction_right_status_panel > diplomatic_relations > list > icon_at_war > enemies > flag
   local leftPanel = find_uicomponent(root, "diplomacy_dropdown", "faction_left_status_panel")
   local rightPanel = find_uicomponent(root, "diplomacy_dropdown", "faction_right_status_panel")

   mapUic(leftPanel, mypcall(
			 function(var)
				local faction = getFactionFromImage(var)
				hoverAttitude:generateComps(var, faction, faction2)
			 end), "flag")
   mapUic(rightPanel, mypcall(
			 function(var)
				local faction = getFactionFromImage(var)
				hoverAttitude:generateComps(var, faction, faction2)
			 end), "flag")

   -- Left Banner root > diplomacy_dropdown > faction_left_status_panel > button_faction
   -- Right Banner root > diplomacy_dropdown > faction_right_status_panel > button_faction
end


-- cleanAll shouldn't refer to the restart button
-- instead should refer to hovering mouse over or closing diplomacy panel
function hoverAttitude:cleanup()
   -- Flag icons
   local t = self.others
   for k,v in pairs(t) do
	  Util.delete(v)
	  t[k] = nil
   end
end


-- when cleanAll is false, things should still be able to operate without reloading a gamesave
local function cleanup(cleanAll)
   -- Cleanup listeners
   for k,v in pairs(listeners) do
	  if cleanAll or (not cleanAll and not dontClean[ k ]) then
		 core:remove_listener(k)
		 listeners[k] = nil
	  end
   end
   -- cleanup components
   hoverAttitude:cleanup()
   for k,v in pairs(comps) do
	  Util.delete(v)
	  comps[k] = nil
   end
   -- Manual checkers & handles reset
   diplo = nil
   faction_panel = nil
   minDiplo = nil
   smallBar = nil
end


-- For reloading the Mod for streamlined testing & development
local function restart()
   Log("Restarting "..ModName)
   cleanup(true)
   package.loaded.factionsTableDB = nil
   package.loaded.inspect = nil
   --package.loaded.pastahbetterui = nil
   --require "pastahbetterui"

   local f, err = loadfile("data/script/campaign/mod/pastahbetterui.lua")

   if f then
   	  setfenv(f, core:get_env());
   	  local success, ret = pcall(f)

   	  if success then
   		 Util.delete(restartButton.uic)
   		 restartButton = nil
   		 pastahbetterui()
   	  else
   		 out("LOADFILE: " .. ret)
   	  end
   else
   	  if err then
   		 out("LOADFILE: " .. err)
   	  end

   	  if subdir_err then
   		 out("LOADFILE: " .. subdir_err)
   	  end
   end
end


--===============================================================================
--==  MAIN FUNCTION  ============================================================
--===============================================================================

function pastahbetterui()

   Log("Initializing " .. ModName)

   -- UIC handles
   root = find_uicomponent(core:get_ui_root())
   layout = find_uicomponent(root, "layout")
   -- Things to disable when toggling diplomacy panel \/
   minDiploJankyButtons = {
	  missionsButton = find_uicomponent(layout, "bar_small_top", "TabGroup", "tab_missions"),
	  factionsButton = find_uicomponent(layout, "bar_small_top", "faction_icons", "button_factions"),
	  financeButton = find_uicomponent(layout, "resources_bar", "topbar_list_parent", "treasury_holder", "dy_treasury", "button_finance"),
	  intrigueButton = find_uicomponent(layout, "faction_buttons_docker", "button_group_management", "button_intrigue"),
	  generalButton = find_uicomponent(layout, "info_panel_holder", "primary_info_panel_holder", "info_button_list", "button_general"),
	  eventsButton = find_uicomponent(layout, "bar_small_top", "TabGroup", "tab_events"),
   }
   -- This is outside because it needs recursion
   unitsList = find_uicomponent(layout, "radar_things", "dropdown_parent", "units_dropdown", "panel", "panel_clip", "sortable_list_units")
   -- Things to disable /\

   -- Restart button for debugging
   restartButton = Button.new("PastahRestartButton", root, "SQUARE", "ui/skins/default/parchment_header_max.png")
   addListener(
	  true,
	  Prefix.."RestartButton",
	  "ComponentLClickUp",
	  function(context) 
		 return context.string == restartButton.name
	  end,
	  mypcall(function(context)
			restart()
	  end), true
   )


   ------------
   -- Listeners
   ------------

   -- For testing
   addListener(
	  true,
	  "pastahtestlistener",
	  --"RegionSelected",
	  --"SettlementSelected",
	  --"CharacterSelected",
	  "ComponentLClickUp",
	  function(context)
		 return true
	  end,
	  function(context)
		 if not is_nil(context.component) then
			local uic = UIComponent(context.component)
			local uic = UIComponent( context.component )
			LogUic(uic)
		 end
	  end, true)


   addListener(
	  true,
	  Prefix.."DiplomacyOpened",
	  "PanelOpenedCampaign",
	  function(context)
		 return context.string == "diplomacy_dropdown"
	  end,
	  mypcall(function(context)
			Log("Diplomacy panel opened")
			diplo = find_uicomponent(root, "diplomacy_dropdown")
			faction_panel = find_uicomponent(diplo, "faction_panel")
			attitudeContainer = createComp(diplo, "PastahAttitudeIcons", "UI/campaign ui/script_dummy")

			-- Can't see selected start faction unless callback ¯\_(ツ)_/¯
			cm:callback(
			   mypcall(function(context)
					 local uic = find_uicomponent(diplo, "faction_right_status_panel", "button_faction")
					 selectedFaction = getFactionFromImage(uic)
					 core:trigger_event(selectedFactionEvent)
			   end), 0)

			if not is_nil(minDiplo) and is_nil(root) then return end

			if is_nil(smallBar) then
			   local small_bar = find_uicomponent(faction_panel, "small_bar")
			   smallBar = copyComp(small_bar, "diploSmallBar")
			   root:Adopt(smallBar:Address())
			   local x, y = smallBar:Position()

			   smallBar:MoveTo(x+1,y)
			   smallBar:SetVisible(false)
			end

			-- Check if it's a skip audio dialogue
			-- Call back needed because dumb trade UI animations
			cm:callback(
			   mypcall(function()
					 --root > diplomacy_dropdown > message_skip_dialogue
					 --root > diplomacy_dropdown > message_skip_dialogue > button_skip
					 --root > diplomacy_dropdown > offers_panel > offers_list_panel > button_set1 > button_cancel
					 local skip = find_uicomponent(diplo, "message_skip_dialogue", "button_skip")
					 --local skip = find_uicomponent(diplo, "message_skip_dialogue")
					 if skip and skip:Visible() then
						local offers = find_uicomponent(diplo, "offers_panel")
						skip:SimulateLClick() -- Disables audio unfortunately

						----offers:SetMoveable(false) -- Doesn't work
						--uim:lock_diplomacy_audio()


						--skip:SetVisible(false)
						--offers:SetVisible(true)
						--play_component_animation("show", "offers_panel");

						
						--for k,v in pairs(core.event_listeners) do
						--for k,v in pairs(cm.script_timers) do
						--   Log( "k:\n"..tostring(k) )
						--   --Log( "v:\n"..tostring(inspect(v)) )
						--   Log(v.callstack)
						--   Log("---")
						--end
						
						--cm:callback(
						--   mypcall(function()
						--   end), 10)
					 end
			   end), 0)


			addListener(
			   Prefix.."SelectedFaction",
			   selectedFactionEvent,
			   true,
			   mypcall(function(context)
					 hoverAttitude:generateRows()
			   end),
			   true)


			addListener(
			   Prefix.."SelectedFaction",
			   selectedFactionEvent,
			   true,
			   mypcall(function(context)
					 hoverAttitude:generateRows()
			   end),
			   true)


			-- Listeners for mousing on
			addListener(
			   Prefix.."FlagMouseOn",
			   "ComponentMouseOn",
			   true,
			   mypcall(function(context)
					 hoverAttitude:cleanup()
					 if context.string ~= "flag" then return end
					 if not is_nil(context.component) then
					 	local uic = UIComponent(context.component)
						local faction = getFactionFromImage(uic)
					 	if faction then
					 	   hoverAttitude:generateMain(uic, faction)
						   hoverAttitude:generateFactionButton(faction)
					 	end
					 end
			   end),
			   true)
			addListener(
			   Prefix.."FactionButtonMouseOn",
			   "ComponentMouseOn",
			   function(context)
				  local uic = UIComponent(context.component)
				  --find_uicomponent(diplo, "faction_right_status_panel", "button_faction")
				  local str = uicomponent_to_str(uic):match("faction_right_status_panel")
				  local str2 = uicomponent_to_str(uic):match("faction_left_status_panel")
				  return context.string == "button_faction" and (str or str2)
			   end,
			   mypcall(function(context)
					 local uic = UIComponent(context.component)
					 local faction = getFactionFromImage(uic)
					 if faction then
						hoverAttitude:generateOthers(faction)
					 end
			   end),
			   true)
			--addListener(
			--   "PastahBetterUiRowMouseOn",
			--   "ComponentMouseOn",
			--   function(context)
			--	  return context.string:match("^(faction_row_entry_).*")
			--   end,
			--   mypcall(function(context)
			--		 local row = UIComponent(context.component)
			--		 local attitudeIcon = find_uicomponent(row, "attitude")
			--		 local factionName = context.string:match("^faction_row_entry_(.*)")
			--		 local faction = cm:get_faction(factionName)
			--		 hoverAttitude:generateMain(attitudeIcon, faction)
			--   end),
			--   true)


			-- Listener for checking double clicks on settlements
			addListener(
			   Prefix.."DoubleClick",
			   "ComponentLClickUp",
			   true,
			   mypcall(function(context)
					 if (lastClickTime ~= 0 and clock() - lastClickTime <= 0.3) then
						local settlement = cm:get_campaign_ui_manager().settlement_selected:sub(12)
						-- Is a settlement is actually selected?
						if settlement ~= nil and settlement ~= "" then
						   selectedFaction = cm:get_region(settlement):owning_faction()
						   core:trigger_event(selectedFactionEvent)
						   local buttonName = "faction_row_entry_" .. selectedFaction:name()
						   local factionButton = find_uicomponent(diplo, "faction_panel", "sortable_list_factions", "list_clip", "list_box", buttonName)
						   if not is_boolean(factionButton) then
							  factionButton:SetVisible(true)
							  factionButton:SimulateLClick()
						   end
						end
					 end
					 lastClickTime = clock()
			   end),
			   true)


			-- Listeners for checking clicks on factions for changing selectedFaction
			addListener(
			   Prefix.."FlagClick",
			   "ComponentLClickUp",
			   function(context)
				  return context.string == "flag"
			   end,
			   mypcall(function(context)
					 local uic = UIComponent(context.component)
					 local faction = getFactionFromImage(uic)
					 if faction then
						selectedFaction = faction
						core:trigger_event(selectedFactionEvent)
					 end
			   end),
			   true)
			addListener(
			   Prefix.."RowClick",
			   "ComponentLClickUp",
			   function(context)
				  return context.string:match("^(faction_row_entry_).*")
			   end,
			   mypcall(function(context)
					 local factionName = context.string:match("^faction_row_entry_(.*)")
					 selectedFaction = cm:get_faction(factionName)
					 core:trigger_event(selectedFactionEvent)
			   end),
			   true)
			addListener(
			   Prefix.."FactionButtonClick",
			   "ComponentLClickUp",
			   function(context)
				  return context.string == "button_faction"
			   end,
			   mypcall(function(context)
					 local uic = UIComponent(context.component)
					 local faction = getFactionFromImage(uic)
					 if faction then
						selectedFaction = faction
						core:trigger_event(selectedFactionEvent)
					 end
			   end),
			   true)


			-- Needs to be refreshed when user enters negotiation
			addListener(
			   Prefix.."NegotiateCloseClick",
			   "ComponentLClickUp",
			   function(context)
				  --root > diplomacy_dropdown > offers_panel > offers_list_panel > button_set1 > button_cancel
				  local uic = UIComponent(context.component)
				  local str = uicomponent_to_str(uic):match("offers_list_panel")
				  return context.string == "button_cancel" and str
			   end,
			   mypcall(function(context)
					 cm:callback(
						mypcall(function(context)
							  hoverAttitude:generateRows()
						end), 0)
			   end),
			   true)

			--root > diplomacy_dropdown > faction_panel > button_enlarge_br
			local test = find_uicomponent(faction_panel, "button_enlarge_br")

			-- Create buttons & button logic
			--local contractAll = UIComponent( faction_panel:CreateComponent(Prefix.."ContractAllButton", "ui/templates/square_medium_button") )
			local contractAll = createComp(faction_panel, Prefix.."ContractAllButton", "ui/templates/square_medium_button")
			contractAll:SetImagePath("ui/skins/default/parchment_header_max.png")
			cm:callback(
			   mypcall(function(context)
					 contractAll:Resize(25, 25)
					 contractAll:SetMoveable(true)
					 contractAll:SetDockingPoint(1)
					 contractAll:SetDockOffset(contractAll:Width()*2.5, 2*contractAll:Height()/3)
					 contractAll:SetCanResizeHeight(false)
					 contractAll:SetCanResizeWidth(false)
			   end), 0.1)
			addListener(
			   Prefix.."ContractAllButtonClick",
			   "ComponentLClickUp",
			   function(context)
				  return context.string == contractAll:Id()
			   end,
			   mypcall(function(context)
					 local uic = find_uicomponent(faction_panel, "sortable_list_factions", "list_clip", "list_box")
					 --faction_row_entry_
					 for i = 0, uic:ChildCount() - 1 do
						local iter = UIComponent( uic:Find(i) )
						if not iter:Id():match("^(faction_row_entry_).*") then
						   iter:SetState("down")
						   --iter:SimulateLClick()
						   --iter:SetState("selected_down")
						else
						   iter:SetVisible(false)
						end
					 end
			   end), true)

			--local expandAll = UIComponent( faction_panel:CreateComponent(Prefix.."ExpandAllButton", "ui/templates/square_medium_button") )
			local expandAll = createComp(faction_panel, Prefix.."ExpandAllButton", "ui/templates/square_medium_button")
			expandAll:SetImagePath("ui/skins/default/parchment_header_min.png")
			cm:callback(
			   mypcall(function(context)
					 expandAll:Resize(25, 25)
					 expandAll:SetMoveable(true)
					 expandAll:SetDockingPoint(1)
					 expandAll:SetDockOffset(expandAll:Width()*3.5, 2*expandAll:Height()/3)
					 expandAll:SetCanResizeHeight(false)
					 expandAll:SetCanResizeWidth(false)
			   end), 0.1)
			addListener(
			   Prefix.."ExpandAllButtonClick",
			   "ComponentLClickUp",
			   function(context)
				  return context.string == expandAll:Id()
			   end,
			   mypcall(function(context)
					 local uic = find_uicomponent(faction_panel, "sortable_list_factions", "list_clip", "list_box")
					 --faction_row_entry_
					 for i = 0, uic:ChildCount() - 1 do
						local iter = UIComponent( uic:Find(i) )
						if not iter:Id():match("^(faction_row_entry_).*") then
						   iter:SetState("selected_down")
						else
						   iter:SetVisible(true)
						end
					 end
			   end), true)


			minDiplo = createComp(root, "MinimizeDiplomacyButton", "ui/templates/square_medium_button")
			minDiplo:SetImagePath("ui/skins/default/parchment_header_max.png")
			cm:callback(
			   mypcall(function(context)
					 minDiplo:Resize(50, 50)
					 minDiplo:MoveTo( diplo:Width()/3 - minDiplo:Width()*3.3, root:Height() - minDiplo:Height() )
					 minDiplo:RegisterTopMost()
			   end), 0)
			addListener(
			   Prefix.."MinimizeDiplomacyClick",
			   "ComponentLClickUp",
			   function(context)
				  return context.string == minDiplo:Id()
			   end,
			   mypcall(function(context)
					 minDiploToggle = not minDiploToggle

					 if minDiploToggle then
						-- HIDE
						minDiplo:SetImagePath("ui/skins/default/parchment_header_min.png")
						cm:get_campaign_ui_manager():lock_ui()
					 else
						-- SHOW
						minDiplo:SetImagePath("ui/skins/default/parchment_header_max.png")
						cm:get_campaign_ui_manager():unlock_ui()
					 end

					 uim:override("diplomacy"):set_allowed(not minDiploToggle) -- disable diplomacy button in main view
					 diplo:SetVisible(not minDiploToggle)
					 smallBar:SetVisible(minDiploToggle)
					 layout:SetVisible(minDiploToggle)

					 -- Disable buttons that break things or look janky
					 for k, v in pairs(minDiploJankyButtons) do
					 	Components.disableComponent(v, minDiploToggle)
					 end
					 mapUic(unitsList,
					 		function(var)
					 		   Components.disableComponent(var, minDiploToggle)
					 		end, "skill_button")

					 end), true)

	  end), true)

   addListener(
	  true,
	  Prefix.."DiplomacyClosed",
	  "PanelClosedCampaign",
	  function(context) 
		 return context.string == "diplomacy_dropdown"
	  end,
	  mypcall(function(context)
			cleanup()
	  end), true
   )
end

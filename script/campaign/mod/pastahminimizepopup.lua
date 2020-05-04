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
function pastahminimizepopup()
   --[[
	  TODO LIST
	  * Tooltips for minimize button and faction attitude overlay
	  * Button for toggling all attitudes in your faction panel
	  * Add load button in battles
	  * Make overlay colours better in campaign
	  * Hovering over a flag will show attitudes in opposing panel (both sides / vice versa)
	  * Perhaps hover over banner flag or attitude of target?
	  * Add tooltip with actual relation #
   --]]
   ------------
   -- Variables
   ------------
   local ModName = "Pastah's BetterUI"
   local logFile = "pastah.txt"
   local listeners = {}
   local components = {}
   local root = find_uicomponent(core:get_ui_root())
   local layout = find_uicomponent(root, "layout")
   -- Things to disable when toggling diplomacy panel \/
   local minDiploJankyButtons = {
	  missionsButton = find_uicomponent(layout, "bar_small_top", "TabGroup", "tab_missions"),
	  factionsButton = find_uicomponent(layout, "bar_small_top", "faction_icons", "button_factions"),
	  financeButton = find_uicomponent(layout, "resources_bar", "topbar_list_parent", "treasury_holder", "dy_treasury", "button_finance"),
	  intrigueButton = find_uicomponent(layout, "faction_buttons_docker", "button_group_management", "button_intrigue"),
	  generalButton = find_uicomponent(layout, "info_panel_holder", "primary_info_panel_holder", "info_button_list", "button_general"),
   }
   -- This is outside because it needs recursion
   local unitsList = find_uicomponent(layout, "radar_things", "dropdown_parent", "units_dropdown", "panel", "panel_clip", "sortable_list_units")
   -- Things to disable /\
   local diplo -- Diplomacy Drop Down UIC
   local minDiplo -- button for minimize diplomacy : UIC
   local smallBar -- Frame for the minDiplo button
   local minDiploToggle = false
   local lastClickTime = 0
   local hoverAttitude = {
	  faction = nil,
	  main = nil,
	  others = {}
   }
   local attitudeIcons = {
	  veryPositive = "ui/PastahBetterUI/icon_status_attitude_very_positive_24px.png",
	  positive = "ui/PastahBetterUI/icon_status_attitude_positive_24px.png",
	  neutral = "ui/PastahBetterUI/icon_status_attitude_neutral_24px.png",
	  negative = "ui/PastahBetterUI/icon_status_attitude_negative_24px.png",
	  veryNegative = "ui/PastahBetterUI/icon_status_attitude_very_negative_24px.png"
   }
   -- For easily disabling vanilla buttons
   local Components = require("uic/components")
   local clock = os.clock
   local tmp -- a variable for swapping functions around for hooking


   ------------
   -- Functions
   ------------
   function sleep(n)  -- seconds
	  local t0 = clock()
	  while clock() - t0 <= n do end
   end

   -- Clear log file
   if true then
	  local file = io.open(logFile, "w")
	  file:write()
	  file:close()
   end
   local function Log(text)
	  if type(text) == "string" then
		 local file = io.open(logFile, "a")
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
   Log("Initializing " .. ModName)
   package.path = package.path .. ";script/campaign/mod/includes/?.lua"
   local inspect = require("inspect")

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

   local function mapUic(uic, func, search)
	  if not is_uicomponent(uic) then
		 return
	  end
	  if not search or (search and uic:Id() == search) then
		 func(uic)
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

   -- Hook functions so we can create a list of listeners and components for cleanup later
   local function addListener(...)
	  table.insert(listeners, arg[1])
	  return core:add_listener(unpack(arg))
   end

   local function createComp(...)
	  table.insert(components, arg[1])
	  local slf = arg[1]
	  arg[1] = nil
	  return slf:createComp(unpack(arg))
   end

   local function newButton(...)
	  table.insert(components, arg[1])
	  return Button.new(unpack(arg))
   end

   local function copyComp(...)
	  table.insert(components, arg[1])
	  local slf = arg[1]
	  arg[1] = nil
	  return slf:CopyComponent(unpack(arg))
   end

   local function getAttitudeIcon(faction, faction2)
	  --faction2 = cm:model():world():faction_by_key(faction2)
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


   local function generateHoverAttitude(uic)
	  local name = "PastahHoverAttitudeOther"..uic:Address()
	  local comp = UIComponent( createComp(root, name, "ui/campaign ui/region_info_pip") )
	  local image = uic:GetImagePath()
	  --ui\flags\wh_main_emp_empire_separatists/mon_24.png
	  local faction2 = image:sub(10):match("(.*)\/")
	  faction = cm:get_faction(faction)
	  local icon = getAttitudeIcon(faction2)
	  comp:SetImagePath(icon)
	  local x, y = uic:Position()
	  hoverAttitude.main:MoveTo(x,y)
	  table.insert(hoverAttitude.others)
   end

   local function generateOtherHoverAttitudes()
	  -- Left Panel root > diplomacy_dropdown > faction_left_status_panel > diplomatic_relations > list > icon_at_war > enemies > flag
	  -- Right Panel root > diplomacy_dropdown > faction_right_status_panel > diplomatic_relations > list > icon_at_war > enemies > flag
	  local leftPanel = find_uicomponent(root, "diplomacy_dropdown", "faction_left_status_panel")
	  local rightPanel = find_uicomponent(root, "diplomacy_dropdown", "faction_right_status_panel")
	  mapUic(leftPanel)

	  -- Left Banner root > diplomacy_dropdown > faction_left_status_panel > button_faction
	  -- Right Banner root > diplomacy_dropdown > faction_right_status_panel > button_faction
   end

   local function cleanupHoverAttitudes()
	  if not is_nil(hoverAttitude.main) then
		 components[hoverAttitude.main:Id()] = nil
		 Util.delete(hoverAttitude.main)
		 hoverAttitude.main = nil
		 hoverAttitude.faction = nil
	  end
	  for key,value in pairs(hoverAttitude.others) do
		 if not is_nil(value) then
			components[value:Id()] = nil
			Util.delete(value)
			hoverAttitude.others[key] = nil
		 end
	  end
   end

   -- when cleanAll is false, things should still be able to operate without reloading a gamesave
   local function cleanup(cleanAll)
	  diplo = nil
	  -- Remove diplomacy double click listener so it doesn't interfere in other screens
	  for k,v in pairs(listeners) do
		 if cleanAll or (not cleanAll and v ~= "MinDiploDiplomacyOpenedListener") then
			core:remove_listener(v)
		 end
	  end
	  cleanupHoverAttitudes()
	  for k,v in pairs(components) do
		 if not is_nil(v) then
			Util.delete(v)
			components[k] = nil
		 end
	  end
   end


   ------------
   -- Listeners
   ------------
   addListener(
	  "MinDiploDiplomacyOpenedListener",
	  "PanelOpenedCampaign",
	  function(context)
		 return context.string == "diplomacy_dropdown"
	  end,
	  mypcall(function(context)
			diplo = find_uicomponent(root, "diplomacy_dropdown")

			if not is_nil(minDiplo) and is_nil(root) then return end
			
			if is_nil(smallBar) then
			   smallBar = UIComponent( copyComp(find_uicomponent(root, "diplomacy_dropdown", "faction_panel", "small_bar"), "diploSmallBar") )
			   root:Adopt(smallBar:Address())
			   local x, y = smallBar:Position()
			   -- For some reason the cloned smallBar shifts by 1 pixel, correct it
			   smallBar:MoveTo(x+1,y)
			   smallBar:SetVisible(false)
			end

			addListener(
			   "MinDiploMouseOn",
			   "ComponentMouseOn",
			   true,
			   mypcall(function(context)
					 cleanupHoverAttitudes()
					 if context.string ~= "flag" then return end
					 if not is_nil(context.component) then
						local uic = UIComponent(context.component)

						--Log(inspect(getmetatable(uic)))
						--for key,value in pairs(uic) do
						--   Log("found member " .. key);
						--end

						local image = uic:GetImagePath()
						--ui\flags\wh_main_emp_empire_separatists/mon_24.png
						local faction = image:sub(10):match("(.*)\/")
						faction = cm:get_faction(faction)
						if faction then
						   hoverAttitude.faction = faction
						   local name = "PastahHoverAttitudeMain"
						   hoverAttitude.main = UIComponent( createComp(root, name, "ui/campaign ui/region_info_pip") )
						   local faction2 = find_uicomponent(root, "diplomacy_dropdown", "faction_right_status_panel", "button_faction")
						   faction2 = faction2:GetImagePath():sub(10):match("(.*)\/")
						   faction2 = cm:get_faction(faction2)
						   local icon = getAttitudeIcon(faction, faction2)
						   hoverAttitude.main:SetImagePath(icon)
						   local x, y = uic:Position()
						   hoverAttitude.main:MoveTo(x,y)
						else
						   error(ModName.." couldn't find faction on MouseOn for 'flag'.\nImage was: "..image)
						end
					 end
			   end),
			   true
			)

			-- Listener for checking double clicks on settlements
			addListener(
			   "MinDiploDoubleClickListener",
			   "ComponentLClickUp",
			   true,
			   mypcall(function(context)
					 if (lastClickTime ~= 0 and clock() - lastClickTime <= 0.3) then
						local settlement = cm:get_campaign_ui_manager().settlement_selected:sub(12)
						-- Is a settlement is actually selected?
						if settlement ~= nil and settlement ~= "" then
						   local selectedFaction = cm:get_region(settlement):owning_faction()
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
			   true
			)

			minDiplo = newButton("MinimizeDiplomacyButton", root, "SQUARE", "ui/skins/default/parchment_header_max.png")

			cm:callback(
			   mypcall(function(context)
					 local uic = find_uicomponent(root, "diplomacy_dropdown")
					 minDiplo:Resize(50, 50)
					 minDiplo:PositionRelativeTo( uic, uic:Width()/3 - minDiplo:Width()*1, root:Height() - minDiplo:Height() )
					 minDiplo.uic:RegisterTopMost()
			   end), 0, "setupMinDiplo"
			)
			minDiplo:RegisterForClick(
			   mypcall(function(context)
					 minDiploToggle = not minDiploToggle

					 if minDiploToggle then
						-- HIDE
						minDiplo:SetImage("ui/skins/default/parchment_header_min.png")
						cm:get_campaign_ui_manager():lock_ui()
					 else
						-- SHOW
						minDiplo:SetImage("ui/skins/default/parchment_header_max.png")
						cm:get_campaign_ui_manager():unlock_ui()
					 end

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
			   end)
			)
	  end), true)

   addListener(
	  "MinDiploDiplomacyClosedListener",
	  "PanelClosedCampaign",
	  function(context) 
		 return context.string == "diplomacy_dropdown"
	  end,
	  mypcall(function(context)
			cleanup()
	  end), true
   )

end

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
   --]]
   ------------
   -- Variables
   ------------
   local ModName = "Pastah's BetterUI"
   local logFile = "pastah.txt"
   local root = find_uicomponent(core:get_ui_root())
   local layout = find_uicomponent(root, "layout")
   local menuBar = find_uicomponent(root, "menu_bar")
   -- Things to disable when toggling diplomacy panel \/
   local missionsButton = find_uicomponent(root, "layout", "bar_small_top", "TabGroup", "tab_missions")
   local factionsButton = find_uicomponent(root, "layout", "bar_small_top", "faction_icons", "button_factions")
   local financeButton = find_uicomponent(root, "layout", "resources_bar", "topbar_list_parent", "treasury_holder", "dy_treasury", "button_finance")
   local intrigueButton = find_uicomponent(root, "layout", "faction_buttons_docker", "button_group_management", "button_intrigue")
   local generalButton = find_uicomponent(root, "layout", "info_panel_holder", "primary_info_panel_holder", "info_button_list", "button_general")
   local unitsList = find_uicomponent(root, "layout", "radar_things", "dropdown_parent", "units_dropdown", "panel", "panel_clip", "sortable_list_units")
   -- Things to disable /\
   local diplo -- Diplomacy Drop Down UIC
   local minDiplo -- button for minimize diplomacy : UIC
   local smallBar -- Frame for the minDiplo button
   local minDiploToggle = false
   local lastClickTime = 0
   local hoverAttitude = {
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
   --package.path = package.path .. ";script/myawesomeperfectmod/includes/?.lua"
   --local inspect = require("inspect")
   --local inspect = require("inspect")
   --local inspect = require "inspect"
   --Log(inspect({foo=123}))
   --for i,v in ipairs(package.loaders) do Log(tostring(i)..", "..tostring(v("inspect"))) end

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

   local function disableRecurseUic(uic, search, toggle)
	  if not is_uicomponent(uic) then
		 return
	  end
	  local ret = uic:Find(search)
	  if ret then
		 ret = UIComponent(ret)
		 Components.disableComponent(ret, toggle)
		 return
	  end
	  for i = 0, uic:ChildCount() - 1 do
		 ret = disableRecurseUic(uic:Find(i), search, toggle)
	  end
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

   local function getAttitudeIcon(faction)
	  local faction2 = find_uicomponent(root, "diplomacy_dropdown", "faction_right_status_panel", "button_faction")
	  faction2 = faction2:GetImagePath():sub(10):match("(.*)\/")
	  faction2 = cm:get_faction(faction2)
	  --faction2 = cm:model():world():faction_by_key(faction2)
	  local attitude = faction2:diplomatic_attitude_towards(faction:name())
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

   local function generateOtherHoverAttitudes()
	  -- Left Panel root > diplomacy_dropdown > faction_left_status_panel > diplomatic_relations > list > icon_at_war > enemies > flag
	  -- Right Panel root > diplomacy_dropdown > faction_right_status_panel > diplomatic_relations > list > icon_at_war > enemies > flag
	  -- Check if it's left or right that is being hovered
	  if uicomponent_to_str(hoverAttitude.main):match() then
	  end

	  -- Left Banner root > diplomacy_dropdown > faction_left_status_panel > button_faction
	  -- Right Banner root > diplomacy_dropdown > faction_right_status_panel > button_faction
   end


   ------------
   -- Listeners
   ------------

   

   --core:add_listener(
   --	  "MinDiploSettlementSelectionListener",
   --	  "SettlementSelected",
   --	  true,
   --	  mypcall(
   --		 function(context)
   --			Log("Finding settlement_panel...")
   --			setlPanel = recurseFind(root, "settlement_panel")
   --			--local selected_settlement = settlement_prepend_str .. context:garrison_residence():region():name()
   --			--selectedFaction = context:garrison_residence():faction()
   --			--Log("Selected Faction: " .. selectedFaction)
   --			--root > diplomacy_dropdown > faction_panel > sortable_list_factions > list_clip > list_box > faction_row_entry_wh_main_brt_bretonnia
   --			--local factionList = find_uicomponent(root, "diplomacy_dropdown", "sortable_list_factions", "list_clip", "list_box")
   --			--out(factionList)
   --		 end
   --	  ),
   --	  true
   --)


   --core:add_listener(
   --	  "BetterUiCharacterSelectedListener",
   --	  "CharacterSelected",
   --	  true,
   --	  mypcall(
   --		 function(context)
   --			Log("Character selected")
   --		 end
   --	  ),
   --	  true
   --)

   core:add_listener(
	  "MinDiploMouseOn",
	  "ComponentMouseOn",
   	  true,
   	  mypcall(function(context)
			if not is_nil(hoverAttitude.main) then
			   Util.delete(hoverAttitude.main)
			   hoverAttitude.main = nil
			end
			if context.string ~= "flag" then return end
			if not is_nil(context.component) then
			   local uic = UIComponent(context.component)
			   LogUic(uic)
			   local image = uic:GetImagePath()
			   --ui\flags\wh_main_emp_empire_separatists/mon_24.png
			   local faction = image:sub(10):match("(.*)\/")
			   faction = cm:get_faction(faction)
			   if faction then
				  --root > 3d_ui_parent > label_settlement:wh_main_ostermark_nagenhof > list_parent > list > faction_symbol_holder > standard_zoom > attitude
				  -- Perhaps copy an existing attitude icon and make another faction own it?
				  --local parent = find_uicomponent(root, "3d_ui_parent")
				  --mapUic(parent,
				  --		 function(var)
				  --			Log(var:GetImagePath())
				  --		 end, "attitude")
				  --ui\skins\default\icon_status_attitude_negative_24px.png

				  --local icon = Image.new("PastahAttitudeIcon", root, "ui/skins/default/icon_status_attitude_very_positive_24px.png")
				  hoverAttitude.main = UIComponent(root:CreateComponent("PastahAttitudeIcon", "ui/campaign ui/region_info_pip"))
				  local icon = getAttitudeIcon(faction)
				  hoverAttitude.main:SetImagePath(icon)
				  local x, y = uic:Position()
				  hoverAttitude.main:MoveTo(x,y)
				  --hoverAttitude:SetImagePath("ui/skins/default/icon_status_attitude_very_positive_24px.png")
				  --hoverAttitude:TextShaderTechniqueSet("colourwheel_t0")
				  --hoverAttitude:TextShaderVarsSet(255, 0, 255, 0)
				  --local a, b, c, d = hoverAttitude:ShaderVarsGet()
				  --Log(tostring(a)..", "..tostring(b)..", "..tostring(c)..", "..tostring(d))

				  --hoverAttitude = UIComponent( hoverAttitude:CopyComponent(hoverAttitude:Id()) )
				  --root:Adopt(hoverAttitude:Address())
				  --hoverAttitude:MoveTo(408,202)

				  --local buttonName = "faction_row_entry_" .. faction:name()
				  --local factionButton = find_uicomponent(diplo, "faction_panel", "sortable_list_factions", "list_clip", "list_box", buttonName)
				  --if not is_boolean(factionButton) then
				  --	 factionButton:SetVisible(true)
				  --	 factionButton:SimulateLClick()
				  --end
			   else
				  error(ModName.." couldn't find faction on MouseOn for 'flag'.\nImage was: "..image)
			   end

			   --Log(inspect(getmetatable(uic)))
			   --for key,value in pairs(uic) do
			   --	  Log("found member " .. key);
			   --end
			end
	  end),
   	  true
   )

   core:add_listener(
	  "MinDiploDiplomacyOpenedListener",
	  "PanelOpenedCampaign",
	  function(context)
		 return context.string == "diplomacy_dropdown"
	  end,
	  mypcall(function(context)
			diplo = find_uicomponent(root, "diplomacy_dropdown")

			if not is_nil(minDiplo) and is_nil(root) then return end
			
			if is_nil(smallBar) then
			   smallBar = UIComponent( find_uicomponent(root, "diplomacy_dropdown", "faction_panel", "small_bar"):CopyComponent("diploSmallBar") )
			   root:Adopt(smallBar:Address())
			   local x, y = smallBar:Position()
			   -- For some reason the cloned smallBar shifts by 1 pixel, correct it
			   smallBar:MoveTo(x+1,y)
			   smallBar:SetVisible(false)
			end

			-- Listener for checking double clicks on settlements
			mypcall(function()
				  core:add_listener(
					 "MinDiploDoubleClickListener",
					 "ComponentLClickUp",
					 true,
					 mypcall(function(context)
						   --"diplomacy_dropdown", "faction_left_status_panel", "diplomatic_relations", "list", "icon_at_war", "enemies", "flag")
						   --local test = find_uicomponent(root, "diplomacy_dropdown", "faction_left_status_panel", "diplomatic_relations")
						   --root > 3d_ui_parent
						   --local test = find_uicomponent(root, "3d_ui_parent")
						   --recurseLogUic(test)
						   --LogUic(root)
						   --root > diplomacy_dropdown > faction_right_status_panel
						   --local test = find_uicomponent(root, "diplomacy_dropdown", "faction_right_status_panel")
						   --mapUic(test,
						   --				 function(var)
						   --					LogUic(var)
						   --				 end
						   --)

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
			end)()

			minDiplo = Button.new("MinimizeDiplomacyButton", root, "SQUARE", "ui/skins/default/parchment_header_max.png")

			cm:callback(
			   mypcall(function(context)
					 local uic = find_uicomponent(root, "diplomacy_dropdown")
					 minDiplo:Resize(50, 50)
					 --minDiplo:PositionRelativeTo(uic, -(minDiplo:Width()*.5), -minDiplo:Height() + 10)
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

						--root:Divorce(diplo:Address())
						-- Say that diplomacy_dropdown panel isn't open
						--local panels = cm:get_campaign_ui_manager().panels_open
						--for k in pairs(panels) do
						--	 panels[k] = nil
						--end
						--local diplomacy_panel_context = cm:get_diplomacy_panel_context()
						--if not is_nil(testcont) then
						--	 core:trigger_event("PanelClosedCampaign", testcont)
						--end
						--core:trigger_event("PanelClosedCampaign", "dropdown_diplomacy", diplo)
						--cm:get_campaign_ui_manager():add_campaign_panel_closed_interaction_monitor("diplomacy_panel_closed", "dropdown_diplomacy")

						--local diplomacy_panel_context = cm:get_diplomacy_panel_context()
						--if diplomacy_panel_context ~= "" then
						--	 --cm.diplomacy_panel_context_listener_started = false
						--	 core:trigger_event("ScriptEventDiplomacyPanelContext", diplomacy_panel_context)
						--end

						--root:Adopt(setlPanel:Address())
						--setlPanel:SetVisible(true)
						--layout:SetInteractive(false)
						--setlPanel:SetDisabled(true)

						-- Actually closes diplomacy like normally
						--local buttonCloseDiplomacy = find_uicomponent(root, "diplomacy_dropdown", "faction_panel", "both_buttongroup", "button_cancel");
						--buttonCloseDiplomacy:SimulateLClick()

						--cm:get_campaign_ui_manager():reset_all_overrides()

						--priority = diplo:PropagatePriority(50)
						--diplo:RemoveTopMost()
						--core:trigger_event("PanelClosedCampaign", "diplomacy_dropdown")

						--local cm = campaign_manager:get_campaign_ui_manager()
						--cm:disable_shortcut("button_diplomacy", "show_diplomacy", true);
						--cm:override_ui("disable_diplomacy", true);
						--local ui_root = root;
						--set_component_active_with_parent(false, ui_root, "button_diplomacy");

						--set_component_active_with_parent(false, root, "diplomacy_dropdown")

						--cm:poll_diplomacy_panel_context()
						--root:Layout()-- Refresh display apparently
					 else
						-- SHOW
						minDiplo:SetImage("ui/skins/default/parchment_header_max.png")
						cm:get_campaign_ui_manager():unlock_ui()

						--root:Adopt(diplo:Address())

						--setlPanel:SetVisible(false)
						--setlPanel:SetDisabled(false)

						-- Actually opens diplomacy like normally
						--local buttonOpenDiplomacy = find_uicomponent(root, "faction_buttons_docker", "button_diplomacy");
						--buttonOpenDiplomacy:SimulateLClick()

						--core:Adopt(diplo:Address())
						--diplo:RegisterTopMost()
						--core:trigger_event("ScriptEventPlayerOpensDiplomacyPanel", "button_diplomacy")

						--cm:disable_shortcut("button_diplomacy", "show_diplomacy", false);
						--cm:override_ui("disable_diplomacy", false);
						--local ui_root = root;
						--set_component_active_with_parent(true, ui_root, "button_diplomacy");
						--set_component_active_with_parent(true, ui_root, "button_diplomacy");

						--core:start_custom_event_generator(
						--	 "ComponentLClickUp", 
						--	 function(context) return UIComponent(context.component) == minDiplo end, 
						--	 "ScriptEventPlayerOpensDiplomacyPanel"
						--)

						--set_component_active_with_parent(true, root, "diplomacy_dropdown")
					 end

					 diplo:SetVisible(not minDiploToggle)
					 smallBar:SetVisible(minDiploToggle)
					 layout:SetVisible(minDiploToggle)

					 -- Disable buttons that break things or look janky
					 Components.disableComponent(missionsButton, minDiploToggle)
					 Components.disableComponent(generalButton, minDiploToggle)
					 Components.disableComponent(factionsButton, minDiploToggle)
					 Components.disableComponent(financeButton, minDiploToggle)
					 Components.disableComponent(intrigueButton, minDiploToggle)
					 disableRecurseUic(unitsList, "skill_button", minDiploToggle)
			   end)
			)
	  end), true)

   core:add_listener(
	  "MinDiploDiplomacyClosedListener",
	  "PanelClosedCampaign",
	  function(context) 
		 return context.string == "diplomacy_dropdown"
	  end,
	  mypcall(function(context)
		 diplo = nil
		 -- Remove diplomacy double click listener so it doesn't interfere in other screens
		 core:remove_listener("MinDiploDoubleClickListener")
		 if is_nil(minDiplo) then return end
		 minDiplo.uic:Adopt(smallBar:Address())
		 minDiploToggle = false
		 minDiplo:Delete()
		 minDiplo = nil
		 smallBar = nil
	  end), true
   )

end

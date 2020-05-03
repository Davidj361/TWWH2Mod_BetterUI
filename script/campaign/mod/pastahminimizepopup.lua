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
   local minDiploToggle = false
   local priority = 0
   local lastClickTime = 0
   local player_faction = cm:get_faction(cm:get_local_faction(true))
   -- For easily disabling vanilla buttons
   local Components = require("uic/components")
   -- Crappy hack to get the handle to the settlement_panel
   --local capital = player_faction:home_region():settlement()
   --capital:SimulateLClick()
   -- Infeasible because panel gets ?deleted?, i.e unable to obtain a permanent handle
   --local setlPanel = find_uicomponent(root, "settlement_panel")
   --CampaignUI.ClearSelection()
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
   --output_uicomponent_on_click()

   local function mypcall(func)
	  local function errFunc(err)
		 Log("Error in "..ModName..":")
		 Log(err)
		 Log(debug.traceback())
	  end
	  return function(context)
		 local ok,err = xpcall(func, errFunc, context)
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


   local function mapUic(uic, search, func, ...)
	  if not is_uicomponent(uic) then
		 return
	  end
	  local ret = uic:Find(search)
	  if ret then
		 ret:func(unpack(arg))
	  end
	  for i = 0, uic:ChildCount() - 1 do
		 ret = mapUic(uic:Find(i), search, unpack(arg))
	  end
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

   local function mydebug()
	  Log("-----------------------------------------------------")
	  --Log("Is root interactive? " .. tostring(root:IsInteractive()))
	  LogUic(root)
	  --local pm = find_uicomponent(root, "panel_manager")
	  --LogUic(pm)
	  Log("minDiploToggle: "..tostring(minDiploToggle))
	  --LogUic(garbage)
	  --LogUic(menuBar)
	  --LogUic(layout)
	  --LogUic(diplo)
	  --local parent = UIComponent(diplo:Parent())
	  --LogUic(parent)
	  --local panels = cm:get_campaign_ui_manager().panels_open
	  --Log(tostring(panels))
	  --for i = 1, #panels do
	  --	 Log(tostring(panels[i]))
	  --end
	  --local panelOpen = cm:get_campaign_ui_manager():is_panel_open("diplomacy_dropdown")
	  --Log("Is diplomacy panel open? " .. tostring(panelOpen))
	  --if not is_nil(setlPanel) and not is_boolean(setlPanel) then
	  --	 LogUic(setlPanel)
	  --	 Log("Parent of setlPanel:")
	  --	 LogUic(UIComponent(setlPanel:Parent()))
	  --end
	  Log("-----------------------------------------------------")
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

   core:add_listener(
	  "MinDiploDiplomacyOpenedListener",
	  "PanelOpenedCampaign",
	  function(context)
		 return context.string == "diplomacy_dropdown"
	  end,
	  function(context)
		 -- Listener for checking double clicks on settlements
		 mypcall(function()
			   core:add_listener(
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
								 Log("Interactive? " .. tostring(factionButton:IsInteractive()))
								 LogUic(factionButton)
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

		 diplo = find_uicomponent(root, "diplomacy_dropdown")

		 if minDiplo ~= nil then return end

		 minDiplo = Button.new("MinimizeDiplomacyButton", find_uicomponent(root), "SQUARE", "ui/skins/default/parchment_header_max.png")
		 -- Frame pic: ui\skins\default\bar_small_central_left.png
		 -- Make frame lower priority than existing diplo frame, but button is higher priority than diplo panel
		 cm:callback(
			function(context)
			   local uic = find_uicomponent(root, "diplomacy_dropdown", "faction_panel", "small_bar")
			   Log(uic:GetImagePath())
			   --minDiplo:Resize(25, 25)
			   minDiplo:PositionRelativeTo(uic, - sizeButton:Width() - 5, -sizeButton:Height())
			end, 0, "moveMinDiploBut"
		 )
		 minDiplo:RegisterForClick(
			mypcall(function(context)
				  minDiploToggle = not minDiploToggle
				  --mydebug()

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
	  end, true)

   core:add_listener(
	  "MinDiploDiplomacyClosedListener",
	  "PanelClosedCampaign",
	  function(context) 
		 return context.string == "diplomacy_dropdown"
	  end,
	  function(context)
		 --mydebug()
		 diplo = nil
		 -- Remove diplomacy double click listener so it doesn't interfere in other screens
		 core:remove_listener("MinDiploDoubleClickListener")
		 if minDiplo == nil then return end
		 minDiplo:Delete()
		 minDiploToggle = false
		 minDiplo = nil
	  end, true
   )

end

GroupBuilder = CreateFrame("frame");

GroupBuilder:RegisterEvent("GROUP_ROSTER_UPDATE");
GroupBuilder:RegisterEvent("TALENT_GROUP_ROLE_CHANGED");
GroupBuilder:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED");
GroupBuilder:RegisterEvent("ROLE_CHANGED_INFORM");
GroupBuilder:RegisterEvent("LFG_LIST_AVAILABILITY_UPDATE");
GroupBuilder:RegisterEvent("LFG_LIST_SEARCH_FAILED");
GroupBuilder:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED");
GroupBuilder:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED");


--[[
	In Progress: 
		When the user presses the Queue button trigger a RoleCheck and then use the results of the role check to start the queue.
		
]]


local initCalled = false
local roleCheckEnum = { none = "NONE", inprogress = "INPROGRESS", complete = "COMPLETE" }

local dungeonQueue = {
	roleCheckState = roleCheckEnum.none,
	roleCheckCount = 0,
	dungeonId = nil,
	dungeonName = "",
	inQueue = false,
	tanks = 0,
	healers = 0,
	dps = 0,
}


local dungeonCategoryId = 2

local dungeonIDs = {
	heroic = {
		OK = 1131,
		AN = 1121,
		DTK = 1129,
		Gundrak = 1130,
		HOL = 1127,
		HOS = 1128,
		Strath = 1126,
		Nexus = 1132,
		Oculus = 1124,
		UK = 1122,
		UP = 1125,
		VH = 1123,
	}
}

local dungeonNames = {
	"OK", "AN", "DTK", "Gundrak", "HOL", "HOS", "Strath", "Nexus", "Oculus", "UK", "UP", "VH",
}

local groupToInvite = {
	tank = "",
	healer = "",
	dps = { "", "", "" }
}

-- DEBUG BEGIN
local DEBUG = false
local DEBUGDUNGEONS = false

function GroupBuilder:DebugLFGList()
	if DEBUGDUNGEONS == false then return end
	local results = select(2, C_LFGList.GetFilteredSearchResults());
	local searchResultInfo = C_LFGList.GetSearchResultInfo(results[1]);
	local name = C_LFGList.GetSearchResultLeaderInfo(results[1]);
	local activityIDs = searchResultInfo.activityIDs
	if activityIDs == nil then print("activityIDs: nil") return end
	for index = 1, #activityIDs do
		local activityInfo = C_LFGList.GetActivityInfoTable(activityIDs[index])
		print(activityInfo.fullName..": catID: "..activityInfo.categoryID .." activityID: " .. activityIDs[index])
	end
end

function GroupBuilder:DebugPrint(text)
	if DEBUG == false then return end
	print("GB DEBUG: " .. text)
end

function GroupBuilder:PrintGroupCache(groupToInvite) 
	GroupBuilder:DebugPrint("GroupCache: " .. groupToInvite.tank .. ":" .. groupToInvite.healer .. ":" .. groupToInvite.dps[1] .. "," .. groupToInvite.dps[2] .. "," .. groupToInvite.dps[3])
end
-- DEBUG END

function GroupBuilder:PrettyPrint(text)
	print("[GroupBuilder] " .. tostring(text)) 
end

-- UI BEGIN
-- TODO not be a shitter and put the UILayer into something not stupid
local boxFrame = CreateFrame("Frame", "GroupBuilderMain", UIParent)
boxFrame:SetSize(420, 130)
boxFrame:SetMovable(true)
local t = boxFrame:CreateTexture(nil,"BACKGROUND")
t:SetAllPoints(boxFrame)
boxFrame.texture = t
boxFrame:SetPoint("CENTER",0,0)
boxFrame.texture:SetColorTexture(0, 0, 0, 0.4)
boxFrame:EnableMouse(true)
boxFrame:SetScript("OnMouseDown", function(self, button)
  if button == "LeftButton" and not self.isMoving then
   self:StartMoving();
   self.isMoving = true;
  end
end)
boxFrame:SetScript("OnMouseUp", function(self, button)
  if button == "LeftButton" and self.isMoving then
   self:StopMovingOrSizing();
   self.isMoving = false;
  end
end)
boxFrame:SetScript("OnHide", function(self)
  if ( self.isMoving ) then
   self:StopMovingOrSizing();
   self.isMoving = false;
  end
end)
boxFrame:Show()

local dungeonNameFrame = CreateFrame("Frame", nil, boxFrame)
dungeonNameFrame:SetSize(30, 100)
dungeonNameFrame.text = dungeonNameFrame:CreateFontString(nil,"OVERLAY", "GameFontNormal") 
dungeonNameFrame.text:SetPoint("TOP", boxFrame, "TOP", 0, 0)
dungeonNameFrame.text:SetText("")

local tankFrame = CreateFrame("Frame", nil, boxFrame)
tankFrame:SetSize(30, 30)
local tf = tankFrame:CreateTexture(nil,"BACKGROUND")
tf:SetAllPoints(tankFrame)
tankFrame.texture = tf
tankFrame:SetPoint("LEFT", 20,0, "LEFT")
tankFrame.texture:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-ROLES");
tankFrame.texture:SetTexCoord(GetTexCoordsForRole("TANK"))
tankFrame.texture:SetDesaturated(1)
tankFrame:Hide()

local tankNameFrame = CreateFrame("Frame", nil, tankFrame)
tankNameFrame:SetSize(30, 100)
tankNameFrame.text = tankNameFrame:CreateFontString(nil,"OVERLAY", "GameFontNormal") 
tankNameFrame.text:SetPoint("TOP", tankFrame, "BOTTOM", 0, 0)
tankNameFrame.text:SetText("")
tankNameFrame:Hide()

local healerFrame = CreateFrame("Frame", nil, tankFrame)
healerFrame:SetSize(30, 30)
local hf = healerFrame:CreateTexture(nil,"BACKGROUND")
hf:SetAllPoints(healerFrame)
healerFrame.texture = hf
healerFrame:SetPoint("LEFT", 80, 0)
healerFrame.texture:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-ROLES");
healerFrame.texture:SetTexCoord(GetTexCoordsForRole("HEALER"))
healerFrame.texture:SetDesaturated(1)
healerFrame:Hide()

local healerNameFrame = CreateFrame("Frame", nil, healerFrame)
healerNameFrame:SetSize(30, 100)
healerNameFrame.text = healerNameFrame:CreateFontString(nil,"OVERLAY", "GameFontNormal") 
healerNameFrame.text:SetPoint("TOP", healerFrame, "BOTTOM", 0, 0)
healerNameFrame.text:SetText("")
healerNameFrame:Hide()

local dpsFrame = CreateFrame("Frame", nil, healerFrame)
dpsFrame:SetSize(30, 30)
local df = dpsFrame:CreateTexture(nil,"BACKGROUND")
df:SetAllPoints(dpsFrame)
dpsFrame.texture = df
dpsFrame:SetPoint("LEFT", 80, 0)
dpsFrame.texture:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-ROLES");
dpsFrame.texture:SetTexCoord(GetTexCoordsForRole("DAMAGER"))
dpsFrame.texture:SetDesaturated(1)
dpsFrame:Hide()

local dpsNameFrame = CreateFrame("Frame", nil, dpsFrame)
dpsNameFrame:SetSize(30, 100)
dpsNameFrame.text = dpsNameFrame:CreateFontString(nil,"OVERLAY", "GameFontNormal") 
dpsNameFrame.text:SetPoint("TOP", dpsFrame, "BOTTOM", 0, 0)
dpsNameFrame.text:SetText("")
dpsNameFrame:Hide()

local dps2Frame = CreateFrame("Frame", nil, dpsFrame)
dps2Frame:SetSize(30, 30)
local d2f = dps2Frame:CreateTexture(nil,"BACKGROUND")
d2f:SetAllPoints(dps2Frame)
dps2Frame.texture = d2f
dps2Frame:SetPoint("LEFT", 80, 0)
dps2Frame.texture:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-ROLES");
dps2Frame.texture:SetTexCoord(GetTexCoordsForRole("DAMAGER"))
dps2Frame.texture:SetDesaturated(1)
dps2Frame:Hide()

local dps2NameFrame = CreateFrame("Frame", nil, dps2Frame)
dps2NameFrame:SetSize(30, 100)
dps2NameFrame.text = dps2NameFrame:CreateFontString(nil,"OVERLAY", "GameFontNormal") 
dps2NameFrame.text:SetPoint("TOP", dps2Frame, "BOTTOM", 0, 0)
dps2NameFrame.text:SetText("")
dps2NameFrame:Hide()

local dps3Frame = CreateFrame("Frame", nil, dps2Frame)
dps3Frame:SetSize(30, 30)
local d3f = dps3Frame:CreateTexture(nil,"BACKGROUND")
d3f:SetAllPoints(dps3Frame)
dps3Frame.texture = d3f
dps3Frame:SetPoint("LEFT", 80, 0)
dps3Frame.texture:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-ROLES");
dps3Frame.texture:SetTexCoord(GetTexCoordsForRole("DAMAGER"))
dps3Frame.texture:SetDesaturated(1)
dps3Frame:Hide()

local dps3NameFrame = CreateFrame("Frame", nil, dps3Frame)
dps3NameFrame:SetSize(30, 100)
dps3NameFrame.text = dps3NameFrame:CreateFontString(nil,"OVERLAY", "GameFontNormal") 
dps3NameFrame.text:SetPoint("TOP", dps3Frame, "BOTTOM", 0, 0)
dps3NameFrame.text:SetText("")
dps3NameFrame:Hide()

local refreshFrame = CreateFrame("Button", "GroupBuilderRefresh", boxFrame, "UIPanelButtonTemplate");
refreshFrame:SetSize(60,20)
refreshFrame:SetPoint("BOTTOMRIGHT",0,0, "BOTTOMRIGHT")
refreshFrame:SetText("Refresh")
refreshFrame:RegisterForClicks("AnyUp")
refreshFrame:SetScript("OnClick", function(self) 
	GroupBuilder:Retry(dungeonQueue)
   self:Hide()
end)
refreshFrame:Hide()

local inviteGroupButton = CreateFrame("Button", "GroupBuilderRefresh", boxFrame, "UIPanelButtonTemplate");
inviteGroupButton:SetSize(100,20)
inviteGroupButton:SetPoint("BOTTOM",0,0)
inviteGroupButton:SetText("INVITE GROUP")
inviteGroupButton:RegisterForClicks("AnyUp")
inviteGroupButton:SetScript("OnClick", function(self) 	
	GroupBuilder:InviteParty(dungeonQueue.dungeonId, groupToInvite, true);
end)
inviteGroupButton:Hide()

local leaveQueueButton = CreateFrame("Button", "GroupBuilderRefresh", boxFrame, "UIPanelButtonTemplate");
leaveQueueButton:SetSize(80,20)
leaveQueueButton:SetPoint("BOTTOMLEFT",0,0, "BOTTOMLEFT")
leaveQueueButton:SetText("Leave Queue")
leaveQueueButton:RegisterForClicks("AnyUp")
leaveQueueButton:SetScript("OnClick", function(self) 
	GroupBuilder:LeaveQueue();
end)
leaveQueueButton:Hide()

local roleCheckButton = CreateFrame("Button", "GroupBuilderRoleCheck", boxFrame, "UIPanelButtonTemplate");
local queueButton = CreateFrame("Button", "GroupBuilderRefresh", boxFrame, "UIPanelButtonTemplate");
queueButton:SetSize(100,20)
queueButton:SetText("QUEUE")
queueButton:RegisterForClicks("AnyUp")
queueButton:SetScript("OnClick", function(self) 
	if dungeonQueue.dungeonId == nil then GroupBuilder:PrettyPrint("You need to select a dungeon") return end
	
	GroupBuilder:FillGroupFor(dungeonQueue.dungeonId);
end)
queueButton:Hide()

roleCheckButton:SetSize(100,20)
 
 -- Create the dropdown, and configure its appearance
 local dropDown = CreateFrame("FRAME", "GBDropDown", boxFrame, "UIDropDownMenuTemplate")
 queueButton:SetPoint("TOPLEFT", dropDown, "CENTER", 5, -15)
 dropDown:SetPoint("CENTER", 0, 0)
 UIDropDownMenu_SetWidth(dropDown, 100)
 UIDropDownMenu_SetText(dropDown, "Select a Heroic")
 
 -- Create and bind the initialization function to the dropdown menu
 UIDropDownMenu_Initialize(dropDown, function(self, level, menuList)
  local info = UIDropDownMenu_CreateInfo()
  
   for i=1,#dungeonNames do
    info.text, info.checked = dungeonNames[i], dungeonQueue.dungeonName == dungeonNames[i]
    info.menuList = i
	info.func = self.SetValue
	info.arg1 = dungeonNames[i]
    UIDropDownMenu_AddButton(info)
  end
 end)

 function dropDown:SetValue(newValue)
	dungeonQueue.dungeonName = newValue
	dungeonQueue.dungeonId = dungeonIDs.heroic[newValue]
	GroupBuilder:DebugPrint("dungeonId: " .. dungeonQueue.dungeonId)
	GroupBuilder:DebugPrint("rolecheckState: " .. dungeonQueue.roleCheckState)
	
	if GetNumGroupMembers() == 0 then
		dungeonQueue.roleCheckState = roleCheckEnum.complete
		queueButton:Show()		
	else 
		roleCheckButton:Show()
	end
	
	if dungeonQueue.roleCheckState == roleCheckEnum.complete then 
		queueButton:Show()
	end
	
	UIDropDownMenu_SetText(dropDown, "HC: " .. newValue)	
	CloseDropDownMenus()
 end
 
roleCheckButton:SetPoint("TOPRIGHT", dropDown, "CENTER", -5,-15)
roleCheckButton:SetText("Role Check")
roleCheckButton:RegisterForClicks("AnyUp")
roleCheckButton:SetScript("OnClick", function(self) 
	-- Ignore presses while a check in progress
	if dungeonQueue.roleCheckState == roleCheckEnum.inprogress then return end
	
	dungeonQueue.roleCheckState = roleCheckEnum.inprogress
	dungeonQueue.roleCheckCount = 0
	
	roleCheckButton:SetText("0 / " .. GetNumGroupMembers())
	InitiateRolePoll()
end)
roleCheckButton:Hide()




local closeButton = CreateFrame("Button", nil, boxFrame, "UIPanelButtonTemplate");
closeButton:SetSize(20,20)
closeButton:SetPoint("TOPRIGHT", boxFrame, "TOPRIGHT", 0,0)
closeButton:SetText("X")
closeButton:RegisterForClicks("AnyUp")
closeButton:SetScript("OnClick", function(self) 
	boxFrame:Hide()
end)

local playerRoleFrame = CreateFrame("Button", "GBPlayerTalentFrameRoleButton", boxFrame)
playerRoleFrame:SetSize(30, 30)
local pRF = playerRoleFrame:CreateTexture(nil,"BACKGROUND")
pRF:SetAllPoints(playerRoleFrame)
playerRoleFrame.texture = pRF
playerRoleFrame:SetPoint("TOPLEFT", 0, 0, "TOPLEFT")
playerRoleFrame.texture:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-ROLES");
playerRoleFrame.texture:SetTexCoord(GetTexCoordsForRole("DAMAGER"))
playerRoleFrame:RegisterForClicks("AnyUp")
playerRoleFrame:SetScript("OnClick", function(self) 
	ToggleDropDownMenu(1, nil, playerRoleFrame, "GBPlayerTalentFrameRoleButton", 17, 4);
end)

 -- Create and bind the initialization function to the dropdown menu
 UIDropDownMenu_Initialize(playerRoleFrame, function(self, level, menuList)
	local info = UIDropDownMenu_CreateInfo();
	info.text = INLINE_TANK_ICON.." "..TANK;
	info.func = self.OnSelect;
	info.classicChecks = true;
	info.arg1 = "TANK";
	info.value = info.arg1;
	info.checked = info.value == currentRole;
	UIDropDownMenu_AddButton(info);

	info.text = INLINE_HEALER_ICON.." "..HEALER;
	info.func = self.OnSelect;
	info.classicChecks = true;
	info.arg1 = "HEALER";
	info.value = info.arg1;
	info.checked = info.value == currentRole;
	UIDropDownMenu_AddButton(info);

	info.text = INLINE_DAMAGER_ICON.." "..DAMAGER;
	info.func = self.OnSelect;
	info.classicChecks = true;
	info.arg1 = "DAMAGER";
	info.value = info.arg1;
	info.checked = info.value == currentRole or currentRole == "NONE";
	UIDropDownMenu_AddButton(info);
 end)

 function playerRoleFrame:OnSelect(newValue)
	local talentGroup = GetActiveTalentGroup()

	SetTalentGroupRole(talentGroup, newValue)
	CloseDropDownMenus()
 end

local dpsFrames = { dpsFrame, dps2Frame, dps3Frame };
local roleFrames = { 
	tank = tankFrame,
	healer = healerFrame,
	dps = dpsFrames,
}
-- UI END


-- OnEvent Handler
GroupBuilder:SetScript("OnEvent", function(f, event)
	if initCalled == false then 
		GroupBuilder:Init()
		initCalled = true
	end
	
	GroupBuilder:DebugLFGList()
	
	if event == "GROUP_ROSTER_UPDATE" then			
		if GetNumGroupMembers() > 0 and dungeonQueue.dungeonId ~= nil then
			roleCheckButton:Show()
		else
			roleCheckButton:Hide()
		end
	end
	
	if event == "ROLE_CHANGED_INFORM" or event == "TALENT_GROUP_ROLE_CHANGED" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
		playerRoleFrame.texture:SetTexCoord(GetTexCoordsForRole(GetTalentGroupRole(GetActiveTalentGroup())))
	end
	
	if event == "ROLE_CHANGED_INFORM" and dungeonQueue.roleCheckState == roleCheckEnum.inprogress then
		dungeonQueue.roleCheckCount = dungeonQueue.roleCheckCount + 1
		roleCheckButton:SetText(dungeonQueue.roleCheckCount .. " / " ..  GetNumGroupMembers())
		
		if dungeonQueue.roleCheckCount == GetNumGroupMembers() then
			dungeonQueue.roleCheckCount = 0
			dungeonQueue.roleCheckState = roleCheckEnum.complete
			roleCheckButton:SetText("Role Check")
		end
	end
	
	if dungeonQueue.roleCheckState == roleCheckEnum.complete then
		if dungeonQueue.dungeonId ~= nil then
			queueButton:Show()
			roleCheckButton:Hide()
		end
	else
		queueButton:Hide()
	end
	
	if dungeonQueue.inQueue == false then
		GroupBuilder:DebugPrint("Not in queue so returning early")
		return
	end

	-- ensure the user isn't navigating the group finder and looking at invalid results
	local entryData = C_LFGList.GetActiveEntryInfo();
	if (entryData) then
		print("found entrydata")
		if entryData.activityID ~= dungoneQueue.dungeonId then
			print("invalid entry id, ignoring it")
			return 
		end 
	end
	
	if ( event == "LFG_LIST_AVAILABILITY_UPDATE" ) then
		GroupBuilder:DebugPrint(event);
	elseif ( event == "LFG_LIST_SEARCH_RESULTS_RECEIVED" ) then
		GroupBuilder:DebugPrint(event);

		local results = select(2, C_LFGList.GetFilteredSearchResults());
		GroupBuilder:EnsurePlayersStillInQueue(groupToInvite, dungeonQueue, results)
		
		for index = 1, #results do
			if dungeonQueue.inQueue == false then break end
			
			local resultID = results[index]
			local searchResultInfo = C_LFGList.GetSearchResultInfo(resultID);
			
			if searchResultInfo.isDelisted == true then
				GroupBuilder:RemovePlayerForDelisted(dungeonQueue, groupToInvite, resultID)
			end

			if GroupBuilder:SearchResultContains(searchResultInfo, dungeonQueue.dungeonId) == true and searchResultInfo.isDelisted == false and searchResultInfo.numMembers == 1 then
				GroupBuilder:CachePlayerIfFits(dungeonQueue, groupToInvite, resultID)
			end
		end		
	elseif ( event == "LFG_LIST_SEARCH_FAILED" ) then
		GroupBuilder:DebugPrint(event);
	end
	
	GroupBuilder:RefreshUI(groupToInvite, dungeonQueue)
end)

function GroupBuilder:SearchResultContains(searchResultInfo, activityId) 
	if (searchResultInfo) then
		if (searchResultInfo.activityID) then
			if searchResultInfo.activityID == activityId then return true end
		end
		
		if (searchResultInfo.activityIDs) then
			if GroupBuilder:TableContainsValue(searchResultInfo.activityIDs, activityId) then return true end
		end
	end
	return false
end

function GroupBuilder:TableContainsValue(tab, val)
	for idx, value in ipairs(tab) do
		if value == val then return true end 
	end
	
	return false
end

function GroupBuilder:RefreshUI(groupToInvite, dungeonQueue)
	dungeonNameFrame.text:SetText(dungeonQueue.dungeonName)
	GroupBuilder:UpdateNameFrames(groupToInvite)
	GroupBuilder:ShowRoleFrames(dungeonQueue.inQueue) -- Always show role frames if in queue
	
	-- Update UI elements for when the queue is complete
	if dungeonQueue.tanks <= 0 and dungeonQueue.healers <= 0 and dungeonQueue.dps <= 0 then
		inviteGroupButton:Show()
	end
	
	GroupBuilder:PrintGroupCache(groupToInvite)
end

function GroupBuilder:EnsurePlayersStillInQueue(groupToInvite, dungeonQueue, results)
	if not groupToInvite.tank == "" then 
		if GroupBuilder:IsPlayerInQueueAsRole(playerName, "tank", results) == false then
			dungeonQueue.tank = 0
			groupToInvite.tank = ""
		end
	end
	
	if not groupToInvite.healer == "" then 
		if GroupBuilder:IsPlayerInQueueAsRole(playerName, "healer", results) == false then
			dungeonQueue.healer = 0
			groupToInvite.healer = ""
		end
	end
	
	for index = 1, #groupToInvite.dps do
		if not groupToInvite.dps[index] == "" then
			if GroupBuilder:IsPlayerInQueueAsRole(playerName, role, results) == false then
				dungeonQueue.dps = dungeonQueue.dps - 1
				groupToInvite.dps[index] = ""
			end
		end
	end	
end

function GroupBuilder:IsPlayerInQueueAsRole(playerName, role, results)
	local role = string.lower(role);
	for index = 1, #results do
		local resultID = results[index]
		local name, _, _, _, _, _, soloRoleTank, soloRoleHealer, soloRoleDPS = C_LFGList.GetSearchResultLeaderInfo(resultID);
	
		if name == playerName then
			if role == "tank" then
				return soloRoleTank
			elseif role == "healer" then
				return soloRoleHealer
			else
				return soloRoleDPS
			end
		end		
	end
	
	return false
end

function GroupBuilder:RemovePlayerForDelisted(dungeonQueue, groupToInvite, resultID)
	local name = C_LFGList.GetSearchResultLeaderInfo(resultID);
	if groupToInvite.tank == name then 
		groupToInvite.tank = ""
		GroupBuilder:SetFrameColor(tankFrame, "red")
		tankNameFrame.text:SetText("")
		dungeonQueue.tanks = dungeonQueue.tanks + 1
		GroupBuilder:DebugPrint("Removing player for delist: " .. name)
	elseif groupToInvite.healer == name then
		groupToInvite.healer = ""
		GroupBuilder:SetFrameColor(healerFrame, "red")
		dungeonQueue.healers = dungeonQueue.healers + 1
		GroupBuilder:DebugPrint("Removing player for delist: " .. name)
	elseif groupToInvite.dps[1] == name then
		groupToInvite.dps[1] = ""
		GroupBuilder:SetFrameColor(dpsFrame, "red")
		dungeonQueue.dps = dungeonQueue.dps + 1
		GroupBuilder:DebugPrint("Removing player for delist: " .. name)
	elseif groupToInvite.dps[2] == name then
		groupToInvite.dps[2] = ""
		GroupBuilder:SetFrameColor(dps2Frame, "red")
		dungeonQueue.dps = dungeonQueue.dps + 1
		GroupBuilder:DebugPrint("Removing player for delist: " .. name)
	elseif groupToInvite.dps[3] == name then
		groupToInvite.dps[3] = ""
		GroupBuilder:SetFrameColor(dps3Frame, "red")
		dungeonQueue.dps = dungeonQueue.dps + 1
		GroupBuilder:DebugPrint("Removing player for delist: " .. name)
	end
end

function GroupBuilder:CachePlayerIfFits(dungeonQueue, groupToInvite, resultID)
	local name, role, classFileName, className, level, areaName, soloRoleTank, soloRoleHealer, soloRoleDPS = C_LFGList.GetSearchResultLeaderInfo(resultID);
	
	-- Guard against duplicates 
	if groupToInvite.tank == name or groupToInvite.healer == name then return end 
	for index = 1, #groupToInvite.dps do
		if groupToInvite.dps[index] == name then return end
	end
	
	if soloRoleTank == true and dungeonQueue.tanks > 0 and GroupBuilder:ValidateRoleIsLogical(className, "TANK") == true then
		dungeonQueue.tanks = dungeonQueue.tanks - 1
		groupToInvite.tank = name
		tankNameFrame.text:SetText(name)
		GroupBuilder:SetFrameColor(roleFrames.tank, "green")
	elseif soloRoleHealer == true and dungeonQueue.healers > 0 and GroupBuilder:ValidateRoleIsLogical(className, "HEALER") == true then
		dungeonQueue.healers = dungeonQueue.healers - 1
		groupToInvite.healer = name
		GroupBuilder:SetFrameColor(roleFrames.healer, "green")
	elseif soloRoleDPS == true and dungeonQueue.dps > 0 then	
		groupToInvite.dps[dungeonQueue.dps] = name
		GroupBuilder:SetFrameColor(roleFrames.dps[dungeonQueue.dps], "green")
		
		dungeonQueue.dps = dungeonQueue.dps - 1
	end
end

function GroupBuilder:ValidateRoleIsLogical(className, role) 
	local class = string.lower(className)
	if role == "TANK" then
		return class == "paladin" or class == "death knight" or class == "warrior" or class == "druid"
	elseif role == "HEALER" then 
		return class == "paladin" or class == "priest" or class == "shaman" or class == "druid"
	end
	
	return true
end

function GroupBuilder:InviteParty(dungeonId, groupToInvite, firstCall)
	GroupBuilder:PrettyPrint("Your Party is Ready!")
	TimeSinceLastInvite = 0

	-- SetDungeonDifficulty(2) -- Set to heroic 

	GroupBuilder:Invite(groupToInvite.tank, "TANK", dungeonId); 
	GroupBuilder:Invite(groupToInvite.healer, "HEALER", dungeonId);
	GroupBuilder:Invite(groupToInvite.dps[1], "DPS", dungeonId);
	GroupBuilder:Invite(groupToInvite.dps[2], "DPS", dungeonId);
	GroupBuilder:Invite(groupToInvite.dps[3], "DPS", dungeonId);
	
	if firstCall == false then return end
	
	C_Timer.After(15, function() GroupBuilder:InviteParty(dungeonQueue.dungeonId, groupToInvite, false) end)
end

function GroupBuilder:Invite(player, role, dungeonId) 
	if player == "player" or player == UnitName("player") then return end
	
	for i = 1, GetNumGroupMembers() do
		local partyIndex = "party"..i
		local name = UnitName(partyIndex)
		if name == player then return end
	end
	
	if DEBUG then
		local activityInfo = C_LFGList.GetActivityInfoTable(dungeonId)
		GroupBuilder:DebugPrint("[GroupBuilder] auto invited " .. player .." to " .. activityInfo.fullName .. " as a " .. role)
		return
	end
	
	
	local activityInfo = C_LFGList.GetActivityInfoTable(dungeonId)
	GroupBuilder:DebugPrint("[GroupBuilder] auto invited " .. player .." to " .. activityInfo.fullName .. " as a " .. role)
	InviteUnit(player)
	SendChatMessage("[GroupBuilder] You were queued for a " .. activityInfo.fullName .. " as a " .. role, "WHISPER", nil, player)
	SendChatMessage("[GroupBuilder] If you are in a party, please drop group. You will be invited again in 15s", "WHISPER", nil, player)
end


function GroupBuilder:ResetRoleFrames() 
	GroupBuilder:SetFrameColor(roleFrames.tank, "red")
	GroupBuilder:SetFrameColor(roleFrames.healer, "red")
	GroupBuilder:SetFrameColor(roleFrames.dps[1], "red")
	GroupBuilder:SetFrameColor(roleFrames.dps[2], "red")
	GroupBuilder:SetFrameColor(roleFrames.dps[3], "red")
end

function GroupBuilder:LeaveQueue() 
	GroupBuilder:ShowRoleFrames(false)
	GroupBuilder:ResetRoleFrames()
	refreshFrame:Hide()
	dungeonNameFrame.text:SetText("")
	inviteGroupButton:Hide()
	
	if dungeonQueue.inQueue and dungeonQueue.dungeonName ~= "" then
		if IsInGroup() then
			SendChatMessage("[GroupBuilder] Left queue for " .. tostring(dungeonQueue.dungeonName), "PARTY", nil, nil)
		else
			GroupBuilder:PrettyPrint("[GroupBuilder] Left queue for " .. tostring(dungeonQueue.dungeonName))
		end
	end
	
	dungeonQueue = {
		roleCheckState = roleCheckEnum.none,
		roleCheckCount = 0,
		dungeonId = dungeonQueue.dungeonId,
		dungeonName = dungeonQueue.dungeonName,
		inQueue = false,
		tanks = 0,
		healers = 0,
		dps = 0,
	}
	groupToInvite = {
		tank = "",
		healer = "",
		dps = { "", "", "" }
	}
	
	UIDropDownMenu_SetText(dropDown, "Select a Heroic")
	GroupBuilder:UpdateNameFrames(groupToInvite)
end

function GroupBuilder:UpdateNameFrames(groupToInvite)
	tankNameFrame.text:SetText(groupToInvite.tank)
	healerNameFrame.text:SetText(groupToInvite.healer)
	dpsNameFrame.text:SetText(groupToInvite.dps[1])
	dps2NameFrame.text:SetText(groupToInvite.dps[2])
	dps3NameFrame.text:SetText(groupToInvite.dps[3])
end

function GroupBuilder:AddPartyMemberToGroupComp(partyIndex, groupComp, role)
	local name = UnitName(partyIndex)
	if name == nil then name = UnitName("player") end
	
	if role == "DAMAGER" then
		groupToInvite.dps[3 - groupComp.dps] = name
		groupComp.dps = groupComp.dps + 1
		GroupBuilder:SetFrameColor(roleFrames.dps[3], "green")
	elseif role == "TANK" then
		groupComp.tanks = groupComp.tanks + 1
		groupToInvite.tank = name
		GroupBuilder:SetFrameColor(tankFrame, "green")
	elseif role == "HEALER" then
		groupComp.healers = groupComp.healers + 1
		groupToInvite.healer = name
		GroupBuilder:SetFrameColor(healerFrame, "green")
	end
	
	GroupBuilder:UpdateNameFrames(groupToInvite)
end

function GroupBuilder:AddPlayerToGroupComp(groupComp, role)
	if role == "DAMAGER" then
		groupComp.dps = groupComp.dps + 1
		groupToInvite.dps[3] = UnitName("player")
		GroupBuilder:SetFrameColor(roleFrames.dps[3], "green")
	elseif role == "TANK" then
		groupComp.tanks = groupComp.tanks + 1
		groupToInvite.tank = UnitName("player")
		GroupBuilder:SetFrameColor(tankFrame, "green")
	elseif role == "HEALER" then
		groupComp.healers = groupComp.healers + 1
		groupToInvite.healer = UnitName("player")
		GroupBuilder:SetFrameColor(healerFrame, "green")
	end
	
	GroupBuilder:UpdateNameFrames(groupToInvite);
end

function GroupBuilder:ShowRoleFrames(shown) 
	if shown then
		dropDown:Hide()
		queueButton:Hide()
		leaveQueueButton:Show()
		roleFrames.tank:Show()
		roleFrames.healer:Show()
		for index = 1, #roleFrames.dps do 
			roleFrames.dps[index]:Show()
		end
		
		tankNameFrame:Show()
		healerNameFrame:Show()
		dpsNameFrame:Show()
		dps2NameFrame:Show()
		dps3NameFrame:Show()
	else
		dropDown:Show()
		queueButton:Show()
		leaveQueueButton:Hide()
		roleFrames.tank:Hide()
		roleFrames.healer:Hide()
		for index = 1, #roleFrames.dps do 
			roleFrames.dps[index]:Hide()
		end
		
		tankNameFrame:Hide()
		healerNameFrame:Hide()
		dpsNameFrame:Hide()
		dps2NameFrame:Hide()
		dps3NameFrame:Hide()
	end
end

function GroupBuilder:FillGroupFor(dungeonId) 
	GroupBuilder:LeaveQueue() 
	GroupBuilder:DebugPrint("queue up for " .. dungeonId);
	if IsInRaid() then GroupBuilder:PrettyPrint("Cannot queue up while in raid") return end
	GroupBuilder:ShowRoleFrames(true) 
	
	local groupComp = {
		tanks = 0,
		healers = 0,
		dps = 0,
	}
	
	if IsInGroup() then
		for i = 1, GetNumGroupMembers() do
			local partyIndex = "party"..i
			local role = UnitGroupRolesAssigned(partyIndex)
			local name = UnitName(partyIndex)
			if name == nil then
				name = "player"
				role = GetTalentGroupRole(GetActiveTalentGroup());
			end
			GroupBuilder:DebugPrint("role for " .. name ..": " .. partyIndex .. ":" .. role)
			GroupBuilder:AddPartyMemberToGroupComp(partyIndex, groupComp, role)
		end
	else
		-- Role found in the players talent tree UI
		local role = GetTalentGroupRole(GetActiveTalentGroup());
		GroupBuilder:DebugPrint("role for solo queue player: " .. role)
		GroupBuilder:AddPlayerToGroupComp(groupComp, role)
	end
	GroupBuilder:DebugPrint("---- Current Group: " .. groupComp["tanks"] .. ":" .. groupComp["healers"] .. ":" .. groupComp["dps"] .. " ----")
	
	--dungeonQueue.dungeonName = dungeonNames[dungeonId]
	dungeonNameFrame.text:SetText(dungeonQueue.dungeonName)
	dungeonQueue.dungeonId = dungeonId
	dungeonQueue.tanks = 1 - groupComp.tanks
	dungeonQueue.healers = 1 - groupComp.healers
	dungeonQueue.dps = 3 - groupComp.dps
	dungeonQueue.inQueue = true
	
	if IsInGroup() then
		SendChatMessage("[GroupBuilder] Joined queue for " .. tostring(dungeonQueue.dungeonName), "PARTY", nil, nil)
	else
		GoupBuilder:PrettyPrint("Joined queue for " .. tostring(dungeonQueue.dungeonName))
	end
	
	C_LFGList.Search(dungeonCategoryId, { dungeonId });
	
	if (C_LFGList.HasActiveEntryInfo()) then
		LFGParentFrame_SearchActiveEntry();
	end
end

function GroupBuilder:Retry(dungeonQueue)
	if dungeonQueue.inQueue == false then GroupBuilder:DebugPrint("Not in Queue") return end
	
	C_LFGList.Search(dungeonCategoryId, { dungeonQueue.dungeonId });
	
	if (C_LFGList.HasActiveEntryInfo()) then
		LFGParentFrame_SearchActiveEntry();
	end
end

function GroupBuilder:Init() 
	playerRoleFrame.texture:SetTexCoord(GetTexCoordsForRole(GetTalentGroupRole(GetActiveTalentGroup())))
	SLASH_GROUPBUILDER1 = "/gb"
	SlashCmdList["GROUPBUILDER"] = function(msg) 
		GroupBuilder:ChatCommands(msg)
	end
end

function GroupBuilder:ChatCommands(msg)
    msg = string.lower(msg)
	local args = {}
	for word in string.gmatch(msg, "[^%s]+") do
		table.insert(args, word)
	end
    if args[1] == nil then
		boxFrame:Show()
	elseif args[1] == "hide" then
		boxFrame:Hide()
	elseif args[1] == "show" then
		boxFrame:Show()
	elseif args[1] == "debug" then
		DEBUG = not DEBUG
		GroupBuilder:PrettyPrint("Debugging: " .. tostring(DEBUG))
    end
end

function GroupBuilder:SetFrameColor(frame, color)
	if frame == nil then return end 
	
	if string.lower(color) == "red" then
		frame.texture:SetDesaturated(1)
	elseif string.lower(color) == "green" then
		frame.texture:SetDesaturated(nil)
	end
end

-- QUEUE HANDLER 
local frame = CreateFrame("Frame")

-- The minimum number of seconds between each update
local ONUPDATE_INTERVAL = 5

-- The number of seconds since the last update
local TimeSinceLastUpdate = 0
frame:SetScript("OnUpdate", function(self, elapsed)
	TimeSinceLastUpdate = TimeSinceLastUpdate + elapsed
		
	if TimeSinceLastUpdate >= ONUPDATE_INTERVAL then
		TimeSinceLastUpdate = 0
		
		if dungeonQueue.inQueue == false then return end
		GroupBuilder:DebugPrint("OnUpdate Queue search")
		refreshFrame:Show()
	end
end)

-- When the frame is shown, reset the update timer
frame:SetScript("OnShow", function(self)
	TimeSinceLastUpdate = 0
end)

-- Difficulty dropdown (multi-select) in the leads section of the Antiquities journal.
-- Filters by the 5 scrying difficulties (Simple ... Ultimate) shown on each lead tile.

AntiquityLeadFilter = AntiquityLeadFilter or {}
local ALF = AntiquityLeadFilter

ALF.name = "AntiquityLeadFilter"

local defaults = {
    hiddenDifficulties = {},   -- [difficulty] = true  -> hide this difficulty
}

local L = ALF.L

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function GetDifficultyName(difficulty)
    -- Localized by the game (same text as "Difficulty: ..." on the lead tiles)
    local name = GetString("SI_ANTIQUITYDIFFICULTY", difficulty)
    if name == nil or name == "" then
        return tostring(difficulty)
    end
    -- Capitalize the first letter (UTF-8 safe via the game's formatter)
    return zo_strformat("<<C:1>>", name)
end

local function IsDifficultyShown(difficulty)
    -- Difficulty 0 (none) is never filtered
    return difficulty <= 0 or not ALF.sv.hiddenDifficulties[difficulty]
end

-- Color per difficulty: the most common antiquity quality color of that difficulty
local function CollectDifficultyColors()
    local qualityCounts = {}
    local antiquityId = GetNextAntiquityId()
    while antiquityId do
        local difficulty = GetAntiquityDifficulty(antiquityId)
        local quality = GetAntiquityQuality(antiquityId)
        if difficulty > 0 and quality > 0 then
            qualityCounts[difficulty] = qualityCounts[difficulty] or {}
            qualityCounts[difficulty][quality] = (qualityCounts[difficulty][quality] or 0) + 1
        end
        antiquityId = GetNextAntiquityId(antiquityId)
    end

    local colors = {}
    for difficulty, counts in pairs(qualityCounts) do
        local bestQuality, bestCount = nil, 0
        for quality, count in pairs(counts) do
            if count > bestCount then
                bestQuality, bestCount = quality, count
            end
        end
        colors[difficulty] = GetAntiquityQualityColor(bestQuality)
    end
    return colors
end

local function RefreshJournal()
    local journal = ANTIQUITY_JOURNAL_KEYBOARD
    if not (journal and journal.scene and journal.scene:IsShowing()) then return end

    -- Same as the journal does on search changes: rebuild the current category
    journal.forceUpdateContentOnCategoryReselect = true
    journal:RefreshCategories()
    journal.forceUpdateContentOnCategoryReselect = false
end

---------------------------------------------------------------------------
-- Dropdown
---------------------------------------------------------------------------

function ALF:CreateDropdown()
    local categoryInset = ZO_AntiquityJournal_Keyboard_TopLevel:GetNamedChild("Contents"):GetNamedChild("Category")

    local control = CreateControlFromVirtual("AntiquityLeadFilterDifficultyDropdown", categoryInset, "ZO_ComboBox")
    control:SetDimensions(220, 31)
    -- Below the category title (vertical), right-aligned with the list (horizontal)
    control:SetAnchor(TOP, categoryInset:GetNamedChild("Title"), BOTTOM, 0, 5, ANCHOR_CONSTRAINS_Y)
    control:SetAnchor(RIGHT, categoryInset, RIGHT, -10, 0, ANCHOR_CONSTRAINS_X)
    control:SetHidden(true)

    local comboBox = ZO_ComboBox_ObjectFromContainer(control)
    comboBox:SetSortsItems(false)
    comboBox:SetFont("ZoFontWinT1")
    comboBox:SetSpacing(4)
    comboBox:EnableMultiSelect()

    -- Custom display text: "All", individual names or a count
    local numDifficulties = ANTIQUITY_DIFFICULTY_MAX_VALUE
    function comboBox:RefreshSelectedItemText()
        local selected = self:GetSelectedItemData()
        local numSelected = #selected
        if numSelected == 0 then
            self:SetSelectedItemText(L.NO_SELECTION)
        elseif numSelected == numDifficulties then
            self:SetSelectedItemText(L.ALL_SELECTED)
        elseif numSelected <= 2 then
            local names = {}
            for i, entry in ipairs(selected) do
                names[i] = entry.difficultyName
            end
            self:SetSelectedItemText(table.concat(names, ", "))
        else
            self:SetSelectedItemText(zo_strformat(L.NUM_SELECTED, numSelected))
        end
    end

    local function OnEntryToggled(_, _, entry)
        ALF.sv.hiddenDifficulties[entry.difficulty] = (not comboBox:IsItemSelected(entry)) or nil
        RefreshJournal()
    end

    local colors = CollectDifficultyColors()
    for difficulty = 1, ANTIQUITY_DIFFICULTY_MAX_VALUE do
        local difficultyName = GetDifficultyName(difficulty)
        local color = colors[difficulty] or ZO_SELECTED_TEXT
        local entry = comboBox:CreateItemEntry(color:Colorize(difficultyName), OnEntryToggled)
        entry.difficulty = difficulty
        entry.difficultyName = difficultyName
        comboBox:AddItem(entry)
        if IsDifficultyShown(difficulty) then
            comboBox:AddItemToSelected(entry)
        end
    end
    comboBox:RefreshSelectedItemText()

    self.dropdown = control
end

---------------------------------------------------------------------------
-- Antiquities journal hooks
---------------------------------------------------------------------------

function ALF:HookJournal()
    local Journal = ZO_AntiquityJournal_Keyboard

    -- 1) Filter lead tiles by difficulty. Empty sections get no heading.
    local originalAddScryableTiles = Journal.AddScryableAntiquityTiles
    Journal.AddScryableAntiquityTiles = function(journal, previousTileOrHeading, headingText, antiquities, sortFunction)
        local filtered = {}
        for _, antiquityData in ipairs(antiquities) do
            if IsDifficultyShown(antiquityData:GetDifficulty()) then
                filtered[#filtered + 1] = antiquityData
            end
        end
        if #filtered == 0 then
            return previousTileOrHeading
        end
        return originalAddScryableTiles(journal, previousTileOrHeading, headingText, filtered, sortFunction)
    end

    -- 2) Show the dropdown only in the leads section; show "list empty" when everything is filtered out
    local originalBuildTiles = Journal.BuildCategoryAntiquityTiles
    Journal.BuildCategoryAntiquityTiles = function(journal, categoryData, ...)
        originalBuildTiles(journal, categoryData, ...)

        local isScryable = ZO_IsAntiquityScryableSubcategory(categoryData)
        ALF.dropdown:SetHidden(not isScryable)

        if isScryable then
            -- Move the list below the dropdown (the game anchors it higher in this section)
            journal.contentList:ClearAnchors()
            journal.contentList:SetAnchor(TOPLEFT, journal.categoryInset, BOTTOMLEFT, 0, 35)
            journal.contentList:SetAnchor(BOTTOMRIGHT, nil, nil, -10, -75)
        end

        if isScryable and next(journal.antiquityTilesByAntiquityId) == nil then
            journal.contentList:SetHidden(true)
            journal.contentEmptyLabel:SetHidden(false)
        end
    end

    -- 3) Locked content: hide the dropdown
    ZO_PostHook(Journal, "ShowLockedContentPanel", function()
        ALF.dropdown:SetHidden(true)
    end)
end

---------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------

local function OnAddOnLoaded(_, addOnName)
    if addOnName ~= ALF.name then return end
    EVENT_MANAGER:UnregisterForEvent(ALF.name, EVENT_ADD_ON_LOADED)

    if not (ZO_AntiquityJournal_Keyboard and ZO_AntiquityJournal_Keyboard_TopLevel) then return end

    ALF.sv = ZO_SavedVars:NewAccountWide("AntiquityLeadFilter_SV", 1, nil, defaults)
    ALF:CreateDropdown()
    ALF:HookJournal()
end

EVENT_MANAGER:RegisterForEvent(ALF.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

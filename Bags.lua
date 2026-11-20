local backpack = Enum.BagIndex.Backpack

local function trimEmptyRows(frame, hiddenCount)
    if hiddenCount == 0 then return end

    local slots
    if InputUtil.IsGamepadUIEnabled() then
        -- Blizzard counts each bag header as a cell and omits collapsed groups.
        local group = GamepadBagBar and GamepadBagBar:GetBagButton(backpack)
        if not group or group.isCollapsed then return end
        slots = frame.shownSlots + NUM_CONTAINER_FRAMES
    else
        slots = frame:GetBagSize()
    end

    local columns = frame:GetColumns()
    local emptyRows = math.ceil(slots / columns) - math.ceil((slots - hiddenCount) / columns)
    if emptyRows == 0 then return end

    local template = C_XMLUtil.GetTemplateInfo(frame.itemButtonPool:GetTemplate())
    local rowHeight = template.height + frame:GetAnchorLayout().paddingY
    local height = frame:GetHeight(true) - emptyRows * rowHeight
    frame:SetHeight(height)
    NineSliceUtil.UpdateCornerCropping(frame, height)
end

local function hideAddSlots(frame)
    if frame.AddSlotsButton then frame.AddSlotsButton:Hide() end
end

local function updateLayout(frame)
    frame:UpdateFrameSize()
    frame:UpdateItemLayout()
    UpdateContainerFrameAnchors()
end

local function attach(frame)
    local capacity
    local hidden = {}
    local standaloneItems = frame:IsBackpack() and {}

    local function collectSlots()
        local total, usable = ContainerFrame_GetContainerNumSlots(backpack)
        capacity = usable
        wipe(hidden)
        if standaloneItems then wipe(standaloneItems) end
        if total == usable then return end

        for _, button in frame:EnumerateItems() do
            if button:GetBagID() == backpack and button:IsExtended() then
                button:Hide()
                hidden[#hidden + 1] = button
            elseif standaloneItems then
                standaloneItems[#standaloneItems + 1] = button
            end
        end
    end

    hooksecurefunc(frame, "UpdateItemSlots", collectSlots)
    hooksecurefunc(frame, "UpdateAddSlots", hideAddSlots)
    hooksecurefunc(frame, "UpdateFrameSize", function()
        trimEmptyRows(frame, #hidden)
    end)

    -- Combined bags already sort unavailable slots last. The standalone backpack puts them first.
    if standaloneItems then
        hooksecurefunc(frame, "UpdateItemLayout", function()
            if #hidden > 0 then
                AnchorUtil.GridLayout(standaloneItems, frame:GetInitialItemAnchor(), frame:GetAnchorLayout())
            end
        end)
    end

    -- An open backpack can gain usable slots during an ordinary inventory refresh.
    hooksecurefunc(frame, "UpdateItems", function()
        if not frame:IsShown() or C_Container.GetContainerNumSlots(backpack) == capacity then return end
        for _, button in ipairs(hidden) do
            if not button:IsExtended() then button:Show() end
        end
        collectSlots()
        updateLayout(frame)
    end)

    if frame:IsShown() then
        collectSlots()
        hideAddSlots(frame)
        if #hidden > 0 then updateLayout(frame) end
    end
end

attach(ContainerFrame1)
attach(ContainerFrameCombinedBags)

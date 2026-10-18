--------------------------------------------------------------------------------
--[[ Auctionator Shopping List Cleaner ]]--
--
-- by ThiagoCMFranco <https://github.com/ThiagoCMFranco>
--
--Copyright (C) 2026  Thiago de C. M. Franco
--
--This program is free software: you can redistribute it and/or modify
--it under the terms of the GNU General Public License as published by
--the Free Software Foundation, either version 3 of the License, or
--(at your option) any later version.
--
--This program is distributed in the hope that it will be useful,
--but WITHOUT ANY WARRANTY; without even the implied warranty of
--MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--GNU General Public License for more details.
--
--You should have received a copy of the GNU General Public License
--along with this program.  If not, see <https://www.gnu.org/licenses/>.
--
--------------------------------------------------------------------------------

local addonName, ns = ...
local L = ns.L 

local managementFrame = nil
local checkboxesContainer = nil
local listElements = {}
local expandedLists = {}
local updateTimer = nil

local RefreshShoppingUI
local lastListSignature = nil

-- Gera uma assinatura rápida do estado atual das listas para detectar mudanças sem custo alto de processamento
local function GetListsSignature()
    local lists = AUCTIONATOR_SHOPPING_LISTS
    if not lists or type(lists) ~= "table" then return "nil" end
    
    local sig = tostring(#lists)
    for i, listObj in ipairs(lists) do
        if type(listObj) == "table" then
            local items = listObj.items or listObj.itemQueries or {}
            sig = sig .. "_" .. tostring(listObj.name or "") .. "_" .. tostring(#items)
        end
    end
    return sig
end

-- Função para limpar o nome principal do item
local function CleanUpItemName(rawText)
    if not rawText or type(rawText) ~= "string" then return L["Unknown_Item"] end

    local cleaned = rawText
    local itemNameFromLink = cleaned:match("%[(.-)%]") or cleaned:match("|h%[(.-)%]|h")
    if itemNameFromLink then
        return itemNameFromLink
    end

    cleaned = cleaned:gsub('^"(.-)"$', "%1")
    cleaned = cleaned:gsub("^!(.-)", "%1")

    if cleaned:match("^item:%d+") then
        local itemInfoName = GetItemInfo(cleaned)
        if itemInfoName then
            return itemInfoName
        end
    end

    cleaned = cleaned:gsub("^%s*(.-)%s*$", "%1")
    if cleaned == "" then
        return rawText
    end

    return cleaned
end

-- Função segura para formatar considerando posições exatas por ";"
local function FormatItemDisplayString(rawItemStr)
    if not rawItemStr or type(rawItemStr) ~= "string" then return L["Unknown_Item"] end

    local parts = {}
    for part in (rawItemStr .. ";"):gmatch("(.-);") do
        table.insert(parts, part)
    end

    if #parts == 0 then
        return CleanUpItemName(rawItemStr)
    end

    local rawName = parts[1] or ""
    local itemName = CleanUpItemName(rawName)
    local auctionFilter = parts[2]
    local quantityStr = parts[#parts]
    local quantity = tonumber(quantityStr) or 0

    local result = itemName

    if auctionFilter and auctionFilter ~= "" and auctionFilter ~= "0" then
        result = result .. " |cff00ccff[" .. auctionFilter .. "]|r"
    end

    if quantity > 0 then
        result = result .. " |cffffd100(x" .. quantity .. ")|r"
    end

    return result
end

-- Atualiza a listagem visual com conversão estruturada de itens
RefreshShoppingUI = function()
    if not checkboxesContainer then return end

    lastListSignature = GetListsSignature()

    for _, elem in pairs(listElements) do
        if elem.cb then elem.cb:Hide(); elem.cb:SetParent(nil) end
        if elem.btnExpand then elem.btnExpand:Hide(); elem.btnExpand:SetParent(nil) end
        if elem.text then elem.text:Hide(); elem.text:SetParent(nil) end
        if elem.items then
            for _, itemCb in pairs(elem.items) do
                if itemCb.cb then itemCb.cb:Hide(); itemCb.cb:SetParent(nil) end
                if itemCb.text then itemCb.text:Hide(); itemCb.text:SetParent(nil) end
            end
        end
    end
    listElements = {}

    if listCheckboxes then
        for _, cb in pairs(listCheckboxes) do
            if cb and cb.Hide then
                cb:Hide()
                cb:SetParent(nil)
            end
        end
        listCheckboxes = nil
    end

    local lists = AUCTIONATOR_SHOPPING_LISTS
    if not lists or type(lists) ~= "table" or #lists == 0 then
        local lbl = checkboxesContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("CENTER", 0, 0)
        lbl:SetText(L["No_List_Found"])
        listCheckboxes = { [1] = lbl }
        checkboxesContainer:SetHeight(50)
        return
    end

    local yOffset = -10

    for i, listObj in ipairs(lists) do
        local listName = nil
        local itemsTable = nil

        if type(listObj) == "string" then
            listName = listObj
            itemsTable = {}
        elseif type(listObj) == "table" then
            listName = listObj.name or listObj.title or (L["List"] .. " #" .. i)
            itemsTable = listObj.items or listObj.itemQueries or {}
        end

        listName = CleanUpItemName(listName)

        local isExpanded = expandedLists[i] == true
        local hasItems = type(itemsTable) == "table" and #itemsTable > 0

        -- Botão Expandir/Recolher
        local btnExpand = CreateFrame("Button", nil, checkboxesContainer, "UIPanelButtonTemplate")
        btnExpand:SetSize(18, 18)
        btnExpand:SetPoint("TOPLEFT", 10, yOffset)
        btnExpand:SetText(hasItems and (isExpanded and "-" or "+") or "")
        if not hasItems then btnExpand:Disable() end

        -- Checkbox da Lista
        local listCb = CreateFrame("CheckButton", nil, checkboxesContainer, "InterfaceOptionsCheckButtonTemplate")
        listCb:SetSize(22, 22)
        listCb:SetPoint("LEFT", btnExpand, "RIGHT", 4, 0)

        local listText = listCb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        listText:SetPoint("LEFT", listCb, "RIGHT", 6, 0)
        listText:SetText(listName .. (hasItems and " (" .. #itemsTable .. " " .. L["Items"] .. ")" or " (" .. L["Empty"] .. ")"))

        local elementData = {
            index = i,
            cb = listCb,
            btnExpand = btnExpand,
            text = listText,
            isList = true,
            items = {}
        }

        btnExpand:SetScript("OnClick", function()
            PlaySound(808)
            expandedLists[i] = not expandedLists[i]
            RefreshShoppingUI()
        end)

        listCb:SetScript("OnClick", function(self)
            PlaySound(808)
            local checked = self:GetChecked()
            elementData.isChecked = checked
            for _, itemData in pairs(elementData.items) do
                if itemData.cb then
                    itemData.cb:SetChecked(checked)
                    itemData.isChecked = checked
                end
            end
        end)

        listElements[i] = elementData
        yOffset = yOffset - 26

        -- Renderiza os itens considerando as posições fixas com ";"
        if isExpanded and hasItems then
            for itemIdx, itemObj in ipairs(itemsTable) do
                local rawItemStr = nil
                if type(itemObj) == "string" then
                    rawItemStr = itemObj
                elseif type(itemObj) == "table" then
                    rawItemStr = itemObj.searchString or itemObj.name or itemObj.queryString or ("Item #" .. itemIdx)
                end

                local formattedItemText = FormatItemDisplayString(rawItemStr)

                local itemCb = CreateFrame("CheckButton", nil, checkboxesContainer, "InterfaceOptionsCheckButtonTemplate")
                itemCb:SetSize(18, 18)
                itemCb:SetPoint("TOPLEFT", 35, yOffset)

                local itemText = itemCb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                itemText:SetPoint("LEFT", itemCb, "RIGHT", 6, 0)
                itemText:SetText("|cffbbbbbb- " .. formattedItemText .. "|r")

                itemCb:SetScript("OnClick", function(self)
                    PlaySound(808)
                    itemCb.isChecked = self:GetChecked()
                end)

                elementData.items[itemIdx] = {
                    listIndex = i,
                    itemIndex = itemIdx,
                    cb = itemCb,
                    text = itemText,
                    isChecked = false
                }

                yOffset = yOffset - 22
            end
        end
    end

    checkboxesContainer:SetHeight(math.abs(yOffset) + 15)
end

-- Inicia ou para o timer de checagem em tempo real apenas quando a janela estiver aberta
local function ToggleRealtimeWatcher(enable)
    if enable then
        if not updateTimer then
            -- Verifica a cada 1 segundo se houve mudança nas listas sem sobrecarregar a CPU
            updateTimer = C_Timer.NewTicker(1.0, function()
                if managementFrame and managementFrame:IsShown() then
                    local currentSig = GetListsSignature()
                    if currentSig ~= lastListSignature then
                        RefreshShoppingUI()
                    end
                end
            end)
        end
    else
        if updateTimer then
            updateTimer:Cancel()
            updateTimer = nil
        end
    end
end

-- Cria ou exibe a janela de gerenciamento acoplada à AH
local function ToggleManagementWindow()
    if managementFrame then
        if managementFrame:IsShown() then
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
            managementFrame:Hide()
            ToggleRealtimeWatcher(false)
        else
            managementFrame:Show()
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
            RefreshShoppingUI()
            ToggleRealtimeWatcher(true)
        end
        return
    end

    managementFrame = CreateFrame("Frame", "AuctionatorShoppingListCleanerManagerFrame", UIParent, "BasicFrameTemplateWithInset")
    managementFrame:SetSize(380, 420)
    
    if AuctionHouseFrame then
        managementFrame:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 5, 0)
    else
        managementFrame:SetPoint("CENTER")
    end

    managementFrame:SetMovable(true)
    managementFrame:EnableMouse(true)
    managementFrame:RegisterForDrag("LeftButton")
    managementFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    managementFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    managementFrame:SetClampedToScreen(true)
    managementFrame:SetScript("OnHide", function () PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE) ToggleRealtimeWatcher(false) end)

    managementFrame.title = managementFrame:CreateFontString(nil, "OVERLAY")
    managementFrame.title:SetFontObject("GameFontHighlight")
    managementFrame.title:SetPoint("CENTER", managementFrame.TitleBg, "CENTER", 0, 0)
    managementFrame.title:SetText(L["Window_Title"])

    local scrollFrame = CreateFrame("ScrollFrame", nil, managementFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -32)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 50)

    checkboxesContainer = CreateFrame("Frame", nil, scrollFrame)
    checkboxesContainer:SetSize(320, 200)
    scrollFrame:SetScrollChild(checkboxesContainer)

    -- Botão: Apagar Selecionadas
    local deleteSelBtn = CreateFrame("Button", nil, managementFrame, "UIPanelButtonTemplate")
    deleteSelBtn:SetSize(175, 24)
    deleteSelBtn:SetPoint("BOTTOMLEFT", 12, 12)
    deleteSelBtn:SetText(L["Button_Remove_Selected"])
    deleteSelBtn:SetScript("OnClick", function()
        PlaySound(808)
        local lists = AUCTIONATOR_SHOPPING_LISTS
        if not lists or type(lists) ~= "table" then return end

        local listsToDelete = {}
        local itemsToDelete = {}

        for listIndex, elemData in pairs(listElements) do
            if elemData.cb and elemData.cb:GetChecked() then
                listsToDelete[listIndex] = true
            else
                for itemIndex, itemData in pairs(elemData.items) do
                    if itemData.cb and itemData.cb:GetChecked() then
                        if not itemsToDelete[listIndex] then itemsToDelete[listIndex] = {} end
                        itemsToDelete[listIndex][itemIndex] = true
                    end
                end
            end
        end

        if next(listsToDelete) == nil and next(itemsToDelete) == nil then
            print("|cffff0000[" .. L['AddonName_Interface'] .. "]:|r " .. L["No_List_Selected"])
            return
        end

        StaticPopupDialogs["ASLC_CONFIRM_SEL"] = {
            text = L["Confirm_Delete_Selected_Lists"],
            button1 = L["Button_Confirm_Yes"],
            button2 = L["Button_Cancel"],
            OnAccept = function()
                for i = #lists, 1, -1 do
                    if listsToDelete[i] then
                        table.remove(lists, i)
                    end
                end

                for listIndex, itemsMap in pairs(itemsToDelete) do
                    if lists[listIndex] then
                        local listObj = lists[listIndex]
                        local itemsTable = nil
                        if type(listObj) == "table" then
                            itemsTable = listObj.items or listObj.itemQueries
                        end

                        if type(itemsTable) == "table" then
                            for itemIndex = #itemsTable, 1, -1 do
                                if itemsMap[itemIndex] then
                                    table.remove(itemsTable, itemIndex)
                                end
                            end
                        end
                    end
                end

                print("|cff00ff00[" .. L['AddonName_Interface'] .. "]:|r " .. L["List_Remove_Success"])
                RefreshShoppingUI()

            pcall(function() Auctionator.Shopping.ListManager:FireMetaChangeEvent("-") end)
            end,
            timeout = 0, whileDead = true, hideOnEscape = true,
        }
        StaticPopup_Show("ASLC_CONFIRM_SEL")
    end)

    -- Botão: Apagar Todas
    local deleteAllBtn = CreateFrame("Button", nil, managementFrame, "UIPanelButtonTemplate")
    deleteAllBtn:SetSize(175, 24)
    deleteAllBtn:SetPoint("LEFT", deleteSelBtn, "RIGHT", 6, 0)
    deleteAllBtn:SetText(L["Button_Remove_All"])
    deleteAllBtn:SetScript("OnClick", function()
        PlaySound(808)
        local lists = AUCTIONATOR_SHOPPING_LISTS
        if not lists or type(lists) ~= "table" or #lists == 0 then return end

        StaticPopupDialogs["ASLC_CONFIRM_ALL"] = {
            text = L["Confirm_Delete_All_Lists"],
            button1 = L["Button_Confirmm_Remove_All"],
            button2 = L["Button_Cancel"],
            OnAccept = function()
                wipe(lists)
                print("|cff00ff00[" .. L['AddonName_Interface'] .. "]:|r " .. L["All_List_Remove_Success"])
                RefreshShoppingUI()
                
                pcall(function() Auctionator.Shopping.ListManager:FireMetaChangeEvent("-") end)
            end,
            timeout = 0, whileDead = true, hideOnEscape = true,
        }
        StaticPopup_Show("ASLC_CONFIRM_ALL")
    end)

    RefreshShoppingUI()
    managementFrame:Show()
    ToggleRealtimeWatcher(true)
end

-- Cria um botão na janela de compras do Auctionator da Casa de Leilões
local function CreateAHFloatingButton()
    if _G["AuctionatorShoppingListCleanerFloatingBtn"] then
        if AuctionHouseFrame and AuctionHouseFrame:IsShown() then
            _G["AuctionatorShoppingListCleanerFloatingBtn"]:Show()
        end
        return
    end

    local floatBtn = CreateFrame("Button", "AuctionatorShoppingListCleanerFloatingBtn", AuctionatorShoppingFrame, "UIPanelButtonTemplate")
    floatBtn:SetSize(200, 24)
    floatBtn:SetPoint("BOTTOMRIGHT", AuctionHouseFrame, "BOTTOMRIGHT", -200, 4)
    floatBtn:SetText(L["Button_Manage_Shopping_Lists"])
    
    floatBtn:SetScript("OnClick", function()
        ToggleManagementWindow()
    end)
    
    floatBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["AddonName_Interface"])
        GameTooltip:AddLine(L["Auction_House_Button_Tooltip"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    floatBtn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    floatBtn:Show()
end

-- Comando de chat para abrir/fechar a janela manualmente
SlashCmdList["AUCTIONATOR_SHOPPING_LIST_CLEANER"] = function()
    ToggleManagementWindow()
end
SLASH_AUCTIONATOR_SHOPPING_LIST_CLEANER1 = "/ASLC"

-- Eventos para controlar a exibição do botão junto com a AH
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "AUCTION_HOUSE_SHOW" then
        C_Timer.After(0.2, function()
            if AuctionHouseFrame and AuctionHouseFrame:IsShown() then
                CreateAHFloatingButton()
            end
        end)
    elseif event == "AUCTION_HOUSE_CLOSED" then
        if _G["AuctionatorShoppingListCleanerFloatingBtn"] then
            _G["AuctionatorShoppingListCleanerFloatingBtn"]:Hide()
        end
        if managementFrame and managementFrame:IsShown() then
            managementFrame:Hide()
            ToggleRealtimeWatcher(false)
        end
    end
end)

-- Notificação de carregamento
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, name)
    if name == "Auctionator" or name == "AuctionatorShoppingListCleaner" then
        print("|cff00ff00[" .. L['AddonName_Interface'] .. "]:|r " .. L['ChatAddonLoadedMessage'])
    end
end)
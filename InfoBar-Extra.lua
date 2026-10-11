local addonName, ns = ...
ns = _G.QFXSystemBarNS or ns
if not ns then return end

-- ========================================================================
-- QFXSystemBar InfoBar - Extra module
-- ------------------------------------------------------------------------
-- 包含两部分：
--   1. 纹章（5 种）：显示、数量、tooltip
--   2. 账号金币统计（所有角色）+ 战团银行 + 完整版金币 tooltip
--
-- 主文件 InfoBar.lua 通过 ns.xxx 调用这里：
--   ns.CREST_DATA_MAP
--   ns.GetCrestQuantity / ns.UpdateCrestNumber / ns.ShowCrestTooltip
--   ns.GetCharacterKey / ns.GetCurrentCharacterGoldGoldOnly
--   ns.UpdateCurrentCharacterGold / ns.GetOtherCharactersGoldTotal
--   ns.GetAllCharactersGoldTotal / ns.ClearAccountGoldData
--   ns.GetOtherCharactersData / ns.ShowGoldTooltip
-- ========================================================================

-- ========================================================================
-- 1. 纹章
-- ========================================================================

ns.CREST_DATA_MAP = {
    crest_adventurer = { id = 3442, icon = 7734054 },
    crest_veteran    = { id = 3443, icon = 7734062 },
    crest_champion   = { id = 3444, icon = 7734056 },
    crest_hero       = { id = 3445, icon = 7734058 },
    crest_mythic     = { id = 3446, icon = 7734060 },
}

local CREST_DATA_MAP = ns.CREST_DATA_MAP

function ns.GetCrestQuantity(id)
    local data = CREST_DATA_MAP[id]
    if not data then return 0 end
    local quantity = 0
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, data.id)
        if ok and info then quantity = info.quantity or 0 end
    end
    return quantity
end

function ns.UpdateCrestNumber(btn, id)
    if not btn.crestNumber then return false end
    if not CREST_DATA_MAP[id] then
        btn.crestNumber:Hide()
        return false
    end
    local quantity = ns.GetCrestQuantity(id)
    btn.crestNumber:SetText(tostring(quantity))

    local fontPath, fontFlag
    if ns.GetInfoBarTextFont then
        fontPath, fontFlag = ns.GetInfoBarTextFont()
    end
    if not fontPath then
        fontPath = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
        fontFlag = "OUTLINE"
    end
    local fontSize = (ns.GetInfoBarFontSize and ns.GetInfoBarFontSize()) or 12

    if btn.qfxCrestFontPath ~= fontPath or btn.qfxCrestFontSize ~= fontSize or btn.qfxCrestFontFlag ~= fontFlag then
        btn.crestNumber:SetFont(fontPath, fontSize, fontFlag or "")
        btn.qfxCrestFontPath = fontPath
        btn.qfxCrestFontSize = fontSize
        btn.qfxCrestFontFlag = fontFlag
    end
    btn.crestNumber:SetTextColor(1, 1, 1, 1)
    btn.crestNumber:Show()
    return true
end

function ns.ShowCrestTooltip(owner, crestId, nameKey)
    if not owner then return end

    local totalEarned = 0
    local maxQuantity = 0
    local weeklyMax = 0
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info = C_CurrencyInfo.GetCurrencyInfo(crestId)
        totalEarned = info and info.totalEarned or 0
        maxQuantity = info and info.maxQuantity or 0
        weeklyMax = info and info.maxWeeklyQuantity or 0
    end

    local y
    if owner and owner.GetCenter then
        local _, centerY = owner:GetCenter()
        y = centerY
    end
    local screenHeight = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or GetScreenHeight() or 768
    local anchor = (y and y > screenHeight / 2) and "TOP" or "BOTTOM"
    local offset = anchor == "TOP" and -75 or 75
    GameTooltip:SetOwner(owner, "ANCHOR_" .. anchor, 0, offset)

    local function LT(key)
        if ns.T then return ns.T(key) end
        if ns.UIText then return ns.UIText(key) end
        return key
    end

    GameTooltip:ClearLines()
    GameTooltip:AddLine(LT(nameKey), 0, 0.6, 1)

    if weeklyMax > 0 then
        GameTooltip:AddLine(string.format("%d / %d (周上限)", totalEarned, weeklyMax), 1, 1, 1)
    elseif maxQuantity > 0 then
        GameTooltip:AddLine(string.format("%d / %d", totalEarned, maxQuantity), 1, 1, 1)
    else
        GameTooltip:AddLine(string.format("%d", totalEarned), 1, 1, 1)
    end

    GameTooltip:Show()
end

-- ========================================================================
-- 2. 账号金币统计
-- ========================================================================

local function DB()
    QFXSystemBarDB = QFXSystemBarDB or {}
    return QFXSystemBarDB
end

function ns.GetCharacterKey()
    local realm = GetRealmName() or "Unknown"
    local name = UnitName("player") or "Unknown"
    return realm .. "-" .. name
end

function ns.GetCurrentCharacterGoldGoldOnly()
    local money = GetMoney() or 0
    return math.floor(money / 10000)
end

function ns.UpdateCurrentCharacterGold()
    if not QFXSystemBarDB then return end
    QFXSystemBarDB.accountGold = QFXSystemBarDB.accountGold or {}

    local key = ns.GetCharacterKey()
    local gold = ns.GetCurrentCharacterGoldGoldOnly()

    QFXSystemBarDB.accountGold[key] = {
        gold = gold,
        lastUpdate = date("%Y-%m-%d %H:%M:%S"),
    }
end

function ns.GetOtherCharactersGoldTotal()
    if not QFXSystemBarDB or not QFXSystemBarDB.accountGold then return 0 end

    local currentKey = ns.GetCharacterKey()
    local total = 0

    for key, data in pairs(QFXSystemBarDB.accountGold) do
        if key ~= currentKey then
            total = total + (data.gold or 0)
        end
    end

    return total
end

function ns.GetAllCharactersGoldTotal()
    if not QFXSystemBarDB or not QFXSystemBarDB.accountGold then return 0 end

    local total = 0
    for _, data in pairs(QFXSystemBarDB.accountGold) do
        total = total + (data.gold or 0)
    end

    return total
end

function ns.ClearAccountGoldData()
    if not QFXSystemBarDB then return end
    QFXSystemBarDB.accountGold = {}
end

function ns.GetOtherCharactersData()
    if not QFXSystemBarDB or not QFXSystemBarDB.accountGold then return {} end

    local currentKey = ns.GetCharacterKey()
    local result = {}

    for key, data in pairs(QFXSystemBarDB.accountGold) do
        if key ~= currentKey then
            local realm, name = key:match("^(.-)-(.+)$")
            if not realm then
                realm = "Unknown"
                name = key
            end
            result[#result + 1] = {
                key = key,
                realm = realm,
                name = name,
                gold = data.gold or 0,
            }
        end
    end

    table.sort(result, function(a, b)
        return a.gold > b.gold
    end)

    return result
end

-- 工具函数（本文件内部使用，避免依赖主文件的 local）
local function FormatMoney(money, full)
    money = tonumber(money or 0) or 0
    local gold = math.floor(money / 10000)
    local silver = math.floor((money % 10000) / 100)
    local copper = money % 100
    local goldSymbol = _G.GOLD_AMOUNT_SYMBOL or "g"
    local silverSymbol = _G.SILVER_AMOUNT_SYMBOL or "s"
    local copperSymbol = _G.COPPER_AMOUNT_SYMBOL or "c"

    if money >= 1000000 and not full then
        local amount = BreakUpLargeNumbers and BreakUpLargeNumbers(tostring(math.floor(money / 10000))) or tostring(math.floor(money / 10000))
        return amount .. "|cffffd700" .. goldSymbol .. "|r"
    end

    if money <= 0 then return "0|cffc77050" .. copperSymbol .. "|r" end
    local text = ""
    if gold > 0 then text = text .. gold .. "|cffffd700" .. goldSymbol .. "|r" end
    if silver > 0 then text = text .. (text ~= "" and " " or "") .. silver .. "|cffd0d0d0" .. silverSymbol .. "|r" end
    if copper > 0 then text = text .. (text ~= "" and " " or "") .. copper .. "|cffc77050" .. copperSymbol .. "|r" end
    return text
end

local function FormatSignedMoney(value)
    value = tonumber(value) or 0
    if value > 0 then return "|cff55ff55+|r" .. FormatMoney(value, true) end
    if value < 0 then return "|cffff5555-|r" .. FormatMoney(-value, true) end
    return FormatMoney(0, true)
end

local function LineString()
    return "------------------------------"
end

local function LeftButtonText()
    return "|TInterface\\TUTORIALFRAME\\UI-TUTORIAL-FRAME:11:11:0:0:512:512:12:66:230:307|t "
end

local function RightButtonText()
    return "|TInterface\\TUTORIALFRAME\\UI-TUTORIAL-FRAME:11:11:0:0:512:512:12:66:330:407|t "
end

local function LT(key)
    if ns.T then return ns.T(key) end
    if ns.UIText then return ns.UIText(key) end
    return key
end

function ns.ShowGoldTooltip(owner)
    if not owner then return end
    local currentGold = ns.GetCurrentCharacterGoldGoldOnly()
    local currentName = UnitName("player") or "Unknown"
    local otherChars = ns.GetOtherCharactersData()
    local allGoldTotal = ns.GetAllCharactersGoldTotal()
    local data = ns.UpdateInfoBarMoneySession and ns.UpdateInfoBarMoneySession() or nil
    local earned = data and tonumber(data.earned) or 0
    local spent = data and tonumber(data.spent) or 0
    local net = earned - spent

    local warbandGold = 0
    if C_Bank and C_Bank.FetchDepositedMoney and Enum and Enum.BankType and Enum.BankType.Account then
        local ok, money = pcall(C_Bank.FetchDepositedMoney, Enum.BankType.Account)
        if ok and money then warbandGold = math.floor(money / 10000) end
    end

    local function FormatGold(gold)
        gold = gold or 0
        local amount = tostring(gold)
        if BreakUpLargeNumbers then amount = BreakUpLargeNumbers(amount) end
        return amount .. " |cffffd700" .. (_G.GOLD_AMOUNT_SYMBOL or "g") .. "|r"
    end

    local function FormatGoldColored(gold)
        if (gold or 0) > 0 then return FormatGold(gold) end
        return " |cff8888880" .. "|cffffd700" .. (_G.GOLD_AMOUNT_SYMBOL or "g") .. "|r"
    end

    local y
    if owner and owner.GetCenter then
        local _, centerY = owner:GetCenter()
        y = centerY
    end
    local screenHeight = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or GetScreenHeight() or 768
    local anchor = (y and y > screenHeight / 2) and "TOP" or "BOTTOM"
    local offset = anchor == "TOP" and -75 or 75
    GameTooltip:SetOwner(owner, "ANCHOR_" .. anchor, 0, offset)

    GameTooltip:ClearLines()
    GameTooltip:AddLine(MONEY or LT("Money"), 0, 0.6, 1)
    GameTooltip:AddLine(" ")

    GameTooltip:AddDoubleLine(currentName, FormatGoldColored(currentGold), 0.85, 0.85, 0.85, 1, 1, 1)

    if #otherChars > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(LT("Other Characters:"), 0.6, 0.6, 0.6)
        for _, char in ipairs(otherChars) do
            local displayName = char.realm .. "-" .. char.name
            GameTooltip:AddDoubleLine(displayName, FormatGoldColored(char.gold), 0.85, 0.85, 0.85, 1, 1, 1)
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(LineString())

    GameTooltip:AddDoubleLine(LT("Total Character Gold"), FormatGoldColored(allGoldTotal), 0.3, 0.8, 1, 1, 1, 1)

    if warbandGold > 0 then
        GameTooltip:AddDoubleLine(LT("Warband Bank"), FormatGoldColored(warbandGold), 0.3, 0.8, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine(LT("Total (Including Bank)"), FormatGoldColored(allGoldTotal + warbandGold), 0.3, 1, 0.3, 1, 1, 1)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(LineString())
    GameTooltip:AddDoubleLine(LT("Session Earned"), FormatSignedMoney(earned), 0.35, 1, 0.35, 1, 1, 1)
    GameTooltip:AddDoubleLine(LT("Session Spent"), spent > 0 and ("|cffff5555-|r" .. FormatMoney(spent, true)) or FormatMoney(0, true), 1, 0.35, 0.35, 1, 1, 1)
    GameTooltip:AddDoubleLine(LT("Session Net"), FormatSignedMoney(net), 0.6, 0.8, 1, 1, 1, 1)

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(LineString())
    GameTooltip:AddDoubleLine(" ", LeftButtonText() .. (CURRENCY or LT("Currency")) .. "  " .. RightButtonText() .. (BAGSLOTTEXT or BAGS or LT("Bags")), 1, 1, 1, 0.6, 0.8, 1)
    GameTooltip:AddDoubleLine(" ", "|cffaaaaaaCtrl+左键 清除所有记录|r", 1, 1, 1, 0.6, 0.6, 0.6)

    GameTooltip:Show()
end
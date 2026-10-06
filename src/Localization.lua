-- Strings for all ESO client languages. Difficulty names come localized from the game (SI_ANTIQUITYDIFFICULTY).
-- Unknown languages fall back to English.

AntiquityLeadFilter = AntiquityLeadFilter or {}

local STRINGS = {
    en = {
        NO_SELECTION = "No Difficulty",
        ALL_SELECTED = "All Difficulties",
        NUM_SELECTED = "<<1>> Difficulties",
    },
    de = {
        NO_SELECTION = "Keine Stufe",
        ALL_SELECTED = "Alle Stufen",
        NUM_SELECTED = "<<1>> Stufen",
    },
    fr = {
        NO_SELECTION = "Aucune difficulté",
        ALL_SELECTED = "Toutes les difficultés",
        NUM_SELECTED = "<<1>> difficultés",
    },
    es = {
        NO_SELECTION = "Ninguna dificultad",
        ALL_SELECTED = "Todas las dificultades",
        NUM_SELECTED = "<<1>> dificultades",
    },
    ru = {
        NO_SELECTION = "Нет сложности",
        ALL_SELECTED = "Любая сложность",
        NUM_SELECTED = "Сложностей: <<1>>",
    },
    jp = {
        NO_SELECTION = "難易度なし",
        ALL_SELECTED = "すべての難易度",
        NUM_SELECTED = "<<1>>種類の難易度",
    },
    zh = {
        NO_SELECTION = "无难度",
        ALL_SELECTED = "所有难度",
        NUM_SELECTED = "<<1>>种难度",
    },
}

local language = GetCVar("language.2")
AntiquityLeadFilter.L = setmetatable(STRINGS[language] or {}, { __index = STRINGS.en })

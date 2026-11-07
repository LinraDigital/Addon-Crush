-- LD - Crush : noyau (données, utilitaires, événements, commandes)
local ADDON, ns = ...
local L = ns.L

ns.PREFIX  = "LDCrush"
ns.CHANNEL = "LDCrushNet"
ns.PROTO   = "1"
ns.VERSION = "0.1.0"
ns.AUTEUR  = "Linra Digital"
ns.SITE    = "wow.linradigital.fr"
ns.MEDIA   = "Interface\\AddOns\\LD_Crush\\media\\"

ns.LANGS = {
    { key = "fr", label = "Français" },
    { key = "en", label = "English" },
    { key = "de", label = "Deutsch" },
    { key = "es", label = "Español" },
    { key = "it", label = "Italiano" },
    { key = "pt", label = "Português" },
}
ns.TAGS = {
    { key = "quetes",  label = L["Quêtes"] },
    { key = "metiers", label = L["Métiers"] },
    { key = "donjons", label = L["Donjons"] },
    { key = "pvp",     label = L["PvP"] },
    { key = "rp",      label = L["RP"] },
    { key = "explo",   label = L["Exploration"] },
}
ns.DISPO = {
    { key = "jour",    label = L["Journée"] },
    { key = "soir",    label = L["Soirée"] },
    { key = "weekend", label = L["Week-end"] },
}

-- Données d'exécution (non sauvegardées)
ns.enLigne = {}               -- [nom] = { t = GetTime() }
ns.pingEnvoye = {}            -- [nom] = true
ns.croisementsEnAttente = {}  -- [nom] = { t, zone }
ns.profilDemande = {}         -- [nom] = GetTime()

---------------------------------------------------------------------------
-- Valeurs par défaut
---------------------------------------------------------------------------
local DEFAUTS_COMPTE = {
    profil = { fait = false, mineur = false, cherche = {}, langs = {} },
}

local DEFAUTS_PERSO = {
    surnom = "",
    bio = "",
    tags = {},
    dispo = {},
    filtres = { ageMin = 18, ageMax = 99, langs = {}, niveau = 0, croisMin = 1 },
    options = { masquerChuchotements = true },
    minimap = { angle = 215 },
    croises = {},     -- [nom] = { n, dernier, zone }
    profils = {},     -- [nom] = { sexe, cherche, age, langs, surnom, classe, race, niveau, tags, dispo, bio, maj }
    likes = {},       -- [nom] = time
    likedBy = {},     -- [nom] = time
    passes = {},      -- [nom] = time
    matchs = {},      -- [nom] = { t }
    bloques = {},     -- [nom] = time
    aEnvoyer = {},    -- [nom] = "L" | "M"  (messages en attente, destinataire hors ligne)
    nouveauxMatchs = 0,
}

local function CopierDefauts(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopierDefauts(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local LOCALE_VERS_LANGUE = {
    frFR = "fr", deDE = "de", esES = "es", esMX = "es",
    itIT = "it", ptBR = "pt", ptPT = "pt", enUS = "en", enGB = "en",
}

---------------------------------------------------------------------------
-- Utilitaires
---------------------------------------------------------------------------
function ns.Split(s, sep)
    local t, debut = {}, 1
    while true do
        local i = string.find(s, sep, debut, true)
        if not i then
            t[#t + 1] = string.sub(s, debut)
            break
        end
        t[#t + 1] = string.sub(s, debut, i - 1)
        debut = i + #sep
    end
    return t
end

function ns.EnsembleVersTexte(ens)
    local t = {}
    for k, v in pairs(ens or {}) do
        if v then t[#t + 1] = k end
    end
    table.sort(t)
    return table.concat(t, ",")
end

function ns.TexteVersEnsemble(txt)
    local ens = {}
    for k in string.gmatch(txt or "", "[^,]+") do ens[k] = true end
    return ens
end

function ns.EnsembleVide(ens)
    return next(ens or {}) == nil
end

-- Nettoie un texte saisi : retire séparateurs du protocole, codes couleur, retours à la ligne
function ns.Nettoyer(txt)
    txt = tostring(txt or "")
    txt = txt:gsub("[%^|]", ""):gsub("[\r\n\t]", " "):gsub("%s+", " ")
    return (txt:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Coupe une chaîne UTF-8 à n octets sans casser un caractère
function ns.CouperOctets(s, n)
    if #s <= n then return s end
    s = string.sub(s, 1, n)
    local i = #s
    while i > 0 do
        local b = string.byte(s, i)
        if b < 0x80 then break end
        if b >= 0xC0 then
            local longueur = (b >= 0xF0 and 4) or (b >= 0xE0 and 3) or 2
            if #s - i + 1 < longueur then s = string.sub(s, 1, i - 1) end
            break
        end
        i = i - 1
    end
    return s
end

local MOTIFS_INTERDITS = {
    "https?://", "www%.", "%.com", "%.fr", "%.gg", "%.net", "%.org", "%.io", "%.me",
    "discord", "snap", "insta", "telegram", "whatsapp", "tiktok", "twitch", "skype", "@",
}

function ns.ContientLien(txt)
    local t = string.lower(txt or "")
    for _, motif in ipairs(MOTIFS_INTERDITS) do
        if string.find(t, motif) then return true end
    end
    return false
end

function ns.IlYA(t)
    if not t then return "" end
    local d = time() - t
    if d < 60 then return L["à l'instant"] end
    if d < 3600 then return (L["il y a %d min"]):format(math.floor(d / 60)) end
    if d < 86400 then return (L["il y a %d h"]):format(math.floor(d / 3600)) end
    return (L["il y a %d j"]):format(math.floor(d / 86400))
end

function ns.AgeActuel()
    local p = ns.compte.profil
    if not p.age then return nil end
    local ecoule = time() - (p.ageDeclareLe or time())
    return p.age + math.floor(ecoule / 31557600)
end

function ns.EstActif()
    local p = ns.compte and ns.compte.profil
    return p and p.fait and not p.mineur
end

function ns.NomClasse(classe, sexe)
    if not classe then return "?" end
    local t = (sexe == "F" and LOCALIZED_CLASS_NAMES_FEMALE) or LOCALIZED_CLASS_NAMES_MALE
    return (t and t[classe]) or classe
end

function ns.NomRace(raceId)
    if raceId and C_CreatureInfo and C_CreatureInfo.GetRaceInfo then
        local info = C_CreatureInfo.GetRaceInfo(raceId)
        if info then return info.raceName end
    end
    return ""
end

function ns.CouleurClasse(classe)
    local c = classe and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classe]
    if c then return c.r, c.g, c.b end
    return 0.93, 0.92, 0.89
end

function ns.LibellesLangues(ens)
    local t = {}
    for _, l in ipairs(ns.LANGS) do
        if ens and ens[l.key] then t[#t + 1] = string.upper(l.key) end
    end
    return table.concat(t, " · ")
end

function ns.LibellesTags(ens, liste)
    local t = {}
    for _, l in ipairs(liste) do
        if ens and ens[l.key] then t[#t + 1] = l.label end
    end
    return table.concat(t, " · ")
end

function ns.Message(txt)
    DEFAULT_CHAT_FRAME:AddMessage("|cffe8b44aLD - Crush|r : " .. txt)
end

-- Rafraîchissement de l'interface (remplacé par UI_Main)
function ns.RafraichirUI() end

---------------------------------------------------------------------------
-- Événements
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")

ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        LDCrushAccount = LDCrushAccount or {}
        LDCrushDB = LDCrushDB or {}
        CopierDefauts(LDCrushAccount, DEFAUTS_COMPTE)
        CopierDefauts(LDCrushDB, DEFAUTS_PERSO)
        ns.compte = LDCrushAccount
        ns.char = LDCrushDB

        -- Langue par défaut : celle du client
        if ns.EnsembleVide(ns.compte.profil.langs) then
            local l = LOCALE_VERS_LANGUE[GetLocale()] or "en"
            ns.compte.profil.langs[l] = true
        end
    elseif event == "PLAYER_LOGIN" then
        ns.Me = UnitName("player")
        ns.MaFaction = UnitFactionGroup("player")
        if ns.InitUI then ns.InitUI() end
        if ns.InitMinimap then ns.InitMinimap() end
        if ns.InitFiltreChuchotements then ns.InitFiltreChuchotements() end
        if ns.EstActif() then
            C_Timer.After(6, ns.Demarrer)
        end
    end
end)

-- Lance le réseau et la détection (appelé au login ou après l'accueil)
function ns.Demarrer()
    if ns.demarre or not ns.EstActif() then return end
    ns.demarre = true
    ns.InitComm()
    ns.InitDetection()
end

---------------------------------------------------------------------------
-- Commandes
---------------------------------------------------------------------------
SLASH_LDCRUSH1 = "/crush"
SLASH_LDCRUSH2 = "/ldcrush"
SlashCmdList.LDCRUSH = function(msg)
    msg = string.lower(msg or "")
    if msg == "profil" then
        ns.Ouvrir("profil")
    elseif msg == "filtres" then
        ns.Ouvrir("filtres")
    elseif msg == "test" then
        ns.CreerFaux()
    elseif msg == "test clear" or msg == "test off" then
        ns.SupprimerFaux()
    elseif msg == "stats" then
        local n = 0
        for _ in pairs(ns.enLigne) do n = n + 1 end
        ns.Message((L["%d utilisateur(s) en ligne, canal %s"]):format(n, tostring(ns.channelId or L["non rejoint"])))
    else
        ns.Basculer()
    end
end

-- LD - Crush : détection des joueurs croisés
-- Sources : barres de nom, survol, cible, groupe et journal de combat.
-- Seuls les joueurs ayant l'addon sont retenus (présents sur le canal ou ayant répondu au « ? »).
local _, ns = ...

local band = bit.band
local vuRecemment = {}

local function Traiter(nom)
    if not nom or nom == "" or nom == ns.Me or not ns.EstActif() then return end
    if ns.char.bloques[nom] then return end
    local maintenant = GetTime()
    local vu = vuRecemment[nom]
    if vu and maintenant - vu < 60 then return end
    vuRecemment[nom] = maintenant

    local zone = GetRealZoneText() or ""
    if ns.enLigne[nom] then
        ns.EnregistrerCroisement(nom, zone)
    elseif not ns.pingEnvoye[nom] then
        -- Inconnu : on demande discrètement s'il a l'addon. Sans addon, rien ne se passe.
        ns.pingEnvoye[nom] = true
        ns.croisementsEnAttente[nom] = { t = maintenant, zone = zone }
        ns.Envoyer("?", "WHISPER", nom, true)
    end
end

local function DepuisUnite(unite)
    if not unite or not UnitExists(unite) or not UnitIsPlayer(unite) then return end
    if UnitIsUnit(unite, "player") then return end
    if UnitFactionGroup(unite) ~= ns.MaFaction then return end
    local nom, royaume = UnitName(unite)
    if not nom or nom == UNKNOWNOBJECT then return end
    if royaume and royaume ~= "" then nom = nom .. "-" .. royaume end
    Traiter(nom)
end

local function DepuisGroupe()
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do DepuisUnite("raid" .. i) end
    else
        for i = 1, 4 do DepuisUnite("party" .. i) end
    end
end

-- Nettoyage périodique pour ne pas accumuler de mémoire
local function Purger()
    local limite = GetTime() - 600
    for nom, t in pairs(vuRecemment) do
        if t < limite then vuRecemment[nom] = nil end
    end
    for nom, a in pairs(ns.croisementsEnAttente) do
        if a.t < limite then ns.croisementsEnAttente[nom] = nil end
    end
end

function ns.InitDetection()
    local f = CreateFrame("Frame")
    f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    f:RegisterEvent("PLAYER_TARGET_CHANGED")
    f:RegisterEvent("GROUP_ROSTER_UPDATE")
    -- Le journal de combat n'est plus enregistré : WoW Forever l'interdit aux addons
    -- (même sous pcall, Blizzard affiche l'avertissement « action bloquée »).
    f:SetScript("OnEvent", function(_, event, arg1)
        if event == "NAME_PLATE_UNIT_ADDED" then
            DepuisUnite(arg1)
        elseif event == "UPDATE_MOUSEOVER_UNIT" then
            DepuisUnite("mouseover")
        elseif event == "PLAYER_TARGET_CHANGED" then
            DepuisUnite("target")
        elseif event == "GROUP_ROSTER_UPDATE" then
            DepuisGroupe()
        end
    end)
    C_Timer.NewTicker(300, Purger)
end

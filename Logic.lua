-- LD - Crush : logique (croisements, compatibilité, likes, matchs, blocage)
local _, ns = ...

local DELAI_NOUVEAU_CROISEMENT = 600 -- 10 min entre deux croisements comptés

function ns.EnregistrerCroisement(nom, zone)
    local c = ns.char.croises[nom]
    local t = time()
    if not c then
        c = { n = 0 }
        ns.char.croises[nom] = c
    end
    if not c.dernier or t - c.dernier > DELAI_NOUVEAU_CROISEMENT then
        c.n = c.n + 1
    end
    c.dernier, c.zone = t, zone

    local p = ns.char.profils[nom]
    if not p or not p.surnom or t - (p.maj or 0) > 86400 then
        ns.DemanderProfil(nom)
    end
    ns.RafraichirUI()
end

---------------------------------------------------------------------------
-- Compatibilité
---------------------------------------------------------------------------

-- Compatibilité mutuelle : chacun correspond à ce que l'autre cherche
function ns.EstCompatibleMutuel(nom)
    local p = ns.char.profils[nom]
    local moi = ns.compte.profil
    if not p or not p.sexe or not p.cherche or not p.age or p.age < 18 then return false end
    return moi.cherche[p.sexe] and p.cherche[moi.sexe] and true or false
end

-- Compatibilité + mes filtres
function ns.PasseFiltres(nom)
    if not ns.EstCompatibleMutuel(nom) then return false end
    local p, c, f = ns.char.profils[nom], ns.char.croises[nom], ns.char.filtres
    if p.age < f.ageMin or p.age > f.ageMax then return false end

    local langs = ns.EnsembleVide(f.langs) and ns.compte.profil.langs or f.langs
    local commun = false
    for k in pairs(p.langs or {}) do
        if langs[k] then commun = true break end
    end
    if not commun then return false end

    if f.niveau > 0 and p.niveau and math.abs(p.niveau - UnitLevel("player")) > f.niveau then
        return false
    end
    if not c or c.n < f.croisMin then return false end
    return true
end

function ns.Statut(nom)
    local ch = ns.char
    if ch.matchs[nom] then return "match" end
    if ch.likes[nom] then return "like" end
    if ch.passes[nom] then return "passe" end
    return "nouveau"
end

-- Joueurs croisés visibles (compatibles, filtrés, profil reçu), du plus récent au plus ancien
function ns.ListeCroises()
    local liste = {}
    for nom, c in pairs(ns.char.croises) do
        local p = ns.char.profils[nom]
        if p and p.surnom and not ns.char.bloques[nom] and ns.PasseFiltres(nom) then
            liste[#liste + 1] = nom
        end
    end
    table.sort(liste, function(a, b)
        return (ns.char.croises[a].dernier or 0) > (ns.char.croises[b].dernier or 0)
    end)
    return liste
end

-- File « Découvrir » : croisés pas encore likés ni passés
function ns.ListeADecouvrir()
    local liste = {}
    for _, nom in ipairs(ns.ListeCroises()) do
        if ns.Statut(nom) == "nouveau" then liste[#liste + 1] = nom end
    end
    return liste
end

function ns.ListeMatchs()
    local liste = {}
    for nom in pairs(ns.char.matchs) do
        if not ns.char.bloques[nom] then liste[#liste + 1] = nom end
    end
    table.sort(liste, function(a, b) return ns.char.matchs[a].t > ns.char.matchs[b].t end)
    return liste
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------
local function CreerMatch(nom)
    if ns.char.matchs[nom] then return end
    ns.char.matchs[nom] = { t = time() }
    ns.char.nouveauxMatchs = (ns.char.nouveauxMatchs or 0) + 1
    PlaySound(SOUNDKIT and SOUNDKIT.READY_CHECK or 8960)
    if ns.AfficherPopupMatch then ns.AfficherPopupMatch(nom) end
    if ns.MajMinimap then ns.MajMinimap() end
end

function ns.Liker(nom)
    ns.char.likes[nom] = time()
    ns.char.passes[nom] = nil
    if ns.char.likedBy[nom] and ns.EstCompatibleMutuel(nom) then
        CreerMatch(nom)
        ns.EnvoyerOuAttendre(nom, "M")
    else
        ns.EnvoyerOuAttendre(nom, "L")
    end
    ns.RafraichirUI()
end

function ns.Passer(nom)
    ns.char.passes[nom] = time()
    ns.RafraichirUI()
end

function ns.RecevoirLike(nom)
    if not ns.EstCompatibleMutuel(nom) then return end
    ns.char.likedBy[nom] = time()
    if ns.char.likes[nom] and not ns.char.matchs[nom] then
        CreerMatch(nom)
        ns.Envoyer("M", "WHISPER", nom)
    end
end

function ns.RecevoirMatch(nom)
    -- On ne valide que si on avait bien liké cette personne
    if ns.char.likes[nom] and not ns.char.matchs[nom] then
        ns.char.likedBy[nom] = time()
        CreerMatch(nom)
    end
end

function ns.Bloquer(nom)
    local ch = ns.char
    ch.bloques[nom] = time()
    ch.matchs[nom], ch.likes[nom], ch.likedBy[nom], ch.aEnvoyer[nom] = nil, nil, nil, nil
    if ns.EstFaux(nom) then
        -- faux joueur du mode test : rien à ajouter à la liste d'ignorés du jeu
    elseif C_FriendList and C_FriendList.AddIgnore then
        C_FriendList.AddIgnore(nom)
    elseif AddIgnore then
        AddIgnore(nom)
    end
    ns.RafraichirUI()
end

---------------------------------------------------------------------------
-- Chuchotements : masque ceux des joueurs passés ou bloqués
---------------------------------------------------------------------------
function ns.InitFiltreChuchotements()
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", function(_, _, _, auteur)
        if not ns.EstActif() or not ns.char.options.masquerChuchotements then return end
        local nom = Ambiguate(auteur or "", "none")
        if ns.char.bloques[nom] or ns.char.passes[nom] then return true end
    end)
end

---------------------------------------------------------------------------
-- Mode test : faux joueurs (noms préfixés « LDTest »), créés par /crush test
-- et supprimés par /crush test clear. Aucun message réseau n'est envoyé vers eux.
---------------------------------------------------------------------------
local PREFIXE_FAUX = "LDTest"

function ns.EstFaux(nom)
    return nom ~= nil and string.sub(nom, 1, #PREFIXE_FAUX) == PREFIXE_FAUX
end

local FAUX_JOUEURS = {
    { "Amelie",  "Lunaria",  "MAGE",    4, "Je collectionne les montures et les couchers de soleil.", { quetes = true, explo = true }, { soir = true } },
    { "Camille", "Brindille", "DRUID",  6, "Soigneuse le jour, taverne le soir.", { donjons = true, rp = true }, { soir = true, weekend = true } },
    { "Lucas",   "Gromm",     "WARRIOR", 3, "", { pvp = true, donjons = true }, { jour = true } },
    { "Sophie",  "Etoile",    "PRIEST",  1, "Cherche quelqu'un pour explorer Azeroth sans se presser.", { explo = true, metiers = true }, { weekend = true } },
    { "Hugo",    "Vagabond",  "ROGUE",   8, "Pas de bio, juste de l'or à dépenser.", { metiers = true, pvp = true }, { soir = true } },
    { "Julie",   "Sylve",     "HUNTER",  4, "Mon chat me suit partout. Même en donjon.", { quetes = true, rp = true }, { jour = true, soir = true } },
}

function ns.CreerFaux()
    if not ns.EstActif() then
        ns.Message("Crée d'abord ton profil.")
        return
    end
    ns.SupprimerFaux(true)
    local moi, ch = ns.compte.profil, ns.char
    local cherches = {}
    for k, v in pairs(moi.cherche) do if v then cherches[#cherches + 1] = k end end
    table.sort(cherches)
    if #cherches == 0 then return end
    local maintenant = time()

    for i, d in ipairs(FAUX_JOUEURS) do
        local nom = PREFIXE_FAUX .. d[1]
        ch.profils[nom] = {
            sexe = cherches[(i - 1) % #cherches + 1],
            cherche = { [moi.sexe] = true },
            age = 20 + i * 3,
            langs = { [next(moi.langs)] = true },
            version = "0", surnom = d[2], classe = d[3], race = d[4],
            niveau = math.max(1, UnitLevel("player") + i - 3),
            tags = d[6], dispo = d[7], bio = d[5], maj = maintenant,
        }
        ch.croises[nom] = {
            n = (i % 3) + 1,
            dernier = maintenant - i * 900,
            zone = GetRealZoneText() or "",
        }
        ns.enLigne[nom] = { t = GetTime() }
        -- Les deux premiers t'ont déjà liké : les liker donne un match immédiat
        if i <= 2 then ch.likedBy[nom] = maintenant end
    end
    ns.RafraichirUI()
    ns.Message(#FAUX_JOUEURS .. " faux joueurs ajoutés (les 2 premiers t'ont déjà liké). /crush test clear pour les supprimer.")
end

function ns.SupprimerFaux(silencieux)
    local n = 0
    for _, nomTable in ipairs({ "profils", "croises", "likes", "likedBy", "passes", "bloques", "matchs", "aEnvoyer" }) do
        local t = ns.char[nomTable]
        for nom in pairs(t) do
            if ns.EstFaux(nom) then
                t[nom] = nil
                if nomTable == "profils" then n = n + 1 end
            end
        end
    end
    for nom in pairs(ns.enLigne) do
        if ns.EstFaux(nom) then ns.enLigne[nom] = nil end
    end
    ns.char.nouveauxMatchs = 0
    ns.RafraichirUI()
    if not silencieux then ns.Message(n .. " faux joueur(s) supprimé(s).") end
end

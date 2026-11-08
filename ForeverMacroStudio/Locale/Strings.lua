local _, studio = ...

studio.strings = {
    enUS = {
        header = "Client diagnostics",
        profile = "WoW %s (%s) · Interface %s · %s",
        checkedProfile = "E00 profile verified",
        unknownProfile = "E00 profile pending verification",
        macroRead = "Macro reading tested in E00",
        macroReadPending = "Macro reading pending verification",
        manual = "Macro transfer: paste the text into /macro",
        inCombat = "In combat",
        outOfCombat = "Out of combat",
        combatUnknown = "Combat state unavailable",
        language = "Language: %s",
        auto = "Automatic",
        storedDrafts = "Drafts in library: %d",
        storageFuture = "The library uses a newer format and is read-only.",
        storageInvalid = "The saved library could not be validated and is read-only.",
        storageUnavailable = "Language changes apply to this session.",
        rescueHint = "Use /fms rescue to copy readable drafts.",
        rescueEmpty = "There are no drafts available for recovery.",
        rescueTitle = "Forever Macro Studio · Draft recovery",
        help = "Commands: /fms, /fms debug, /fms debug compiler, /fms probe, /fms rescue",
        compilerPreview = "Compiler example (%d/%d characters, %d bytes)",
        compilerPreviewFailed = "The compiler example failed validation.",
        probeUnavailable = "Enable the Forever Macro Studio E00 Probe to use this command.",
    },
    csCZ = {
        header = "Diagnostika klienta",
        profile = "WoW %s (%s) · rozhraní %s · %s",
        checkedProfile = "Profil E00 ověřen",
        unknownProfile = "Profil čeká na ověření v E00",
        macroRead = "Čtení maker ověřeno v E00",
        macroReadPending = "Čtení maker čeká na ověření",
        manual = "Přenos makra: vlož text do /macro",
        inCombat = "V boji",
        outOfCombat = "Mimo boj",
        combatUnknown = "Stav boje není dostupný",
        language = "Jazyk: %s",
        auto = "Automaticky",
        storedDrafts = "Návrhy v knihovně: %d",
        storageFuture = "Knihovna má novější formát a je jen pro čtení.",
        storageInvalid = "Uloženou knihovnu se nepodařilo ověřit. Je jen pro čtení.",
        storageUnavailable = "Změny jazyka platí pro tuto relaci.",
        rescueHint = "Příkaz /fms rescue otevře čitelné návrhy ke zkopírování.",
        rescueEmpty = "K obnově nejsou dostupné žádné návrhy.",
        rescueTitle = "Forever Macro Studio · Záchrana návrhů",
        help = "Příkazy: /fms, /fms debug, /fms debug compiler, /fms probe, /fms rescue",
        compilerPreview = "Ukázka kompilátoru (%d/%d znaků, %d bajtů)",
        compilerPreviewFailed = "Ukázka kompilátoru neprošla kontrolou.",
        probeUnavailable = "Pro tento příkaz zapni diagnostický addon Forever Macro Studio E00 Probe.",
    },
}

function studio.GetStrings()
    local language = studio.preferences.language
    if language == nil or language == "auto" then
        language = studio.client.locale
    end
    return studio.strings[language] or studio.strings.enUS
end

function studio.GetLanguageLabel(strings)
    local language = studio.preferences.language
    if language == "csCZ" then return "Čeština" end
    if language == "enUS" then return "English" end
    return strings.auto
end

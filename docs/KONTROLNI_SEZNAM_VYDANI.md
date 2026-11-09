# Kontrolní seznam vydání 0.4.7

Záznam z 9. listopadu 2026 pro kandidáta `adf895f`. Herní profil byl WoW Forever 1.60.1 (70862), rozhraní 16001, jazyk klienta enUS a macOS arm64.

## Automatická kontrola

- [x] Všech pět sad Lua 5.1 a kontrola syntaxe prošly lokálně i v [GitHub Actions na main](https://github.com/JendaNDT/Forever-Macro-Studio/actions/runs/42644558083).
- [x] Workflow vytvořilo [instalační artefakt](https://github.com/JendaNDT/Forever-Macro-Studio/actions/runs/42644558083/artifacts/13686603279). Místní ZIP prošel kontrolou integrity, obsahoval `ForeverMacroStudio/ForeverMacroStudio.toc` a jeho rozbalené soubory odpovídaly nainstalovanému kandidátovi.

## Zkoušky v klientu

Funkční scénáře spouštěla dočasná testovací sonda přes skutečná tlačítka a API klienta. Po zkoušce se obnovily soubory kandidáta a jeho knihovna se po `/reload` znovu otevřela s oběma původními návrhy.

- [x] Otevření `/fms`, zavření při `/reload` a opětovné otevření.
- [x] Přepnutí češtiny a angličtiny. Český dialog exportu zobrazil text makra po jednotlivých řádcích.
- [x] Čtení knihy kouzel i batohu, ruční volba počtu sloupců přes tlačítko, kroky 1–5, cílení, podmínka, kompilace a simulace.
- [x] Uložení návrhu, přiřazení postavě, oblíbené položky, archivace a obnovení. Návrh a označení oblíbeného přežily `/reload`.
- [x] Import účtového a postavového makra. U testovacího postavového makra odpovídalo tělo po normalizaci koncových bílých znaků.
- [x] Náhled a opětovná kontrola pro účet i postavu. Snímek herních maker byl před a po potvrzení shodný.
- [x] Odmítnutí kolize názvu v postavovém rozsahu a zastaralého náhledu po odstranění testovacího makra ze slotu.
- [x] Aktualizace z 0.4.6. Porovnání se zálohou potvrdilo shodný obsah obou původních návrhů a jazykové volby.
- [ ] Ruční klikání, tažení okna a za roh, automatické přepnutí mezi širokým a kompaktním režimem při změně rozlišení.
- [ ] Ruční kopírování do `/macro` a praktická zkouška příkazů a podmínek.
- [ ] Čistá instalace a zachování návrhu po odhlášení a opětovném vstupu.
- [ ] Plný rozsah, boj a neověřený profil ověřit v odpovídajícím herním prostředí.

## Doplnění kompatibility E00

Na ověřeném buildu vrátily kniha kouzel i `C_Spell` pro ID 6603 název `Attack`. `C_Item` vrátil pro ID 6948 název `Hearthstone`. Po reloadu vrátil klient pro čerstvě vytvořené testovací makro odlišné koncové bílé znaky a sonda E00 kvůli rozdílu správně odmítla smazání. Samostatná kontrola názvu, rozsahu, ikony a normalizovaného těla umožnila odstranit pouze vytvořený testovací slot. Zbývající případy jsou v [matici E00](E00.md).

## Podmínky ostrého vydání

Verze 0.4.7 zůstává kandidátem do uzavření zbývajících herních zkoušek. Případný přímý zápis maker vyžaduje samostatné bezpečnostní ověření a rozhodnutí.

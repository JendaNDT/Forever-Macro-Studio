# Hlavní plán vývoje Forever Macro Studio

Aktualizováno: 2026-11-09. Zdroj pravdy pro další práci: tento dokument, [README](../README.md), [E00](E00.md) a zdrojové soubory ve větvi `main`.

## Účel a pravidla
Addon pro World of Warcraft: Forever umožňuje vizuálně navrhovat, kontrolovat, simulovat, ukládat a přenášet makra. Priorita: bezpečné chování v cílovém klientu, srozumitelnost pro českého hráče a žádné přepisování cizích maker bez výslovného souhlasu. Nezaměňovat přítomnost kódu, úspěšný automatický test a ověření ve skutečné hře.

**Stavové značky:** IMPLEMENTOVÁNO = existuje kód (nikoli potvrzení bezchybnosti); DOOVĚŘIT = vyžaduje test nebo opravu; PLÁN = zatím není prokázaná implementace; BLOKOVÁNO = čeká na konkrétní výsledek. Pro každou etapu zapisovat datum, commit, výsledky automatických testů, výsledky herního testu a zbývající problémy.

## Inventura k 9. listopadu 2026
Prohlédnut strom repozitáře a obsah README, E00 a vybraných zdrojových souborů. **Automatické testy jsem při této inventuře nespouštěl a addon jsem ve hře nezkoušel.** Popisy dalších funkcí vycházejí z README a existence modulů; jejich provozní stav je nutné potvrdit.

| Oblast | Důkaz v repozitáři | Stav |
| --- | --- | --- |
| Základ addonu a spuštění | `ForeverMacroStudio.toc`, `Bootstrap.lua`, `UI/Main.lua`, README (`/fms`) | IMPLEMENTOVÁNO; DOOVĚŘIT ve hře |
| Klient a bezpečnostní profil | `Core/Capabilities.lua`; E00 potvrzuje build 70862, Interface 16001, enUS | ČÁSTEČNĚ OVĚŘENO pro konkrétní profil |
| Sonda klienta | `ForeverMacroStudioProbe/Probe.lua`, `tests/probe.lua`, E00 | IMPLEMENTOVÁNO; řada testů E00 čeká |
| Kompilace, validace, převod textu | `Domain/Compiler.lua`, `MacroSyntax.lua`, `MacroText.lua`, `tests/compiler.lua` | IMPLEMENTOVÁNO; DOOVĚŘIT |
| Průvodce a vizuální úpravy | `UI/Wizard.lua`, `Domain/Editor.lua`, `tests/editor.lua` | IMPLEMENTOVÁNO; DOOVĚŘIT |
| Knihovna a obnova dat | `Storage/Library.lua`, `tests/storage.lua`; schéma 3, archiv a rescue podle README | IMPLEMENTOVÁNO; DOOVĚŘIT |
| Import maker z WoW | `WoW/ClientMacros.lua`, `UI/Main.lua` | IMPLEMENTOVÁNO pro čtení; DOOVĚŘIT |
| Přednastavení pro třídy a profese | `Domain/Presets.lua`, `UI/PresetPanels.lua`, README | IMPLEMENTOVÁNO dle README; DOOVĚŘIT dostupnost |
| Simulátor pravidel | `Domain/Simulator.lua`, `UI/Simulator.lua` | IMPLEMENTOVÁNO pro vybrané podmínky; není simulátorem skutečného seslání |
| Čeština a angličtina | `Locale/*.lua`, `UI/Fonts.lua` | IMPLEMENTOVÁNO; DOOVĚŘIT zobrazení |
| Přímý zápis maker z hlavního Studia | README popisuje ruční kopírování; E00 ověřuje zápis pouze sondou | PLÁN, nezapínat před bezpečnostními testy |

## Etapy a kritéria dokončení

### E00 – Kompatibilita klienta (ROZPRACOVÁNO)
Dokumentace a dosavadní výsledky: [E00.md](E00.md). Ověřeno 8. 11. 2026: identita klienta, čtení slotů, zápis/úprava/smazání testovacích maker mimo boj v účtovém i postavovém rozsahu, persistence na stejné postavě. **Nedokončeno:** srovnání s `/macro`, skutečná mez délky a názvu, dynamické ikony a PickupMacro, bojové přechody, katalog kouzel/předmětů, dvě postavy, syntaxe a podmínky v reálném klientu.
**Hotovo, až:** každá položka matice v E00 má výsledek, datum, profil klienta a bezpečnou náhradní cestu; neověřené schopnosti zůstanou vypnuté.

### E01 – Základ a diagnostika (IMPLEMENTOVÁNO, DOOVĚŘIT)
Otevření `/fms`, `/reload`, jazyk, zobrazení profilu, bezpečné chování na jiném buildu.
**Hotovo, až:** funguje čistá instalace a reload, bez Lua chyb, při neznámém buildu se neprezentuje neověřená funkce jako bezpečná.

### E02 – Knihovna návrhů (IMPLEMENTOVÁNO, DOOVĚŘIT)
Uložení, opětovné otevření, kopie, filtrování postav, archivace, obnova po chybě schématu.
**Hotovo, až:** testy `tests/storage.lua` projdou a herní test potvrdí zachování dat po reloadu/odhlášení; poškozená data nebudou tiše přepsána.

### E03 – Kompilátor a kontrola syntaxe (IMPLEMENTOVÁNO, DOOVĚŘIT)
`/cast`, `/use`, `#showtooltip`, podmínky, přesný text, limity, UTF-8, diagnostika.
**Hotovo, až:** `tests/compiler.lua` projde, zobrazený text souhlasí s kopírovaným a podporované vzory jsou ručně ověřeny ve hře; neznámé příkazy se nepřekládají potichu.

### E04 – Průvodce, editor, přednastavení, simulátor a import (IMPLEMENTOVÁNO, DOOVĚŘIT)
Funkce popsané v README. Ověřit návrat mezi kroky, textový/vizuální režim, přepnutí jazyka, třídy/profese, import z obou rozsahů, simulátor a kopírování.
**Hotovo, až:** `tests/editor.lua` projde a kontrolní scénáře fungují v klientu bez ztráty návrhu.

### E05 – Stabilizace a použitelnost (PLÁN; další doporučená etapa)
Provést společný test E01–E04, opravit chyby, ověřit čitelnost a ovládání při různém rozlišení, české popisky, chybové zprávy, přehledné návody a práci s dlouhým makrem. Sepsat reprodukovatelné chyby.
**Hotovo, až:** žádná známá chyba se ztrátou dat; všechny kritické scénáře projdou v cílovém klientu.

### E06 – Bezpečný přímý export do maker WoW (PODMÍNĚNO E00 a E05)
Nejprve návrh a potvrzovací obrazovka: účet/postava, jméno, ikona, přesný text, délka, případná kolize, obsazenost. Před zápisem znovu ověřit boj, index, aktuální obsah a kapacitu. Nikdy automaticky nepřepsat existující makro. Při neznámém výsledku znovu načíst skutečný stav, nezkoušet slepě opakovat zápis. Zachovat ruční cestu `/macro`.
**Hotovo, až:** bezpečné scénáře vytvoření, úpravy se souhlasem, kolize, plný rozsah, boj, změna indexu, reload a chybové stavy projdou testy i ve hře. Pokud API neumožní spolehlivou ochranu, etapu nezapínat.

### E07 – Kvalita a vydání (PLÁN)
Verzování, instalační návod, changelog, čistá instalace, aktualizace bez ztráty dat, testy pro podporovaný profil a vydání balíčku addonu.
**Hotovo, až:** čistý hráč addon nainstaluje podle README a projde základní scénář bez asistence.

### E08 – Volitelná rozšíření (NÁVRHY, nikoli závazek)
Další podporované příkazy/podmínky jen po ověření na Forever; případně přenos návrhů mezi postavami, přístupnější UI a více šablon. Každou novinku nejprve vyhodnotit z hlediska kompatibility a bezpečnosti.

## Nejbližší pracovní dávka
1. Spustit `lua5.1 tests/probe.lua`, `lua5.1 tests/storage.lua`, `lua5.1 tests/compiler.lua`, `lua5.1 tests/editor.lua`; zaznamenat výsledky a případné chybějící prostředí. **Zatím neprovedeno v rámci této inventury.**
2. V klientu projít scénáře E01–E04 a doplnit nedokončené řádky E00. Zvlášť ověřit import, kopírování, archiv a obnovu po `/reload`.
3. Založit přehled nalezených chyb s prioritou (P0 ztráta dat, P1 nefunkční hlavní cesta, P2 UI/drobnosti), konkrétním postupem reprodukce a očekávaným výsledkem.
4. Teprve po stabilizaci rozhodnout, zda zahájit E06. Do té doby zachovat ruční přenos maker.

## Záznam pokračování
Při každé další práci aktualizovat:
- **Poslední dokončená etapa:** zatím žádná etapa E01–E04 nebyla v této inventuře nezávisle potvrzena jako dokončená.
- **Aktuální priorita:** E00 zbývající herní zkoušky + E05 stabilizace existujících funkcí.
- **Poslední ověření:** 2026-11-09, statická inventura repozitáře a dokumentace, bez spuštění testů.
- **Další konkrétní krok:** automatické testy a kontrolní seznam herních scénářů.


## E06 průběžný záznam – 2026-11-09
- Přidán `ForeverMacroStudio/WoW/MacroExport.lua` a načten v `.toc`. Funkce `MacroExport.Prepare` provádí **pouze kontrolu a náhled**, nikoli zápis do hry.
- Kontroluje ověřený profil klienta, přítomnost a délku textu, název, stav boje, kapacitu a kolizi názvu v cílovém rozsahu. Vrací náhled označený `readOnly`.
- Přidán `tests/export.lua` s modelovými scénáři. **Test zatím nebyl spuštěn; PASS nelze tvrdit.**
- Zatím není připojeno uživatelské tlačítko, potvrzovací dialog ani bezpečná zapisovací vrstva. Nic se samo neukládá ani nepřepisuje.
- **Další práce:** spustit Lua 5.1 testy, ověřit limity názvu a textu na reálném Forever klientu, navrhnout dvoufázové potvrzení s opětovným načtením stavu a kontrolou kolizí těsně před zápisem. Teprve po dokončení E00/E05 povolit zápis.

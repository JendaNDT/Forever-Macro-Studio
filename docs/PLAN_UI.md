# Plán vylepšení rozhraní UI01–UI06

Stav k 2026-11-09. Rozlišujeme implementaci, automatické testy a test ve hře.

| Fáze | Stav | Rozsah |
| --- | --- | --- |
| UI01 | ČÁSTEČNĚ IMPLEMENTOVÁNO | Ukazatel postupu v průvodci. Vizuální karty s ikonami zatím chybí. |
| UI02 | ČÁSTEČNĚ EXISTUJE | Krok 4 již ukazuje kompilovaný text, délku a diagnostiku. Trvalý náhled během všech kroků zatím chybí. |
| UI03 | ČÁSTEČNĚ IMPLEMENTOVÁNO | Existující hledání, filtry a archiv. Nově počet vyfiltrovaných návrhů. Oblíbené a rychlé akce vyžadují návrh datového modelu. |
| UI04 | IMPLEMENTOVÁNO V KÓDU | Přeložené vysvětlení chyb náhledu exportu. Nutno ověřit zobrazení a přístupnost ve hře. |
| UI05 | PLÁN | Bezpečný statický náhled ikony akčního tlačítka, bez napodobování živé hry. |
| UI06 | PLÁN | Změna velikosti: nejprve navrhnout rozložení; současné souřadnice jsou pevné a prosté roztažení okna by vytvořilo prázdné plochy. |

## Technická pravidla
- Neprovádět zápis do maker WoW; zachovat ruční kopírování.
- Zachovat kompatibilitu Lua 5.1 a původní datové schéma, pokud změna není nezbytná.
- Nové UI prvky nepřekrývají navigaci ani tlačítka na okraji okna 760×530.
- Zachovat češtinu i angličtinu, všechny změny kontrolovat testy a později v klientu.
- Po každé fázi zkontrolovat GitHub Actions a zaznamenat případné chyby.

## Další pořadí
1. UI01: vizuální karty akcí s ikonami z katalogu a textovým fallbackem.
2. UI02: trvalý kompaktní náhled v průvodci bez zakrytí stávajících kroků.
3. UI03: oblíbené návrhy bez rizika ztráty dat, rychlé akce.
4. UI05: statický vzhled tlačítka.
5. UI06: skutečně adaptivní rozložení a ověření malých obrazovek.

## Pokračování implementace 2026-11-09
- UI02: přidán kompaktní živý textový náhled do levého sloupce průvodce.
- UI05: přidán statický obrázek tlačítka s univerzální ikonou a názvem návrhu. Ikona zatím není odvozena od skutečného kouzla.
- UI06: přidáno měřítko celého okna přes Ctrl + kolečko myši; nejedná se o plně adaptivní rozložení.
- UI01: existující výběr kouzel a kategorií zůstává tlačítkový, karty s ikonami nejsou implementovány.
- UI03: existující vyhledávání a filtry plus počet výsledků; trvalé oblíbené položky nejsou implementovány.
- Automatické ani herní testy těchto nových změn nebyly potvrzeny.

## Další úpravy 2026-11-09
- UI01: přidána karta právě vybrané akce s ikonou kouzla, pokud ji klient bezpečně poskytuje; při nedostupnosti se zobrazí obecná ikona. Výběrový seznam zůstává tlačítkový.
- UI03: hvězdička/plus u návrhů, oblíbené uložené v nastavení bez úprav samotných návrhů; filtr pouze oblíbených.
- UI05: statický náhled v posledním kroku přebírá ikonu vybraného kouzla.
- UI06: škálování Ctrl+kolečko zachovává původní rozložení, není to plně responzivní systém.
- **Neověřeno:** Lua 5.1 testy, CI běh a skutečné zobrazení v klientu.

## UI01/UI06 – dokončení implementace (2026-11-09)
- UI01: katalog je nyní skutečná dvousloupcová mřížka šesti grafických karet na stránku, se jménem a ikonou kouzla/předmětu (pokud ji klient poskytuje); zbývá pouze ověření ve hře.
- UI06: okno lze přesouvat a měnit jeho měřítko tažením pravého dolního rohu; reaguje také na změnu rozlišení a UI měřítka. Vnitřní rozložení používá pevné souřadnice a adaptivní měřítko, nikoli přeskupení sloupců.
- Bez klienta WoW nelze potvrdit funkčnost vykreslení ani kompatibilitu s konkrétní verzí Forever.
- Před vydáním ověřit Lua 5.1 syntax, GitHub Actions a ve hře klikání na karty, stránkování, změnu měřítka a drag.

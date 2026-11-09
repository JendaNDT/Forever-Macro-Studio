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

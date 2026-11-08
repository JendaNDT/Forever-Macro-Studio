# Forever Macro Studio

Vizuální tvorba a správa maker pro World of Warcraft: Forever. E04 přidává knihovnu, průvodce a editor maker pro `/cast`, `/use` a `#showtooltip`.

Složku `ForeverMacroStudio` vlož do `World of Warcraft/_forever_/Interface/AddOns/`. Po spuštění hry otevři panel příkazem `/fms`. Tlačítkem jazyka přepneš mezi automatikou, češtinou a angličtinou. Po `/reload` znovu otevři panel a zkontroluj uložený jazyk. Příkaz `/fms debug` vypíše profil klienta i do chatu.

V knihovně zvol **Vytvořit makro**. Vyber kouzlo z knihy, předmět z batohu nebo slot tretky. V dalších krocích vyber cíl a podmínky. Vlevo uvidíš **Přehled návrhu** s aktuálním nastavením. Kliknutím na řádek se můžeš vrátit přímo k příslušnému kroku. V náhledu uvidíš, zda je makro připravené ke kopírování. Klikni na **Označit text makra**, zkopíruj ho přes Cmd+C nebo Ctrl+C a pokračuj podle postupu v náhledu. Návrh můžeš uložit do knihovny a vrátit se k němu později.

Pokud s makry začínáš, vpravo v knihovně najdeš **Příklady**. Zkus třeba **Kouzlo vždy na sebe** a vyber léčivé nebo obranné kouzlo, které lze použít na vlastní postavu. Záložka **Makra pro třídu** nabízí pět přednastavení pro každou z devíti tříd ve Forever. Horní šipky přepínají třídu, dolní listují makry. Některé dvojice používají jedno kouzlo při běžném stisku a druhé se Shiftem. Pokud máš kombinaci se Shiftem přiřazenou jiné akci, můžeš podržet Shift a kliknout na tlačítko na liště.

Záložka **Profese** nabízí 12 přednastavení pro otevření výrobních oken, rybaření, sledování bylin a rudy a použití obvazu. Studio ukáže dostupné volby jako první. V záložkách **Makra pro třídu** a **Profese** můžeš pomocí přepínače **Jen dostupná** zobrazit jen přednastavení, pro která má postava potřebné kouzlo nebo předmět. Pro obvaz Studio vybere konkrétní druh z batohu a zobrazí ho v náhledu. Pokud ho spotřebuješ, můžeš v návrhu vybrat jiný. Kliknutím na přednastavení otevřeš náhled, který popíše účinek makra a umožní zkopírovat text do `/macro`. V **Pokročilých úpravách** můžeš měnit jednotlivé řádky, větve a skupiny.

**Vložit text** otevře textový režim. **Vizuální editor** převede text, když kompilátor dokáže zachovat stejné příkazy, cíle, podmínky a argumenty. Návrh s chybou můžeš uložit k pozdějšímu zpracování. Pokud uložená knihovna vyžaduje obnovu, `/fms rescue` otevře čitelné návrhy ke zkopírování.

Příkaz `/fms debug compiler` vypíše ukázku generování i délku výsledku. Kompilátor počítá znaky UTF-8 a bajty po sjednocení konců řádků na LF. Pro ruční přenos používá limit 255 znaků z vestavěného editoru. Statická kontrola pracuje s počáteční sadou jednotek `player`, `target` a `mouseover` a podmínkami `help`, `harm`, `exists`, `nodead` a `mod:shift/ctrl/alt`. Ověření chování maker ve hře je popsané v E00.

Pro zkoušky klienta nainstaluj do stejné složky `ForeverMacroStudioProbe`. Příkaz `/fms probe` zobrazí dostupná API a obsazenost slotů. Funguje i `/fmsprobe`. Zápisové zkoušky mají samostatné příkazy a pracují s testovacími makry `FMSE00…`.

[Výsledky, matice schopností a postup E00](docs/E00.md)

Z kořene projektu spusť `lua5.1 tests/probe.lua` pro test sondy, `lua5.1 tests/storage.lua` pro test úložiště, `lua5.1 tests/compiler.lua` pro test kompilátoru a `lua5.1 tests/editor.lua` pro průchod editorem v simulovaném klientu.

Studio používá písmo [Source Sans 3 od Adobe](https://github.com/adobe-fonts/source-sans/tree/3.052R) s [licencí SIL Open Font License](ForeverMacroStudio/Fonts/OFL.md).

# Kontrolní seznam vydání E05–E07

## Automatická kontrola
- [ ] GitHub Actions: všechny testy Lua 5.1 úspěšné
- [ ] Kontrola syntaxe všech Lua modulů úspěšná
- [ ] Vytvořený ZIP obsahuje `ForeverMacroStudio/ForeverMacroStudio.toc`
- [ ] Rozbalení ZIPu zachovává správnou strukturu

## Herní testy (čekají na přístup ke klientu)
- [ ] Otevření `/fms`, zavření a `/reload`
- [ ] Český a anglický jazyk, včetně diakritiky v náhledu exportu
- [ ] Vytvoření a uložení návrhu, odhlášení a opětovné načtení
- [ ] Archivace a obnovení návrhu
- [ ] Import účtového a postavového makra
- [ ] Náhled exportu pro účet a postavu
- [ ] Náhled exportu při plném rozsahu, kolizi jména a během boje
- [ ] Náhled exportu po změně existujícího makra
- [ ] Žádné makro se nesmí samo vytvořit, upravit ani smazat
- [ ] Ověřit bezpečné chování na nepodporovaném klientu
- [ ] Ověřit zbývající body `docs/E00.md`
- [ ] Aktualizace bez ztráty SavedVariables a čistá instalace

## Podmínky ostrého vydání
Bez úspěšných automatických testů a herního ověření neoznačovat E05/E06/E07 za dokončené. Zápis maker povolit teprve po bezpečnostním ověření a samostatném rozhodnutí.

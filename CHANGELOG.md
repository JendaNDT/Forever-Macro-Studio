# Přehled změn

## 0.4.7 – kandidát k vydání
- Průvodce se načte v Lua 5.1. Katalog s ikonami přechází mezi širokým a kompaktním rozložením a volbu počtu sloupců lze změnit ručně.
- Knihovna umožňuje označit a filtrovat oblíbené návrhy. Průvodce zobrazuje průběžný textový náhled a v kroku uložení ikonu vybrané akce.
- E06: bezpečný náhled exportu v průvodci, volba rozsahu účet/postava a opětovná kontrola před potvrzením.
- E06: při změně názvu, textu, obsazenosti nebo obsahu již existujících maker se náhled považuje za neplatný.
- E06: české a anglické texty potvrzovacího okna.
- E05: rozšířen modelový test exportu o změnu obsahu existujícího makra.
- E07: GitHub Actions spouští Lua 5.1 testy, kontrolu syntaxe a připravuje instalační ZIP.

Přenos do WoW probíhá zkopírováním do `/macro`. Před vydáním je potřeba ověřit kandidáta podle [kontrolního seznamu](docs/KONTROLNI_SEZNAM_VYDANI.md).

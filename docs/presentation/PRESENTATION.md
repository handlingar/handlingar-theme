---
marp: true
paginate: true
theme: default
---

<!--
30–45 min presentation för en ICKE-TEKNISK publik om den nya
handlingar.se-plattformens uppbyggnad, följt av / varvat med en livedemo.

Hur du använder den här filen:
- Den fungerar som ett normalt dokument uppifrån och ned.
- Det är också en Marp-presentation: `npx @marp-team/marp-cli PRESENTATION.md -o slides.pdf`
  (eller presentera direkt från VS Code Marp-tillägget). Varje `---` är ett bildspel.
- Talarnoteringar finns i HTML-kommentarer som den här — syns i presentatörsvyn,
  osynliga på bilderna.
- Det tillhörande demoskriptet med exakta kommandon och reservplaner finns i DEMO.md.

Föreslagen tidplan (40 min totalt):
  min 0–2    Bild 1–2, och KÖR `make bringup` LIVE på scen (se DEMO.md, akt 0)
  min 2–12   Bilder: vad handlingar.se är, problemet vi hade
  min 12–22  Bilder: vad vi byggde, de fem förmågorna
  min 22–35  DEMO (klustret du startade vid min 0 är nu igång)
  min 35–40  Vad detta möjliggör härnäst + frågor
-->

# handlingar.se
## En plattform du kan bygga om från grunden på 17 minuter

<!--
Öppningsgrepp (demo akt 0): visa `make resources` — en TOM tabell. "Det här är
vårt molnkonto: ingenting." Kör sedan `make bringup`: "Det kommandot bygger nu
en hel kopia av vår plattform från ingenting: servrar, databas, webbplats,
certifikat, allt. Det är klart innan demon. Låt mig förklara varför det är viktigt."
Den tomma tabellen återkommer två gånger: full (akt 2) och tom igen (finalen) —
det är den icke-tekniska tråden genom föredraget.
-->

---

## Vad är handlingar.se?

- En offentlig webbplats där **vem som helst i Sverige kan skicka en
  begäran om allmän handling** till en myndighet
- Begäranden **och myndigheternas svar publiceras öppet**, så att en
  persons fråga blir allas svar
- Byggt på **Alaveteli** — beprövad öppen källkod som driver offentlighetssajter i
  30+ länder (t.ex. WhatDoTheyKnow i Storbritannien)
- Vi underhåller den **svenska anpassningen**: språk, grafisk profil och allt
  som krävs för att driva det som en pålitlig samhällstjänst

<!--
Håll det kort om publiken redan känner till sajten. Det viktiga att etablera för
resten av föredraget: det är en SAMHÄLLSTJÄNST — folk är beroende av den — så hur
den driftsätts är lika viktigt som vad den gör.
-->

---

## Problemet: plattformen levde på en handbyggd server

- Produktionssajten körde på **en server, konfigurerad för hand över tid**
- Ingen kunde säga exakt vad som fanns på den — kunskapen levde **i folks
  huvuden och i servern själv**
- Att testa en förändring säkert var svårt: det fanns **ingen andra kopia** att prova på
- Om servern försvann — eller personen som kände den var otillgänglig —
  skulle återställningen bli **långsam, stressig gissning**

**Analogi:** vi hade ett hus, men inga ritningar. Man kan bo i det,
men man kan inte bygga ett till, och reparationer beror på vem som kommer ihåg
var rören sitter.

<!--
Undvik att lägga skuld — framställ det som det normala sättet för små projekt att växa,
och det som varje projekt till slut måste lösa för att bli hållbart.
-->

---

## Vad vi förändrade, i en mening

> **Hela plattformen är nu nedskriven som kod i ett repository —
> och ett enda kommando förvandlar den koden till en körande kopia av handlingar.se,
> från ingenting, på ungefär 17 minuter.**

- Servrar, databas, webbplats, e-posthantering, säkerhetscertifikat, DNS —
  allt är **beskrivet i textfiler**, granskat och versionshanterare som vilket dokument som helst
- Repositoryt är **ritningen**; molnet är bara platsen där vi väljer att
  bygga från den
- Det här tillvägagångssättet kallas *Infrastructure as Code* — branschstandarden
  för att driva tjänster man kan lita på

<!--
Det här är tesbilden. Allt som följer är bevis.
17 minuter: uppmätt 2026-06-15, fullständig återuppbyggnad från noll, utan manuella steg.
-->

---

## Förmåga 1 — Bygg om allt med ett enda kommando

```
make bringup
```

- Från **noll till en levande, fungerande webbplats** — riktig adress, riktig kryptering
  (hänglåset i webbläsaren), svensk grafisk profil, sök, e-post — **inga manuella steg**
- Uppmätt: **17 minuter**, kallstart
- Varje steg är **självläkande**: om en förutsättning saknas installerar eller reparerar
  verktyget den och fortsätter

**Varför det spelar roll:** katastrofåterställning slutar vara en krishanteringsplan
och blir en kaffepaus.

<!--
Det här är kommandot du körde vid minut 0. Återkoppling: "Det här är det som körs
i bakgrunden just nu."
-->

---

## Förmåga 2 — Riv ner det lika enkelt (och sluta betala)

```
make cluster-down
```

- Förstör hela testmiljön på **sekunder** — och **stoppar notan**
- Testmiljön kostar ungefär **0,70 € per dag när den finns** (faktureras
  per timme, ≈ 21 €/månad om den lämnas igång) — så vi har den helt enkelt inte
  kvar när vi inte använder den
- En inbyggd **revision bevisar att inget lämnats kvar**: nedrivningen misslyckas
  tydligt om någon betald resurs överlever, istället för att tyst fakturera oss

**Varför det spelar roll:** vi får en fullskalig testmiljö *på begäran*
för några euro, istället för att betala för overksamma servrar året om.

<!--
Revisionen (resources-assert) kom ur en verklig incident: en tidig nedrivning
lämnade tyst kvar en lastbalanserare som fakturerades. Nu är det strukturellt omöjligt
att missa. Bra ärlig anekdot om det frågas.
-->

---

## Förmåga 3 — Inga kommandon att memorera, ingen enskild felkälla

```
make
```

- Att bara skriva `make` listar **varje operation med en tydlig beskrivning** —
  driftsätt, status, återbygg, riv ner, testdata, e-postverktyg
- **Vilken bidragsgivare som helst på sin egen dator** får ett identiskt resultat:
  inga hårdkodade sökvägar, ingen personlig konfiguration, inget "det fungerar bara
  på min dator"
- Det enda manuella steget, någonsin: klistra in **en åtkomsttoken** första gången
  (hemligheter lagras avsiktligt *aldrig* i repositoryt)

**Varför det spelar roll:** plattformen är inte längre beroende av en
enskild persons minne eller laptop.

<!--
Det här är kontinuitets-/bussgrepsbilden — för en icke-teknisk publik är det ofta
den som landar hårdast. Designregeln är inskriven som ett formellt beslut (ADR 0005):
vilken kollega som helst reproducerar identiskt.
-->

---

## Förmåga 4 — En säker plats att prova allt, även e-post

Testmiljön är en **komplett, realistisk kopia** — med skyddsräcken:

- **Fejkade svenska myndigheter** och en testanvändare, seedade med ett kommando
- Lämna in en **riktig begäran om allmän handling** via den riktiga kodvägen
- All utgående e-post **fångas i en säker inkorg** — inget kan någonsin nå
  en riktig myndighet av misstag
- Vi kan till och med **spela myndigheten**: skicka ett svar och se det anlända
  och publiceras på begärandets sida — **hela rundturen** av tjänsten

**Varför det spelar roll:** vi kan repetera hela användarresan — inklusive
misstag — utan någon risk för den offentliga sajten.

<!--
Det här är hjärtat av demon. E-postflödet använder Alaveteli's RIKTIGA inkommande
e-postmaskineri (POP3-polling), inte en genväg — så det vi testar är vad
produktionen kommer att göra.
-->

---

## Förmåga 5 — Räcken som gör misstag svåra

- Verktyget är **bevisligt blint för produktion**: det arbetar från ett explicit
  register över *våra* testresurser — allt utanför listan rörs aldrig
- DNS-automatisering (internets adressbok) är **låst till testsubdomänen** —
  den *kan inte* ändra den live-saidtens poster
- En **kvalitetsgrind** körs varje session: kontrollerar för läckta hemligheter,
  personuppgifter och avvikelse från våra dokumenterade arkitekturbeslut
- Varje viktigt val är nedskrivet som ett **beslutsdokument** — framtida
  bidragsgivare ser inte bara *vad*, utan *varför*

**Varför det spelar roll:** säkerheten kommer från systemets design,
inte från att folk är försiktiga.

<!--
Om det frågas "vad händer om kommandot körs fel?": skyddsräcken är strukturella —
t.ex. external-dns har ett domänfilter + ägarskapsregister; molnrevisionen är
tillåtelseslistedriven. Att vara slarvig är möjligt att återhämta sig från.
-->

---

## Demo

**En tabell berättar historien — du såg den tom vid minut 0:**

1. Miljön som byggdes *under den här presentationen* — live på internet,
   med ett riktigt säkerhetscertifikat
2. Den tabellen igen: **varje del vi kör och betalar för**
3. Seeda testmyndigheter → **lämna in en begäran om allmän handling** på sajten
4. Se begärandets e-post anlända i den **säkra inkorgen**
5. **Svara som myndigheten** → svaret visas offentligt på sajten
6. (Final) riv ner allt — **tabellen är tom igen, notan stoppas**

<!--
Växla till DEMO.md akter 1–6 här. Håll terminalfonten STOR.
Om live-bringup från minut 0 inte är klar eller misslyckades, använd det förbyggda
reservklustret — se DEMO.md "Reservplaner".
-->

---

## Vad detta möjliggör härnäst

- **Ett register för våra programvarubilder** — minskar återbyggnadstiden ytterligare
  och tar bort den sista hastighetsbegränsningen
- **Produktionsfärdigt läge** — samma upplägg, härdat för den riktiga sajten
- **Automatiska driftsättningar** — en granskad förändring går live utan manuellt arbete
- **En stagingmiljö** — en identisk generalrepetitionsscen, skapad
  med *samma* kommando (det är poängen: miljöer är nu billiga)
- **Övervakningsdashboards** — se tjänstens hälsa på ett ögonkast

Målet: **den offentliga sajten själv körs från den här ritningen** —
återbyggbar, testbar och oberoende av en enskild person.

<!--
Koppla till färdplanen: register = P2-T9, produktionshärdning = P2-T10, overlays =
P2-T11, CI/CD = Fas 4, staging = Fas 5, observabilitet = Fas 6.
Lova inga datum.
-->

---

## Sammanfattningen på en bild

| Förut | Nu |
| --- | --- |
| En handbyggd server, inga ritningar | Hela plattformen som granskad kod |
| Återbyggnad = gissning, dagar | Återbyggnad = ett kommando, **17 minuter** |
| Testning riskerade den live sajten | Fullständig säker kopia, på begäran, ~20 €/mån bara när den används |
| Kunskapen i folks huvuden | Kunskapen i repositoryt, självdokumenterande |
| Beroende av specifika personer | Vilken bidragsgivare som helst, vilken dator som helst, identiskt resultat |

**Frågor?**

<!--
Troliga frågor & korta svar:
- "Vad kostade det att bygga?" — utvecklingstid plus små testklusterstimmar;
  klustret faktureras per timme, ≈ 0,70 €/dag *bara när det körs*
  (revisionstabellen visar live-priser per resurs).
- "Är den live sajten på det här ännu?" — inte ännu; den migrationen är
  färdplanens destination, gjord avsiktligt med samma säkerhetsräcken.
- "Vad händer om molnleverantören försvinner?" — ritningen är leverantörstunna;
  samma tillvägagångssätt återbygger på annan plats med måttliga ändringar.
- "Vem kan drifta det här?" — vem som helst med repot + två tokens; `make` listar
  varje operation. Designad så att en icke-teknisk operatör memorerar ingenting.
-->

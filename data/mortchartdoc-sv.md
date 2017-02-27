---
title: Dokumentation till Mortalitetsdiagram
author: Karl Pettersson
lang: sv-SE
mainlang: sv-SE
classoption: a4paper
fontsize: 12pt
...

#Introduktion

Syftet med denna webbplats är att erbjuda överskådlig
information om orsaksspecifika mortalitetstrender i befolkningar.
Diagram kan visas och laddas ned efter val av befolkning, åldersgrupp
och dödsorsaksgrupp. De mått som redovisas i diagrammen har beräknats
med hjälp av öppna data från @whomort, men WHO är inte ansvariga för
något innehåll på webbplatsen.

Det finns sedan tidigare flera webbplatser med visualiseringar av
mortalitetstrender. En av de mest avancerade är @ihmecodviz, som
innehåller data för alla världens länder och använder komplicerade
algoritmer för att justera för osäkerhet i underliggande data. Denna
webbplats genererar diagrammen dynamiskt och kan ibland vara tungrodd.
Dessutom sträcker sig visualiseringarna för närvarande inte längre
tillbaka än till 1980, samtidigt som @whomort för många befolkningar har
data tillgängliga från 1950. @mortrends är en webbplats med en stor
mängd statiska diagram baserade på @whomort. Dock underhålls denna
webbplats inte längre sedan dess skapare avlidit.

Webbplatsen är gjord för att snabbt och enkelt ta fram relevanta
visualiseringar av mortalitetstrender från mitten av 1900-talet fram
till våra dagar. Den innehåller ingen kod som körs på serversidan med
kopplingar till några databaser. De skript och andra källfiler som
används för att generera diagram och webbplats finns tillgängliga via
[GitHub-förråd](https://github.com/klpn/Mortchartgen.jl). 

#Mått på dödlighet

*Dödstal* är ett grundläggande mått på dödlighet.
Dödstalet i en orsak $c$ i en befolkning $x$ under en tidsperiod $t$,
$m_{c,t}(x)$, beräknas enligt $m_{c,t}(x)=n_{c,t}(x)/p_t(x)$, där
$n_{c,t}$ är antalet dödsfall i $c$ under $t$ och $p_t$ är
medelfolkmängden under $t$. Om $x$ utgör ett brett åldersintervall
kommer dödstalen i olika orsaker ofta att påverkas av trender i
åldersfördelningen. Stigande medelålder hos befolkningen ger ofta ökade
dödstal i åldersrelaterade sjukdomsgrupper som cancer, hjärtsjukdomar
och demens. @whomort tillhandahåller data över folkmängd och antal
dödsfall i 5-åriga åldersintervall, med vilka det är möjligt att beräkna
dödstal som inte är så känsliga för dessa trender, och därför ger ett
bättre mått på direkta effekter av sådant som sjukvård och miljöfaktorer
på dödlighet. Dödstal i snäva åldersintervall drabbas dock ofta av
slumpmässiga förändringar i mindre befolkningar. På denna webbplats redovisas
ovägda medelvärden av åldersspecifika dödstal i de 5-årsintervall som
ingår i bredare åldersintervall (för närvarande 15--44, 45--64, 65--74
och 75--84 år). Dessutom redovisas andelen dödsfall i alla åldrar och
för åldersgrupperna under och över 85 år (vilket kan användas för att
bedöma om trender för andelar i hela befolkningen är relaterade till
trender i de högsta åldersgrupperna, vars tolkning kan vara vansklig).

Tillgängliga data utgår från en binär könskategorisering. För de flesta
dödsorsaker varierar dödstalen signifikant mellan kvinnor och män (och
även tidstrenderna divergerar ofta, t.ex.\ när det gäller ischemisk
hjärtsjukdom och lungcancer), och alla diagram redovisar därför
könsspecifika trender.

#Underliggande dödsorsaker och konstlade trender

Alla data gäller s.k. underliggande dödsorsaker. För varje dödsfall
registreras precis en underliggande dödsorsak i befolkningarnas
statistik, och den definieras som den sjukdom som inledde det morbida
förlopp som ledde till döden eller omständigheterna kring den olycka
eller våldshandling som orsakade den dödliga skadan [@icd10v2ed10, s.
31]. I en del fall är begreppet relativt oproblematiskt, t.ex.\ att
primära tumörer och inte metastaser är underliggande dödsorsak vid
dödsfall i cancer. I många fall kan emellertid tolkningen inte
självklar. Detaljerade instruktioner för val av underliggande dödsorsak
har ändrats mellan olika ICD-versioner, och praxis för val av
underliggande dödsorsak kan skilja sig mellan olika befolkningar som
använder samma ICD-version. Exempel på fall där tolkningen skiljer sig
mellan befolkningar och tidsperioder, vilket kan ge upphov till
konstlade trender:

* Diabetes som underliggande dödsorsak hos personer som dött av
  hjärtinfarkt eller slaganfall. 
* Lunginflammation som underliggande
  dödsorsak hos personer med bakomliggande sjukdomar som ökar risken för
  lunginflammation.

För ICD-versionerna före ICD-10 finns inte uppgifter om dödsorsak
tillgängliga på detaljnivå: i stället används förkortade listor, som de
s.k.\ A-listorna i ICD-7 och ICD-8 och BTL (Basic Tabulation List) i
ICD-9. Det bidrar till att det ofta är svårt att konstruera
epidemiologiskt meningsfulla kategorier som någorlunda väl täcker samma
sjukdomsgrupper för de olika ICD-versionerna, vilket märks t.ex.\ på de
olika grupperna av infektionssjukdomar som presenteras nedan.

År då det skett byte av ICD-lista i en befolkning har markeras i rött
längs $x$ i diagrammen: $07A$ och $08A$ anger ICD-7 och ICD-8 med
A-lista, $09B$ anger ICD-9 med BTL, $103$ och $104$ anger ICD-10 med
koder på tre respektive fyra tecken (den mest detaljerade nivån) och
$10M$ anger ICD-10 med koder på tre tecken för vissa orsaker och fyra
tecken för andra. Kraftiga förändringar som uppträder i anslutning till
byte av klassifikation kan i regel antas vara konstlade.

#Inkluderade befolkningar

Jag inkluderar i första hand befolkningar med
i stort sett kontinuerlig tillgång till data över dödsfall och
befolkning från 1950-talet fram till 2000-talet. Detta innefattar till
största delen länder i Västeuropa och Nordamerika samt andra
höginkomstländer (t.ex.\ Australien, Nya Zeeland och Japan). Några
kommentarer om enskilda befolkningar:

Israel
:    Endast data över judisk befolkning före 1975. 

Tyskland 
:    Inkluderar Västtyskland före 1990. Data för Östtyskland
(vars befolkning vid sammanslagningen var cirka en fjädedel av
Västtysklands) och Västberlin finns inte tillgängliga för hela den
föregående perioden, vilket hade gjort att kostlade trender ändå inte
kunnat undvikas om inte befolkningarna redovisats separat.

#Inkluderade dödsorsaksgrupper

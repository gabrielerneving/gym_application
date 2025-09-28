# 🏋️ Gym App - Vad jag använt för att bygga appen

## 🤔 Vad appen gör

Basically en komplett träningsapp där du kan:
- Skapa träningsprogram med övningar
- Köra träningspass med timer som räknar tid
- Se hur du utvecklas över tid med grafer
- Kolla statistik över vilka muskelgrupper du tränar mest
- Spara allt i molnet så det funkar på alla enheter

## 🛠️ Huvudsakliga verktyg jag valt

### Flutter - För att bygga själva appen
**Vad det är**: Ett sätt att skriva kod en gång och få en app som funkar på iPhone, Android, webb osv.

**Varför jag valde det**: Super snabbt att testa ändringar (hot reload är magiskt), Google ligger bakom det, massor av färdiga components.

### Firebase - För backend/databas
**Vad det är**: Google's "backend-as-a-service" - typ en färdig server/databas som du bara använder.

**Varför jag valde det**:
- Behövde inte bygga egen server
- Automatisk synkning mellan enheter  
- Inbyggd användarsystem (inloggning osv)
- Gratis att börja med
- Fungerar superbra med Flutter
- Har viss tidigare erfarenhet så kändes säkert

**Vad jag använder från Firebase**:
- **Firestore**: Databasen där all träningsdata sparas
- **Auth**: Hanterar inloggning/användarkonton
- **Real-time updates**: Appen uppdateras direkt när data ändras

## 📦 Viktiga paket jag lagt till

### Riverpod - För att hantera data i appen
**Vad det gör**: Håller koll på data som behöver delas mellan olika skärmar (typ pågående träningspass, användarinfo osv).

**Varför just Riverpod**:
- Mycket mindre risk för buggar än andra alternativ
- Många online rekommenderade det
- Smidigare att jobba med än "setState" överallt
- Perfekt för saker som träningspass som behöver uppdateras live

### fl_chart - För grafer och diagram  
**Vad det gör**: Alla snygga grafer i statistik-delen (progression över tid, vilka muskler du tränar mest osv).

**Varför jag valde det**:
- Ser proffsigt ut direkt
- Massa olika chart-typer (line charts, bar charts etc)
- Går att anpassa färger och utseende
- Fungerar bra med touch (man kan trycka på punkter för mer info)
- AI implementerade större delen av denna, och den rekommenderade den så

### Andra praktiska paket:
- **uuid**: Skapar unika ID:n för varje träningspass/övning (så inget krashar)
- **intl**: Fixar datum-formatting på svenska/engelska beroende på telefon-inställningar


## 📁 Hur jag organiserat koden

Basically delat upp allt i logiska mappar så det inte blir kaos:

```
lib/
├── main.dart                  Där appen startar
├── models/                   "Recept" för data (hur träningspass/övningar ser ut)
├── pages/                     Alla skärmar (hemskärm, träningspass, statistik osv)
├── providers/                 Riverpod-grejer (håller koll på data mellan skärmar)
├── services/                  Kod som pratar med Firebase/databas
└── widgets/                   Smådelar som används på flera ställen
```

Varför jag organiserat det så här:

Models = Typ mallar för hur data ska se ut. Så när jag skapar ett träningspass vet appen "okej det ska ha namn, datum, lista med övningar" osv.

Pages = Varje skärm i appen. Hemskärm, skapa-träning-skärm, statistik-skärm etc.

Services = All kod som pratar med Firebase. Typ "spara träningspass", "hämta användarens träningar" osv. Håller UI-koden ren.

Widgets = Småbitar som jag använder på flera ställen. Typ knappen för att starta träningspass, eller card:en som visar en övning.

Providers = Riverpod-kod som håller koll på saker som flera skärmar behöver veta om. Typ "är användaren inloggad?", "vilket träningspass pågår just nu?" osv.




## 💡 Smartare saker jag löst

### Hur träningspass fungerar i praktiken
När du startar ett träningspass händer massa saker bakom kulisserna:
1. Appen skapar ett "aktivt träningspass" som alla skärmar kan se
2. Timern börjar ticka och alla skärmar uppdateras automatiskt  
3. När du ändrar vikter/reps sparas det direkt lokalt (så inget försvinner om appen krashar)
4. När du är klar pushas allt till Firebase så det synkar mellan enheter

### Hur real-time uppdatering funkar
Firebase håller reda på mycket, så om du har appen på både telefon och surfplatta och lägger till ett träningspass på telefonen så dyker det upp på surfplattan direkt utan att du behöver uppdatera.

Det funkar genom "streams" - typ som att appen lyssnar på databasen hela tiden och säger "hej, har något ändrats? okej då uppdaterar jag UI:t".

### Smart datastruktur i Firebase
Istället för att ha en jättestor tabell med allt, har jag delat upp det:
- workouts: Träningsprogram du skapat  
- masterExercises: Mall-övningar sorterade på muskelgrupp
- Varje användare får sin egen data så folk inte ser andras träning

Bilden visar collection users, där jag har 2 stycken och varje har maser_exercies (som innehåller alla sparade övningar), workout:programs för sparade program och sessions för historik, alla träningspass som körts. 

Det betyder att appen kan hämta bara det den behöver och det blir lätt att lägga till ny funktionalitet senare än att man bara har en stor tabell. 



## 🔒 Säkerhet och sådant som var viktigt

### Användarsystem
Firebase Auth fixar allt automatiskt:
- Inloggning/registrering  
- Säkra tokens
- "Kom ihåg mig"-funktionalitet så man inte blir utloggad varje gång
- Lösenordsåterställning (tror jag, inte testat egenligen)

Det betyder att jag inte behövde bygga eget användarsystem (vilket är sjukt komplicerat och lätt att göra fel).



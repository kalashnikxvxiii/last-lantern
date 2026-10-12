# Contribuire a Ultima Lanterna

Grazie per voler dare una mano. Questa guida spiega come preparare l'ambiente, dove mettere le mani e come proporre una modifica.

## Le due versioni del gioco

- **`js/`**: la versione originale in JavaScript (beta 0.9.0, cinque profondità). È il **riferimento del comportamento**: in caso di dubbio su come deve funzionare qualcosa, fa fede il codice JS.
- **`godot/`**: il porting in Godot 4.7, dove continua lo sviluppo. Per ora contiene la prima profondità fino al primo guardiano. La specifica è in [docs/superpowers/specs/2026-10-11-godot-port-vertical-slice-design.md](docs/superpowers/specs/2026-10-11-godot-port-vertical-slice-design.md).

Le nuove funzioni si fanno in Godot. Nel JS si correggono solo i bug della beta.

## Cosa serve

| Strumento | Per cosa |
|---|---|
| [Godot 4.7.2](https://godotengine.org) (comando `godot` nel PATH) | sviluppo e test della versione Godot |
| Modelli di esportazione di Godot 4.7.2 | solo per creare il pacchetto Windows |
| Node.js 20 o superiore | dati di riferimento dei test (`tools/golden/`) |
| Python 3 | script dei pacchetti per i tester |
| npm, ffmpeg (opzionali) | Electron e conversione audio, solo per riesportare gli asset |

## Primo avvio

```bash
git clone <repository> && cd Game1
godot --headless --path godot --import   # la prima volta registra le classi
godot --path godot                       # avvia il gioco
tools/test.sh                            # esegue tutti i test
```

Per lavorare nell'editor: `godot -e --path godot`.

### Argomenti di sviluppo

Dopo `--` si può saltare direttamente a una situazione:

```bash
godot --path godot -- --test=boss --seed=7          # stanza del boss, piano riproducibile
godot --path godot -- --test=fight --perks=multishot,comet --relics=r_anvil
godot --path godot -- --seed=7 --spawn=rat,ghoul,skull   # nemici nella stanza iniziale
godot --path godot -- --seed=7 --lv=2 --coins=50     # scelta dei doni subito
godot --path godot -- --scene=title --screenshot=/tmp/titolo.png --shot-after=40
```

Valori di `--test`: `fight`, `boss`, `shop`, `treasure`, `shrine`, `secret`. Altri argomenti: `--lantern=`, `--ardore=`, `--sim=N` (tick simulati), `--fire` (spara al primo nemico durante `--sim`), `--pause`, `--map`. Queste esecuzioni scrivono nel salvataggio locale, come una partita vera.

## Struttura di `godot/`

| Cartella | Contenuto |
|---|---|
| `autoload/` | servizi sempre attivi: `Save`, `Sfx`, `Music`, `Fx`, `Controls`, `Run` (stato della partita), `Game` (scene, argomenti, errori) |
| `core/` | costanti, utilità numeriche, generatore casuale, sprite e font |
| `data/` | doni, reliquie, maledizioni, consumabili (script) e nemici, boss, biomi, lanterne (Resource `.tres`, modificabili nell'Inspector) |
| `world/` | generazione di piani e stanze, flusso della partita, interazioni, luce, disegno del mondo |
| `actors/` | giocatore, nemici, IA, boss e pattern d'attacco |
| `combat/` | collisioni, proiettili, danni, stati alterati, effetti, raccoglibili |
| `ui/` | HUD, menu, pannelli e schermate |
| `assets/` | sprite, tile, font, effetti sonori, musica |
| `tests/` | test automatici e dati di riferimento (`golden/`) |

La logica gira a 60 tick al secondo: `scenes/play.gd` chiama `Flow.update_game()`, che aggiorna giocatore, nemici, proiettili ed effetti **nello stesso ordine del JS**.

## Regole del codice

- **GDScript** con tipi espliciti dove l'inferenza darebbe `Variant`. Esempio: `var x: Array = dizionario.campo`; per gli arrotondamenti usa `floorf`/`ceilf`/`absf` e mai `floor()` con `:=`.
- **Nomi:** variabili e funzioni in `snake_case`. Le chiavi dei dizionari che rispecchiano oggetti del JS (statistiche, stanze, effetti, proiettili) restano in camelCase come nel JS, così si confrontano con i dati di riferimento.
- **Testi:** in italiano, uguali al JS quando esistono, con i codici colore `^y`, `^r` e così via. Anche i commenti sono in italiano.
- **Casualità:**
  - nella logica di gioco usa sempre `U.random()`, `U.rnd()`, `U.pick()`… oppure un `RNG` con seme, mai `randf()`/`randi()`;
  - nel disegno usa `Fx.vrnd()`, che non tocca la sequenza di gioco.
- **Divisioni:** tra valori delle statistiche scrivi `float(a) / b`. Molti valori base sono interi e la divisione intera dà risultati sbagliati.
- **Confronti tra dizionari o array:** `==` confronta il contenuto. Per sapere se sono lo stesso oggetto usa `is_same(a, b)`.
- **Liste che crescono durante un ciclo** (`Run.fx`, `Run.bullets`, `Run.enemies`): ciclo per indice con `while i < arr.size()`.
- **Portare codice dal JS:** la tabella completa delle regole di traduzione è nella sezione «Convenzioni del porting» di [docs/superpowers/plans/2026-10-12-godot-port-vertical-slice.md](docs/superpowers/plans/2026-10-12-godot-port-vertical-slice.md).

## Test

- `tools/test.sh` esegue tutto; `tools/test.sh --only=boss` solo i file o le funzioni che contengono `boss`.
- **Un test fallisce** se registra un fallimento o se durante la sua esecuzione compare un errore di script. Se un test provoca apposta un errore, chiama `allow_errors()`.
- **Dove scrivere i test:** un nuovo file `godot/tests/test_<argomento>.gd` che estende `TestCase`, con funzioni `test_*`. Le asserzioni sono `check`, `eq`, `near` e `fail`; gli aiuti per creare partite e stanze sono in `tests/helpers.gd` (`TH.new_run`, `TH.arena`, `TH.spawn`).
- **Dati di riferimento (golden):** i file in `tests/golden/` vengono dal codice JS (`node tools/golden/gen.js`). Se una modifica rende il comportamento diverso dal JS **di proposito**, scrivilo nella descrizione della modifica. Se cambi il JS, rigenera i dati e controlla il diff.
- **Test prima del codice:** scrivi il test che fallisce, poi la modifica che lo fa passare.

## Asset

Gli asset in `godot/assets/` sono stati generati una volta dal codice JS e ora **si modificano direttamente**: i PNG con Aseprite o un editor di pixel art, i WAV e gli OGG con un editor audio.

- **Sprite:** le dimensioni dei frame sono in `assets/sprites/manifest.json`. Se cambi la dimensione di uno sprite, aggiorna il manifest.
- **Tile:** dopo una modifica agli atlas rigenera le TileSet con `godot --headless --path godot -s res://tools/build_tilesets.gd`.
- **Riesportare dal JS:** `tools/export_assets/` sovrascrive le modifiche fatte a mano, quindi rifiuta di farlo senza `--force`. Usalo solo se sai di volerlo.

## Aggiungere contenuti

- **Nemico:** crea `data/enemies/<id>.tres` (classe `EnemyDef`, copia un esistente) e aggiungilo al `pool` del bioma in `data/biomes/<bioma>.tres`. Se serve un comportamento nuovo, aggiungi un metodo in `actors/ai.gd` e il suo caso in `AI.run`. Lo sprite va in `assets/sprites/` con la voce nel manifest.
- **Dono o reliquia:** aggiungi la voce in fondo a `Perks.ALL` o `Relics.ALL` (l'ordine conta per le estrazioni) e il suo effetto in `apply()`. Poi aggiungi in `tests/test_data.gd` un test che controlli l'effetto: i test delle statistiche coprono solo i doni che esistono anche nel JS.
- **Lanterna:** crea un nuovo `.tres` in `data/lanterns/` e aggiungi il suo id a `DB.LANTERN_IDS`.

## Proporre una modifica

1. Crea un branch da `master`: `git checkout -b nome-breve`.
2. Fai commit piccoli e con un messaggio in italiano che dica cosa cambia, ad esempio «Ghoul: la carica si ferma contro le rocce».
3. Prima di proporre la modifica:
   - `tools/test.sh` deve passare;
   - prova la situazione nel gioco con gli argomenti di sviluppo;
   - se cambia qualcosa di visibile, allega uno screenshot.
4. Apri una pull request che spieghi il perché della modifica, come l'hai provata e le eventuali differenze volute rispetto al JS.

## Pacchetti per i tester

- **Versione Godot (Windows):** `python3 tools/build_godot.py`. Esegue i test, esporta e crea `dist/godot/UltimaLanterna-<versione>-Windows.zip` con le istruzioni per i tester (`tools/tester-godot/`). Il numero di versione è `VERSION` in `godot/core/consts.gd`.
- **Versione JS (Windows, Linux, browser):** `python3 tools/build.py` (vedi [README.md](README.md)).

## Segnalare un bug

Apri una issue con:
- cosa è successo e cosa ti aspettavi;
- il seme della partita (si legge in pausa);
- uno screenshot;
- se c'è, il registro degli errori: `%APPDATA%\Ultima Lanterna Godot\logs\godot.log` su Windows, `~/.local/share/Ultima Lanterna Godot/logs/godot.log` su Linux.

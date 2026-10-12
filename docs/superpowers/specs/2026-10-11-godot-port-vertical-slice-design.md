# Ultima Lanterna in Godot — Vertical slice (Profondità 1)

Data: 2026-10-11
Stato: implementata (vertical slice)

## 1. Obiettivo

Portare Ultima Lanterna (beta 0.9.0, JavaScript + canvas) in **Godot 4.7** con **GDScript**, in modo idiomatico, così da continuare lo sviluppo in Godot. Il comportamento di gioco resta quello della 0.9.0; la struttura interna è nuova (scene, nodi, Resource, TileMapLayer, luci 2D).

Questo documento copre il **primo sotto-progetto**: fondamenta del progetto Godot + Profondità 1 (Le Cripte) giocabile dall'inizio fino al guardiano. Le profondità 2–5 e il resto sono sotto-progetti successivi, ognuno con la sua specifica.

**Criterio di successo**: chi conosce la 0.9.0 può giocare la Profondità 1 in Godot e ritrovare gli stessi controlli, la stessa sensazione di movimento e di sparo, gli stessi contenuti e lo stesso bilanciamento; i test golden confermano che generazione, statistiche e formule coincidono con il JS.

Il gioco JS resta nella cartella attuale come riferimento fino al raggiungimento della parità completa.

## 2. Perimetro

### Incluso

- **Scene**: titolo, scelta lanterna, opzioni (volume musica, volume effetti, tremolio, numeri di danno), aiuto, record, gioco, game over, schermata "Fine della demo".
- **Pannelli in gioco**: pausa, equipaggiamento, mappa completa, scelta dei doni (3 carte, 4 con `extraChoice`), riepilogo.
- **Stanze della Profondità 1**: iniziale (con pavimento del tutorial), normali a ondate, tesoro (non chiuso a chiave in Profondità 1), mercante, santuario (`blood`, `fortune`, `fountain`, `pact`), segreta (si apre con le bombe), boss. Botola dopo il boss.
- **Nemici**: `rat`, `bat`, `skeleton`, `skull`, `ghoul` con le AI `chaser`, `erratic`, `shooter`, `caster`, `charger`; tutti i modificatori d'élite (`ELITE_MODS`).
- **Boss**: `bones` (Il Custode delle Ossa), 2 fasi, pattern `aimed`, `ring`, `summon`, `charge`, `spiral`; introduzione e morte del boss.
- **Sistemi completi**: 41 doni, 26 reliquie, 8 maledizioni, 13 consumabili, tutti gli stati alterati (`STATUS`), olio/luce/Vampata, scatto con cariche, esperienza e livelli, monete, chiavi, forzieri, pickup, tile dinamici (rocce incrinate, barili, urne, bracieri, spuntoni, porte), lucciole orbitanti, fulmini a catena, comete, schegge, rimbalzi, homing, esplosioni, scie di fuoco.
- **Lanterne**: tutte e 5 come dati con i loro criteri di sblocco (nella slice è raggiungibile solo lo sblocco del Pellegrino).
- **Feedback**: shake, hitstop, flash, rallentamento, particelle, numeri fluttuanti, toast e banner, minimappa.
- **Audio**: effetti sonori e musica a strati per titolo e Cripte.
- **Input**: tastiera + mouse e gamepad, con le stesse mappature del README.
- **Salvataggio**: stesso schema dati di `Save` del JS.

### Escluso (sotto-progetti successivi)

- Profondità 2–5, i loro 18 nemici e 4 boss, la stanza élite (appare da Profondità 2), tesoro chiuso a chiave.
- Abisso Infinito, livelli di Ardore (dati presenti, non selezionabili), vittoria finale.
- Export ed eseguibili per i tester (sostituiranno l'involucro Electron e `tools/build.py`).
- Migrazione dei salvataggi dal `localStorage` del browser.

Sconfitto il boss, la botola porta alla schermata "Fine della demo" (riepilogo della run, statistiche salvate, sblocchi ottenuti), poi al titolo.

## 3. Architettura

### 3.1 Impostazioni del progetto

- Risoluzione interna **480×270**, `stretch_mode = viewport`, `stretch_aspect = keep`, scala intera, filtro texture `nearest`.
- Logica a **60 Hz fissi** (`physics_ticks_per_second = 60`), come `DT = 1/60` del JS.
- Finestra iniziale 1440×810, F11 e Alt+Invio per lo schermo intero.
- Cursore nascosto durante il gioco, mirino disegnato dal gioco come oggi.

### 3.2 Struttura delle cartelle

```
godot/
  project.godot
  autoload/
    save.gd        salvataggio in user://save.json
    sfx.gd         effetti sonori con varianti e intervalli minimi, bus audio
    music.gd       musica a strati per traccia e intensità
    fx.gd          shake, hitstop, flash, tempo di rendering
    controls.gd    azioni di input (tastiera, mouse, gamepad), ultimo dispositivo, input simulato per i test
    run.gd         stato della run corrente (piano, stanza, giocatore, liste, contatori, notifiche)
    game.gd        cambio scena, argomenti di sviluppo, screenshot, cattura errori
  core/
    consts.gd      VERSION, W, H, TS, RW, RH, RX, RY, tipi di tile (T)
    rng.gd         mulberry32 identico al JS
    util.gd        dist, angoli, jround (Math.round del JS), hash2, imul, casualità globale
    spr.gd         sprite da manifest.json, sagome bianche generate al caricamento, disegno
    txt.gd         larghezze dei glifi, misura e a capo dei testi con codici ^x
  data/
    enemy_def.gd, boss_def.gd, biome_def.gd, lantern_def.gd   classi Resource
    enemies/*.tres, bosses/*.tres, biomes/*.tres, lanterns/*.tres
    db.gd          accesso alle Resource (nemici, boss, biomi, lanterne)
    stats.gd       baseStats(), RARITY
    perks.gd, relics.gd, curses.gd, consumables.gd, statuses.gd, elite_mods.gd
  world/
    tile_pick.gd   scelta delle varianti dei tile con hash2
    room_util.gd   DIRS, porte, tile, raggiungibilità
    floor_gen.gd   genFloor
    room_builder.gd buildRoom, planWaves, makeShop, makeShrine, randomRelics
    room_view.gd   TileMapLayer (pavimento, muri, rocce) + decorazioni + ombra dei muri
    lights.gd      collectLights
    lighting.gd    shader del buio, del bagliore e della vignettatura
    flow.gd        flusso della run: stanze, ondate, porte, transizioni, ricompense
    interact.gd    reliquie, forzieri, mercante, santuari, botola
    draw_ground.gd, draw_air.gd, draw_overlay.gd   disegno del mondo nell'ordine del JS
  actors/          (Node2D creati con .new(), senza scene .tscn)
    player.gd
    enemy.gd, ai.gd (un metodo per comportamento)
    boss.gd, boss_patterns.gd
  combat/
    collision.gd    collides, moveAxis, moveActor, lineClear, nudge
    flow_field.gd   updateFlow / flowAngle
    status.gd       addStatus, updateStatuses, cleanse
    combat.gd       hurtPlayer, morte, hitEnemy, killEnemy, fulmini, tile distruttibili
    effects.gd      fx (esplosioni, bombe, onde, avvisi, nubi, fuoco, evocazioni, fulmini)
    bullets.gd      proiettili del giocatore e dei nemici
    pickups.gd      raccoglibili
    particles.gd, floaters.gd
  ui/
    ui_draw.gd     primitive pixel, pannelli, barre, tasti, testo con codici colore
    menu.gd, notices.gd, map_draw.gd, panels_draw.gd, hud.gd, panels.gd, well_bg.gd
    screens/       title, options, select, records, help, gameover, demo_end (.tscn + .gd)
  scenes/
    play.tscn / play.gd
  shaders/
    darkness.gdshader, glow.gdshader, vignette.gdshader
  tools/
    build_tilesets.gd   genera le TileSet dagli atlas esportati
  assets/          generati dallo script di esportazione (vedi §4)
    sprites/, tiles/, font/, sfx/, music/
  tests/
    test_main.tscn, run_tests.gd, test_*.gd, golden/*.json
tools/
  export_assets/   esportazione asset dal codice JS (Electron)
  golden/          generazione dei dati golden dal codice JS (Node)
```

### 3.3 Principi

- **Movimento e collisioni portati dal JS**, non dal motore fisico: `moveAxis` ad assi separati contro la griglia della stanza, colpi come confronto di raggi, `lineClear` per la linea di vista. Nessun `PhysicsBody2D` o `Area2D` per gli attori e i proiettili.
- **Ordine di aggiornamento centralizzato**: `play.gd` esegue a ogni tick fisso, nell'ordine di `updateCommon` del JS: input, giocatore, orbitali, proiettili del giocatore, nemici, proiettili nemici, effetti, pickup, flusso della stanza, porte, notifiche. Gli attori espongono `tick(dt)` e non usano `_physics_process` propri. Hitstop e rallentamento agiscono saltando o scalando il tick, non tramite `Engine.time_scale`.
- **Run separata dalle scene**: `Run` contiene i dati della run. Il piano è una struttura dati (stanze con griglia, porte, oggetti, ondate, stato). Entrare in una stanza istanzia `room.tscn` da quei dati; uscire li aggiorna e libera la scena.
- **Statistiche**: `recalcStats()` riparte da `baseStats()` e applica lanterna, doni (`apply(stats, n)`), reliquie, maledizioni, come nel JS. Le funzioni `pDamage`, `pFireRate`, `pSpeed`, `pLight` restano funzioni.
- **Nemici guidati dai dati**: una sola classe `Enemy` configurata da una `EnemyDef` (hp, velocità, danno, raggio, sprite, AI, colpo, flag). Ogni AI è un metodo statico di `ai.gd` con firma `(e, dt, tg, m)`. Un nuovo nemico = un `.tres` più, se serve, un nuovo metodo.
- **Contenuti con effetti in codice**: doni, reliquie, maledizioni, consumabili restano dizionari GDScript con `Callable` (`apply`, `onTake`, `use`), perché i loro effetti sono codice. Testi e numeri restano identici al JS.
- **Casualità**: generazione di piano e stanze con `RNG` a seme (mulberry32 portato bit per bit, con mascheramento a 32 bit). La casualità di gioco (colpi critici, drop) usa un RNG globale, come `Math.random` nel JS.
- **Proiettili come dati**: i proiettili sono dizionari negli array `Run.bullets` e `Run.ebullets`, aggiornati da `bullets.gd` e disegnati in blocco da un nodo; niente nodo per proiettile. Lo stesso vale per effetti, pickup e oggetti della stanza.
- **Attori come nodi**: `Player`, `Enemy` e `Boss` sono `Node2D` con le coordinate logiche `x`, `y` del JS; a fine tick la `position` viene allineata e il nodo si ridisegna in `_draw()`. Funzionano anche fuori dall'albero, così i test li usano senza scena.
- **Modalità di sviluppo**: argomenti da riga di comando dopo `--` (`--test=fight|boss|shop|treasure|shrine|secret`, `--lantern=`, `--perks=`, `--relics=`, `--lv=`, `--coins=`, `--seed=`, `--spawn=`, `--sim=`, `--fire`, `--pause`, `--map`, `--scene=`, `--screenshot=` con `--shot-after=`) sostituiscono i parametri `?test=` del JS. `--screenshot` salva un PNG della finestra dopo N tick ed esce: serve per confrontare a occhio con la versione JS.

### 3.4 Rendering e luce

- Pavimento, muri e rocce su `TileMapLayer`; decorazioni, porte, tile dinamici, oggetti, pickup, effetti e proiettili disegnati con `_draw()` portando le funzioni di `render.js`; ombra dei muri sul pavimento come nodo dedicato.
- Ordinamento in profondità per Y degli attori (`y_sort_enabled`).
- **Livelli**, nello stesso ordine di `drawWorld` del JS: mondo (con lo scuotimento), luce, sovrimpressione visibile anche al buio (telegrafi, occhi, proiettili nemici, particelle alte, numeri, prompt), effetti a schermo (braci d'olio, flash, bordo rosso), HUD, pannelli.
- **Luce**: uno shader a schermo intero riproduce esattamente lo strato di buio del JS. Colore `#050309` con opacità `amb` (`biome.dark` più le stesse correzioni: profondità oltre la 5, stanza ripulita, olio esaurito in combattimento); ogni sorgente di `collectLights()` (al massimo 128) toglie opacità con lo stesso gradiente radiale (raggio interno 0,12·r, arresti 0 / 0,55 / 1 con alfa a / 0,6·a / 0) e le sorgenti si combinano moltiplicando come `destination-out`. Un secondo shader additivo disegna il bagliore colorato, un terzo la vignettatura. Si è scelto lo shader al posto di `CanvasModulate` + `PointLight2D` perché queste non riproducono la combinazione moltiplicativa del buio e avrebbero richiesto una taratura a occhio.
- Flash e tinta degli sprite: si disegna la sagoma bianca dello sprite (generata al caricamento) modulata con il colore, come `silhouette()` nel JS.
- HUD e pannelli su `CanvasLayer` separati, non influenzati dalla luce.

### 3.5 Flusso

- `Game.set_scene(name, arg)` cambia scena subito, come `setScene` del JS; `Play` è una scena unica che contiene il mondo e la UI.
- I pannelli (scelta dei doni, pausa, equipaggiamento, mappa, opzioni) fermano il tick del mondo e ricevono l'input; corrispondono ai `mode` di `Scenes.play`.
- Pausa automatica quando la finestra perde il focus durante il gioco.
- Transizioni tra stanze, introduzione di profondità e del boss, morte e vittoria con gli stessi tempi del JS (`run.trans`, `run.intro`, `run.bossIntro`, `deathT`).

### 3.6 Salvataggio

- File `user://save.json` con lo schema di `Save.defaults()`: `settings`, `stats`, `unlocks`, `seen`.
- Caricamento tollerante come `Save.load`: valori mancanti presi dai default, file corrotto sostituito dai default.
- Scrittura negli stessi momenti del JS (inizio run, nuovo record di profondità, sblocchi, fine run, opzioni).

### 3.7 Gestione degli errori

- Un errore durante il gioco viene registrato nel log di Godot (`user://logs/`) e mostrato in una barra in basso con il messaggio, la versione e il seme della run, come oggi. La cattura usa un `Logger` registrato con `OS.add_logger` (GDScript non ha `try/catch`: un errore interrompe solo la funzione in corso).
- La versione è una costante in `core/consts.gd` (`VERSION`), inizialmente `godot 0.1.0`.

## 4. Pipeline degli asset

Script in `tools/export_assets/`, eseguito **una volta**. Avvia Electron in una finestra nascosta e carica i file JS esistenti senza modificarli (`core.js`, `font.js`, `gfx.js`, `sprites.js`, `audio.js`, `data.js`, `dungeon.js`), poi scrive in `godot/assets/` e lancia `godot --headless --import`. Rifiuta di sovrascrivere asset esistenti senza `--force`. Dopo l'esportazione i file in `godot/assets/` sono le sorgenti da modificare.

### 4.1 Sprite

- Un PNG per sprite in `assets/sprites/`, frame affiancati in orizzontale, outline incluso (output di `compileRows`).
- `assets/sprites/manifest.json` con nome, larghezza e altezza del frame, numero di frame.
- `core/spr.gd` legge il manifest, carica le texture e genera al caricamento le sagome bianche per flash e tinta; `Spr.draw()` riproduce `drawSpr` del JS (centrato, flip, flash, alfa, scala, tinta). Le varianti `flash` e `tint` quindi non si esportano: modificando un PNG, le sagome seguono da sole.
- Si esportano anche le icone (`i_*`, `s_*`) e gli sprite dei consumabili e degli oggetti.

### 4.2 Tile

Per ogni bioma (nella slice solo `crypt`, ma lo script li esporta tutti e 5) un atlas `assets/tiles/<bioma>.png` e una `TileSet` `assets/tiles/<bioma>.tres`:

- pavimento: 3 colori × 6 varianti (giunti, crepe e granelli disegnati con semi diversi);
- muri: parità della riga × bordo (alto, basso, sinistra, destra, angoli, interno) × con o senza crepa;
- rocce: piena e incrinata × 2 varianti;
- `godot/tools/build_tilesets.gd` (Godot headless) genera le `TileSet` dagli atlas e da `assets/tiles/layout.json`.

Porte e decorazioni del pavimento restano disegnate dal codice (porting di `drawDoors` e `drawDecal`), perché dipendono dallo stato della porta e da parametri continui. `room_view.gd` sceglie colore e variante con lo stesso `hash2(tx, ty, seed)` del JS. Risultato atteso: stesso stile e stessa distribuzione, **non identico pixel per pixel** (scelta accettata).

### 4.3 Font

- Il font bitmap di `font.js` esportato come atlas bianco `assets/font/lanterna.png` con `glyphs.json` (posizione e larghezza di ogni glifo), più un BMFont `lanterna.fnt` sullo stesso atlas per usarlo in futuro nei nodi `Label` dell'editor.
- `UiDraw.text()` porta `Font.draw` del JS: codici colore `^w ^y ^r ^g ^b ^o ^p ^d ^c ^s ^k` (`TEXT_COLORS`), allineamento, ombra, scala, alfa. `Txt.width()` e `Txt.wrap()` portano misura e a capo, così l'impaginazione resta identica.

### 4.4 Effetti sonori

- Ogni nome gestito da `Sound.play` è registrato con `OfflineAudioContext` in `assets/sfx/<nome>_<1..3>.wav` (3 varianti, perché alcuni suoni usano `Math.random`).
- `Sfx.play(name, vol)` sceglie una variante a caso e applica gli stessi intervalli minimi del JS (`shoot` 0,045 s, `hit` 0,035 s, `xp` 0,03 s, `coin` 0,04 s, `enemyShoot` 0,05 s, `kill` 0,04 s, `tick` 0,05 s, altri 0,02 s).
- Bus audio `Master` → `Sfx` / `Music`, con un compressore sul Master (soglia −14 dB, rapporto 4) e i volumi delle opzioni (`sfx × 0,8`, `music × 0,55`).

### 4.5 Musica

- Per ogni traccia di `TRACKS` (`title`, `crypt`, `fungus`, `forge`, `abyss`, `heart`) il sequencer gira con un seme fisso per 32 battute e viene registrato per strati: `drone`, `arp` (triangolo, intensità 0–1), `arp_hi` (quadra, intensità 2), `bass` (basso + cassa), `hats`. File `assets/music/<traccia>_<strato>.ogg`, in loop.
- In Godot ogni traccia è un `AudioStreamSynchronized`; `Music.set_intensity(i)` dissolve i volumi degli strati: intensità 0 = drone + arp; 1 = + bass + hats; 2 = drone + arp_hi + bass + hats.
- **Perdita accettata**: l'accelerazione del 20% del tempo all'intensità 2 non viene riprodotta.

## 5. Test e verifica

### 5.1 Test runner

- `godot/tests/test_main.tscn` con `run_tests.gd`, avviato con `godot --headless --path godot res://tests/test_main.tscn` (come scena principale, così gli autoload sono attivi). Esegue tutte le funzioni `test_*` dei file `tests/test_*.gd`, conta come fallimento anche un errore di script catturato dal `Logger`, stampa i risultati e termina con codice diverso da zero se un test fallisce. Nessun addon.

### 5.2 Dati golden dal JS

`tools/golden/` (Node) carica in una sandbox `vm` `core.js`, `data.js`, `dungeon.js` e le funzioni pure di `entities.js`, con `Math.random` sostituito da un RNG a seme, e scrive `godot/tests/golden/*.json`:

- prime 1000 uscite di `RNG` per 5 semi;
- `genFloor(1, rng)` per 50 semi: stanze, coordinate, tipi, porte, distanze;
- `buildRoom` per tutte le stanze di quei piani: griglia dei tile, oggetti, decorazioni, ondate;
- `recalcStats` per ogni dono (livello 1 e massimo), ogni reliquia, ogni maledizione, ogni lanterna e 30 combinazioni casuali;
- formule: `xpNeed`, `depthHp`, `depthDmg`, `basePrice`, `priceOf`, calcolo del danno del giocatore e del danno subito (armatura, `dmgTaken`, schivata) a parità di estrazioni.

I test Godot riproducono gli stessi calcoli e confrontano i risultati campo per campo.

### 5.3 Test unitari Godot

- `Txt.width()` e `Txt.wrap()` con codici colore, spazi, caratteri accentati e caratteri senza glifo.
- `Save`: caricamento con campi mancanti, file corrotto, assenza del file, scrittura impossibile.
- `bullets.gd`: muri, rimbalzi, perforazione, schegge, uscita di scena.
- Stati alterati: applicazione, accumulo del veleno, tre cariche di gelo che congelano, scadenza, immunità.

### 5.4 Smoke test headless

- Run con seme fisso, ingresso in una stanza di combattimento, fuoco simulato verso il nemico più vicino per 1800 tick: nessun errore, la stanza viene ripulita.
- Stanza del boss con doni e reliquie forzati (multishot, chain, orbit, comet, split, bounce): nessun errore, il boss viene sconfitto entro un limite di tick.

### 5.5 Verifica manuale

Checklist di playtest nel piano di implementazione, da eseguire affiancando la versione JS: controlli (tastiera, mouse, gamepad), sensazione di movimento e sparo, luce e olio, Vampata, ogni tipo di stanza, bombe e stanze segrete, mercante, santuari, scelta dei doni, boss in entrambe le fasi, morte, sblocco del Pellegrino, persistenza del salvataggio tra sessioni, volumi.

L'implementazione segue il TDD per logica, dati e generazione; la parte visiva e audio è verificata con la checklist e con screenshot affiancati.

## 6. Decisioni prese

| Decisione | Scelta | Motivo |
|---|---|---|
| Obiettivo | Base idiomatica per continuare a sviluppare in Godot | Scelto dall'utente |
| Linguaggio | GDScript con tipizzazione statica | Nativo, nessuna dipendenza .NET, export web |
| Architettura | Scene per entità, movimento/collisioni portati dal JS | Struttura Godot senza cambiare il feeling |
| Asset | Esportati una volta in file modificabili | Modificabili con Aseprite/editor |
| Musica | Strati registrati e sincronizzati | Sostituibile con brani composti |
| Primo traguardo | Vertical slice della Profondità 1 completa | Giocabile e verificabile presto |
| Test | Runner minimale + golden dal JS | Verifica oggettiva della parità |
| Posizione | `godot/` in questa cartella, JS come riferimento | Confronto diretto durante il porting |

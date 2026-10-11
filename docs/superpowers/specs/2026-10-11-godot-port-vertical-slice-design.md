# Ultima Lanterna in Godot — Vertical slice (Profondità 1)

Data: 2026-10-11
Stato: in revisione

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
    game.gd        cambio scena con dissolvenza, gestione errori
    run.gd         stato della run corrente (piano, stanze, giocatore, contatori)
    save.gd        salvataggio in user://save.json
    sfx.gd         effetti sonori con varianti e intervalli minimi
    music.gd       musica a strati per bioma e intensità
    fx.gd          shake, hitstop, flash, rallentamento
  core/
    consts.gd      W, H, TS, RW, RH, RX, RY, tipi di tile (T)
    rng.gd         mulberry32 identico al JS
    util.gd        clamp, lerp, angDiff, approach, hash2, fmtTime...
    txt.gd         conversione dei codici colore ^x in BBCode
  data/
    enemy_def.gd, boss_def.gd, biome_def.gd, lantern_def.gd   classi Resource
    enemies/*.tres, bosses/*.tres, biomes/*.tres, lanterns/*.tres
    stats.gd       baseStats()
    perks.gd, relics.gd, curses.gd, consumables.gd, statuses.gd, elite_mods.gd
  world/
    floor_gen.gd   genFloor
    room_builder.gd buildRoom, planWaves, makeShop, makeShrine
    room.tscn      TileMapLayer (pavimento, muri, rocce) + decorazioni + oggetti
    room_view.gd   istanzia la stanza dai dati generati, aggiorna i tile dinamici
    lighting.tscn  CanvasModulate + gestione delle luci
  actors/
    player.tscn / player.gd
    enemy.tscn / enemy.gd + ai/*.gd
    boss.tscn / boss.gd + boss_patterns.gd
    pickup.tscn, objects/*.tscn (chest, relic, shopitem, merchant, shrine, trapdoor)
  combat/
    bullet_pool.gd  proiettili del giocatore e dei nemici, disegnati in blocco
    collision.gd    collides, moveAxis, moveActor, lineClear (griglia)
    damage.gd       hurtPlayer, hitEnemy, killEnemy, chainLightning, esplosioni
    status.gd       addStatus, updateStatuses, cleanse
    effects.gd      fx a terra e in aria (fuoco, esplosioni, raggi, bombe)
    flow_field.gd   updateFlow / flowAngle
  ui/
    hud.tscn, minimap.gd, full_map.gd, perk_cards.tscn, pause.tscn, build_panel.tscn,
    title.tscn, lantern_select.tscn, options.tscn, help.tscn, records.tscn,
    gameover.tscn, demo_end.tscn, menu.gd, notices.gd, floaters.gd
  scenes/
    play.tscn / play.gd
  shaders/
    flash_tint.gdshader
  assets/          generati dallo script di esportazione (vedi §4)
    sprites/, tiles/, font/, sfx/, music/
  tests/
    run_tests.gd, test_*.gd, golden/*.json
tools/
  export_assets/   esportazione asset dal codice JS (Electron)
  golden/          generazione dei dati golden dal codice JS (Node)
```

### 3.3 Principi

- **Movimento e collisioni portati dal JS**, non dal motore fisico: `moveAxis` ad assi separati contro la griglia della stanza, colpi come confronto di raggi, `lineClear` per la linea di vista. Nessun `PhysicsBody2D` o `Area2D` per gli attori e i proiettili.
- **Ordine di aggiornamento centralizzato**: `play.gd` esegue a ogni tick fisso, nell'ordine di `updateCommon` del JS: input, giocatore, orbitali, proiettili del giocatore, nemici, proiettili nemici, effetti, pickup, flusso della stanza, porte, notifiche. Gli attori espongono `tick(dt)` e non usano `_physics_process` propri. Hitstop e rallentamento agiscono saltando o scalando il tick, non tramite `Engine.time_scale`.
- **Run separata dalle scene**: `Run` contiene i dati della run. Il piano è una struttura dati (stanze con griglia, porte, oggetti, ondate, stato). Entrare in una stanza istanzia `room.tscn` da quei dati; uscire li aggiorna e libera la scena.
- **Statistiche**: `recalcStats()` riparte da `baseStats()` e applica lanterna, doni (`apply(stats, n)`), reliquie, maledizioni, come nel JS. Le funzioni `pDamage`, `pFireRate`, `pSpeed`, `pLight` restano funzioni.
- **Nemici guidati dai dati**: una sola `enemy.tscn` configurata da una `EnemyDef` (hp, velocità, danno, raggio, sprite, AI, colpo, flag). Le AI sono script piccoli che implementano `tick(enemy, dt, target)`. Un nuovo nemico = un `.tres` più, se serve, una nuova AI.
- **Contenuti con effetti in codice**: doni, reliquie, maledizioni, consumabili restano dizionari GDScript con `Callable` (`apply`, `onTake`, `use`), perché i loro effetti sono codice. Testi e numeri restano identici al JS.
- **Casualità**: generazione di piano e stanze con `RNG` a seme (mulberry32 portato bit per bit, con mascheramento a 32 bit). La casualità di gioco (colpi critici, drop) usa un RNG globale, come `Math.random` nel JS.
- **Proiettili in pool**: `bullet_pool.gd` tiene i proiettili in array e li disegna in un unico nodo; niente nodo per proiettile.
- **Modalità di sviluppo**: argomenti da riga di comando dopo `--` (`--test=fight|boss|shop|treasure`, `--lantern=`, `--perks=`, `--relics=`, `--lv=`, `--coins=`, `--seed=`) sostituiscono i parametri `?test=` del JS.

### 3.4 Rendering e luce

- Pavimento, muri e rocce su `TileMapLayer`; decorazioni come sprite; ombra dei muri sul pavimento come nodo dedicato.
- Ordinamento in profondità per Y degli attori e degli oggetti.
- **Luce**: `CanvasModulate` che riproduce lo strato di buio del JS (colore `#050309` con opacità `amb` = `biome.dark`, più le stesse correzioni: profondità oltre la 5, stanza ripulita, olio esaurito in combattimento); il valore esatto del modulate è tarato con screenshot affiancati. Ogni sorgente di `collectLights()` diventa una `PointLight2D` con texture a gradiente radiale (stessi punti di arresto 0,12 / 0,55 / 1) e lo stesso raggio, intensità e tremolio. Il bagliore colorato additivo è una seconda texture in modalità additiva. Vignettatura come `TextureRect` sopra il mondo.
- Le luci per oggetti numerosi (proiettili, monete) usano un pool di `PointLight2D` con lo stesso tetto del JS (120 luci).
- Flash di colpo e tinta degli sprite tramite `flash_tint.gdshader`.
- HUD e pannelli su `CanvasLayer` separati, non influenzati dalla luce.

### 3.5 Flusso

- `Game.change_scene(name)` con dissolvenza; `Play` è una scena unica che contiene il mondo e la UI.
- I pannelli (scelta dei doni, pausa, equipaggiamento, mappa, opzioni) fermano il tick del mondo e ricevono l'input; corrispondono ai `mode` di `Scenes.play`.
- Pausa automatica quando la finestra perde il focus durante il gioco.
- Transizioni tra stanze, introduzione di profondità e del boss, morte e vittoria con gli stessi tempi del JS (`run.trans`, `run.intro`, `run.bossIntro`, `deathT`).

### 3.6 Salvataggio

- File `user://save.json` con lo schema di `Save.defaults()`: `settings`, `stats`, `unlocks`, `seen`.
- Caricamento tollerante come `Save.load`: valori mancanti presi dai default, file corrotto sostituito dai default.
- Scrittura negli stessi momenti del JS (inizio run, nuovo record di profondità, sblocchi, fine run, opzioni).

### 3.7 Gestione degli errori

- Un errore durante il gioco viene registrato nel log di Godot (`user://logs/`) e mostrato in una barra in basso con il messaggio, la versione e il seme della run, come oggi.
- La versione è una costante in `core/consts.gd` (`VERSION`), inizialmente `godot 0.1.0`.

## 4. Pipeline degli asset

Script in `tools/export_assets/`, eseguito **una volta**. Avvia Electron in una finestra nascosta e carica i file JS esistenti senza modificarli (`core.js`, `font.js`, `gfx.js`, `sprites.js`, `audio.js`, `data.js`, `dungeon.js`), poi scrive in `godot/assets/` e lancia `godot --headless --import`. Rifiuta di sovrascrivere asset esistenti senza `--force`. Dopo l'esportazione i file in `godot/assets/` sono le sorgenti da modificare.

### 4.1 Sprite

- Un PNG per sprite in `assets/sprites/`, frame affiancati in orizzontale, outline incluso (output di `compileRows`).
- `assets/sprites/manifest.json` con nome, larghezza e altezza del frame, numero di frame.
- `tools/build_spriteframes.gd` (eseguito con Godot headless) genera una risorsa `SpriteFrames` per gli sprite animati; quelli a frame singolo si usano come `Texture2D`.
- Le varianti `flash` e `tint` non si esportano: le fa lo shader.
- Si esportano anche le icone (`i_*`, `s_*`) e gli sprite dei consumabili e degli oggetti.

### 4.2 Tile

Per ogni bioma (nella slice solo `crypt`, ma lo script li esporta tutti e 5) un atlas `assets/tiles/<bioma>.png` e una `TileSet` `assets/tiles/<bioma>.tres`:

- pavimento: 3 colori × 6 varianti (giunti, crepe e granelli disegnati con semi diversi);
- muri: parità della riga × bordo (alto, basso, sinistra, destra, angoli, interno) × con o senza crepa;
- rocce: piena e incrinata × 2 varianti;
- porte nei loro stati;
- decorazioni del bioma come sprite separati.

`room_builder.gd` sceglie colore e variante con lo stesso `hash2(tx, ty, seed)` del JS. Risultato atteso: stesso stile e stessa distribuzione, **non identico pixel per pixel** (scelta accettata).

### 4.3 Font

- Il font bitmap di `font.js` esportato come BMFont (`assets/font/lanterna.fnt` + `.png`) con larghezze variabili e altezza di riga 10.
- `Txt.fmt()` converte i codici colore `^w ^y ^r ^g ^b ^o ^p ^d ^c ^s ^k` (`TEXT_COLORS`) in BBCode per `RichTextLabel`.
- Ombra del testo come `shadow` del tema.

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

- `godot/tests/run_tests.gd`, avviato con `godot --headless --path godot -s tests/run_tests.gd`. Esegue tutte le funzioni `test_*` dei file `tests/test_*.gd`, stampa i risultati e termina con codice diverso da zero se un test fallisce. Nessun addon.

### 5.2 Dati golden dal JS

`tools/golden/` (Node) carica in una sandbox `vm` `core.js`, `data.js`, `dungeon.js` e le funzioni pure di `entities.js`, con `Math.random` sostituito da un RNG a seme, e scrive `godot/tests/golden/*.json`:

- prime 1000 uscite di `RNG` per 5 semi;
- `genFloor(1, rng)` per 50 semi: stanze, coordinate, tipi, porte, distanze;
- `buildRoom` per tutte le stanze di quei piani: griglia dei tile, oggetti, decorazioni, ondate;
- `recalcStats` per ogni dono (livello 1 e massimo), ogni reliquia, ogni maledizione, ogni lanterna e 30 combinazioni casuali;
- formule: `xpNeed`, `depthHp`, `depthDmg`, `basePrice`, `priceOf`, calcolo del danno del giocatore e del danno subito (armatura, `dmgTaken`, schivata) a parità di estrazioni.

I test Godot riproducono gli stessi calcoli e confrontano i risultati campo per campo.

### 5.3 Test unitari Godot

- `Txt.fmt()` su tutti i codici colore e casi limite.
- `Save`: caricamento con campi mancanti, file corrotto, assenza del file.
- `bullet_pool`: creazione, riuso, rimozione fuori stanza.
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

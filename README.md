# Ultima Lanterna

Roguelike d'azione 2D in pixel art. Il sole si è spento: sei l'ultimo portatore di lanterna e scendi nel Pozzo per riaccendere la Fiamma Prima, divorata da qualcosa che vive in fondo al buio.

## Come avviarlo

Apri `index.html` in un browser moderno (Firefox, Chrome, Edge). Non servono installazioni, server o connessione: grafica, font e audio sono generati dal codice.

Se il browser blocca i file locali, puoi servirlo da una cartella qualsiasi:

```
python3 -m http.server 8000
```

e poi visita `http://localhost:8000`.

## Versione Godot (in sviluppo)

In `godot/` c'è il porting in Godot 4.7. Per ora contiene la prima profondità completa, fino al guardiano.

    godot --path godot

Test: `tools/test.sh`. Argomenti di sviluppo dopo `--`, ad esempio `godot --path godot -- --test=boss --seed=7`.
Gli asset in `godot/assets/` sono stati esportati una volta dal codice JS con `tools/export_assets/` e ora si modificano direttamente.

## Comandi

| Azione | Tastiera e mouse | Gamepad |
|---|---|---|
| Muoversi | W A S D | stick sinistro |
| Mirare e sparare | mouse + clic sinistro, oppure frecce | stick destro |
| Scatto (invulnerabile) | Spazio / Shift | A, LB |
| Vampata (consuma olio) | clic destro / F | B, RB |
| Consumabili | 1 2 3 4 | croce direzionale |
| Interagire | E | X |
| Mappa | Tab / M | Back |
| Pausa ed equipaggiamento | Esc / P | Start |

## Il gioco in breve

- **Cinque profondità** (Cripte, Fungaie, Fonderia Sommersa, Abisso Allagato, Cuore del Pozzo), ognuna generata a stanze con un guardiano finale. Dopo la vittoria si può continuare nell'Abisso Infinito.
- **La lanterna è la tua vita**: l'olio si consuma in combattimento e restringe la luce; i nemici uccisi lo restituiscono. Senza olio subisci più danni. La Vampata brucia e respinge i nemici e cancella i proiettili vicini.
- **Doni** (41) scelti a ogni livello, **reliquie** (26) nei tesori, nei negozi, nei segreti e dai guardiani, **maledizioni** (8), **consumabili** (13) e **stati alterati** (bruciatura, veleno, gelo, lentezza, debolezza, fragilità, accecamento...).
- **23 tipi di nemici** con comportamenti diversi, varianti d'élite con 7 modificatori, **5 boss** con più fasi.
- Stanze speciali: tesoro (chiave richiesta dalla seconda profondità), mercante, santuari, sale della sfida, stanze segrete da aprire con le bombe.
- **Progressione permanente**: 5 lanterne iniziali da sbloccare e 5 livelli di Ardore (difficoltà) dopo la prima vittoria. I progressi sono salvati nel browser.

## Pacchetto per i tester

```
python3 tools/build.py
```

Crea in `dist/` tre archivi con dentro istruzioni per i tester (`LEGGIMI.txt`) e un modulo di feedback:

- `...-Windows.zip`: versione desktop per Windows 10/11 x64 (`Ultima Lanterna.exe`).
- `...-Linux.tar.gz`: versione desktop per Linux x64 (`avvia.sh`, più `installa-scorciatoia.sh` per il menu delle applicazioni).
- `...-Browser.zip`: il gioco in un solo file HTML, per qualsiasi sistema con un browser.

Servono Node.js e npm (la prima volta scarica Electron). Wine è facoltativo e serve solo per mettere l'icona sull'eseguibile Windows. Il numero di versione si cambia in `js/core.js` (`VERSION`).

La versione desktop salva gli errori in `registro-errori.txt` nella cartella dati dell'utente (`%APPDATA%\Ultima Lanterna` su Windows, `~/.config/Ultima Lanterna` su Linux).

## Struttura

```
index.html        pagina e canvas
js/core.js        costanti, utilità, RNG, input, salvataggio
js/font.js        font bitmap disegnato a mano
js/gfx.js         sprite, particelle, pannelli UI
js/sprites.js     pixel art (stringhe)
js/audio.js       effetti sonori e musica generativa (WebAudio)
js/data.js        doni, reliquie, maledizioni, consumabili, nemici, boss, biomi
js/dungeon.js     generazione delle profondità e delle stanze
js/entities.js    giocatore, nemici, boss, proiettili, effetti
js/render.js      rendering del mondo e illuminazione
js/ui.js          HUD, minimappa, menu
js/game.js        scene, flusso di gioco, ciclo principale
desktop/          involucro Electron (main.js) e script di impacchettamento
tools/            build dei pacchetti, generatore dell'icona, testi per i tester
```

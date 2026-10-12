# Playtest della vertical slice Godot

Da eseguire affiancando la versione JS (`index.html`). Segnare ogni voce con ✅ o con la differenza trovata.

Le voci già segnate sono state verificate durante l'implementazione con test automatici (`tools/test.sh`) o con screenshot affiancati alla versione JS. Le altre richiedono di giocare con tastiera, mouse, gamepad e audio, e vanno controllate a mano.

## Controlli
- [ ] WASD, mira col mouse, sparo tenendo premuto il tasto sinistro
- [ ] Frecce per mirare e sparare
- [ ] Spazio e Shift per lo scatto; cariche di scatto sotto i piedi
- [ ] Vampata con tasto destro e F; «Olio insufficiente»
- [ ] Consumabili 1–4; E per interagire; Tab/M mappa; Esc/P pausa
- [ ] Gamepad: stick, A, B, X, Y, LB, RB, RT, croce, Start, Back
- [ ] Passaggio mouse ↔ gamepad a metà partita (mira e icone dei tasti)

## Sensazione
- [ ] Velocità di movimento e scatto identiche
- [x] Cadenza, velocità e gittata dei proiettili identiche
- [ ] Scivolamento sugli spigoli delle porte
- [ ] Hitstop, scossa, flash ai colpi subiti e ai critici

## Luce e olio
- [ ] Raggio della luce che si restringe con l'olio
- [ ] Buio più fitto senza olio in combattimento, scritta BUIO
- [ ] Stanze ripulite più chiare
- [ ] Bracieri, monete e proiettili che illuminano; occhi rossi nel buio

## Stanze e contenuti
- [x] Stanza iniziale con tutorial a terra
- [x] Stanze normali a una o due ondate, porte che si chiudono e riaprono
- [x] Tesoro: due reliquie, se ne prende una sola
- [ ] Mercante: prezzi, battute, acquisti, «Borsa piena», «Sei già in forze»
- [x] Santuari: sangue, fortuna, fonte, idolo
- [x] Stanza segreta aperta con una bomba (crepe sul muro)
- [ ] Rocce incrinate, barili che esplodono, urne, spuntoni
- [ ] Ratto, pipistrello, scheletro, teschio, ghoul; campioni d'élite con contorno colorato

## Progressione
- [x] Livelli: scelta dei doni a stanza sicura, rilancio con R
- [x] Doni, reliquie e maledizioni applicati (pannello statistiche in pausa)
- [x] Il Custode delle Ossa: due fasi, pattern, morte, botola
- [ ] Fine della demo con riepilogo
- [x] Sblocco della Lanterna del Pellegrino dopo il guardiano
- [ ] Morte, game over con «Ucciso da», abbandono dalla pausa

## Salvataggio e opzioni
- [ ] Volumi di musica ed effetti, scossa, numeri del danno, schermo intero (anche F11 e Alt+Invio)
- [ ] Archivio aggiornato tra una sessione e l'altra (chiudere e riaprire)
- [ ] Pausa automatica quando la finestra perde il fuoco

## Audio
- [ ] Musica del titolo e delle Cripte, intensità che cresce in combattimento e al boss
- [ ] Tutti gli effetti sonori presenti e riconoscibili

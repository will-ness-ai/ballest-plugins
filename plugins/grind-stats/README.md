# Grind Stats

Per-track grind stats for Ballest of Them All, after Trackmania's Grinding Stats plugin. A small card in the top
left of every track shows:

| Row | Meaning |
|---|---|
| TOTAL | Time played on this track, all-time |
| SESSION | Time played since the track was loaded |
| ATTEMPTS | Runs started, all-time, and this session in lime |
| FINISHES | Runs finished, all-time, and this session in lime |

Time only counts while a race is running, the game isn't paused, and you've steered or jumped in the last five
seconds. Restarting doesn't start a new session; loading the track again does.

- **F6** hides and shows the card until the game closes. **Show card** in the plugin's settings hides it for good.
- **F8** writes the track's stats to the plugin manager's log.
- The card can be dragged anywhere while the cursor is on screen.

Stats are kept per track in the plugin's storage, so they survive updates and reinstalls.

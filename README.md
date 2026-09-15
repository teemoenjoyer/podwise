# PodWise

An Android life tracker and pod builder for Magic: The Gathering Commander.

Commander is a four-player format played at 40 life, where damage comes from
every direction and each player tracks damage from every opponent's commander
separately. Paper and pen works, but it drifts. PodWise is the phone that sits
flat in the middle of the table: life totals face outwards, every number is a
big tap target, and the things a table actually argues about — who goes first,
who is out, who is playing whom next week — have a button.

It works completely offline. The only network call is looking up commander
cards, and those are cached so a table with no signal still works.

> Unofficial fan project. Card data and images come from
> [Scryfall](https://scryfall.com). Not affiliated with, endorsed or sponsored
> by Wizards of the Coast.

---

## Features

### The board

A landscape board with one panel per player, two to ten. Panels above the
midpoint are rotated 180° so they read right-side-up to the player sitting
opposite. Life numerals scale to fill whatever space a seat gets.

- **Tap to adjust life.** Taps within about two seconds batch into one change
  and show a running `+5` while you go, so a mis-tap is corrected before it
  lands. There is deliberately no undo stack — the window replaces it.
- **Commander damage, per commander and per player.** Not "Bob has 12
  commander damage" but "Bob has taken 12 from Sarah's Atraxa and 6 from
  Chris's Krenko". The 21-damage threshold is flagged per source, and a player
  with two partners tracks each one separately. Commander damage also reduces
  life, which is the mistake most trackers make. A player who never entered a
  commander still has one in the command zone, so they get a stand-in source
  and can deal it like anybody else.
- **Counters and statuses.** Poison (lethal at 10), energy, experience, rad,
  storm, commander tax, Ring temptations and treasure; Monarch, Initiative,
  City's Blessing, and Day/Night. Monarch and the Initiative move to whoever
  takes them rather than being held by two players at once, and Day/Night
  replace each other across the table.
- **Elimination is always asked, never assumed.** Commander has many loss
  conditions, so hitting zero raises a prompt rather than knocking you out.
  Ten poison and twenty-one from a single commander do the same, because they
  mean the same thing — and the prompt says which of the three it was, since
  "at 40 life" on its own reads as the app asking at random. Recovering and
  going back under asks again; sitting at −7 does not nag.
- **The last player standing wins automatically.** Once everyone else is out
  there is nothing to decide, so the game ends itself and saves.
- **A hidden game clock** that starts with the game. It runs whether or not it
  is on screen; Settings puts it on the board if you want to see it.
- **The screen stays awake** while a game is in progress.

### Starting a game

Saved players are reused between sessions, so nobody retypes names. Starting
life presents **40** as already decided — it is right for all but a handful of
games — with the other totals and a free-text option one tap behind it.
Anything other than 40 is flagged, because starting a Commander game on 20 by
accident is a miserable way to find out.

Commanders are searched from Scryfall, with partners, backgrounds and
Doctor/companion pairings all supported. Non-legal cards (silver-bordered
Secret Lairs and similar) are offered with a **NOT LEGAL** badge rather than
hidden, because Commander is a Rule 0 format — a setting restricts the search
to sanctioned cards if your group prefers.

### Who goes first

A draw offered once as the board opens. Names sweep and decelerate with a
click per name — a ratchet slowing down, not an even buzz — then land on one
player, whose name pops out of a small burst of sparks. The winner is recorded
so the question is not asked twice. Skipping counts as an answer. Available
any time from the in-game menu.

The sparks are painted beside the names rather than laid out among them, so a
celebration can never push the buttons off a landscape screen.

### Dice

d4, d6, d10 and d20 from the in-game menu, with the last few rolls of the
current die kept so a table rolling off against each other can remember what
everyone got.

### Pod Builder

The part that is not just a life counter. Given a list of players it
enumerates every legal way to split them and scores each one, so nine people
become 5 + 4 rather than an argument.

The Pod Builder still splits at six to a pod — ten at one table is for the
nights when everybody insists on playing together. Pod sizes default to one
table up to six players, then 4+3 at seven, 4+4 at
eight and 5+4 at nine; a pod of three is only allowed alongside a pod of four.
You can override the number of pods.

Seven modes, each weighting the same measures differently:

| Mode | Optimises for |
| --- | --- |
| Random | Pure shuffle, no balancing |
| Fairest | Even estimated deck power between pods |
| Diverse | Variety of colours, commanders and strategies |
| Fresh Matchups | Separating people who keep playing each other |
| Casual Balance | Stopping the strongest decks stacking into one pod |
| Competitive Balance | Putting the strongest decks at the same table |
| Smart Pods | Everything: power, variety, history and answers |
| Deck Roulette | Random pods, and everyone plays somebody else's deck |

**Deck Roulette** deals the group's decks back out at random. Nobody is handed
their own list, no deck is dealt twice — it is a physical object and cannot be
at two seats at once — and each player has a re-roll if they would rather have
something else. The night goes into history and counts towards everyone's win
rate, but it **never touches a deck's power rating**: how a deck performs in a
stranger's hands says nothing about how it plays in its owner's.

Casual Balance and Competitive Balance are deliberate opposites. Casual
spreads the strong decks out so no table is lopsided; Competitive groups them,
so cEDH plays cEDH and the precons play each other.

Every result comes with a **"Why these pods?"** panel rating power balance,
strategy and colour diversity, repeat matchups and available answers in plain
words, so the table can disagree with it and hit REBUILD.

Where the group has told the app nothing, a measure scores **neutral rather
than badly** — absent data is not evidence of a bad pod.

### Decks, players and statistics

Each player owns a **library of decks**. Power, archetypes, colour identity
and win/loss all belong to the deck, not the person: someone who brings a
precon one week and a tuned list the next is two different opponents, and
averaging them would mislead the Pod Builder about both.

- Deck power is rated 1–10 by hand — Scryfall describes the commander, never
  the 99 cards behind it — and then **corrects itself** from that deck's own
  results. The correction needs four games and is capped at ±1.5, so a lucky
  night cannot overrule the group's judgement.
- Choosing a commander when starting a game saves it as a deck automatically.
- Per player: games, wins, win rate, average finish, average game length and a
  "plays against" breakdown. Figures below five games are shown muted, because
  "100% win rate" after one night is worse than showing nothing.
- **Finishing position comes from the order players were knocked out**, never
  from life totals. First out finishes last. A player eliminated from 38 life
  ranks below somebody who limped to the end on 2.

### Passing a pod to another phone

Only one pod can be tracked on one phone, so the rest of a game night would go
unrecorded — and the statistics would quietly become a biased sample of the
pods you personally sat in.

A built pod can be handed to a friend's phone as a **QR code** (or a pasteable
text code). Their phone tracks that pod's life totals and hands the result
back as a second code, which drops into your history with the right decks
attributed. No server, no accounts, nothing to sign in to.

The receiving phone is a **borrowed scoreboard**: it writes nothing to its own
history, players, decks or statistics, so your playgroup never appears in
theirs. It does keep the in-progress game on disk, because a borrowed pod runs
for an hour or two on a phone whose owner will open other apps, and losing it
would lose the result with no way to recover it.

A result is only accepted by the phone that sent the pod out, and importing
the same result twice is refused rather than doubling everybody's record.

### Elsewhere

- **Game history** with winner, duration and final standings.
- **Four themes**: Dark Fantasy (candlelit gold), Minimal (greyscale), Arcane
  (violet) and Gremlin Mode.
- **Haptics** on by default, **sounds** off — a beep per life point gets old
  fast at a table.
- Everything is stored in one local SQLite file, so it backs up as a unit.

---

## Building it

Android only. You need the Flutter SDK and the Android SDK; Android Studio's
bundled JDK is the easiest way to get a JDK the Android Gradle Plugin accepts.

```bash
flutter pub get

# Drift generates the database code, and it is checked in — re-run after
# changing any table in lib/data/database.dart.
dart run build_runner build

flutter test
flutter analyze

flutter run                              # onto a device or emulator
flutter build apk --debug                # for adb install -r
flutter build apk --release --split-per-abi
```

A release build is about **27MB** for arm64. Debug builds are far larger
because they carry every ABI and the JIT snapshot.

`flutter build apk --release` works without a signing key — the release build
type is wired to the debug signing config. Replace that before shipping
anywhere.

The debug build uses the application id
`io.github.teemoenjoyer.podwise.debug`, so it installs alongside a release or
profile build. That is how the two-phone transfer flow is tested on a single
emulator.

---

## How it is put together

```text
lib/
  domain/    Pure Dart. No Flutter imports, no I/O.
             Game state, pod scoring, the transfer codec, dice.
  data/      SQLite via Drift, and the Scryfall client.
  state/     Riverpod providers — the only place the two meet.
  features/  One folder per screen.
  core/      Theme and haptics.
```

The rule worth knowing: **`domain/` is pure**, so the parts most worth testing
— pod scoring, the transfer codec, finishing order, dice — are testable with
no device and no database. 224 tests run in about fifteen seconds.

### The Pod Builder algorithm

1. Enumerate every legal split of the selected players into pods of the
   allowed sizes. Ten players give 126 distinct splits; a playgroup is small
   enough that exhaustive search beats anything cleverer.
2. Score each split on seven measures, all normalised to 0–1 where 1 is
   better: power balance, power tiering, colour diversity, archetype
   diversity, fresh matchups, interaction coverage, and player-count balance.

   Power balance and power tiering are opposites, and no mode weights both.
   Tiering is measured as the average *variance* within each pod rather than
   the spread between pods — squared error, so one badly placed deck in an
   otherwise tight table costs more than several small differences.
3. Weight those by the chosen mode, sort, and keep the best twelve. REBUILD
   steps through that shortlist rather than recomputing the same answer.

Power uses each deck's **self-corrected** rating, so the algorithm improves as
the group records games without anyone re-rating anything.

### Data model

Six tables — players, games, game participants, decks, a Scryfall card cache,
and key/value settings — currently at schema version 9. Every migration
preserves existing games; the v6 upgrade turned the old one-deck-per-player
row into a deck library and back-filled history so nobody lost a
self-corrected power rating.

Every step is additive except **v9**, which is the one migration that rewrites
existing rows. It reconnects decks that know their commander's name but not
its card id — everything v6 carried over, since the table it read from
predated card ids. Those decks showed a commander everywhere a name was
enough and nowhere the card was needed: no art, and commander damage tracked
against a stand-in source rather than the real card.

It matches by exact name against the local card cache, so it needs no network,
and rewrites a deck only when **every** one of its commanders resolves to
exactly one cached card. A name held by two cached printings is left alone
rather than guessed at, and so is one the cache has never seen — attaching the
wrong card is worse than attaching none, because commander damage is tracked
per card. Anything it cannot reconnect still shows its commander's name, which
the game now carries alongside the cards for exactly this case.

### Offline behaviour

Card search hits Scryfall (rate-limited, with a proper User-Agent) and falls
back to the local cache on any failure, ranked by how often your group has
actually picked each card. A lookup failure never reaches an error screen.

---

## Known limitations

- **A game in progress is held in memory.** Backgrounding the app is fine, but
  if Android kills the process the game is lost. Borrowed pods are the
  exception — those are written to disk, because nobody else has a copy.
- **No undo, no event log, no turn tracker.** Deliberate. The two-second
  batching window covers mis-taps.
- **Deck power and archetypes are self-reported.** The app cannot see the 99
  cards. Treat every pod score as an estimate, never a measurement.
- **Sounds use the platform's own UI clicks** rather than bundled audio, which
  would need sourcing and licensing.
- **Card art needs a network connection the first time.** A pod imported from
  another phone offline shows commander names without art, and falls back to
  name-only placeholders so commander damage still tracks.
- **A result can only go home to the phone that sent the pod.** There is no
  way to merge two people's histories, and with no server there never will be.
- **Your friend needs PodWise installed.** With no server there is nothing to
  put an install link behind.
- **Player names are not unique.** Two players called Dave are two separate
  records and are indistinguishable in history.

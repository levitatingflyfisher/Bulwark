# Tutorial: your first week

*Learning-oriented — this walks you through installing Bulwark and using it
for real for seven days. It assumes nothing except that you have the app
open.*

## Day 0: install and onboard

Open the [PWA](https://levitatingflyfisher.github.io/Bulwark/) or install the
sideloaded APK, then launch it. Onboarding is three short steps:

1. **Read the welcome and the disclaimer.** Bulwark is habit-tracking with
   health education, not medical advice — you'll see this line again on
   every intervention card, so it isn't a one-time speed bump, it's a
   standing fact about the app.
2. **Map your day.** Set your wake and bed times (required), and optionally
   your meal times. Habits stick better when they hang off a moment you
   already live through, so these times are what the engine anchors
   suggestions to — skip a meal time and Bulwark simply won't suggest
   anything anchored to it. Pick what matters most right now (sleep, energy,
   pain, longevity, immunity, or general health) and how much you want to
   take on at once — one at a time, a couple, or a few. If you're caring for
   a newborn, flip the "Caring for a newborn?" switch; it queues a
   survival-stack bundle tuned for fragmented sleep once you're set up (see
   [content-schema.md](../reference/content-schema.md#presetsjson) for exactly
   what's in it). You can also set an optional daily check-in reminder time
   here — leave it blank and Bulwark never reminds you about anything.
3. **Meet your starter pack.** Based on your goal and your chosen pace,
   Bulwark picks 1–3 free, low-time-cost habits anchored to moments you just
   told it you have. Tap **Start tonight** and they go active immediately —
   no separate "activate" step for the starter pack.

You land on Home. Until your first check-in, the top of it says what the
daily job is, and until you set up backup a dismissible line says your data
is only on this device; neither blocks anything.

## Day 1–6: the daily check-in

Each day, open the **Check in** button from Home. For every active habit
you'll see one row with three choices:

- **Did it** — you did the thing.
- **Skipped** — you made a call not to, on purpose.
- **Forgot** — the trigger didn't work; this is tracked separately from
  "skipped" because a repeated "forgot" is a signal the anchor needs
  changing, not that you need more willpower. After three forgets in two
  weeks, that habit's card on Home offers **Change the moment** (or **Not
  now**), so you can hang it off a moment that works.

Each answer is saved the moment you tap it; there is no Save to forget, and
leaving the screen any way you like keeps what you tapped. **Done** just
takes you back. Once you've answered a row you can add a note if you want
to record why (optional, and it's yours; nothing leaves the device). The
whole check-in is meant to take under thirty seconds. There is no streak counter anywhere on this screen —
missing a day is just a data point, not a broken chain.

## Somewhere in week two or three: the queue and the gate

Once your starter pack habits feel routine, open **Queue** from the menu and
tap **I'm ready for another**. Bulwark looks at how your current habits are
settling — how recently you added one, how many you're juggling, whether any
of them are shaky — and gives you a verdict:

- If it looks like a good time, you'll see **Activate `<habit>`** for the
  top of your queue.
- If it advises waiting, you'll see the specific, kind reason (never more
  than a sentence or two) *and* an **Add `<habit>` anyway** button in the
  same breath. The gate only ever advises — see
  [why-advisory-not-blocking](../design-philosophy.md#why-advisory-not-blocking)
  for the reasoning. Nothing in Bulwark can stop you from doing what you
  want.

## Weeks three to six: graduation and the wall

Keep a habit active for at least three weeks with a strong recent adherence
rate and Bulwark will suggest it's ready to graduate — you confirm "this is
automatic now," and it becomes a **stone** on the **Progress** screen's wall.
Open Progress any time to see:

- **The wall itself** — one stone per graduated habit, tap any stone for its
  name and graduation date. The habits you're working on show as outlined
  stones on top; tap one to see which it is and when you started it. The
  line above the wall counts both.
- **A weekly adherence trend** — bars, not a percentage of shame, showing
  the last few weeks.
- **The "made automatic" list**, in case a picture of stones isn't specific
  enough for you.

Once a habit graduates, its daily check-in row disappears and is replaced by
a **weekly pulse** (solid / shaky) that shows up on the Check-in screen on
your pulse day. Two shaky weeks in a row weathers that stone — it cracks and
tints clay, and Progress offers a **Repoint** button that reactivates the
habit as a normal daily one again. The stone never disappears; at worst it
just needs a little masonry work.

## Whenever you want more, or less

- Browse the full **Library** any time — search, filter by category or
  minimum evidence, and open any item's detail card for the full mechanism,
  evidence explanation, safety note, and (where relevant) generic shopping
  criteria.
- Adjust your day map, pace, evidence floor, reminders, or New Parent Mode
  from **Settings** any time — see
  [everyday-tasks.md](../how-to/everyday-tasks.md) for the exact steps, plus
  how to turn reminders on and export your data.

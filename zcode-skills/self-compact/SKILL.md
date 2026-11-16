---
name: self-compact
description: Shrink this session's context and keep the work running. A session cannot run the /compact client command itself, so it messages itself through the zcode-sessions MCP — a delivered `/compact <handoff>` performs the compaction, a second wake message resumes the work. Triggers — `/self-compact`, «закомпакть сессию», «ужми контекст сессии и продолжай работу», «контекст раздулся — сократи его, не останавливаясь». Use when the user asks to compact a long-running session's context without ending the work.
---

# self-compact

`/compact` is a client command — the model cannot invoke it from inside its own turn.
The workaround, proven live (2026-11-16, sess_b8ee2451): a message delivered through the
zcode-sessions automation queue while the session is **idle** is parsed by the client
exactly like a typed input, slash commands included, and `/compact <handoff>` runs as a
standalone compaction turn — the handoff text is woven into the summary (a role statement
lands there verbatim).

Delivery state decides everything (failed runs 2026-11-16, sess_608e32de): the client
picks the delivery mode from the target's state — a message landing while the session
runs a **model turn** is delivered as **guide** (a steer: text spliced into the running
turn; slash commands in it do NOT execute — that killed both first attempts), while a
message landing on an **idle** session is delivered as a real input and commands run. A
message that comes due during the model-less compaction turn is held in the queue and
delivered as a real input once the summary is done (observed live: held ~2 min, clean).
`send_message` has no mode parameter — the delays do the work, by landing each message
on the right state: the compact on an idle session, the ping after the compaction.

## Procedure

1. Bring the current item to a stable point — commit, merge, or report sent. The handoff
   describes finished work; an in-flight edit loses its details to the summary. Done when
   the state fits the sentence «сделано X, осталось Y».
2. Learn your own session id if it is not already in context:
   `mcp__zcode-sessions__current_session`.
3. Compose the handoff (structure below).
4. `mcp__zcode-sessions__send_message(<self>, "/compact " + handoff, delay_seconds: 45)`
   — then STOP DEAD: no verification of the sends, no summary of what was done, no
   retry loop on a failed ping, at most one short sentence to the user. The compact's
   landing depends on the turn closing fast — the closing model step still runs (5-15 s,
   with rare spikes), and 45 s covers it.
5. `mcp__zcode-sessions__send_message(<self>, ping, delay_seconds: 240)` — the ping is a
   one-line wake-up: «Продолжай работу по плану из саммари. Если история до этого
   сообщения не свёрнута в саммари — /compact не исполнился, прогони /self-compact
   заново.» From the compact delivery to the finished summary takes ~180-200 s (a
   ~100 s start gap plus the 80-100 s summary run); 240 s clears that window, and if
   the compaction is still running the queue holds the ping and delivers it as the
   next real input — the session wakes and continues on its own.
6. That is the whole turn: send, send, stop. Everything from here is automatic — the
   compaction turn runs, the ping wakes the session.

If the user keeps talking to the session inside the 45 s window, the compact may land as
a steer and not execute — the ping's self-check catches exactly that: the session sees
its full history instead of a summary and reruns `/self-compact` (a user interrupt with
real work legitimately wins over the rerun; compaction waits for the next call). A ping
lost to a locked-DB write is not retried past the stop: the compact still runs, and the
next incoming message (user input or a worker report) wakes the session anyway. Reports
from other sessions queued during the compaction deliver afterwards, unaffected.

## Handoff structure

The handoff sets the accents of the summary, it does not replace it: the compactor
summarizes the whole conversation anyway, and what the handoff names prominently survives
(verified: commit hashes, a conflict-resolution recipe, and do-not-touch notes all made
it into the summary's Pending/Current/Next sections). Write state, not commands:

- **Role passport** — «Ты — <роль> в <repo, branch>» plus what normal traffic looks like:
  reports from other sessions arrive here as user inputs — name them, or the
  post-compact self won't recognize them. Lands in the summary verbatim.
- **Done** — areas/tasks with commit hashes and paths.
- **Left** — next steps with session ids, worktrees, branches; expected conflicts and
  their resolution recipes.
- **Caveats** — whose commits to leave alone, what runs only on an explicit user request.

One boundary: the handoff states the situation and never carries the self-compact
instruction itself — a «пошли себе /compact» phrase survives into the summary and may
fire again after the compaction. The wake carries the continuation; the handoff carries
the state.

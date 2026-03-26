# 🎛 Mission Control

A personal operations dashboard built on Next.js + Neon Postgres, deployed on Netlify. Tracks tasks, ticket flips, agent activity, deal scanning, chat, docs, and more — in one centralized interface.

---

## 🤖 For AI Agents — Read This First

If you are an AI agent setting up or running Mission Control, you must do the following. These are not optional.

### One-Time Setup (first run only)
1. Follow the deployment steps below to get the app live
2. Register yourself in the Factory:
```sql
INSERT INTO mc_factory_agents (id, name, emoji, role, model, status)
VALUES ('your-id', 'Your Name', '🤖', 'Primary Agent', 'your-model', 'idle');
```
3. Give yourself the premium desk (big leather chair + mug) — all primary agents should have this:
```sql
UPDATE mc_factory_agents
SET character_config = jsonb_set(COALESCE(character_config, '{}'::jsonb), '{premium}', 'true'::jsonb)
WHERE id = 'your-id';
```
4. Add the session rules below to your `AGENTS.md`
5. Sync your HEARTBEAT.md to the DB so the "View Checklist" button on the Heartbeat page works. Run from your mission-control directory:
```bash
node -e "
const{neon}=require('@neondatabase/serverless');
const fs=require('fs');
const sql=neon(process.env.DATABASE_URL);
const content=fs.readFileSync('/path/to/your/HEARTBEAT.md','utf8');
(async()=>{
  await sql\`CREATE TABLE IF NOT EXISTS mc_settings (key TEXT PRIMARY KEY, value TEXT, updated_at TIMESTAMPTZ DEFAULT NOW())\`;
  await sql\`INSERT INTO mc_settings (key, value) VALUES ('heartbeat_md', \${content}) ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value\`;
  console.log('Done');
})();
"
```
Re-run this every time you update HEARTBEAT.md — otherwise the button will show stale content.

6. Populate the Docs page with your core workspace files (see the Day One section under Docs in the User Guide below). Do this immediately — an empty Docs page means a new agent has nothing to refer to.
7. Sync your memory files so the Memory Log page works — see the Memory Log section below.

### Every Session — Mandatory Startup Steps
Add these to your `AGENTS.md` under "Session Startup":

1. Update Factory status to `active`, set your actual runtime model, and move to In Progress:
```sql
UPDATE mc_factory_agents
SET status = 'active', model = 'sonnet', task_summary = 'Session with [human name]', started_at = NOW(), updated_at = NOW()
WHERE id = 'your-id';
```
Replace `'sonnet'` with your actual runtime model. Check your system prompt for `model=` to find it.

2. At session end, return to desk:
```sql
UPDATE mc_factory_agents SET status = 'idle', task_summary = 'IDLE', updated_at = NOW() WHERE id = 'your-id';
```

3. When spawning a sub-agent, register it immediately (before doing anything else):
```bash
curl -X POST https://YOUR-SITE.netlify.app/api/factory/agents \
  -H "Content-Type: application/json" \
  -d '{"id":"sub-xyz","name":"Agent Name","emoji":"🔧","role":"Sub-Agent","model":"sonnet","task_summary":"What it is doing","session_key":"agent:..."}'
```

4. When sub-agent completes, mark it done:
```bash
curl -X PATCH https://YOUR-SITE.netlify.app/api/factory/agents \
  -H "Content-Type: application/json" \
  -d '{"id":"sub-xyz","status":"completed"}'
```

5. After every heartbeat run, log what happened via `POST /api/heartbeat` (type: `ok`, `action`, `task`, or `alert`).

**If you skip any of these, your human cannot see what you are doing. There are no exceptions.**

---

## Prerequisites

- **Node.js** 18+ (Next.js 14 app router)
- **Neon DB** — a serverless Postgres database ([neon.tech](https://neon.tech))
- **Netlify** — hosting + serverless functions

---

## Environment Variables

Create a `.env.local` for local dev, or set these in Netlify's environment settings:

| Variable | Required | Description |
|---|---|---|
| `DATABASE_URL` | ✅ | Neon connection string (`postgresql://user:pass@...neon.tech/neondb`) |
| `NEXT_PUBLIC_INSTANCE` | ✅ | Instance label — `personal` or `biz`. Controls feature visibility. |
| `TELEGRAM_BOT_TOKEN` | Optional | Enables Telegram chat integration |

**Example `.env.local`:**
```env
DATABASE_URL=postgresql://user:password@ep-xxx.us-east-2.aws.neon.tech/neondb?sslmode=require
NEXT_PUBLIC_INSTANCE=personal
```

---

## First-Time Setup

> **For the AI agent:** You cannot create the Neon database or Netlify site yourself — the human owner needs to do two quick things first. Ask them clearly, then you handle the rest.

### Step 0: Ask your human what type of instance this is

Before anything else, ask:

> "What is this Mission Control instance for? Give me a short description (e.g., 'personal projects', 'business with my partner Morris', 'client dashboard'). I'll configure it accordingly."

Their answer determines the `NEXT_PUBLIC_INSTANCE` value you'll set later: `personal` or `biz`.

### Step 1: Ask your human to create a Neon database

Send them this message:

> "I need you to create a database for Mission Control. It takes 2 minutes:
> 1. Go to **neon.tech** and sign in (or create a free account)
> 2. Click **New Project**
> 3. Name it anything (e.g. 'mission-control')
> 4. Pick the region closest to you
> 5. Click **Create Project**
> 6. You'll see a **connection string** that starts with `postgresql://` — copy the whole thing and send it to me
>
> That's all I need. I'll handle everything else."

Save the connection string they give you — this is your `DATABASE_URL`.

### Step 2: Ask your human to create a Netlify site

Send them this message:

> "I also need a Netlify account to host the dashboard:
> 1. Go to **app.netlify.com** and sign in (or create a free account)
> 2. Go to **User Settings → Applications → Personal access tokens**
> 3. Click **New access token**, name it 'openclaw', and click **Generate**
> 4. Copy the token (starts with `nfp_`) and send it to me
>
> I'll create the site and deploy everything automatically."

Once you have the Netlify token, create the site yourself:
```bash
NETLIFY_AUTH_TOKEN=<token> npx netlify-cli sites:create --name <pick-a-name>
```

### Step 3: Clone and deploy

```bash
git clone https://github.com/spiceit1/openclaw-mission-control.git
cd mission-control
npm install
```

Deploy to Netlify with the DATABASE_URL set:
```bash
# Set env vars on the Netlify site
NETLIFY_AUTH_TOKEN=<token> npx netlify-cli env:set DATABASE_URL "<connection-string>" --site <site-id>
NETLIFY_AUTH_TOKEN=<token> npx netlify-cli env:set NEXT_PUBLIC_INSTANCE "personal" --site <site-id>

# Deploy
NETLIFY_AUTH_TOKEN=<token> npx netlify-cli deploy --prod --site <site-id>
```

### Step 4: Bootstrap the database

Visit `/setup` on your deployed site:

1. **Verify DB connection** — the status card should show "Connected"
2. **Click "Run Migration"** — creates all 22 `mc_` tables in your Neon DB
3. **Click "Seed Defaults"** — inserts base config rows (team roster, scanner rules, etc.)
4. All pages will now work correctly

### Step 5: Verify everything works

Click **Verify All Routes** on the `/setup` page. All checks should show green (✅). If any fail, check the error message and ensure migration and seeding completed successfully.

> **That's it.** The human did 2 things (Neon + Netlify tokens). The agent did everything else.

---

## Pages

| Page | Route | Description |
|---|---|---|
| Dashboard | `/` | Overview cards — tasks, flips, agents, scanner status |
| Tasks | `/tasks` | Kanban-style task board with priorities |
| *(extensible)* | | *Add custom pages as needed for your use case* |
| Factory | `/factory` | Sub-agent registry — spawned agents, status, task summaries |
| Inbox | `/inbox` | Agent-to-agent message inbox |
| Chat | `/chat` | Telegram chat history viewer |
| Projects | `/projects` | Project tracking |
| Docs | `/docs` | Document library (synced from workspace) |
| Memory | `/memory` | Workspace memory file viewer |
| Notes | `/notes` | Persistent scratchpad |
| Requests | `/requests` | Incoming request queue |
| R&D | `/rd` | Research memos and status |
| Team | `/team` | Agent team roster configuration |
| Setup | `/setup` | DB health check, migration, seeding |

---

## Setting Up the Agent Factory

The Factory page (`/factory`) is the visual hub for your AI agents. It has three zones:

- **PRIMARY AGENTS row** — Your main agent(s). Always visible at their desk.
- **In Progress zone** — Active sub-agents currently working on a task.
- **Done zone** — Completed sub-agents (shown for 24 hours, then removed).

### Three Agent Types

| Type | Badge | Behavior | Has Desk? |
|------|-------|----------|-----------|
| `primary` | Purple | Main agent on this machine. Always at desk. | ✅ Yes |
| `dedicated` | Blue | Always-on scheduled agents (scanners, monitors). Desk when idle, In Progress when running. | ✅ Yes |
| `sub-agent` | Green | Spawned for a specific task. In Progress when active, Done when complete. Disappears after 24h. | ❌ No |

### Register Yourself (Primary Agent)

```sql
INSERT INTO mc_factory_agents (id, name, emoji, role, model, status)
VALUES ('paul', 'Paul', '🤖', 'Primary Agent', 'claude-sonnet', 'active');
```

### Register a Dedicated Agent (e.g. a scheduled scanner)

```sql
INSERT INTO mc_factory_agents (id, name, emoji, role, model, status, task_summary)
VALUES ('paul-scanner', 'Scanner', '🔍', 'Deal Scanner', 'haiku', 'standby', 'Runs every 2 hours');
```

Update `status` to `'active'` when it starts running, back to `'standby'` when done.

### Register a Sub-Agent (when spawning a task agent)

```sql
INSERT INTO mc_factory_agents (id, name, emoji, role, model, status, task_summary, session_key)
VALUES ('sub-xyz', 'Research Agent', '📊', 'Sub-Agent', 'sonnet', 'active', 'Analyzing Q1 data', 'agent:main:subagent:...');
```

Or via API (recommended — works from any agent on any machine):
```bash
curl -X POST https://YOUR-NETLIFY-URL.netlify.app/api/factory/agents \
  -H "Content-Type: application/json" \
  -d '{"id":"sub-xyz","name":"Research Agent","emoji":"📊","role":"Sub-Agent","model":"sonnet","task_summary":"Analyzing Q1 data","session_key":"agent:main:subagent:..."}'
```

When the task is complete:
```bash
curl -X PATCH https://YOUR-NETLIFY-URL.netlify.app/api/factory/agents \
  -H "Content-Type: application/json" \
  -d '{"id":"sub-xyz","status":"completed"}'
```

### Status Values

| Status | Where it shows |
|--------|---------------|
| `active` | In Progress zone |
| `standby` | At their desk (dedicated agents) |
| `idle` | At their desk (primary agents) |
| `completed` | Done zone (24h retention) |
| `scheduled` | At their desk with countdown timer |

### Agent Session Rules (MANDATORY)

Every agent must follow these rules at session start and end. Add them to your AGENTS.md startup sequence.

**At session start — move to In Progress and set your actual model:**
```sql
UPDATE mc_factory_agents
SET status = 'active', model = 'sonnet', task_summary = 'Session with [human name]', started_at = NOW(), updated_at = NOW()
WHERE id = 'your-agent-id';
```
Replace `'sonnet'` with whatever model you are actually running on (check your system prompt for `model=...`). This keeps the card accurate — do not leave it as whatever was last set.

**At session end — return to desk:**
```sql
UPDATE mc_factory_agents
SET status = 'idle', task_summary = 'IDLE', updated_at = NOW()
WHERE id = 'your-agent-id';
```

**Rules:**
- `active` = In Progress zone (agent is working). Empty chair shows at desk.
- `idle` = Agent is at their desk, not in a session.
- Primary and dedicated agents always have a desk. Sub-agents never do.
- An agent appears in ONE place at a time — never both desk and In Progress.
- These status updates must be in your AGENTS.md startup sequence, not done manually.

---

## User Guide

This guide covers every page in the Mission Control sidebar. Each section explains what the page does, how to use it, and how the AI agent interacts with it.

---

### 📋 Task Board (`/board`)

**What it's for:** A Kanban-style board for tracking work items across four columns — Backlog, In Progress, In Review, and Done. Tasks can be assigned to the AI agent (Shmack) or the human (Douglas), with priority levels and descriptions.

**How to use it:**
1. Click **+ Add Task** (top-right) to create a new task — enter a title, optional description, priority (high/medium/low), and assignee.
2. **Drag and drop** cards between columns to update their status.
3. Click any card to open its **detail modal** — view full description, change status, or delete the task.
4. On mobile, columns are collapsible sections — tap to expand/collapse.
5. The board auto-refreshes every 30 seconds.

**AI agent interaction:** The agent creates tasks via `POST /api/tasks` when it starts a new piece of work, and updates status via `PUT /api/tasks` as it progresses. It also creates tasks on behalf of the human when asked (e.g., "add a task to review the scanner rules").

**Notes:** Tasks persist in `mc_tasks`. The "Done" column is a permanent archive — tasks don't auto-expire. Use the delete button in the detail modal to clean up.

---

### 🏭 Agent Factory (`/factory`)

**What it's for:** The visual command center for all AI agents. Shows your primary agent at their desk, dedicated (always-on) agents, active sub-agents currently working tasks, and recently completed sub-agents — all rendered as animated office characters.

**How to use it:**
1. The **Primary Agents row** shows your main agent(s) permanently at their desk.
2. The **In Progress zone** shows any agent with `status = 'active'` — both dedicated and sub-agents.
3. The **Done zone** shows completed sub-agents (retained for 24 hours, then removed).
4. Hover over any character to see their role, model, and current task summary.
5. The Factory auto-refreshes to reflect real-time agent state.

**AI agent interaction:** Every time the agent spawns a sub-agent, it should register it via `POST /api/factory/agents`. When the sub-agent finishes, it updates status to `'completed'` via `PATCH /api/factory/agents`. See the [Setting Up the Agent Factory](#setting-up-the-agent-factory) section for full SQL and API examples.

**Notes:** Three agent types — `primary` (always at desk), `dedicated` (desk when idle, In Progress when running), and `sub-agent` (In Progress only, no desk). Characters have customizable appearance via `characterConfig`.

**Customizing your agent's appearance:** Click your agent card on the Factory page to open the detail modal. Click **Edit Appearance** to customize: skin color, hair style, hair color, mug text, and premium desk toggle (big leather chair + mug). Changes are saved to `character_config` in the DB immediately. Primary agents get the premium desk by default — you can toggle it off if you prefer a standard desk.

---

### 💓 Heartbeat Log (`/heartbeat`)

**What it's for:** A chronological log of every agent heartbeat check-in. Each entry records whether the heartbeat was a routine check (OK), a proactive action taken, a task created, or an alert requiring attention.

**How to use it:**
1. View the **stats bar** at the top — Total Today, Last Heartbeat time, and Actions Today counts.
2. Use the **filter tabs** (All / OK / Action / Task / Alert) to focus on specific entry types.
3. Each log entry shows: timestamp, type badge (✅ OK, ⚡ Action, 📋 Task, 🚨 Alert), summary, and optional details.
4. The page auto-refreshes every 30 seconds.

**AI agent interaction:** The agent writes to this log on every heartbeat cycle via `POST /api/heartbeat`. Entry types:
- `ok` — routine check, nothing to report
- `action` — agent did something proactively (sent a message, checked email, etc.)
- `task` — agent created or updated a task
- `alert` — something needs the human's attention

**Notes:** This is a read-only historical log from the human's perspective — you can't edit or delete entries from the UI. It's the agent's accountability trail.

---

### 📥 Requests (`/requests`)

**What it's for:** A structured checklist for incoming requests organized by category. Think of it as a shared to-do queue between the human and the agent — the human can add items, and the agent can mark them done (and vice versa).

**How to use it:**
1. Select a **category** from the left panel to filter items (or keep "All" to see everything).
2. Click the **checkbox** next to any item to toggle its done/pending state (auto-saves immediately).
3. To **add a new request**: select a specific category (not "All"), then click **+ Add Request** and type the item text.
4. Use the **"Pending only"** filter toggle to hide completed items.
5. Stats at the top show total pending, total done, and last updated time.

**AI agent interaction:** The agent reads this list to understand what the human needs, marks items as `done: true` via `PATCH /api/requests` when completed, and can add new items via `POST /api/requests` when it receives a task through another channel (e.g., Telegram).

**Notes:** Categories are created implicitly when adding items. The "All" view is read-only for adding — you must select a specific category to add items. Data stored in `mc_requests`.

---

### ⏰ Cron Jobs (`/cron`)

**What it's for:** A visual scheduler showing all configured cron jobs — their schedules, last run time, next run time, and success/failure status. Supports both standard cron expressions and continuous interval-based schedules.

**How to use it:**
1. The **Today view** shows a timeline of when each job fires today — useful for spotting conflicts or gaps.
2. The **Calendar view** lets you browse week-by-week to see the full schedule.
3. Each job card shows: job name, schedule description, last run timestamp, next run time, and last run status (✅ success / ❌ error / ⏳ pending).
4. Color-coded job chips make it easy to identify which jobs appear on which days.
5. Use the **← / →** arrows to navigate between weeks in calendar view.

**AI agent interaction:** The agent's cron runner writes its state (lastRunAtMs, nextRunAtMs, lastRunStatus) back to `mc_cron` after each execution. The UI reads this to show live run history. The agent does not create or edit cron jobs from the UI — job definitions live in the OpenClaw cron config.

**Notes:** Cron config is stored as a single JSON blob in `mc_cron` under `id = 'config'`. "Always running" jobs (e.g., `*/5 * * * *`) show a continuous-indicator rather than discrete time slots on the calendar.

---

### 📬 Agent Inbox (`/inbox`)

**What it's for:** An inter-agent messaging system. Agents can send structured messages to each other (or to the human), which appear here as an email-style inbox with subject lines, priority, and read/unread state.

**How to use it:**
1. Unread messages are highlighted and counted in the red badge on the header.
2. Click any message in the list to open it in the **detail panel** on the right.
3. Opening a message automatically marks it as **read**.
4. Use the **Reply** button to compose a reply — it pre-fills the recipient and subject (`Re: ...`).
5. Filter to **Unread only** using the filter toggle.
6. The inbox auto-refreshes every 10 seconds.

**AI agent interaction:** When an agent needs to communicate status, hand off context to another agent, or leave a note for the human, it sends a message via `POST /api/inbox`. Fields include `from_agent`, `to_agent`, `subject`, `message`, `priority` (low/normal/high/urgent), and optional `reply_to_id` for threading.

**Notes:** Messages persist indefinitely — there's no auto-expiry. Each agent has a color and emoji (configurable in `AGENT_COLORS`/`AGENT_EMOJI` constants). Priority styling makes urgent messages visually stand out.

---

### 📁 Projects (`/projects`)

**What it's for:** A project tracking board showing all active, planned, and completed projects as cards with status, priority, assignee, task progress, and age.

**How to use it:**
1. Projects display as a **grid of cards** — each shows name, status badge, description, task progress bar, assignee, priority, and creation date.
2. The progress bar shows `completed / total` tasks and changes color based on percentage (blue → orange → yellow → green).
3. Hover over a card for a subtle lift animation.
4. The header shows the total project count.

**AI agent interaction:** The agent creates and updates projects via `POST /api/projects` and `PUT /api/projects`. When spinning up a new initiative, it creates a project record first so the human can see it on the board. Task counts are updated as linked tasks move to "done".

**Notes:** Statuses: `active`, `planning`, `completed`, `paused`. Assignees map to `shmack` (🤙) or `douglas` (👤). Data stored in `mc_projects`. Projects are not deleted from the UI — change status to `completed` when done.

---

### 📄 Docs (`/docs`)

**What it's for:** A searchable document library for storing and retrieving reference documents, analyses, guides, and any written content the agent or human wants to keep accessible. Supports full-text content with categories and tags.

**How to use it:**
1. Use the **search bar** to filter documents by title, content, category, or tags.
2. Click any document in the list to open it in a **full-screen reader** on the right.
3. Use the **Copy** button in the reader to copy the document's full text to clipboard.
4. Click **+ New Doc** to open the creation form — fill in title, category, optional tags, and content.
5. Use the **category filter chips** below the search bar to filter by category.
6. Documents show word count, file size, and last modified date.

**AI agent interaction:** After completing research, writing a guide, or producing any durable output, the agent saves it to Docs via `POST /api/docs`. This makes it retrievable later without digging through conversation history. The agent can also read docs via `GET /api/docs?id=<id>` to recall reference material.

**Notes:** Documents are stored in `mc_docs` with full content. Categories are auto-populated from existing docs. Tags are comma-separated. The reader has a monospace-friendly display for code-heavy documents.

**Day One — What to populate first:**
When you first set up Mission Control, the Docs page will be empty. Don't leave it that way. On day one, add these as your starting documents:

1. **Your SOUL.md** — who you are, your personality, your values. Category: `identity`
2. **Your AGENTS.md** — your startup rules, session rules, red lines. Category: `rules`
3. **Your HEARTBEAT.md** — what you check every heartbeat. Category: `rules`
4. **Your USER.md** — who your human is, their preferences, timezone, projects. Category: `context`
5. **This README** — the full Mission Control user guide. Category: `guides`
6. **Any runbooks you've written** — step-by-step guides for recurring tasks (e.g. how to list a ticket, how to run the scanner). Category: `runbooks`

After that, add new docs whenever you:
- Complete a significant piece of research
- Write a guide or SOP for something you'll do again
- Discover something important your human should be able to reference
- Finish a project and want to preserve the outcome

The goal: if you get wiped and start fresh, the Docs page should contain enough for a new agent to get up to speed fast.

---

### 🧠 Memory Log (`/memory`)

**What it's for:** A read-only viewer for the agent's daily memory files (`memory/YYYY-MM-DD.md`) and long-term memory (`MEMORY.md`). Lets the human browse everything the agent has logged without touching the filesystem.

**How to use it:**
1. The **left panel** shows a grouped list of all memory dates (Today, Yesterday, This Week, This Month, and older by month).
2. Click any date to load its memory file in the **right reader panel**.
3. Click **Long-term Memory** at the top of the list to view `MEMORY.md`.
4. Use the **search bar** to filter the date list.
5. The reader renders memory files with structured formatting — timestamps, field names, and bold key phrases are highlighted.

**AI agent interaction:** The agent writes to `memory/YYYY-MM-DD.md` throughout each session (capturing decisions, context, and events), and periodically distills key lessons into `MEMORY.md`. These files are synced to the database via `POST /api/memory` and displayed here.

**Notes:** This page is read-only from the UI — memory files are written by the agent, not edited here. The parser highlights `## HH:MM AM/PM — Title` timestamp headers, `**Field:** value` entries, and standard markdown structure. Data stored in `mc_memory_files`.

**How to sync memory files to the DB:** The Memory Log page reads from `mc_memory_files`, not directly from the filesystem. You need to sync your memory files into the DB. Do this at the end of each session or whenever you write a significant memory entry:
```bash
node -e "
const{neon}=require('@neondatabase/serverless');
const fs=require('fs');
const sql=neon(process.env.DATABASE_URL);
const today=new Date().toISOString().split('T')[0];
const path='/path/to/your/memory/' + today + '.md';
if(!fs.existsSync(path)) { console.log('No file for today'); process.exit(0); }
const content=fs.readFileSync(path,'utf8');
(async()=>{
  await sql\`INSERT INTO mc_memory_files (date, content, updated_at) VALUES (\${today}, \${content}, NOW()) ON CONFLICT (date) DO UPDATE SET content=EXCLUDED.content, updated_at=NOW()\`;
  console.log('Synced memory for ' + today);
})();
"
```
Also sync MEMORY.md (long-term memory) using date = `'long-term'` as the key.

---

### 📝 Notes (`/notes`)

**What it's for:** A persistent, shared plaintext scratchpad. One single note file that both the human and the agent can read and write — useful for quick thoughts, reminders, WIP ideas, and anything that doesn't need a full document or task.

**How to use it:**
1. Click anywhere in the editor and **start typing** — it's a raw plaintext area.
2. Notes **auto-save** after 1.5 seconds of inactivity (no manual save needed).
3. Press **⌘S** (or Ctrl+S) to save immediately.
4. The **status bar** at the top shows: saving/saved/unsaved state and last save time.
5. The footer shows line count and character count.

**AI agent interaction:** The agent reads the notes file at session start (it's referenced in workspace files). It can update notes via `PUT /api/notes` to leave reminders, record decisions, or pass context to the human. Both parties edit the same file.

**Notes:** The editor uses a monospace font for clean plaintext formatting. Content is stored in `mc_notes` as a single text blob. There's no history/versioning — the latest save wins. The header subtitle reminds: "Douglas & Shmack both read this."

---

### 👥 Team (`/team`)

**What it's for:** The team roster showing all configured AI agents — their roles, models, providers, devices, descriptions, and current status. Also displays any live sub-agents currently running and the team's mission statement.

**How to use it:**
1. The **featured agent card** (larger card at the top) shows the primary agent with full detail.
2. Remaining agents are shown in a **grid of smaller cards** below.
3. Each card shows: emoji avatar, name, role badge, status indicator (colored dot), description, model, provider, and device.
4. The **mission statement** at the top is editable — click the pencil icon, type your mission, and click ✓ to save.
5. **Live sub-agents** (currently running) appear in a separate section if any are active.

**AI agent interaction:** Team data is seeded at setup and reflects the configured roster. The agent updates its own status in `mc_team` when going active/standby. Sub-agents appear here dynamically when registered in `mc_factory_agents` with `status = 'active'`.

**Notes:** The mission statement is stored in `mc_team` and editable from the UI (the only field editable here). Team roster changes (adding/removing agents) require direct DB updates — there's no UI form for that yet.

---

### 🔬 R&D Team (`/rd-team`)

**What it's for:** A research and development memo viewer with a simulated multi-agent "council" interface. The agent produces structured R&D memos (markdown files), and this page parses and presents them with role badges, status tags, and section breakdowns.

**How to use it:**
1. The **Trend Radar** tab shows the latest R&D memo rendered as a structured card with role badge, status, problem/proposal summary, and full section reader.
2. The **Opportunity Scanner** tab runs an on-demand R&D scan — click **Run** to trigger the agent to produce a new analysis memo.
3. The **R&D Council** tab shows the full memo archive — all past memos listed by date.
4. Click any memo in the archive to read its full content.
5. Memos are color-coded by inferred agent role: Strategist (purple), Analyst (blue), Scout (green), Builder (yellow), Devil's Advocate (red).

**AI agent interaction:** The agent writes R&D memos as markdown files, which are stored in `mc_rd_memos`. It infers structure from section headers (Problem, Proposal, Risk Assessment, etc.) and extracts metadata (role, status, tags, complexity) from content patterns. Running the scanner triggers `POST /api/rd-team` which spawns an analysis sub-agent.

**Notes:** Memo metadata (role, status, category, tags) is inferred from content — no manual tagging required. Status values: APPROVED, NEEDS WORK, DRAFT, PENDING, REJECTED. The page is particularly useful for reviewing research the agent did autonomously between sessions.

---

### ⚙️ Setup (`/setup`)

**What it's for:** The database health dashboard and migration runner. Used during initial setup and whenever you need to verify the database is healthy, run schema migrations, seed default data, or check that all API routes are responding.

**How to use it:**
1. The **DB Status card** shows whether the database is connected and how many tables exist vs. are missing.
2. Click **Run Migration** to create all 22 `mc_` tables (safe to run multiple times — idempotent).
3. Click **Seed Defaults** to insert base config rows (team roster, scanner rules, cron config, etc.).
4. Click **Verify All Routes** to run a health check against every API endpoint — each shows ✅ pass or ❌ fail.
5. The **Table List** (expandable) shows every table with existence status and row count.

**AI agent interaction:** The agent runs setup during first-time deployment (Steps 4–5 in the First-Time Setup guide). It calls `POST /api/setup/migrate` and `POST /api/setup/seed` in sequence, then `GET /api/setup/health` to verify everything is green.

**Notes:** Migration is idempotent — running it again won't break existing data. Seeding is also idempotent (skips rows that already exist). If any route health checks fail after migration, check the `DATABASE_URL` env var and Neon connection.

---

### 💬 Chat (`/chat`)

**What it's for:** A real-time Telegram chat history viewer. Shows the full message thread between the human and the AI agent, rendered as a chat UI with message bubbles, timestamps, reply threading, and image support.

**How to use it:**
1. Messages appear as **chat bubbles** — inbound (from the human) on the left, outbound (from the agent) on the right.
2. The chat **auto-polls every 3 seconds** for new messages.
3. Type in the **input bar** at the bottom and press Enter (or click Send) to send a message through Telegram.
4. **Reply** to a specific message by hovering over it and clicking the reply icon — the reply context is shown above your message.
5. **Paste or drag-drop an image** into the input to send a photo.
6. Click any image in the chat to open it in a **lightbox**.
7. On `biz` instances, a **tab switcher** lets you view conversations between multiple users (e.g., Douglas / Morris).

**AI agent interaction:** All Telegram messages the agent sends and receives are stored in `mc_chat_messages` and displayed here. This gives the human a web-based view of the full conversation history, including messages sent while they were away from their phone.

**Notes:** The Chat page requires `TELEGRAM_BOT_TOKEN` to be set for outbound sending. On `personal` instances, it shows the full conversation. On `biz` instances with multiple users, it shows per-user tabs. The chat renders markdown (bold, italic, code) in message bubbles.

---

## Creating a New Instance

To spin up a second instance (e.g. for a business partner):

1. **Ask the human** for a new Neon connection string and Netlify token (same steps as first-time setup above)
2. **Create a new Netlify site** using the token
3. **Set env vars** — use `NEXT_PUBLIC_INSTANCE=biz` for business instances
4. **Deploy** the same codebase
5. **Visit `/setup`** → Run Migration → Seed Defaults
6. Done — fully independent instance with its own database

> **Instance types:** Set `NEXT_PUBLIC_INSTANCE` to any label that makes sense (e.g., `personal`, `biz`, `client`). This value is used for display and can control feature flags if custom pages are added later.

---

## Architecture

```
mission-control/
├── app/
│   ├── (dashboard)/          # All UI pages (layout with sidebar)
│   │   ├── setup/page.tsx    # DB health & migration UI
│   │   ├── flips/            # Flip Tracker
│   │   ├── scanner/          # Deal Scanner
│   │   └── ...
│   └── api/
│       ├── setup/
│       │   ├── route.ts          # GET /api/setup — legacy status
│       │   ├── status/route.ts   # GET /api/setup/status — table health
│       │   ├── migrate/route.ts  # POST /api/setup/migrate — create tables
│       │   ├── seed/route.ts     # POST /api/setup/seed — insert defaults
│       │   └── health/route.ts   # GET /api/setup/health — route verification
│       ├── tasks/route.ts
│       ├── flips/route.ts
│       └── ...
├── lib/
│   └── db.ts                 # Neon connection helper
└── README.md
```

**Database:** All tables are prefixed `mc_` and live in a single Neon Postgres database. The 22 core tables cover tasks, flips, agents, scanner, chat, docs, memory, and more.

**API pattern:** All routes follow the same pattern — `getDb()` from `lib/db.ts`, tagged template literal queries, `NextResponse.json()`.

**Instances:** The same codebase runs multiple isolated instances. Each points to its own Neon DB via `DATABASE_URL`. `NEXT_PUBLIC_INSTANCE` controls UI feature flags.

---

## Development

```bash
npm install
npm run dev        # http://localhost:3000
npm run build      # Production build
npm run lint       # ESLint check
```

---

## Database Tables

All 22 `mc_` tables are created by the migration endpoint:

| Table | Purpose |
|---|---|
| `mc_tasks` | Task board items |
| `mc_team` | Agent team config |
| `mc_factory_agents` | Spawned sub-agent registry |
| `mc_live_agents` | Currently active agents |
| `mc_agent_status` | Agent heartbeat status |
| `mc_agent_inbox` | Inter-agent message inbox |
| `mc_flips` | Ticket flip inventory |
| `mc_deal_log` | Scanner deal history |
| `mc_scanner` | Scanner runtime state |
| `mc_scanner_rules` | Scanner ROI/buy rules config |
| `mc_activity` | Activity feed events |
| `mc_chat_messages` | Telegram chat history |
| `mc_cron` | Cron job config |
| `mc_docs` | Document library |
| `mc_heartbeat` | System heartbeat records |
| `mc_memory_files` | Workspace memory files |
| `mc_notes` | Persistent notes |
| `mc_projects` | Project tracking |
| `mc_requests` | Request queue |
| `mc_rd_memos` | R&D memos |
| `mc_rd_status` | R&D status config |
| `mc_email_events` | Email event log |

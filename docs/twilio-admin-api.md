# Twilio Admin API

All endpoints require the `x-api-key` header.

Base URL: `https://your-backend.com`

---

## Concepts

### Agents vs Assignments

An **agent** is a person (phone number, name). Created once, reused everywhere.

An **assignment** links an agent to a **queue** (support, hr, sales) or an **edition** (festival UUID). One agent can have many assignments.

Both the agent and the assignment have an `is_active` flag. The IVR only calls an agent when **both** are active. This lets you:
- Globally disable an agent (e.g. on vacation) via the agent's `is_active`
- Disable a specific assignment (e.g. no longer on support) via the assignment's `is_active`

### Queues

Three generic queues: `support`, `hr`, `sales`. These are fixed strings — not database entities.

### Editions

Editions are festivals with a UUID `id`. Each edition can have its own assigned agents and its own opening hours. When callers dial the edition's Twilio number, they reach agents assigned to that edition.

### Priority

Lower number = called first. Agents with the same priority are called simultaneously.

### Opening Hours

Each queue and edition can have opening hours. Editions without custom hours inherit from `support`. The IVR checks hours before routing calls.

Hours format is a JSON object keyed by weekday (0=Sunday, 6=Saturday):
```json
{
  "1": { "open": "08:00", "close": "17:00" },
  "2": { "open": "08:00", "close": "17:00" },
  "3": { "open": "08:00", "close": "17:00" },
  "4": { "open": "08:00", "close": "17:00" },
  "5": { "open": "08:00", "close": "16:00" }
}
```
Days not listed = closed.

---

## Agents

### List all agents
```
GET /twilio/agents
```

Returns agents with their assignments inline:
```json
[
  {
    "id": 1,
    "agent_phone": "+4561234567",
    "agent_name": "Jonas",
    "show_caller_id": 1,
    "is_active": 1,
    "created_at": "2025-01-15 10:00:00",
    "assignments": [
      {
        "id": 10,
        "agent_id": 1,
        "queue_name": "support",
        "edition_id": null,
        "priority": 0,
        "is_active": 1,
        "edition_name": null
      },
      {
        "id": 11,
        "agent_id": 1,
        "queue_name": null,
        "edition_id": "abc-123",
        "priority": 1,
        "is_active": 1,
        "edition_name": "Roskilde 2025"
      }
    ]
  }
]
```

### Get single agent
```
GET /twilio/agents/{id}
```
Same shape as above (single object).

### Create agent
```
POST /twilio/agents
```
```json
{
  "agent_phone": "+4561234567",
  "agent_name": "Jonas",
  "show_caller_id": 1,
  "is_active": 1
}
```
Only `agent_phone` is required. `show_caller_id` defaults to `1`, `is_active` defaults to `1`.

**Response** `201`:
```json
{ "id": 1, "message": "Agent created" }
```

### Update agent
```
PUT /twilio/agents/{id}
```
Send only the fields you want to change:
```json
{
  "agent_name": "Jonas J",
  "is_active": 0
}
```
Updatable fields: `agent_phone`, `agent_name`, `show_caller_id`, `is_active`.

### Delete agent
```
DELETE /twilio/agents/{id}
```
Deletes the agent **and all their assignments** (cascade).

---

## Assignments

### List assignments for an agent
```
GET /twilio/agents/{id}/assignments
```
```json
[
  {
    "id": 10,
    "queue_name": "support",
    "edition_id": null,
    "priority": 0,
    "is_active": 1,
    "edition_name": null
  },
  {
    "id": 11,
    "queue_name": null,
    "edition_id": "abc-123",
    "priority": 1,
    "is_active": 1,
    "edition_name": "Roskilde 2025"
  }
]
```

### Assign agent to queue or edition
```
POST /twilio/agents/{id}/assignments
```

**For a generic queue:**
```json
{
  "queue_name": "support",
  "priority": 0
}
```

**For an edition:**
```json
{
  "edition_id": "abc-123",
  "priority": 1
}
```

Send either `queue_name` or `edition_id`, not both. `priority` defaults to `0`, `is_active` defaults to `1`.

**Response** `201`:
```json
{ "id": 10, "message": "Assignment created" }
```

### Update assignment
```
PUT /twilio/agents/{id}/assignments/{assignment_id}
```
```json
{
  "priority": 2,
  "is_active": 0
}
```
Updatable fields: `queue_name`, `edition_id`, `priority`, `is_active`.

### Remove assignment
```
DELETE /twilio/agents/{id}/assignments/{assignment_id}
```
Removes the assignment only — the agent still exists.

---

## Queues Overview

### List all queues with agent counts
```
GET /twilio/queues
```
```json
{
  "edition_queues": [
    {
      "edition_id": "abc-123",
      "edition_name": "Roskilde 2025",
      "type": "edition",
      "total_agents": 3,
      "active_agents": 2
    }
  ],
  "generic_queues": [
    {
      "queue_name": "support",
      "type": "generic",
      "total_agents": 4,
      "active_agents": 3
    },
    {
      "queue_name": "hr",
      "type": "generic",
      "total_agents": 1,
      "active_agents": 1
    }
  ]
}
```
`active_agents` = both the agent and their assignment are active.

---

## Editions

### List editions with agent counts
```
GET /twilio/editions
```
```json
[
  {
    "id": "abc-123",
    "name": "Roskilde 2025",
    "startDate": "2025-06-28",
    "endDate": "2025-07-05",
    "total_agents": 3,
    "active_agents": 2,
    "is_active_now": 1
  }
]
```
Only shows editions that have agents assigned OR are currently active (within 7 days of start/end).

### Get edition with agents
```
GET /twilio/editions/{id}
```
```json
{
  "id": "abc-123",
  "name": "Roskilde 2025",
  "startDate": "2025-06-28",
  "endDate": "2025-07-05",
  "is_active_now": 1,
  "agents": [
    {
      "assignment_id": 11,
      "agent_id": 1,
      "agent_phone": "+4561234567",
      "agent_name": "Jonas",
      "show_caller_id": 1,
      "priority": 0,
      "assignment_active": 1,
      "agent_active": 1
    }
  ]
}
```

### Assign agent to edition (shortcut)
```
POST /twilio/editions/{id}/agents
```
```json
{
  "agent_phone": "+4561234567",
  "agent_name": "Jonas",
  "show_caller_id": 1,
  "priority": 0
}
```
Only `agent_phone` is required. If the phone already exists as an agent, reuses it. Otherwise creates a new agent.

**Response** `201`:
```json
{
  "agent_id": 1,
  "assignment_id": 11,
  "message": "Agent assigned to edition"
}
```

### Remove agent from edition
```
DELETE /twilio/editions/{id}/agents/{assignment_id}
```
Removes the assignment only. The agent remains in the system.

---

## Opening Hours

### List all opening hours
```
GET /twilio/opening-hours
```
```json
[
  {
    "id": 1,
    "queue_name": "support",
    "edition_id": null,
    "opening_hours": {
      "1": { "open": "08:00", "close": "17:00" },
      "2": { "open": "08:00", "close": "17:00" }
    },
    "updated_at": "2025-01-15 10:00:00",
    "edition_name": null
  }
]
```

### Get hours for a queue
```
GET /twilio/opening-hours/queue/{name}
```
`name` = `support`, `hr`, or `sales`.

Returns `null` opening_hours if none configured (queue is always closed).

### Set hours for a queue
```
PUT /twilio/opening-hours/queue/{name}
```
```json
{
  "opening_hours": {
    "1": { "open": "08:00", "close": "17:00" },
    "2": { "open": "08:00", "close": "17:00" },
    "3": { "open": "08:00", "close": "17:00" },
    "4": { "open": "08:00", "close": "17:00" },
    "5": { "open": "08:00", "close": "16:00" }
  }
}
```
Creates or updates (upsert).

### Get hours for an edition
```
GET /twilio/opening-hours/edition/{id}
```
If no custom hours set, returns the inherited `support` queue hours with `"inherited_from": "support"`.

### Set hours for an edition
```
PUT /twilio/opening-hours/edition/{id}
```
Same body format as queue hours.

### Delete edition hours (revert to inherited)
```
DELETE /twilio/opening-hours/edition/{id}
```
Removes custom hours — edition falls back to inheriting from `support` queue.

---

## Hold Music

### List all tracks
```
GET /twilio/hold-music
```
```json
[
  {
    "id": 1,
    "title": "Ella Augusta",
    "url": "https://upcdn.io/G22nhxN/raw/hold-music/holdmix_ella-augusta.wav",
    "is_active": 1,
    "sort_order": 1,
    "created_at": "2025-01-15 10:00:00",
    "updated_at": "2025-01-15 10:00:00"
  }
]
```
Sorted by `sort_order` ascending. Only tracks with `is_active = 1` play for callers.

### Get single track
```
GET /twilio/hold-music/{id}
```

### Add track
```
POST /twilio/hold-music
```
```json
{
  "title": "Bruno Mars - I Just Might",
  "url": "https://upcdn.io/G22nhxN/raw/hold-music/holdmix_bruno.wav",
  "is_active": 1,
  "sort_order": 5
}
```
`title` and `url` are required.

### Update track
```
PUT /twilio/hold-music/{id}
```
Send only fields to change:
```json
{
  "is_active": 0,
  "sort_order": 10
}
```
Returns the updated track.

### Delete track
```
DELETE /twilio/hold-music/{id}
```

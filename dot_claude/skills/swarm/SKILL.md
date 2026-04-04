---
name: swarm
description: Orchestrate multiple swarms of specialized agents with inter-swarm communication for complex collaborative tasks
---

Orchestrate parallel agent swarms for complex tasks requiring cross-domain coordination.

## Process

1. **Analyze** — Break objective into domain-specific chunks
2. **Design swarms** — Group related work (e.g. backend, frontend, testing, devops). Each swarm gets a leader, clear objective, and success criteria.
3. **Deploy** — Launch swarms as parallel background tasks with specialized prompts
4. **Coordinate** — Share learnings between swarms (API contracts, integration points, dependencies). Monitor progress, rebalance as needed.
5. **Integrate** — Combine deliverables, validate against objectives

## Key principles

- Each swarm is autonomous within its domain
- Share context between swarms proactively (don't let them diverge)
- Define integration points upfront (API contracts, shared types, data formats)
- Dynamically adjust — kill stalled swarms, spin up new ones as needed

## Task

$ARGUMENTS
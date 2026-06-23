@AGENTS.md

# Catalyst Dashboard

Internal operations dashboard for **Catalyst**, a fine art business. It is the single back-office surface for the team, bundling four areas of functionality:

- **Reporting** — sales, revenue, and operational dashboards built from the business's data sources.
- **Gmail automation** — drafting, labeling, and triaging email tied to client and sales workflows.
- **Licensing contract tracking** — tracking fine-art licensing agreements, their parties, terms, and renewal/expiry dates.
- **Scheduled tasks** — Vercel cron jobs that run reporting refreshes, contract reminders, and email automations on a schedule.

This is a private, single-tenant internal tool — not a public-facing product.

## ⚠️ Read this before writing any code

This project runs **Next.js 16.2.9** (App Router, React 19, Tailwind CSS v4). Per `AGENTS.md`, this is **not** the Next.js in your training data — APIs, conventions, and file layout have breaking changes. **Read the relevant guide under `node_modules/next/dist/docs/` before writing or changing code**, and heed deprecation notices. Notable differences already confirmed in the local docs:

- **`middleware` is deprecated → renamed to `proxy`.** Use a `proxy.ts` file at the project root for auth/logging/redirect logic. See `node_modules/next/dist/docs/01-app/03-api-reference/03-file-conventions/proxy.md`.
- **Instant client navigations require `export const unstable_instant`** from a route — Suspense / `loading.js` / streaming alone do not guarantee it. See `node_modules/next/dist/docs/01-app/02-guides/instant-navigation.mdx`.
- Request APIs (`cookies`, `headers`, route `params`) follow the current async model — `await` them.

When in doubt, grep the docs (`grep -rn "AI agent hint" node_modules/next/dist/docs`) — they contain agent-targeted hints.

## Tech stack

- **Next.js 16.2.9** App Router, **React 19.2**, **TypeScript** (strict).
- **Tailwind CSS v4** via `@tailwindcss/postcss` (configured in `postcss.config.mjs`; styles in `app/globals.css`).
- **ESLint 9** (`eslint.config.mjs`, `eslint-config-next`).
- Path alias `@/*` → project root (see `tsconfig.json`).
- Deployed on **Vercel**, including its cron scheduler.

## Commands

```bash
npm run dev     # start dev server at http://localhost:3000
npm run build   # production build
npm run start   # serve the production build
npm run lint    # eslint
```

## Layout & conventions

- `app/` — App Router routes, layouts, and UI. `app/page.tsx` is the dashboard entry; `app/layout.tsx` is the root layout.
- API and cron endpoints belong in **route handlers** (`app/<segment>/route.ts`) using the Web `Request`/`Response` APIs.
- **Vercel cron jobs** are wired to route handlers and defined in `vercel.json` (`crons` array). Each scheduled task should be a route handler that the cron hits; verify the caller is Vercel cron (e.g. check the `Authorization` header against a `CRON_SECRET`) before doing work.
- Keep new code consistent with the surrounding App Router patterns; prefer Server Components and server-side data fetching, dropping to Client Components only when interactivity requires it.

## Integrations (planned/expected)

The dashboard is the orchestration layer over external services — keep credentials in environment variables (Vercel project env), never in the repo:

- **Gmail** — email automation (drafts, labels, thread triage).
- **Licensing / contracts** — agreement and signature tracking (e.g. DocuSign-style e-sign flows).
- Reporting data sources feeding the dashboards.

When adding an integration, isolate its client/SDK setup and secret handling so it can be reused by both interactive routes and cron handlers.

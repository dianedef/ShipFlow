---
title: "sf-auth-debug"
slug: "sf-auth-debug"
tagline: "Debug a broken auth flow in a real browser before you start guessing from static code alone."
summary: "A browser-level auth diagnosis skill for reproducing login failures, reading local Clerk/Google/Convex/Flutter references, and isolating the exact break point in the flow."
category: "Operations"
audience:
  - "Founders debugging sign-in and session failures"
  - "Teams working on Clerk, OAuth, or protected-flow issues"
  - "Builders integrating Flutter web, Astro, Convex, or YouTube OAuth"
problem: "Authentication failures are often hard to diagnose from code review alone because the break only becomes obvious once the browser flow actually runs."
outcome: "You get a concrete diagnosis of where the auth flow fails across redirects, cookies, callbacks, middleware, provider tokens, Convex session propagation, and post-login behavior."
founder_angle: "This skill matters when login bugs are blocking real usage and static inspection keeps producing weak theories instead of evidence."
when_to_use:
  - "When login, callback, or session behavior is broken in the browser"
  - "When an auth bug needs reproduction in a real flow instead of pure code reading"
  - "When redirects, cookies, or middleware behavior look suspicious"
  - "When Clerk, Google OAuth, YouTube OAuth, Convex auth, or Flutter web auth bridges are involved"
what_you_give:
  - "A failing auth flow, bug report, or repro description"
  - "Any environment, provider, URL, or expected behavior details you already know"
what_you_get:
  - "A browser-level diagnosis"
  - "Evidence around the exact auth failure point"
  - "Stack-specific checks against bundled Clerk, Google OAuth, Convex, Astro, Flutter, Python, and Playwright references"
  - "Reusable implementation notes from ContentFlow and TubeFlow auth patterns when relevant"
  - "A clearer next fix or verification step"
example_prompts:
  - "/sf-auth-debug login with Google returns to sign-in page"
  - "/sf-auth-debug Clerk callback fails on staging"
  - "/sf-auth-debug users authenticate but land on a blank dashboard"
  - "/sf-auth-debug Flutter web cannot exchange Clerk session into Convex"
  - "/sf-auth-debug YouTube OAuth works in Next.js but fails in Flutter"
limits:
  - "Some human-gated steps such as MFA or captcha may limit full automation"
  - "Google login through Playwright may require a prepared test account, saved state, or manual handoff when anti-bot checks trigger"
  - "It diagnoses the failure path; it does not replace the later fix or verification step"
related_skills:
  - "sf-fix"
  - "sf-spec"
  - "sf-start"
  - "sf-verify"
  - "sf-prod"
featured: false
order: 525
---

## Bundled Technical References

`sf-auth-debug` carries focused reference notes for the auth stacks used most often in ShipFlow projects:

- Clerk session and callback debugging
- Google OAuth and YouTube OAuth consent/token flows
- Convex auth propagation with Clerk
- Playwright authentication strategies, including saved browser state and manual handoff boundaries
- Astro + Clerk integration
- Flutter web + ClerkJS bridge patterns
- Python + Convex integration notes
- SDK policy for avoiding immature client SDKs when a stable bridge is safer

## Cross-Project Patterns

The skill includes reusable implementation notes from real project flows:

- ContentFlow documents a working Flutter web auth bridge using ClerkJS and Convex.
- TubeFlow documents a working Next.js + Convex YouTube OAuth flow that can inform Flutter implementations.

Use this skill before starting a fix when the symptom only appears after redirects, provider consent, session restoration, protected-route evaluation, or backend auth propagation.

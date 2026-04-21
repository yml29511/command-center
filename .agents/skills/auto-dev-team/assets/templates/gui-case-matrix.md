# GUI Case Matrix

> Use this template for Web, desktop, or embedded GUI journeys. Keep it small and risk-driven.

## Task

- Name:
- Executor:
- Visual mode:
- Scope:

## Cases

| ID | Journey | Type | Preconditions | Steps | Expected page change | Expected network | Expected backend side effect | Fallback observation |
|----|---------|------|---------------|-------|----------------------|------------------|------------------------------|---------------------|
| G1 | [Happy path] | Happy | [...] | [...] | [...] | [...] | [...] | [...] |
| G2 | [Negative path] | Negative | [...] | [...] | [...] | [...] | [...] | [...] |
| G3 | [Boundary or Recovery] | Boundary/Recovery | [...] | [...] | [...] | [...] | [...] | [...] |

## Notes

- Prefer business helpers over raw selector piles.
- Every GUI-capable task should cover at least `Happy` plus `Negative` or `Boundary`.
- Add a recovery or permission case when session, auth, or role changes are involved.

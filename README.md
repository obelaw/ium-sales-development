# Obelawium Sales & Order Management System (`ium-sales`) Development Skill

This skill provides comprehensive instructions, architectural guidelines, domain invariants, API recipes, and integration patterns for developing with, integrating against, and extending the **Obelawium Sales & Order Management System (`ium-sales`)** domain module.

---

## Directory Structure

```text
ium-sales-skill/
├── SKILL.md                                 # Primary skill instructions and agent decision matrix
├── README.md                                # This overview document
├── references/
│   ├── architecture.md                     # Domain topology, bounded contexts, and state machines
│   ├── invariants-and-exceptions.md        # The 5 non-negotiable domain rules and exception catalog
│   ├── recipes.md                          # Practical code recipes for common commercial workflows
│   ├── cross-domain-integration.md         # Anti-Corruption Layer (ACL) for WMS, TMS, FMS, and CRM
│   └── testing-and-verification.md         # PestPHP testing guide, assertions, and mocks
└── scripts/
    └── run-tests.sh                        # Bash helper script to execute module test suite
```

---

## When to Use This Skill

Activate this skill when:
- Creating, modifying, or querying sales quotations and master orders via `ium()->sales()`.
- Implementing omnichannel order ingestion pipelines (E-Commerce, POS, Mobile, EDI feeds).
- Implementing multi-facility split fulfillment routing and tracking.
- Orchestrating reverse logistics and Return Merchandise Authorizations (RMA).
- Validating commercial domain invariants (Financial Balance Rule, The Price-Lock Law).
- Integrating the Sales domain with downstream contexts (WMS, TMS, Accounting / FMS).

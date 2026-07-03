# SeedRover Developer Specification

Version: 1.0

This document defines the official development standards for the SeedRover project.

Every generated file, module, screen, service, and component must follow these guidelines.

Maintain consistency throughout the entire codebase.

Do not sacrifice readability for clever solutions.

The objective is to build a clean, maintainable, scalable, and production-quality Flutter application.

---

# Core Philosophy

The project should prioritize:

- Simplicity
- Readability
- Maintainability
- Scalability
- Consistency

Choose the simplest correct solution.

Avoid unnecessary complexity.

Do not over-engineer features.

Always think about future maintainability.

---

# Development Workflow

Before implementing any feature:

- Review the Roadmap.
- Review the Database Specification.
- Review the UI Design System.
- Review the Screen Specification.
- Review existing files before creating new ones.

Never duplicate functionality that already exists.

Always determine whether an existing widget, service, or utility can be reused.

---

# Development Order

Always follow this sequence.

1. Review documentation.
2. Create data models.
3. Create repositories/services.
4. Create providers.
5. Create reusable widgets.
6. Build UI.
7. Connect backend.
8. Test.
9. Update documentation.

Do not skip steps.

---

# Planning

Before beginning major features:

- Create a short implementation plan.
- Break the work into manageable tasks.
- Present the plan before making major architectural changes.
- Never perform large refactors without approval.

---

# Code Style

Generate concise code.

Prefer short functions.

Prefer readable code over compact code.

Avoid deeply nested logic.

Avoid unnecessary abstraction.

Avoid excessively large files.

Keep naming consistent throughout the project.

Use descriptive names.

Never use single-letter variable names except in simple loops.

---

# File Organization

Every file should have a single responsibility.

Recommended limits

Widget files

< 300 lines

Screen files

< 500 lines

Service files

< 300 lines

Provider files

< 250 lines

Model files

Small and focused.

If a file grows significantly beyond these recommendations, consider refactoring into smaller components.

---

# Folder Structure

Follow the official architecture.

lib/

core/

features/

shared/

services/

models/

providers/

widgets/

Do not create unnecessary folders.

---

# State Management

Use Riverpod exclusively.

Do not introduce another state management library.

Separate UI from business logic.

Business logic must never exist inside Widgets.

---

# Navigation

Use GoRouter.

Centralize all application routes.

Avoid Navigator.push unless absolutely necessary.

Role-based navigation should be handled through GoRouter guards whenever practical.

---

# Supabase

Use Supabase as the only backend.

Authentication

Supabase Auth

Database

Supabase PostgreSQL

Storage

Supabase Storage (when needed)

Never hardcode credentials.

Never expose service_role keys.

Use environment variables.

---

# Database

Never write raw SQL inside UI code.

All database interactions must go through repositories or services.

Models should match the official database specification.

Never duplicate queries across multiple files.

---

# Architecture

Follow a feature-first architecture.

Each feature should contain only its own files.

Example

features/

authentication/

dashboard/

plant/

inventory/

crops/

notifications/

profile/

Every feature should remain independent whenever possible.

---

# Widgets

Create reusable widgets.

Avoid duplicated UI.

If the same component appears more than once, convert it into a reusable widget.

Keep widgets small.

Prefer composition over inheritance.

---

# Theme

Never hardcode colors.

Never hardcode typography.

Never hardcode spacing.

Use the official Design System.

All visual values should come from centralized theme files.

---

# Responsive Design

The application should adapt to:

Small phones

Large phones

Tablets (future support)

Avoid fixed pixel values whenever practical.

Use flexible layouts.

---

# Animations

Animations should feel modern, smooth, and purposeful.

Use implicit Flutter animations whenever possible.

Avoid excessive animations.

Animation duration should generally remain between:

200ms–500ms

Transitions should never reduce usability.

---

# Error Handling

Every asynchronous operation must handle:

Loading

Success

Failure

Unexpected exceptions

Display user-friendly messages.

Never expose raw exception messages to users.

---

# Logging

Only log information useful during development.

Remove unnecessary debug logging before production.

Avoid excessive console output.

---

# Documentation

After completing a significant feature:

Update

docs/activity-log.md

Include

Date

Feature completed

Files modified

Summary

Known issues

Next steps

Do not automatically commit documentation files.

---

# Comments

Write comments only when necessary.

Comments should explain "why", not "what".

Rules

- One sentence.
- One line whenever possible.
- No emojis.
- No decorative separators.

Good

// Fetch latest sensor values before updating UI.

Bad

// ========================== SENSOR CODE ==========================

---

# Naming Conventions

Classes

PascalCase

Variables

camelCase

Functions

camelCase

Files

snake_case

Markdown

kebab-case

Constants

camelCase or static const

Avoid abbreviations unless universally understood.

---

# Dependencies

Only use packages that provide clear value.

Prefer Flutter SDK solutions first.

Avoid unnecessary third-party packages.

Before adding any dependency:

- Verify that Flutter does not already provide the functionality.
- Ensure the package is actively maintained.
- Prefer widely adopted packages.

---

# Code Quality

Prefer composition.

Avoid duplicate logic.

Choose appropriate algorithms.

Use efficient data structures.

Keep methods focused.

Avoid premature optimization.

Refactor only when it improves readability or maintainability.

---

# Security

Follow the principle of least privilege.

Never expose:

Passwords

API Keys

Tokens

Connection strings

Secret credentials

Never commit .env files.

Use Supabase Row Level Security.

Validate all user input.

Sanitize user-generated content where appropriate.

---

# Version Control

Commit after significant milestones.

Commit messages should be concise and descriptive.

Examples

feat: complete inventory module

fix: resolve login validation bug

refactor: simplify dashboard layout

docs: update activity log

Keep commits focused.

Do not combine unrelated changes.

Never push automatically.

Never rewrite Git history without approval.

---

# AI Development Rules

Before generating new code:

Review existing implementation.

Do not recreate existing components.

Respect project architecture.

Avoid introducing breaking changes.

Prefer extending existing modules over replacing them.

When uncertain, choose the simplest maintainable solution.

---

# Performance

Avoid unnecessary rebuilds.

Reuse widgets.

Dispose controllers properly.

Optimize database queries.

Lazy load data when appropriate.

Avoid blocking the UI thread.

---

# Testing

Every completed feature should be manually verified.

Check

UI

Navigation

Role permissions

Database interaction

Error handling

Responsive layout

Before marking a feature complete, ensure it functions as intended.

---

# Future Compatibility

Write code with future expansion in mind.

The architecture should support future additions including:

Multiple robotic units

LoRa communication

ESP32 Camera streaming

Weather integration

GPS tracking

AI recommendations

Do not implement these features now.

Simply avoid architecture decisions that would prevent them later.

---

# Final Rule

Every contribution to the SeedRover project should leave the codebase cleaner, more consistent, and easier to maintain than before.

If a generated solution feels overly complex, simplify it.

If a generated solution duplicates existing functionality, reuse the existing implementation.

Always prioritize clarity, consistency, and maintainability over cleverness.
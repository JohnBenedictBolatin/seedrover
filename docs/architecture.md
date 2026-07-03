# SeedRover Architecture Specification

Version: 1.0

This document defines the official software architecture for the SeedRover mobile application.

All generated code must strictly follow this architecture.

No file or folder should be created outside this structure unless explicitly approved.

---

# Architecture Principles

SeedRover follows a modified Clean Architecture.

The application should prioritize:

- Scalability
- Readability
- Maintainability
- Reusable components
- Separation of concerns
- Modular development
- Testability

Business logic must never depend on the presentation layer.

The user interface must remain independent from database and hardware implementations.

---

# State Management

State Management

Riverpod

Rules

- Never use setState() for application state.
- Keep providers focused on a single responsibility.
- Avoid unnecessary global providers.
- Providers should expose immutable state whenever possible.

---

# Navigation

Navigation

GoRouter

Rules

- All routes should be centralized.
- Never hardcode route names.
- Use route constants.
- Support role-based navigation.

---

# Dependency Injection

Dependencies should be injected rather than instantiated directly.

Repositories should receive services through dependency injection.

Controllers should receive repositories.

Widgets should never instantiate repositories or services.

---

# Folder Structure

lib/

core/

config/

constants/

theme/

errors/

extensions/

utils/

services/

communication/

wifi/

bluetooth/

shared/

models/

widgets/

features/

authentication/

dashboard/

rover/

camera/

crops/

inventory/

notifications/

users/

Each feature should remain independent.

Features must never directly depend on one another.

Shared functionality belongs inside core or shared.

---

# Core Folder

Purpose

Contains application-wide functionality.

Contents

config/

Application configuration

constants/

Global constants

theme/

Application theme

Typography

Colors

Spacing

errors/

Custom exceptions

Failure models

extensions/

Dart extensions

utils/

Utility functions

services/

Application-wide services

communication/

Communication abstraction

---

# Communication Layer

The communication layer must remain independent from the user interface.

Current communication methods

- Wi-Fi
- Bluetooth

Future communication methods

- LoRa
- MQTT

Changing the communication method must not require modifying UI widgets.

Widgets communicate only with controllers.

Controllers communicate with repositories.

Repositories communicate with communication services.

---

# Feature Structure

Every feature follows the same internal architecture.

Example

features/

inventory/

data/

models/

repositories/

controllers/

presentation/

screens/

widgets/

providers/

Feature folders should remain self-contained.

Business logic should never exist inside widgets.

---

# Data Layer

Responsibilities

- Database access
- Communication with Supabase
- Hardware communication
- Data conversion
- Local caching

Contains

Models

Repositories

Data sources

Services

---

# Repository Layer

Repositories act as the single source of truth.

Repositories may combine

- Supabase
- Hardware
- Local cache

Widgets must never communicate directly with Supabase.

Widgets must never communicate directly with ESP32.

---

# Controller Layer

Responsibilities

- Coordinate application logic
- Validate requests
- Call repositories
- Handle failures
- Prepare UI state

Controllers should never contain UI code.

---

# Presentation Layer

Contains

Screens

Reusable widgets

Animations

Dialogs

Bottom sheets

Presentation should only display data.

No database logic.

No communication logic.

No business logic.

---

# Shared Widgets

Common reusable widgets belong inside

shared/widgets/

Examples

Primary Button

Secondary Button

Status Badge

Information Card

Sensor Card

Loading Indicator

Confirmation Dialog

Error Dialog

Search Field

Statistic Card

Empty State

Widgets should be highly reusable.

---

# Theme

The entire application must use the centralized theme.

Never hardcode

- Colors
- Font sizes
- Font weights
- Border radius
- Shadows
- Animation durations

Everything should originate from the theme.

---

# Communication Flow

User

↓

Widget

↓

Controller

↓

Repository

↓

Communication Service

↓

ESP32

The reverse flow follows the same architecture.

ESP32

↓

Communication Service

↓

Repository

↓

Controller

↓

Widget

---

# Database Flow

Widget

↓

Controller

↓

Repository

↓

Supabase

Widgets must never directly access Supabase.

---

# Hardware Flow

Widget

↓

Controller

↓

Repository

↓

Communication Service

↓

Wi-Fi or Bluetooth

↓

ESP32

Hardware communication should remain fully abstracted.

---

# Error Handling

Errors should propagate upward.

Communication Service

↓

Repository

↓

Controller

↓

Presentation

Widgets should display user-friendly messages.

Never expose raw exceptions.

---

# Logging

Application logs should record

- Authentication
- Communication
- Inventory updates
- Planting activities
- User management
- Unexpected failures

Logging should never interrupt user workflows.

---

# Naming Conventions

Folders

snake_case

Files

snake_case

Classes

PascalCase

Variables

camelCase

Methods

camelCase

Constants

UPPER_SNAKE_CASE

Providers

featureProvider

Controllers

FeatureController

Repositories

FeatureRepository

Models

FeatureModel

Services

FeatureService

---

# Widget Rules

Widgets should remain small.

Preferred maximum

200 lines

If a widget becomes too large

Extract reusable widgets.

One widget should perform one responsibility.

---

# Screen Rules

Each screen should contain

- App Bar
- Content
- Loading State
- Empty State
- Error State

Business logic must remain outside screens.

---

# Communication Rules

Never communicate directly from widgets.

Never place JSON parsing inside widgets.

Never place hardware commands inside widgets.

Communication belongs only inside communication services.

---

# Supabase Rules

Supabase access belongs only inside repositories.

Authentication should remain centralized.

Never duplicate queries.

Never hardcode table names throughout the project.

Use centralized constants.

---

# Future Expansion

The architecture should support future implementation of

- LoRa
- Multiple SeedRovers
- GPS
- OTA Firmware Updates
- AI Crop Recommendations
- Cloud Synchronization

Future expansion should require minimal structural changes.

---

# Development Rules for Codex

Always follow this architecture.

Do not invent new folder structures.

Do not duplicate business logic.

Create reusable components whenever possible.

Keep controllers lightweight.

Keep repositories focused.

Keep widgets presentation-only.

Never bypass repositories.

Never bypass communication services.

Follow Clean Architecture throughout the project.

If a generated implementation conflicts with this architecture, this document takes precedence.
# SeedRover UI Design System

Version: 2.0

This document serves as the official visual specification for the SeedRover mobile application.

All screens, components, interactions, animations, and future features must strictly follow this document.

This design system is based primarily on the approved SeedRover Figma designs. External inspirations are only used to improve interaction quality and motion while preserving the existing visual identity.

---

# Design Philosophy

SeedRover is an intelligent robotic farming platform.

The application should feel like operating a modern agricultural robot rather than using a traditional farm management system.

The experience should communicate:

• Intelligence

• Precision

• Automation

• Professionalism

• Reliability

• Simplicity

The interface should remain clean while presenting technical information in an approachable manner.

---

# Primary Design Inspiration

The application's visual identity is based on the official SeedRover Figma designs.

The following products are used only as secondary inspiration:

• Tesla App

• DJI Fly

• Nothing OS

• Bryl Lim Portfolio

• Linear

• Apple Human Interface Guidelines

The application must NEVER copy these products directly.

Instead, use them only as references for motion, transitions, spacing, and polish.

---

# Theme

Dark Mode First

SeedRover is designed primarily for dark mode.

All interfaces should assume a dark environment.

Light mode is not required during initial development.

# Design Principles

Every screen should prioritize clarity over decoration.

The interface should feel like controlling an intelligent robotic machine rather than operating a traditional mobile application.

Primary design principles:

• Function First

• Motion with Purpose

• Instant Readability

• Minimal Cognitive Load

• Large Interactive Areas

• Consistent Component Language

• Progressive Disclosure

The application should never overwhelm the user with excessive information.

Only the information relevant to the user's current task should receive visual emphasis.
---

# Color Palette

Primary Background

#1B1B1B

Secondary Background

#252525

Card Background

#313131

Primary Border

#53D11E

Inactive Border

#505050

Primary Text

#FFFFFF

Secondary Text

#D4D4D4

Muted Text

#9A9A9A

Primary Green

#53D11E

Secondary Green

#2FAF3E

Accent Green

#8DFF2A

Primary Button Gradient

Start

#188A11

End

#7CFF28

Dark Green Gradient

#0A4F08

↓

#53D11E

Success

#41D75B

Warning

#FFB000

Danger

#FF3B30

Information

#2196F3

---

# Color Usage

Green represents:

• Active devices

• Healthy crops

• Online connection

• Primary actions

• Selected navigation

Red represents:

• Errors

• Low inventory

• Critical notifications

Orange represents:

• Warnings

Blue represents:

• Information

Gray represents:

• Disabled elements

---

# Overall Style

SeedRover should look like an industrial robotic control interface.

Characteristics:

• Minimal

• Dark

• Soft

• Rounded

• Technical

• Premium

• Organized

Avoid excessive decoration.

Avoid glassmorphism.

Avoid colorful gradients except for action buttons.

# Visual Language

SeedRover follows a modern industrial interface inspired by robotics, automation systems, and precision agricultural equipment.

Visual Characteristics

• Dark matte surfaces

• Bright green highlights

• Rounded industrial panels

• Thin borders

• Clean typography

• Soft shadows

• High information density without clutter

The application should resemble a premium robotic operating console rather than a generic management application.

---

# Layout

Every screen should have:

Top App Bar

↓

Primary Information

↓

Main Content

↓

Secondary Information

↓

Floating Bottom Navigation

Every screen should immediately communicate its purpose.

---

# Cards

Cards are the primary UI element.

Every card should include:

Rounded corners

20-24px radius

Dark surface

Thin neon green outline

Minimal shadow

20-24px internal padding

Consistent spacing

Cards should never feel flat.

# Information Hierarchy

Each screen should clearly communicate information using the following hierarchy.

Primary

Current robot activity

Secondary

Sensor information

Battery

Seed level

Connection

Tertiary

Historical information

Descriptions

Metadata

The most important operational information should always remain visible without scrolling.

---

# Borders

Use thin borders.

1px–2px maximum.

Primary cards use green borders.

Inactive cards use dark gray borders.

---

# Buttons

Buttons are highly emphasized.

Primary buttons always use the official green gradient.

Border radius:

16px

Minimum height:

48px

Buttons should never appear flat.

Pressed state slightly darkens.

---

# Typography

SeedRover uses a dual-font system to create a balance between readability and a modern industrial interface.

Primary UI Font
Inter

Technical Font
Roboto Mono

The application should resemble a professional robotic control system, where general interface elements remain clean and readable while operational data feels precise and machine-oriented.

---

# Font Usage

## Inter

Use Inter for all human-readable interface elements.

Includes:

• Screen titles

• Section headings

• Navigation labels

• Buttons

• Cards

• Forms

• Dialogs

• Notifications

• Paragraphs

• Descriptions

• Labels

• Empty states

• Helper text

• User profile information

• Crop descriptions

• Inventory descriptions

---

## Roboto Mono

Use Roboto Mono exclusively for technical information and live operational data.

Includes:

• Soil moisture values

• Soil temperature

• Environmental temperature

• Battery percentage

• Seed level percentage

• Robot status

• Base station status

• Live telemetry

• Camera overlay

• Device IDs

• Plant IDs

• Inventory quantities

• LoRa signal strength (future)

• GPS coordinates (future)

• Activity timestamps

• Robot diagnostics

• Runtime information

• System logs

• Status badges

Examples:

ONLINE

ACTIVE

READY

PLANTING

ERROR

OFFLINE

LOW STOCK

These should feel like labels from industrial machinery rather than standard mobile interfaces.

---

# Typography Scale

## Display Heading

Font

Inter Bold

Size

32 px

Weight

700

Line Height

40 px

Usage

• Greeting

• Welcome message

• Login heading

Example

Good afternoon, Randy!

---

## Screen Title

Font

Inter SemiBold

Size

26 px

Weight

600

Line Height

34 px

Usage

Dashboard

Plant

Inventory

Notifications

Crops

Profile

---

## Section Heading

Font

Inter SemiBold

Size

20 px

Weight

600

Line Height

28 px

Usage

Recent Activities

Robot Status

Inventory

Planting History

Crop Monitoring

---

## Card Title

Font

Inter Medium

Size

18 px

Weight

500

Line Height

24 px

Usage

SeedRover Unit

Base Station

Garlic

Peanut Sprout

---

## Body Text

Font

Inter Regular

Size

15 px

Weight

400

Line Height

22 px

Usage

Descriptions

Forms

Activity details

Notifications

---

## Small Text

Font

Inter Regular

Size

13 px

Weight

400

Line Height

18 px

Usage

Dates

Metadata

Labels

Helper text

---

## Caption

Font

Inter Regular

Size

12 px

Weight

400

Line Height

16 px

Usage

Copyright

Version

Tiny labels

---

# Buttons

Primary Button

Font

Inter SemiBold

Size

16 px

Weight

600

Letter Spacing

0.2

Examples

LOG IN

Plant Seed

Check Soil & Temp

View Details

---

Secondary Button

Font

Inter Medium

Size

14 px

Weight

500

---

# Bottom Navigation

Font

Inter Medium

Size

11 px

Weight

500

Items

Dashboard

Plant

Crops

Stocks

Notifications

Profile

---

# Technical Typography

## Large Live Values

Font

Roboto Mono Bold

Size

24 px

Weight

700

Usage

Major telemetry

Examples

96%

37°C

58%

ONLINE

---

## Sensor Values

Font

Roboto Mono Medium

Size

18 px

Weight

500

Usage

Battery

Moisture

Temperature

Humidity

Seed Percentage

---

## Technical Labels

Font

Roboto Mono Medium

Size

14 px

Weight

500

Usage

PN-02

CM-105

SR-001

Base Station IDs

Robot IDs

---

## Inventory Quantities

Font

Roboto Mono SemiBold

Size

16 px

Weight

600

Usage

30 kg

120 pcs

12 Seeds

50 Units

---

## Timestamp

Font

Roboto Mono Regular

Size

12 px

Weight

400

Usage

Today, 2:33 PM

May 12, 2026

14:25:32

---

## Status Badge

Font

Roboto Mono SemiBold

Size

12 px

Weight

600

Letter Spacing

0.8

Uppercase

Enabled

Examples

ONLINE

ACTIVE

READY

PLANTING

WATERING

CONNECTED

OFFLINE

ERROR

LOW STOCK

CHARGING

These badges should resemble indicators found on industrial robotics dashboards.

---

# Numeric Formatting

Enable Tabular Figures (fontFeatureSettings: "tnum")

All changing numerical values must maintain identical width.

This prevents layout shifting during live updates.

Examples include:

• Battery percentage

• Temperature

• Soil moisture

• Seed level

• Inventory count

• Progress percentage

• Timers

---

# Typography Principles

• Inter is the default font for the entire application.

• Roboto Mono is reserved for operational and technical information.

• Never use Roboto Mono for paragraphs or long descriptions.

• Green headings establish hierarchy.

• White body text maximizes readability.

• Technical values should always feel precise, machine-generated, and instantly recognizable.

• Status badges should visually resemble industrial equipment indicators to reinforce the application's identity as a robotic farming control platform.
---

# Icons

Use only one icon family.

Preferred:

Cupertino Icons

or

Phosphor

Icons should remain outline-based whenever possible.

---

# Navigation

Bottom Navigation

Floating

Rounded container

Dark surface

Green selected icon

White inactive icons

No more than six navigation items.

Current navigation:

Dashboard

Plant

Crops

Stocks

Notifications

Profile

---

# Dashboard

The dashboard should immediately communicate the current operational state of the rover.

Order

Greeting

↓

Rover Overview

↓

Connection Status

↓

Live Sensor Summary

↓

Current Activity

↓

Quick Actions

↓

Recent Activities

↓

Notifications

The dashboard should allow operators to understand the rover's condition within five seconds.

Quick actions should include:

• Connect Rover

• Manual Control

• Live Camera

• Planting Logs

• Inventory

• Crop Monitoring
---

# Rover Control Screen

This is the application's primary operational interface.

It should resemble the control panel of a professional drone.

Primary Sections

• Live Camera Preview

• Movement Controls

• Robot Status

• Live Sensor Values

• Battery Level

• Seed Level

• Current Activity

• Emergency Stop

• Connection Status

Movement Controls

Support:

• Virtual Joystick

• Direction Buttons

• Speed Indicator

• Stop Button

Status Cards

Display

• Wi-Fi Status

• Bluetooth Status

• Camera Status

• Battery

• Soil Moisture

• Soil Temperature

• Humidity

• Seed Level

The interface should always prioritize camera visibility during manual operation.

# Live Camera Experience

The camera is one of SeedRover's defining features.

The live camera should feel immersive while remaining lightweight.

Requirements

• Rounded video container

• Dark placeholder while connecting

• Animated loading indicator

• Connection badge

• Camera refresh

• Fullscreen mode

• Snapshot button

• Smooth appearance animation

The camera should always maintain a stable aspect ratio.

Avoid stretching or cropping the stream excessively.

# Motion Design

Motion should make the interface feel premium.

Every interaction should have feedback.

No abrupt changes.

Use easing curves.

# Micro-interactions

Every interactive component should provide immediate visual feedback.

Buttons

• Scale animation

• Shadow adjustment

Cards

• Elevation animation

Navigation

• Smooth active indicator

Lists

• Staggered entrance

Dialogs

• Scale + Fade

Status Indicators

• Color interpolation

Sensor Values

• Animated number transitions

Camera Loading

• Skeleton placeholder

Loading States

• Shimmer effect

Connection Changes

• Animated status badges

---

# Animation Duration

Fast

180ms

Default

250ms

Slow

350ms

Screen Transition

400ms

# Motion Principles

Animations should improve usability rather than attract attention.

Rules

• Never animate purely for decoration.

• Motion should communicate hierarchy.

• Motion should reinforce state changes.

• Motion should never delay user interaction.

All animations should maintain approximately 60 FPS on supported devices.

---

# Empty States

Every screen should define an empty state.

Examples

Inventory

"No inventory items available."

Notifications

"You're all caught up."

Planting Logs

"No planting records yet."

Camera

"Waiting for camera connection."

Robot

"Rover is currently offline."

Empty states should include:

• Illustration or icon

• Short explanation

• Primary action button

# Loading States

Avoid blank screens whenever possible.

Preferred loading patterns

• Skeleton cards

• Skeleton lists

• Animated placeholders

• Circular progress indicators only when appropriate

Loading should preserve the final layout to reduce visual shifting.


# Error States

Every critical screen must gracefully recover from failures.

Examples

Wi-Fi disconnected

Bluetooth unavailable

Camera unavailable

Sensor timeout

Database unavailable

Each error should provide:

• Explanation

• Retry button

• Recovery suggestion

Never display raw technical errors to end users.

# Required Animations

Screen transitions

Fade + Slide

Cards

Fade + Scale

Buttons

Scale on press

Navigation

Smooth selection animation

Sensor values

Animated counting

Status changes

Color transition

Notifications

Slide in

Dialogs

Fade + Scale

Lists

Staggered appearance

---

# Live Data

Sensor values should animate.

Battery percentages should animate.

Progress indicators should animate.

Status indicators should smoothly transition.

Avoid instant updates.

---

# Images

Use real agricultural imagery whenever possible.

Crop images should have transparent backgrounds.

Avoid stock-style illustrations.

Robot renders should be realistic.

---

# Accessibility

Maintain high contrast.

Minimum touch size:

48x48

Readable typography.

Never rely solely on color.

---

# Responsiveness

Design primarily for:

Android phones

Secondary:

Android tablets

Future:

iPad

Desktop

---

# Coding Guidelines for UI

Never hardcode colors.

Never hardcode spacing.

Never hardcode typography.

Create centralized:

theme.dart

colors.dart

spacing.dart

radius.dart

animations.dart

typography.dart

Every repeated UI component should become a reusable widget.

---

# Future UI Improvements

The architecture should allow future implementation of:

• Live ESP32 camera stream

• Animated rover movement visualization

• Interactive farm map

• Real-time telemetry charts

• Communication diagnostics dashboard

• AI crop recommendations

• Weather dashboard

These additions should integrate naturally without changing the existing design language.

# UI Quality Standards

Every completed screen should satisfy the following checklist before implementation is considered complete.

✓ Consistent spacing

✓ Responsive layout

✓ Dark mode compliant

✓ Theme colors only

✓ Typography follows design system

✓ Motion implemented

✓ Loading state implemented

✓ Empty state implemented

✓ Error state implemented

✓ Accessible touch targets

✓ Reusable widgets

✓ No hardcoded values

✓ Pixel-consistent with approved Figma designs

If any checklist item is incomplete, the screen should not be considered production-ready.
---

# Final Design Rule

If a generated screen differs from the approved SeedRover Figma designs, the Figma design always takes precedence.

The objective is to preserve a consistent visual identity across the entire application while introducing modern motion, smooth interactions, and high-quality animations inspired by premium technology products.
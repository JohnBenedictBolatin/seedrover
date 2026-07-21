# SeedRover Screen Specification

Version: 1.0

This document defines the complete user interface, screen behaviors, navigation flow, and user experience of the SeedRover mobile application.

This serves as the official blueprint for every screen to be developed throughout the project.

Every implementation must follow this document together with:

- UI Design System
- Roadmap
- Database Schema
- Developer Specification

The application should resemble a modern commercial IoT platform rather than a traditional mobile CRUD application.

---

# Design Philosophy

SeedRover should communicate the following characteristics immediately when opened:

- Modern
- Premium
- Professional
- Intelligent
- Clean
- Reliable
- Agricultural Technology

The application should feel closer to software like:

- Linear
- Arc Browser
- Rivian Mobile
- Tesla App
- Nothing OS
- Bryllim

Rather than a traditional Flutter application.

The interface should never feel crowded.

Large breathing spaces should be used throughout.

Content should be prioritized over decoration.

Animations should enhance usability instead of distracting the user.

---

# General User Experience Principles

Every screen should provide:

- Fast loading
- Immediate visual feedback
- Smooth transitions
- Consistent spacing
- Large touch targets
- High readability
- Accessible navigation

Users should always understand at a glance:

- Current rover status
- Wi-Fi connection status
- Bluetooth connection status
- Camera connection status
- Current sensor readings
- Current battery level
- Current seed level
- Current planting status
- Current rover activity

Critical operational information should always be visible without requiring users to navigate between multiple screens.

---

# User Roles

The application supports four user roles.

## System Administrator

Responsibilities

- Manage all users
- Assign user roles
- Reset passwords
- Activate or deactivate accounts
- Access all application modules
- Monitor overall system health
- View reports
- Configure system settings

Has unrestricted access.

---

## Farm Planting Manager

Responsibilities

- Monitor crop progress
- Review planting logs
- Control rover operations
- View sensor information
- Monitor robot status
- View live camera feed

Cannot manage users.

Cannot modify inventory records.

---

## Farm Inventory Manager

Responsibilities

- Manage inventory
- Monitor stock levels
- Update storage records
- View inventory history

Cannot control rover movement.

Cannot access planting management features.

---

## Farm Staff

Responsibilities

Access only the modules explicitly assigned by the System Administrator or respective manager.

Examples

- Rover control
- Inventory updates
- Planting logs

Permissions are configurable.

---

# Authentication

## Login Screen

Purpose

Authenticate authorized users.

The login screen should create a strong first impression.

Layout

Top Section

- SeedRover logo
- Application name
- Short welcome message

Center Section

- Username
- Password
- Show password button

Bottom Section

- Login button
- Version number

Behavior

- Validate all fields.
- Prevent duplicate submissions.
- Disable login button while authenticating.
- Display loading animation.
- Display friendly authentication errors.

Upon successful login

Automatically redirect users according to their assigned role.

Animations

- Fade in
- Slight upward movement
- Smooth button scaling
- Animated loading indicator

---

# Navigation

SeedRover should not use the default BottomNavigationBar.

Instead, use a floating glass navigation dock.

The dock should remain visible throughout the application.

Design

- Floating
- Centered horizontally
- Positioned slightly above the bottom edge
- Pill-shaped
- Frosted glass
- Semi-transparent
- Rounded corners
- Soft green glow
- Thin translucent border
- Floating shadow

Behavior

Selected icon

- Enlarges smoothly
- Changes to gradient green
- Displays animated indicator

Dock

- Slightly elevates when keyboard appears
- Uses blur effect
- Maintains smooth transitions

Navigation Items

- Dashboard
- Rover
- Crops
- Inventory
- Profile

Role permissions automatically determine visible navigation items.

Users should never see modules they cannot access.

Do not disable hidden modules.

Hide them completely.

---

# Motion Design

Animations should feel intentional.

The application should never appear static.

Recommended animations

Pages

- Fade transition
- Slide transition
- Hero animations

Cards

- Fade in
- Upward motion
- Hover elevation

Buttons

- Scale animation
- Ripple feedback
- Glow animation

Sensor Values

- Animated number transitions
- Smooth refresh

Dialogs

- Fade
- Scale

Lists

- Staggered appearance
- Animated insertion
- Animated removal

Animation Duration

Small interactions

200ms

Medium interactions

300ms

Large transitions

400ms

Avoid animations longer than 500ms.

---

# Visual Hierarchy

Information priority should always follow this order.

Primary

- Robot Status
- Live Camera
- Sensor Readings
- Current Activity

Secondary

- Crop Monitoring
- Inventory
- Notifications

Tertiary

- Profile
- Settings
- Reports
- History

Users should never scroll excessively to locate operational information.

---

# Dashboard

Purpose

The Dashboard serves as the command center of the SeedRover application.

It provides a real-time overview of the robot, farm conditions, and operational activities.

This should be the first screen users see after authentication.

Layout

Hero Header

Displays

- Greeting
- Current date
- Current time
- User role

Robot Status Card

Displays

- Wi-Fi connection
- Bluetooth connection
- Camera connection
- Current rover activity
- Battery level
- Seed level
- Current planting status
- Last communication timestamp

Environment Card

Displays

- Soil moisture
- Soil temperature
- Environmental temperature
- Humidity

Each value should include:

- Numerical value
- Interpretation
- Color indicator

Example

Good

Moderate

Poor

Live Camera Preview

Displays

- Live ESP32 camera feed
- Expand button
- Camera status

Quick Actions

Displayed according to user role.

Examples

- Control Rover
- View Inventory
- View Crops
- Planting Logs

Recent Activity Timeline

Displays

- Latest operations
- Latest inventory updates
- Latest planting records

Notifications Preview

Displays

Latest unread notifications.

Behavior

Cards refresh independently.

Only changed values animate.

Dashboard should remain visually active without unnecessary movement.

Avoid full page refreshes.

# Rover Control

Purpose

The Rover Control module is the primary operational screen of the application. It enables authorized users to remotely control the SeedRover while monitoring its live status and sensor readings.

This screen should feel like a professional control center rather than a simple remote-control interface.

Visible To

- System Administrator
- Farm Planting Manager
- Authorized Farm Staff

---

## Layout

The screen should prioritize the live camera and robot status.

Suggested hierarchy:

1. Live Camera
2. Robot Status
3. Manual Controls
4. Sensor Readings
5. Activity Information

---

## Live Camera

The camera occupies the upper section of the screen.

Displays

- Live ESP32 Camera stream
- Connection indicator
- Fullscreen button

Behavior

- Automatically reconnect if connection is interrupted.
- Maintain low latency whenever possible.
- Fullscreen mode should animate smoothly.
- Display a placeholder if the camera is unavailable.

---

## Robot Status

Displays

- Current activity
- Wi-Fi status
- Bluetooth status
- Camera status
- Battery percentage
- Seed level
- Current operating mode
- Current planting status

Status should update automatically without refreshing the page.

---

## Manual Controls

Movement Controls

- Forward
- Backward
- Rotate Left
- Rotate Right
- Stop

Planting Controls

- Start Planting
- Pause Planting
- Resume Planting
- Stop Planting

Emergency Controls

- Emergency Stop

Button Behavior

- Scale slightly when pressed.
- Display active state while command is being sent.
- Disable controls if robot disconnects.

Emergency Stop

- Always visible.
- Larger than other controls.
- Red accent.
- Confirmation dialog optional.

---

## Sensor Panel

Displays

- Soil Moisture
- Soil Temperature
- Environmental Temperature
- Humidity

Each sensor card should contain

- Sensor icon
- Current value
- Measurement unit
- Status label

Example

Soil Moisture

42%

Status

Good

Color Coding

Excellent

Green

Moderate

Yellow

Poor

Red

Sensor values should animate whenever updated.

---

## LCD Preview

Displays the latest message currently shown on the rover LCD.

Example

Initializing...

Monitoring Soil...

Moving Forward...

Scanning Area...

Idle

---

## Operational Status

The current SeedRover system supports

- Manual rover movement
- Automated seed planting
- Live ESP32-CAM video
- Soil moisture monitoring
- Soil temperature monitoring
- Environmental temperature monitoring
- Humidity monitoring
- Battery monitoring
- Seed level monitoring
- LCD status display
- Activity LEDs
- Real-time Wi-Fi communication
- Bluetooth communication

The Rover Control screen should dynamically display the available functions according to the rover's current operating mode.

------

# Crop Monitoring

Purpose

Monitor crop information collected after planting.

Visible To

- System Administrator
- Farm Planting Manager

---

## Layout

Crop Summary

Displays

- Total Crops
- Active Crops
- Ready for Harvest

Crop Cards

Each card displays

- Crop Name
- Date Planted
- Current Growth Stage
- Estimated Harvest Date

Crop Details

Displays

- Growth timeline
- Maintenance notes
- Sensor history (future)

---

## Search

Support

- Instant search
- Filter by crop
- Filter by status

---

## Empty State

Example

"No crops have been recorded yet."

---

# Inventory Management

Purpose

Manage all farm inventory and storage.

Visible To

- System Administrator
- Farm Inventory Manager
- Authorized Farm Staff

---

## Dashboard

Displays

- Total Inventory Items
- Low Stock Items
- Recently Updated Items
- Sales Today
- Sales This Month
- Units Sold This Month
- Sales Transaction Count

---

## Inventory Cards

Each card displays

- Item Name
- Item ID
- Category
- Current Quantity
- Unit
- Stock Status
- Storage Location
- Last Updated

---

## Inventory Actions

- Add Item
- Edit Item
- Add Stock
- Deduct Stock
- Record Sale
- Delete Item

Actions should open modal dialogs.

Record Sale displays:

- Quantity Sold
- Unit Price
- Total Amount
- Sale Date
- Customer Name
- Remarks

Record Sale must confirm before saving and must not allow sales greater than current stock.

---

## Transaction History

Displays

- Date
- Item
- Quantity
- Transaction Type
- Updated By

Newest records appear first.

## Sales History

Displays

- Quantity Sold
- Unit Price
- Total Amount
- Date
- Time
- Customer Name
- Remarks
- Recorded By

Newest records appear first.

---

## Alerts

Automatically highlight

- Low Stock
- Empty Stock

Use subtle warning colors.

---

# Planting Logs

Purpose

Store historical planting activities.

Visible To

- System Administrator
- Farm Planting Manager

---

## Planting Summary

Displays

- Total Planting Sessions
- Crops Planted
- Latest Activity

---

## Planting Log Cards

Each card displays

- Seed Type
- Operator
- Date
- Time
- Status

---

## Details

Displays

- Notes
- Duration
- Related Crop

Support future attachment of images.

---

# Notifications

Purpose

Centralize all important system alerts.

Visible To

All authenticated users.

---

## Categories

- Robot
- Inventory
- Planting
- Crop
- System

---

## Notification Card

Displays

- Icon
- Title
- Description
- Timestamp

Unread notifications

- Green indicator
- Bold title

---

## Actions

- Mark as Read
- Mark All Read
- Open Related Module

---

## Empty State

"No notifications available."

---

# Profile

Purpose

Allow users to manage their personal information.

Visible To

All users.

---

## User Information

Displays

- Full Name
- Username
- Assigned Role

---

## Account Actions

- Change Password
- Logout

---

## About

Displays

- Application Version
- Current Build
- Developer Information

---

# User Management

Visible To

System Administrator only.

Purpose

Manage every user account within the application.

---

## User Dashboard

Displays

- Total Users
- Active Users
- Inactive Users

---

## User List

Each card displays

- Full Name
- Username
- Assigned Role
- Status

---

## User Actions

- Create User
- Edit User
- Reset Password
- Activate User
- Deactivate User

Passwords should be generated automatically during user creation.

Users cannot register themselves.

Only the System Administrator creates accounts.

---

## Role Assignment

Available Roles

- System Administrator
- Farm Planting Manager
- Farm Inventory Manager
- Farm Staff

Role changes should immediately affect accessible modules after the next login.

---

## Security

The interface must never expose administrative actions to non-administrative users.

Role permissions should be enforced both visually and through backend authorization.

# Loading States

The application should never display empty white screens while data is loading.

Every page must provide immediate visual feedback.

Preferred Loading Components

- Skeleton cards
- Skeleton text
- Skeleton lists
- Circular progress indicator (only when necessary)

Avoid fullscreen loading unless the application is starting.

Loading animations should follow the official motion guidelines.

---

# Empty States

Every module should provide a meaningful empty state.

Empty states should never appear broken or unfinished.

Each empty state should include

- Simple illustration or icon
- Short explanation
- Suggested action

Examples

Dashboard

"No recent activity yet."

Inventory

"No inventory items available."

Crop Monitoring

"No crops have been added."

Notifications

"You're all caught up."

Planting Logs

"No planting records found."

User Management

"No users available."

---

# Error States

Errors should be informative but never technical.

Do not expose stack traces or raw exception messages.

Each error screen should include

- Friendly title
- Brief explanation
- Retry button

Examples

Connection Lost

Unable to connect to the server.

Check your internet connection and try again.

Robot Offline

The robot is currently unavailable.

Reconnect before sending commands.

Camera Offline

Unable to retrieve the live camera feed.

Database Error

Unable to retrieve the requested information.

Unexpected Error

Something went wrong.

Please try again.

---

# Forms

Every form should follow the same behavior.

Required Fields

Clearly indicate required fields.

Validation

Inline validation only.

Never wait until submission to validate obvious errors.

Buttons

Submit buttons should become disabled while processing.

Loading

Display loading indicator inside the button.

Success

Display a confirmation message.

Failure

Display an inline error message.

Never clear form fields after validation errors.

---

# Dialogs

Dialogs should follow the official glassmorphism design language.

Use dialogs for

- Delete confirmation
- Logout confirmation
- Inventory adjustment
- User creation
- Password reset
- Critical warnings

Behavior

Dialogs should

- Fade in
- Scale slightly
- Dim the background
- Prevent accidental dismissal for destructive actions

---

# Search

Search should be available wherever large datasets exist.

Supported Modules

- Inventory
- Crops
- Planting Logs
- Notifications
- Users

Behavior

Search updates instantly.

Support partial matching.

Include a clear search button.

Search animation should feel responsive.

---

# Filtering

Lists should support filtering whenever appropriate.

Examples

Inventory

- Low Stock
- Available
- Empty

Crop Monitoring

- Active
- Harvest Ready

Notifications

- Unread
- Read
- Robot
- Inventory
- System

Filters should animate smoothly.

---

# Sorting

Supported sorting methods

Newest

Oldest

Alphabetical

Recently Updated

Sorting changes should not reload the page.

---

# Responsive Design

The application should adapt to

Small phones

Large phones

Future tablet support

Avoid hardcoded dimensions.

Prefer flexible layouts.

Cards should resize naturally.

Text should never overflow.

---

# Permission Behavior

The interface must adapt according to the authenticated user's role.

Users should never see functionality they cannot access.

Avoid disabled buttons for restricted features.

Instead

Hide unavailable modules completely.

Navigation should automatically update according to permissions.

---

# Session Management

Automatically keep authenticated users logged in.

If authentication expires

Redirect to Login Screen.

Display an appropriate message.

Save user preferences whenever possible.

---

# Offline Behavior

When internet connectivity is unavailable

Display

Offline banner

Disable cloud-dependent features

Continue displaying cached information whenever available.

Robot controls should automatically disable whenever both Wi-Fi and Bluetooth communication are unavailable.

If one communication method disconnects while the other remains active, the application should continue operating without interrupting the user's workflow.

---

# Notifications

Notification badges should update automatically.

Unread notifications should display

- Green indicator
- Bold title

Opening a notification should automatically mark it as read.

---

# Camera Experience

The live camera feed should remain responsive.

Provide

Fullscreen mode

Loading indicator

Offline placeholder

Connection status

The camera should support

- Live video streaming
- Fullscreen viewing
- Snapshot capture
- Automatic reconnection
- Connection diagnostics

# Communication Experience

The application supports two communication methods.

Primary

- Wi-Fi

Secondary

- Bluetooth

The user interface should clearly indicate the active communication method.

Connection indicators should update in real time.

Whenever communication changes, only the affected components should animate.

Avoid full-screen refreshes.

Communication failures should present clear recovery actions rather than technical error messages.
---

# Microinteractions

Every interaction should provide feedback.

Buttons

- Slight scale animation
- Ripple effect
- Soft glow

Cards

- Slight elevation on touch
- Soft shadow animation

Navigation

- Animated active indicator
- Icon scaling

Lists

- Smooth insertion
- Smooth removal

Notifications

- Slide animation

Dialogs

- Fade and scale

Sensor Updates

- Animated value changes
- Smooth transitions

Successful Operations

- Green confirmation animation

Failed Operations

- Gentle shake animation

# Live Data Updates

Sensor values should update independently without rebuilding the entire screen.

The following values should animate whenever they change:

- Battery Level
- Seed Level
- Soil Moisture
- Soil Temperature
- Environmental Temperature
- Humidity
- Current Activity

Animations should remain subtle and never distract the user from operating the rover.

---

# Accessibility

Maintain excellent readability.

Minimum touch target

48x48 pixels

Maintain high color contrast.

Support system font scaling.

Avoid relying only on colors for important information.

Icons should always include labels whenever appropriate.

---

# Performance Guidelines

Avoid unnecessary rebuilds.

Reuse widgets whenever possible.

Only update components that change.

Lazy load large datasets.

Optimize image loading.

Dispose controllers properly.

Avoid blocking the UI thread.

---

# Current System Capabilities

The current SeedRover implementation supports

- Manual rover movement
- Automated seed planting
- Live ESP32-CAM streaming
- Soil moisture monitoring
- Soil temperature monitoring
- Environmental temperature monitoring
- Humidity monitoring
- Battery monitoring
- Seed inventory monitoring
- LCD status display
- Activity LED indicators
- Wi-Fi communication
- Bluetooth communication

The application should fully expose these features through the appropriate user interface while remaining modular for future expansion.
---

# Future Compatibility

The application architecture should support future modules without requiring redesign.

Future Features

- Automated seed planting
- Long-range LoRa communication
- Weather integration
- GPS tracking
- AI crop recommendations
- Multiple robotic units
- Remote firmware updates

These features should not appear in the current application but should be considered during development.

# Overall Experience Guidelines

This section defines the overall experience, design standards, and interaction principles that should guide every future screen, feature, and component developed for SeedRover.

These guidelines take precedence over individual screen specifications whenever design decisions need to be made.

---

# Product Vision

SeedRover should feel like a modern agricultural technology platform designed for real-world deployment.

The application should not resemble:

- A student project
- A traditional CRUD application
- A generic Flutter template
- A dashboard filled with tables and forms

Instead, the application should resemble:

- A professional IoT control platform
- A commercial farm management system
- A premium robotics dashboard
- A modern SaaS product

Users should immediately feel that the application is:

- Reliable
- Intelligent
- Modern
- Easy to use
- Professionally developed

---

# Design Principles

Every screen should follow these principles.

## Clarity First

Users should never need to guess.

Important information must be obvious.

The interface should communicate clearly through:

- Layout
- Typography
- Color
- Icons
- Motion

Avoid unnecessary complexity.

---

## Information Before Decoration

Visual design should support information.

Do not add decorative elements that reduce readability.

Every element should serve a purpose.

---

## Consistency

All screens should behave consistently.

The same interaction should always produce the same result.

Examples

Buttons should always animate similarly.

Cards should always use the same styling.

Dialogs should always follow the same behavior.

Spacing should remain consistent.

---

## Minimal Cognitive Load

Users should not need to remember information across multiple screens.

The system should present important information proactively.

Reduce unnecessary navigation whenever possible.

---

## Progressive Disclosure

Show only what users need.

Avoid overwhelming screens with too many controls.

Advanced functionality should appear only when relevant.

---

# Visual Language

The visual language should remain consistent throughout the application.

Core Characteristics

- Dark theme
- Glassmorphism
- Green gradients
- Layered depth
- Smooth shadows
- Rounded corners
- Premium spacing

The interface should feel modern without appearing futuristic or experimental.

---

# Color Usage

Green should represent:

- Success
- Active status
- Healthy conditions
- Connected systems

Yellow should represent:

- Warnings
- Moderate conditions

Red should represent:

- Critical issues
- Errors
- Emergency controls

Avoid excessive use of bright colors.

Green should remain the primary accent color.

---

# Typography Philosophy

Typography should prioritize readability.

Roboto Mono should be used strategically.

Use Roboto Mono for:

- Sensor values
- Statistics
- Measurements
- Timestamps
- System data

Use Inter for:

- Headings
- Body text
- Navigation
- Forms

This combination creates a modern technical appearance while preserving readability.

---

# Layout Philosophy

Every screen should feel spacious.

Avoid crowded interfaces.

Preferred layout characteristics

- Large margins
- Large card spacing
- Comfortable padding
- Clear visual separation

Users should never feel overwhelmed by information.

---

# Component Philosophy

Components should feel alive.

Cards

- Elevate subtly
- Respond to interaction

Buttons

- Animate on press
- Provide feedback

Navigation

- Clearly indicate current location

Sensor values

- Update smoothly

The application should never feel static.

---

# Dashboard Philosophy

The Dashboard is the heart of the application.

It should function as a command center.

Users should be able to understand the current state of the system within seconds.

Critical information should always appear first.

---

# Rover Control Philosophy

The Rover Control screen should prioritize confidence.

Users must always understand:

- Whether Wi-Fi is connected
- Whether Bluetooth is connected
- Whether the camera is connected
- Whether the rover is connected
- Whether commands are being transmitted
- What the rover is currently doing
- Whether planting is currently active

Control actions should feel immediate and responsive.

---

# Error Philosophy

Errors should be calm and informative.

Never blame the user.

Avoid technical language.

Examples

Good

Unable to connect to the rover.

Please check the connection and try again.

Bad

Socket exception.

Connection timeout.

Stack trace...

---

# Empty State Philosophy

Empty states should feel intentional.

Every empty state should guide the user toward the next action.

Example

No inventory items found.

Add your first inventory item to begin tracking storage.

---

# Future Feature Guidelines

Future modules should follow existing design standards.

New features should not introduce:

- Different navigation systems
- Different card styles
- Different animation styles
- Different spacing systems

Every new module should feel like part of the same product.

---

# Development Standards

Developers should prioritize:

- Maintainability
- Readability
- Performance
- Reusability

Avoid creating one-off UI components.

Build reusable widgets whenever possible.

---

# Design Anti-Patterns

Avoid the following.

Do Not Use

- Sharp corners
- Heavy borders
- Dense tables
- Overly bright colors
- Excessive animations
- Cluttered screens
- Multiple floating buttons
- Generic Material Design templates

Avoid interfaces that feel outdated.

---

# Success Criteria

The application is successful if users can:

- Understand the system quickly
- Control the rover confidently
- Monitor farm conditions easily
- Access information without confusion
- Complete tasks efficiently

The interface should require minimal training.

---

# Long-Term Vision

As SeedRover evolves, the application should grow into a complete agricultural technology platform.

Future additions may include:

- Fully autonomous planting 
- AI recommendations
- Weather forecasting
- GPS tracking
- Multi-rover management
- Predictive analytics

Regardless of future growth, the application should remain:

- Clean
- Modern
- Consistent
- Fast
- Easy to use

Every future design decision should support these goals.

---

# Final Principle

Every screen, interaction, animation, and feature should answer one question:

"Does this help the user understand and operate the SeedRover system more effectively?"

If the answer is no, reconsider the design.

SeedRover should leave the impression of a premium, professional, and production-ready agricultural IoT platform.

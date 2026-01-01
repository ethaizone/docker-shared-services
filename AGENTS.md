# AGENTS.md - Development Guidelines for OpenMemory

## Build & Test Commands

### Backend (openmemory/backend/)
- `npm run dev` - Start development server with hot reload
- `npm run build` - Compile TypeScript to dist/
- `npm start` - Run production server
- `npm run format` - Format code with Prettier
- Type check: `npx tsc --noEmit`

### Dashboard (openmemory/dashboard/)
- `npm run dev` - Start Next.js dev server
- `npm run build` - Build for production
- `npm start` - Start production server
- `npm run lint` - Run ESLint

### JavaScript SDK (openmemory/sdk-js/)
- `npm run build` - Compile TypeScript to dist/

### Testing
Tests use custom harness (not Jest). Run single test:
- `node openmemory/tests/backend/api.test.js`
- `node openmemory/tests/js-sdk/js-sdk.test.js`
- `cd openmemory/tests/py-sdk && python test-sdk.py`

Run all: `make test` from openmemory/ directory

## Code Style Guidelines

### TypeScript/JavaScript

#### Imports
- Use `node:` prefix for builtin modules: `import fs from 'node:fs'`
- Group imports: builtins → external → internal
- Use absolute imports within same module: `from "../core/db"`

#### Formatting
- Backend: 4 spaces, double quotes, trailing commas
- Dashboard: 2 spaces, single quotes, trailing commas
- Run `npm run format` in respective directories

#### Naming Conventions
- Variables/functions: `camelCase`
- Classes: `PascalCase`
- Interfaces: `PascalCase` (e.g., `OpenMemoryOptions`)
- Constants: `SCREAMING_SNAKE_CASE` for magic numbers
- Private properties: prefix with `private` keyword, not underscore

#### Types
- Use interfaces for object shapes
- Use `any` sparingly; prefer `unknown` or explicit types
- Async functions: `Promise<T>` return type

#### Error Handling
- Use `throw new Error("message")` for expected errors
- Validate inputs early in functions
- Include context in error messages

### Python

#### Imports
- Group imports: stdlib → external → local
- Use absolute imports: `from openmemory.core.db import q`

#### Formatting
- Follow PEP 8
- Use `snake_case` for variables/functions
- Use `PascalCase` for classes

#### Error Handling
- Use `ValueError` for invalid inputs
- Use `Exception` for general errors
- Include descriptive messages

### React/Next.js

#### Components
- Functional components only
- `"use client"` directive for client components
- `PascalCase` component names
- Destructure props in function signature

#### Styling
- Tailwind CSS for styling
- Use `@/` alias for app-level imports

### Database & Storage

- SQLite with WAL mode enabled
- Vector store abstraction (sqlite, pgvector, valkey, weaviate)
- Use prepared statements via `q` object
- Thread-safe operations with locks (Python)

## Best Practices

- Check for existing functions before creating new ones
- Follow established patterns in similar modules
- Use parameterized functions instead of duplicating logic
- Avoid hardcoding paths; use variables
- Test changes before committing
- Ask before making destructive changes
- Keep functions focused on single responsibility

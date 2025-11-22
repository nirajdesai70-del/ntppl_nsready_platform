# NSReady Dashboard

Frontend dashboard application for the NSReady platform.

## Tech Stack

- **Vite** - Build tool and dev server
- **React 18** - UI framework
- **TypeScript** - Type safety
- **Tailwind CSS** - Styling
- **React Router** - Client-side routing

## Setup

1. Install dependencies:
   ```bash
   npm install
   ```

2. Start development server:
   ```bash
   npm run dev
   ```

3. Build for production:
   ```bash
   npm run build
   ```

## Development

The app runs on `http://localhost:5173` by default.

### Routing

The application uses tenant-based routing:
- Root path `/` redirects to `/t/demo-tenant`
- All routes are prefixed with `/t/:tenantSlug/`

Example URLs:
- `http://localhost:5173/t/demo-tenant`
- `http://localhost:5173/t/acme-corp`

## Project Structure

```
frontend_dashboard/
├── src/
│   ├── layouts/
│   │   └── DashboardLayout.tsx  # Main layout component
│   ├── App.tsx                   # Root component with routing
│   ├── main.tsx                  # Entry point
│   └── index.css                 # Global styles with Tailwind
├── index.html
├── package.json
├── vite.config.ts
├── tailwind.config.js
└── tsconfig.json
```

## Next Steps

- Add TenantBanner component
- Implement navigation menu
- Configure API proxy in `vite.config.ts` for backend integration
- Add dashboard pages and components



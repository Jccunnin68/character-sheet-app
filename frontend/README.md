# Character Sheet Frontend

React-based frontend for the character sheet management application.

## Features

- User authentication (login/register)
- Character creation and management
- Character sheet viewing and editing
- Responsive design with Tailwind CSS
- Form validation with React Hook Form and Yup

## Technology Stack

- React 18
- React Router for navigation
- Tailwind CSS for styling
- Axios for API calls
- React Hook Form for form handling
- React Toastify for notifications

## Getting Started

### Prerequisites

- Node.js 18 or higher
- npm or yarn

### Installation

1. Install dependencies:
```bash
npm install
```

2. Start the development server:
```bash
npm start
```

3. Open [http://localhost:3000](http://localhost:3000) to view it in the browser.

## Available Scripts

- `npm start` - Runs the app in development mode
- `npm build` - Builds the app for production
- `npm test` - Launches the test runner
- `npm eject` - Ejects from Create React App (one-way operation)

## Environment Variables

- `REACT_APP_API_URL` - Backend API URL (defaults to proxy configuration)

## Docker

Build and run with Docker:

```bash
docker build -t character-sheet-frontend .
docker run -p 3000:3000 character-sheet-frontend
``` 
# snake-game-qa2

Browser-playable Snake game served by Node.js 20 + Express, deployed to AWS EC2 via GitHub Actions.

## Local dev

```bash
npm install
npm start
# Visit http://localhost:3000
```

## Tests

```bash
npm test
```

## Endpoints

- `GET /` — Snake game (HTML)
- `GET /health` — `{"status":"ok"}` with HTTP 200
- All other paths — HTTP 404

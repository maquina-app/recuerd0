# Tech Stack

## Frontend

- **Framework:** Rails 8 views with Hotwire (Turbo + Stimulus)
- **Styling:** Tailwind CSS 4 with oklch colors
- **Build Tool:** Propshaft + Importmaps (no Node.js)
- **Component Library:** maquina-components gem

## Backend

- **Framework:** Ruby on Rails 8.0.2
- **Language:** Ruby 3.4.2
- **API Style:** Server-rendered HTML with Turbo Drive/Frames/Streams
- **Authentication:** Rails 8 built-in (bcrypt + sessions)
- **Background Jobs:** Solid Queue (SQLite-backed, in-process)

## Database

- **Primary:** SQLite 3 (via sqlite3 gem 2.1+)
- **Cache:** Solid Cache (SQLite-backed)
- **Search:** FTS5 virtual tables with trigram tokenizer
- **ORM:** ActiveRecord

## Infrastructure

- **Hosting:** Single server deployment
- **CI/CD:** GitHub Actions
- **Containerization:** Docker + Kamal 2.x
- **HTTP Acceleration:** Thruster
- **SSL:** Let's Encrypt via Kamal proxy

## Key Libraries

| Library | Purpose |
|---------|---------|
| Commonmarker | Markdown rendering (CommonMark spec) |
| Pagy | Pagination |
| maquina-components | UI component library |
| Solid Queue/Cache/Cable | SQLite-backed Rails infrastructure |

## Development Tools

- **Version Control:** Git, GitHub
- **Package Manager:** Bundler
- **Linting:** Standard Ruby (RuboCop wrapper)
- **Testing:** Minitest + Capybara + Selenium

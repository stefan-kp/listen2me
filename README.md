# Listen2Me

Listen2Me is an assistive communication application designed for people who are temporarily or permanently unable to speak, such as patients after tracheostomy or those with other conditions affecting speech capabilities.

## Features

- Text-to-Speech functionality
- Sentence categorization and management
- Quick access to frequently used sentences
- Multilingual interface (English/German)
- Three-step onboarding for language, interaction mode, and device checks
- Conversation mode with AI-powered response suggestions
- Optional low-latency Realtime conversation adapter with a local fallback
- Responsive design for desktop and mobile devices

## AI suggestions

Generated reply suggestions use an OpenAI-compatible LiteLLM proxy on the
server. Provider credentials and routing stay in LiteLLM; the browser receives
only the three short suggestions. Listen2Me supports two stable proxy aliases:

- `fast` for the lowest practical interaction latency (default)
- `cheap` for a lower-cost model

Set `LITELLM_HOST` (with or without `/v1`) and a dedicated
`LITELLM_SECRET`. The optional `LITELLM_FAST_MODEL` and
`LITELLM_CHEAP_MODEL` variables can map the two profiles to different proxy
aliases. The app bounds the request to three through five seconds (five by default),
validates the response, and immediately falls back to three localized standard
answers if the proxy is missing, unavailable, or returns malformed data.
Suggestions are never spoken merely because they were generated; the person
using Listen2Me always chooses the next action.

For the proxy, use a virtual application key restricted to these model aliases
and set budgets and rate limits centrally. Do not put provider keys into the
Listen2Me browser or source tree.

When LiteLLM runs directly on the Docker host, use
`LITELLM_HOST=http://host.docker.internal:4000` as shown in `.env.sample`.
When it runs as another Compose service, place both services on the same network
and use that service name instead, for example `http://litellm:4000`.

## Speech Output

The application supports two types of speech output:

### 1. Browser Speech (Default)
- Uses the built-in Web Speech API
- No additional configuration required
- Available in all modern browsers
- Quality depends on browser and installed voices
- Currently used for every spoken output, including when provider credentials are stored

### 2. Personal voice provider (planned adapter)
- The current settings contain device tests, but no personal provider key
  fields.
- A future personal-voice adapter must run server-side.
- The current demo deliberately uses browser speech only. Provider keys are
  never sent to the browser.
- Context suggestions work without a configured LiteLLM proxy by using three
  built-in, localized fallback suggestions.

![Category Overview](docs/sample1.png)
![Conversation View](docs/sample2.png)

> **Note**: This project is currently in early development and is being developed in our free time. We aim to create a free, open-source tool for people who need this type of assistance. We warmly welcome anyone who would like to contribute to this meaningful project!

## Quick Start with Docker

### Prerequisites
- Docker Desktop installed ([Download here](https://www.docker.com/products/docker-desktop/))
- Git installed ([Download here](https://git-scm.com/downloads))

### Installation Steps

1. Clone the repository:
   ```bash
   git clone https://github.com/stefan-kp/listen2me.git
   cd listen2me
   ```

2. Start the application:
   ```bash
   docker compose up
   ```

3. Access the application:
   - Open your browser and go to http://localhost:80
   - Create a new account
   - External services are optional for the current demo.
   - A server-side LiteLLM proxy enables generated conversation suggestions;
     without it, safe built-in suggestions remain available.

The first sign-in opens a short onboarding flow. The regular conversation mode
works without external services. If `OPENAI_API_KEY` is configured on the
server, the conversation screen additionally offers an experimental,
user-initiated Realtime mode; if it cannot connect, the normal flow remains
available. This key is not stored in a user account and is never sent to the
browser. The default is OpenAI's `gpt-realtime-2.1` model with low reasoning
effort for lower interaction latency; it can be overridden with
`OPENAI_REALTIME_MODEL`.

That's it! The application will automatically:
- Set up the database
- Install all dependencies
- Start the development server
- Initialize required data, including an idempotent default-content backfill for
  existing accounts

> **Note**: The application uses Docker and PostgreSQL. The database configuration 
> is handled automatically through environment variables in docker-compose.yml - 
> no manual database configuration is needed.

For deployments, keep `SECRET_KEY_BASE` stable. Provider-key encryption is
derived from it unless the three dedicated variables
`ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`,
`ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`, and
`ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` are supplied. Dedicated,
secret-managed values are recommended for production.

### Stopping the Application
```bash
docker compose down
```

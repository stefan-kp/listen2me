# Listen2Me

Listen2Me is an assistive communication application designed for people who are temporarily or permanently unable to speak, such as patients after tracheostomy or those with other conditions affecting speech capabilities.

## Features

- Text-to-Speech functionality
- Sentence categorization and management
- Quick access to frequently used sentences
- Multilingual interface (English/German)
- Conversation mode with AI-powered response suggestions
- Responsive design for desktop and mobile devices

## Speech Output

The application supports two types of speech output:

### 1. Browser Speech (Default)
- Uses the built-in Web Speech API
- No additional configuration required
- Available in all modern browsers
- Quality depends on browser and installed voices
- Automatically used when ElevenLabs is not configured

### 2. ElevenLabs Integration (Optional)
- High-quality, natural-sounding voices
- Multilingual support
- Requires:
  - ElevenLabs API key
  - Voice ID
- Configure through the settings page
- Automatic fallback to browser speech if not configured or on errors

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

   copy the database config:
   ```bash
   cp config/database.yml.sample config/database.yml
   ```

2. Start the application:
   ```bash
   docker compose up
   ```

3. Access the application:
   - Open your browser and go to http://localhost:80
   - Create a new account
   - IMPORTANT Add your API keys in the settings:
     - ElevenLabs API key for text-to-speech
     - Choose your preferred LLM provider (OpenAI, Anthropic, or Gemini) and add the API key

That's it! The application will automatically:
- Set up the database
- Install all dependencies
- Start the development server
- Initialize required data

> **Note**: The application uses Docker and PostgreSQL. The database configuration 
> is handled automatically through environment variables in docker-compose.yml - 
> no manual database configuration is needed.

### Stopping the Application
```bash
docker compose down
```
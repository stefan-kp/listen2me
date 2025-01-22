# Listen2Me

Listen2Me is an assistive communication application designed for people who are temporarily or permanently unable to speak, such as patients after tracheostomy or those with other conditions affecting speech capabilities.

![Category Overview](docs/sample1.png)
![Conversation View](docs/sample2.png)

> **Note**: This project is currently in early development and is being developed in our free time. We aim to create a free, open-source tool for people who need this type of assistance. We warmly welcome anyone who would like to contribute to this meaningful project!

## Overview

The application provides a multi-modal communication system that combines:
- Pre-defined phrases organized by categories
- Text-to-speech capabilities
- Speech recognition for caregivers
- AI-powered conversation suggestions
- Multi-language support (English and German)

## Features

### Category-Based Communication
- Quick access to common phrases organized by categories (Basic Needs, Food, Health, etc.)
- Visual icons for intuitive navigation
- Usage tracking to prioritize frequently used phrases

### Speech Synthesis
- High-quality text-to-speech using ElevenLabs API
- Natural-sounding voice output
- Support for multiple languages

### Interactive Conversations
- Two-way communication support
- Speech recognition for caregiver responses
- Real-time transcription of spoken words

### AI-Powered Suggestions
- Context-aware response suggestions using GPT-4
- Dynamic adaptation to conversation flow
- Personalized suggestions based on user profile and conversation history

## Technical Details

### Requirements
- Ruby 3.2+
- Rails 7.1+
- PostgreSQL
- ElevenLabs API key for speech synthesis
- OpenAI API key for conversation suggestions

### Key Technologies
- Rails 8.0 for the backend
- Stimulus.js for frontend interactivity
- Turbo for real-time updates
- Tailwind CSS for styling
- LangChain for AI integration
- Web Speech API for speech recognition

### Setup
1. Clone the repository
2. Install dependencies: `bundle install`
3. Setup database: `rails db:setup`
4. Add your API keys to credentials
5. Start the server: `rails s`

## Contributing

We welcome contributions! Please feel free to submit pull requests or open issues for any improvements or bug fixes.

We are actively seeking contributors who want to help make this tool better for people who need it. Whether you're a developer, designer, healthcare professional, or someone with experience in assistive technologies, your input is valuable.

### Ways to Contribute
- Code contributions
- UI/UX improvements
- Accessibility enhancements
- Documentation
- Testing and feedback
- Translations
- Feature suggestions

Our goal is to keep this tool free and accessible to everyone who needs it. Together, we can make communication easier for people facing speech challenges.

## License

This project is licensed under the MIT License - see the LICENSE.md file for details.

## Acknowledgments

- ElevenLabs for providing the text-to-speech capabilities
- OpenAI for powering the conversation suggestions
- All contributors and supporters of the project

## Contact

For questions or support, please open an issue in the GitHub repository.

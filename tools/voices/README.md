# Dialogue voices (ElevenLabs)

Pre-generates MP3 lines for Jack, Reggie, Vivienne and Lord Ashcombe, then plays them from `DialogueBox` when the speaker+text match exactly.

## Setup

1. Copy `secrets.local.json.example` → `secrets.local.json` and put your API key there (gitignored).
2. Voice IDs live in `voices.json`.
3. Generate:

```powershell
python tools/voices/generate_dialogue_voices.py --dry   # list 116 static lines
python tools/voices/generate_dialogue_voices.py         # write assets/voices/**/*.mp3
```

Professional / library voices need a paid API balance (about $5). Free premade voices work; the four cast voices do not until credits are added.

## In game

`VoiceBank` loads `assets/voices/manifest.json`. Dynamic lines with `%` numbers stay silent until you regenerate after hardcoding or add a runtime TTS path.

Re-run the script after adding or changing static dialogue text; existing files are skipped unless `--force`.

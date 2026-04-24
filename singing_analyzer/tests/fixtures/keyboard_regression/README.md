# Keyboard Regression Samples

Place a few short keyboard recordings here to enable real-audio regression checks.

Recommended format:

- `.wav`
- 1 to 10 seconds
- small files suitable for local test runs

The FastAPI tests always run the synthetic keyboard AB checks. Files in this
directory add a lighter real-recording check: each sample must return a completed
keyboard response, keep the four keyboard-specific scores, and avoid extreme
all-low or all-high results.

The current fixture set also includes small `.wav` samples for weak pairwise
regression checks:

- `connected_keyboard.wav` > `choppy_keyboard.wav` for `note_connection_score`
- `even_touch_keyboard.wav` > `uneven_touch_keyboard.wav` for `touch_score`
- `stable_chord_keyboard.wav` > `wobbly_chord_keyboard.wav` for `chord_stability_score`
- `clean_harmony_keyboard.wav` > `noisy_harmony_keyboard.wav` for `harmony_score`

Replace or add to these files with short real recordings when available, keeping
the file sizes small enough for local and CI test runs.

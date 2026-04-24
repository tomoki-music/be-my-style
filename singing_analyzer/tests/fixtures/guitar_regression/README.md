# Guitar Regression Samples

Place a few short guitar recordings here to enable real-audio regression checks.

Recommended format:

- `.wav`
- 1 to 10 seconds
- small files suitable for local test runs

The FastAPI tests always run the synthetic guitar AB checks. Files in this
directory add a lighter real-recording check: each sample must return a completed
guitar response, keep the three guitar-specific scores, and avoid extreme all-low
or all-high results.

The current fixture set also includes small `.wav` samples for a weak pairwise
regression check:

- `clear_attack_guitar.wav` > `blurred_attack_guitar.wav` for `attack_score`

Replace or add to these files with short real recordings when available, keeping
the file sizes small enough for local and CI test runs.

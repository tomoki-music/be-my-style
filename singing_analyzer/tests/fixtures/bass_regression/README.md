# Bass Regression Samples

Place a few short bass recordings here to enable real-audio regression checks.

Recommended format:

- `.wav`
- 1 to 10 seconds
- small files suitable for local test runs

The FastAPI tests always run the synthetic bass AB checks. Files in this
directory add a lighter real-recording check: each sample must return a completed
bass response, keep the three bass-specific scores, and avoid extreme all-low or
all-high results.

The current fixture set also includes small `.wav` samples for a weak pairwise
regression check:

- `steady_groove_bass.wav` > `irregular_groove_bass.wav` for `groove_score`

Replace or add to these files with short real recordings when available, keeping
the file sizes small enough for local and CI test runs.

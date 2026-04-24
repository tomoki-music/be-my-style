import io
import math
from pathlib import Path
import struct
import wave
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)

GUITAR_SPECIFIC_KEYS = {
    "attack_score",
    "muting_score",
    "stability_score",
}
BASS_SPECIFIC_KEYS = {
    "groove_score",
    "note_length_score",
    "stability_score",
}
KEYBOARD_SPECIFIC_KEYS = {
    "chord_stability_score",
    "note_connection_score",
    "touch_score",
    "harmony_score",
}
BAND_SPECIFIC_KEYS = {
    "balance",
    "tightness",
    "groove",
    "role_clarity",
    "dynamics",
    "cohesion",
}
GUITAR_REGRESSION_SAMPLE_DIR = Path(__file__).parent / "fixtures" / "guitar_regression"
BASS_REGRESSION_SAMPLE_DIR = Path(__file__).parent / "fixtures" / "bass_regression"
KEYBOARD_REGRESSION_SAMPLE_DIR = Path(__file__).parent / "fixtures" / "keyboard_regression"
GUITAR_REGRESSION_SAMPLE_PAIRS = {
    "attack_score": ("clear_attack_guitar.wav", "blurred_attack_guitar.wav"),
}
BASS_REGRESSION_SAMPLE_PAIRS = {
    "groove_score": ("steady_groove_bass.wav", "irregular_groove_bass.wav"),
}
KEYBOARD_REGRESSION_SAMPLE_PAIRS = {
    "note_connection_score": ("connected_keyboard.wav", "choppy_keyboard.wav"),
    "touch_score": ("even_touch_keyboard.wav", "uneven_touch_keyboard.wav"),
    "chord_stability_score": ("stable_chord_keyboard.wav", "wobbly_chord_keyboard.wav"),
    "harmony_score": ("clean_harmony_keyboard.wav", "noisy_harmony_keyboard.wav"),
}


def make_wav_bytes(duration_seconds=1.2, sample_rate=16000, frequency=440.0, amplitude=0.35):
    buffer = io.BytesIO()
    frame_count = int(duration_seconds * sample_rate)

    with wave.open(buffer, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)

        for index in range(frame_count):
            sample = amplitude * math.sin(2 * math.pi * frequency * (index / sample_rate))
            wav.writeframes(struct.pack("<h", int(sample * 32767)))

    return buffer.getvalue()


def make_silent_wav_bytes(duration_seconds=12.0, sample_rate=16000):
    buffer = io.BytesIO()
    frame_count = int(duration_seconds * sample_rate)

    with wave.open(buffer, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)

        for _ in range(frame_count):
            wav.writeframes(struct.pack("<h", 0))

    return buffer.getvalue()


def make_clipped_wav_bytes(duration_seconds=12.0, sample_rate=16000, frequency=220.0):
    buffer = io.BytesIO()
    frame_count = int(duration_seconds * sample_rate)

    with wave.open(buffer, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)

        for index in range(frame_count):
            raw_sample = 1.35 * math.sin(2 * math.pi * frequency * (index / sample_rate))
            sample = max(-1.0, min(raw_sample, 1.0))
            wav.writeframes(struct.pack("<h", int(sample * 32767)))

    return buffer.getvalue()


def make_plucked_wav_bytes(duration_seconds=1.6, sample_rate=16000, frequency=220.0, amplitude=0.45):
    buffer = io.BytesIO()
    frame_count = int(duration_seconds * sample_rate)
    pluck_interval = int(0.25 * sample_rate)

    with wave.open(buffer, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)

        for index in range(frame_count):
            local_index = index % pluck_interval
            envelope = math.exp(-7.0 * (local_index / max(pluck_interval, 1)))
            sample = amplitude * envelope * math.sin(2 * math.pi * frequency * (index / sample_rate))
            wav.writeframes(struct.pack("<h", int(sample * 32767)))

    return buffer.getvalue()


def make_sequence_wav_bytes(
    duration_seconds=1.6,
    sample_rate=16000,
    frequency=220.0,
    intervals=(0.25,),
    amplitudes=(0.45,),
    active_seconds=(0.22,),
    attack_seconds=0.008,
    decay=7.0,
    sustain_floor=0.0,
    detune_depth=0.0,
    noise_amount=0.0,
):
    buffer = io.BytesIO()
    frame_count = int(duration_seconds * sample_rate)
    note_starts = []
    elapsed = 0.0
    note_index = 0
    while elapsed < duration_seconds:
        note_starts.append(elapsed)
        elapsed += intervals[note_index % len(intervals)]
        note_index += 1

    with wave.open(buffer, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)

        current_note = 0
        for index in range(frame_count):
            time = index / sample_rate
            while current_note + 1 < len(note_starts) and time >= note_starts[current_note + 1]:
                current_note += 1

            local_time = time - note_starts[current_note]
            active_time = active_seconds[current_note % len(active_seconds)]
            if local_time > active_time:
                sample = 0.0
            else:
                attack = max(attack_seconds, 1 / sample_rate)
                envelope = min(1.0, local_time / attack)
                envelope *= sustain_floor + ((1.0 - sustain_floor) * math.exp(-decay * (local_time / max(active_time, 1 / sample_rate))))
                amplitude = amplitudes[current_note % len(amplitudes)]
                detune = 1.0 + (detune_depth * math.sin(2 * math.pi * 3.7 * time))
                tone = math.sin(2 * math.pi * frequency * detune * time)
                overtone = 0.28 * math.sin(2 * math.pi * frequency * 2.01 * detune * time)
                deterministic_noise = (((index * 1103515245 + 12345) & 0x7FFFFFFF) / 0x7FFFFFFF) * 2.0 - 1.0
                sample = amplitude * envelope * (tone + overtone)
                sample += noise_amount * envelope * deterministic_noise

            wav.writeframes(struct.pack("<h", int(max(-1.0, min(sample, 1.0)) * 32767)))

    return buffer.getvalue()


def make_blurred_guitar_wav_bytes():
    return make_sequence_wav_bytes(
        frequency=220.0,
        attack_seconds=0.09,
        decay=1.8,
        sustain_floor=0.3,
        active_seconds=(0.24,),
    )


def make_ringing_guitar_wav_bytes():
    return make_sequence_wav_bytes(
        frequency=220.0,
        attack_seconds=0.012,
        decay=0.5,
        sustain_floor=0.68,
        active_seconds=(0.25,),
        noise_amount=0.015,
    )


def make_unstable_guitar_wav_bytes():
    return make_sequence_wav_bytes(
        frequency=220.0,
        intervals=(0.18, 0.31, 0.22, 0.36),
        amplitudes=(0.18, 0.55, 0.28, 0.48),
        active_seconds=(0.1, 0.24, 0.15, 0.28),
        decay=4.0,
        detune_depth=0.045,
        noise_amount=0.035,
    )


def make_steady_bass_wav_bytes():
    return make_sequence_wav_bytes(
        frequency=110.0,
        intervals=(0.25,),
        amplitudes=(0.42,),
        active_seconds=(0.18,),
        attack_seconds=0.01,
        decay=6.0,
    )


def make_irregular_bass_wav_bytes():
    return make_sequence_wav_bytes(
        frequency=110.0,
        intervals=(0.17, 0.34, 0.2, 0.31),
        amplitudes=(0.38, 0.44, 0.35, 0.46),
        active_seconds=(0.16, 0.21, 0.12, 0.28),
        attack_seconds=0.012,
        decay=5.0,
        detune_depth=0.02,
    )


def make_uneven_note_length_bass_wav_bytes():
    return make_sequence_wav_bytes(
        frequency=110.0,
        intervals=(0.25,),
        amplitudes=(0.34, 0.52, 0.3, 0.47),
        active_seconds=(0.055, 0.32, 0.08, 0.36),
        attack_seconds=0.01,
        decay=2.0,
        sustain_floor=0.42,
    )


def make_unstable_bass_wav_bytes():
    return make_sequence_wav_bytes(
        frequency=110.0,
        intervals=(0.18, 0.3, 0.21, 0.35),
        amplitudes=(0.18, 0.56, 0.26, 0.5),
        active_seconds=(0.08, 0.3, 0.13, 0.34),
        attack_seconds=0.012,
        decay=3.5,
        sustain_floor=0.25,
        detune_depth=0.055,
        noise_amount=0.025,
    )


def make_percussive_wav_bytes(duration_seconds=1.6, sample_rate=16000, frequency=110.0, amplitude=0.5):
    buffer = io.BytesIO()
    frame_count = int(duration_seconds * sample_rate)
    hit_interval = int(0.2 * sample_rate)

    with wave.open(buffer, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)

        for index in range(frame_count):
            local_index = index % hit_interval
            envelope = math.exp(-14.0 * (local_index / max(hit_interval, 1)))
            tone = math.sin(2 * math.pi * frequency * (index / sample_rate))
            overtone = 0.45 * math.sin(2 * math.pi * frequency * 2.1 * (index / sample_rate))
            sample = amplitude * envelope * (tone + overtone)
            wav.writeframes(struct.pack("<h", int(max(-1.0, min(sample, 1.0)) * 32767)))

    return buffer.getvalue()


def make_keyboard_wav_bytes(duration_seconds=1.6, sample_rate=16000, amplitude=0.32):
    buffer = io.BytesIO()
    frame_count = int(duration_seconds * sample_rate)
    note_interval = int(0.4 * sample_rate)
    frequencies = (261.63, 329.63, 392.0)

    with wave.open(buffer, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)

        for index in range(frame_count):
            local_index = index % note_interval
            envelope = min(1.0, local_index / max(int(0.04 * sample_rate), 1))
            envelope *= math.exp(-0.8 * (local_index / max(note_interval, 1)))
            sample = 0.0
            for frequency in frequencies:
                sample += math.sin(2 * math.pi * frequency * (index / sample_rate))
            sample = amplitude * envelope * (sample / len(frequencies))
            wav.writeframes(struct.pack("<h", int(max(-1.0, min(sample, 1.0)) * 32767)))

    return buffer.getvalue()


def make_choppy_keyboard_wav_bytes(duration_seconds=1.6, sample_rate=16000, amplitude=0.32):
    buffer = io.BytesIO()
    frame_count = int(duration_seconds * sample_rate)
    note_interval = int(0.4 * sample_rate)
    active_samples = int(0.08 * sample_rate)
    frequencies = (261.63, 329.63, 392.0)

    with wave.open(buffer, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)

        for index in range(frame_count):
            local_index = index % note_interval
            if local_index > active_samples:
                sample = 0.0
            else:
                envelope = math.exp(-1.8 * (local_index / max(active_samples, 1)))
                sample = 0.0
                for frequency in frequencies:
                    sample += math.sin(2 * math.pi * frequency * (index / sample_rate))
                sample = amplitude * envelope * (sample / len(frequencies))
            wav.writeframes(struct.pack("<h", int(max(-1.0, min(sample, 1.0)) * 32767)))

    return buffer.getvalue()


def make_uneven_touch_keyboard_wav_bytes(duration_seconds=1.6, sample_rate=16000):
    buffer = io.BytesIO()
    frame_count = int(duration_seconds * sample_rate)
    note_interval = int(0.4 * sample_rate)
    amplitudes = (0.18, 0.52, 0.24, 0.46)
    frequencies = (261.63, 329.63, 392.0)

    with wave.open(buffer, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)

        for index in range(frame_count):
            note_index = (index // note_interval) % len(amplitudes)
            local_index = index % note_interval
            envelope = min(1.0, local_index / max(int(0.025 * sample_rate), 1))
            envelope *= math.exp(-0.9 * (local_index / max(note_interval, 1)))
            sample = 0.0
            for frequency in frequencies:
                sample += math.sin(2 * math.pi * frequency * (index / sample_rate))
            sample = amplitudes[note_index] * envelope * (sample / len(frequencies))
            wav.writeframes(struct.pack("<h", int(max(-1.0, min(sample, 1.0)) * 32767)))

    return buffer.getvalue()


def make_wobbly_keyboard_wav_bytes(duration_seconds=1.6, sample_rate=16000, amplitude=0.32):
    buffer = io.BytesIO()
    frame_count = int(duration_seconds * sample_rate)
    note_interval = int(0.4 * sample_rate)
    frequencies = (261.63, 329.63, 392.0)

    with wave.open(buffer, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)

        for index in range(frame_count):
            time = index / sample_rate
            local_index = index % note_interval
            envelope = min(1.0, local_index / max(int(0.04 * sample_rate), 1))
            envelope *= math.exp(-0.7 * (local_index / max(note_interval, 1)))
            envelope *= 0.72 + (0.28 * math.sin(2 * math.pi * 5.0 * time))
            sample = 0.0
            for position, frequency in enumerate(frequencies, start=1):
                detune = 1.0 + (0.035 * math.sin(2 * math.pi * (3.0 + position) * time))
                sample += math.sin(2 * math.pi * frequency * detune * time)
            sample = amplitude * envelope * (sample / len(frequencies))
            wav.writeframes(struct.pack("<h", int(max(-1.0, min(sample, 1.0)) * 32767)))

    return buffer.getvalue()


def make_noisy_keyboard_wav_bytes(duration_seconds=1.6, sample_rate=16000, amplitude=0.28):
    buffer = io.BytesIO()
    frame_count = int(duration_seconds * sample_rate)
    note_interval = int(0.4 * sample_rate)
    frequencies = (261.63, 329.63, 392.0, 415.3)

    with wave.open(buffer, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)

        for index in range(frame_count):
            local_index = index % note_interval
            envelope = min(1.0, local_index / max(int(0.035 * sample_rate), 1))
            envelope *= math.exp(-0.85 * (local_index / max(note_interval, 1)))
            sample = 0.0
            for frequency in frequencies:
                sample += math.sin(2 * math.pi * frequency * (index / sample_rate))
            deterministic_noise = (((index * 1103515245 + 12345) & 0x7FFFFFFF) / 0x7FFFFFFF) * 2.0 - 1.0
            sample = (amplitude * envelope * (sample / len(frequencies))) + (0.16 * envelope * deterministic_noise)
            wav.writeframes(struct.pack("<h", int(max(-1.0, min(sample, 1.0)) * 32767)))

    return buffer.getvalue()


def post_performance_diagnosis(performance_type, audio_bytes, diagnosis_id):
    return client.post(
        "/diagnoses",
        data={
            "diagnosis_id": diagnosis_id,
            "performance_type": performance_type,
            "song_title": f"{performance_type.title()} AB",
            "memo": f"Check {performance_type} AB",
        },
        files={
            "audio_file": (f"{diagnosis_id}.wav", audio_bytes, "audio/wav"),
        },
    )


def post_keyboard_diagnosis(audio_bytes, diagnosis_id="keyboard-ab"):
    return post_performance_diagnosis("keyboard", audio_bytes, diagnosis_id)


def post_band_diagnosis(audio_bytes, diagnosis_id="band-ab"):
    return post_performance_diagnosis("band", audio_bytes, diagnosis_id)


def post_keyboard_sample_file(sample_path):
    return post_keyboard_diagnosis(sample_path.read_bytes(), f"keyboard-real-{sample_path.stem}")


def post_regression_sample_file(performance_type, sample_path):
    return post_performance_diagnosis(
        performance_type,
        sample_path.read_bytes(),
        f"{performance_type}-real-{sample_path.stem}",
    )


def regression_sample(sample_dir, filename):
    return sample_dir / filename


def keyboard_regression_sample(filename):
    return regression_sample(KEYBOARD_REGRESSION_SAMPLE_DIR, filename)


def assert_valid_keyboard_body(body):
    assert body["schema_version"] == 1
    assert body["performance_type"] == "keyboard"
    assert body["common"] == {
        "overall_score": body["overall_score"],
        "pitch_score": body["pitch_score"],
        "rhythm_score": body["rhythm_score"],
        "expression_score": body["expression_score"],
    }
    assert set(body["specific"].keys()) == KEYBOARD_SPECIFIC_KEYS
    assert all(0 <= body[key] <= 100 for key in body["common"].keys())
    assert all(0 <= value <= 100 for value in body["specific"].values())


def assert_valid_specific_body(body, performance_type, specific_keys):
    assert body["schema_version"] == 1
    assert body["performance_type"] == performance_type
    assert body["common"] == {
        "overall_score": body["overall_score"],
        "pitch_score": body["pitch_score"],
        "rhythm_score": body["rhythm_score"],
        "expression_score": body["expression_score"],
    }
    assert set(body["specific"].keys()) == specific_keys
    assert all(0 <= body[key] <= 100 for key in body["common"].keys())
    assert all(math.isfinite(value) and 0 <= value <= 100 for value in body["specific"].values())


def assert_valid_band_analysis_debug(body):
    debug = body["analysis_debug"]

    assert set(debug.keys()) == {
        "rms_mean",
        "rms_std",
        "peak",
        "silence_ratio",
        "onset_count",
        "onset_interval_std",
        "spectral_balance",
        "dynamics_range",
        "cohesion_inputs",
    }
    assert math.isfinite(debug["rms_mean"]) and debug["rms_mean"] >= 0
    assert math.isfinite(debug["rms_std"]) and debug["rms_std"] >= 0
    assert math.isfinite(debug["peak"]) and 0 <= debug["peak"] <= 1.0
    assert math.isfinite(debug["silence_ratio"]) and 0 <= debug["silence_ratio"] <= 1.0
    assert isinstance(debug["onset_count"], int) and debug["onset_count"] >= 0
    assert math.isfinite(debug["onset_interval_std"]) and debug["onset_interval_std"] >= 0
    assert set(debug["spectral_balance"].keys()) == {"low", "mid", "high"}
    assert all(
        math.isfinite(value) and 0 <= value <= 1.0
        for value in debug["spectral_balance"].values()
    )
    assert 0.95 <= sum(debug["spectral_balance"].values()) <= 1.05
    assert math.isfinite(debug["dynamics_range"]) and debug["dynamics_range"] >= 0
    assert debug["cohesion_inputs"] == {
        "balance": body["specific"]["balance"],
        "tightness": body["specific"]["tightness"],
        "groove": body["specific"]["groove"],
        "role_clarity": body["specific"]["role_clarity"],
        "dynamics": body["specific"]["dynamics"],
    }


def assert_valid_band_quality(body):
    quality_flags = body["quality_flags"]

    assert set(quality_flags.keys()) == {
        "too_short",
        "too_quiet",
        "too_loud",
        "clipping_detected",
        "mostly_silent",
        "low_confidence",
    }
    assert all(isinstance(value, bool) for value in quality_flags.values())
    assert body["quality_message"] is None or isinstance(body["quality_message"], str)


def assert_keyboard_scores_not_extreme(body):
    scores = list(body["specific"].values())

    assert not all(score <= 5 for score in scores)
    assert not all(score >= 98 for score in scores)


def assert_specific_scores_not_extreme(body):
    scores = list(body["specific"].values())

    assert not all(score <= 5 for score in scores)
    assert not all(score >= 98 for score in scores)


def test_health():
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_create_diagnosis():
    response = client.post(
        "/diagnoses",
        data={
            "diagnosis_id": "123",
            "performance_type": "vocal",
            "song_title": "Sample Song",
            "memo": "Check pitch",
        },
        files={
            "audio_file": ("sample.wav", make_wav_bytes(), "audio/wav"),
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["schema_version"] == 1
    assert body["performance_type"] == "vocal"
    assert body["common"] == {
        "overall_score": body["overall_score"],
        "pitch_score": body["pitch_score"],
        "rhythm_score": body["rhythm_score"],
        "expression_score": body["expression_score"],
    }
    assert set(body["specific"].keys()) == {
        "volume_score",
        "pronunciation_score",
        "relax_score",
        "mix_voice_score",
    }
    assert body["analysis_debug"] == {}
    assert body["quality_flags"] == {}
    assert body["quality_message"] is None
    assert all(0 <= body[key] <= 100 for key in body["common"].keys())
    assert all(0 <= value <= 100 for value in body["specific"].values())


def test_create_diagnosis_returns_reference_comparison_when_reference_is_provided():
    response = client.post(
        "/diagnoses",
        data={
            "diagnosis_id": "reference-123",
            "performance_type": "vocal",
            "song_title": "Reference Song",
            "memo": "Check reference",
            "reference_key": "A",
            "reference_bpm": "120",
        },
        files={
            "audio_file": ("reference.wav", make_plucked_wav_bytes(frequency=220.0), "audio/wav"),
        },
    )

    assert response.status_code == 200
    body = response.json()
    comparison = body["reference_comparison"]

    assert comparison["reference_key"] == "A"
    assert comparison["estimated_key"] == "A"
    assert comparison["key_match_level"] in {"exact", "close"}
    assert comparison["reference_bpm"] == 120.0
    assert comparison["estimated_bpm"] is not None
    assert comparison["bpm_diff"] >= 0
    assert comparison["tempo_match_level"] in {"close", "near", "far"}


def test_create_diagnosis_rejects_unsupported_performance_type():
    response = client.post(
        "/diagnoses",
        data={
            "diagnosis_id": "123",
            "performance_type": "violin",
            "song_title": "Sample Song",
            "memo": "Check violin",
        },
        files={
            "audio_file": ("sample.wav", make_wav_bytes(), "audio/wav"),
        },
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "Unknown performance_type: violin."


def test_create_diagnosis_accepts_guitar():
    response = client.post(
        "/diagnoses",
        data={
            "diagnosis_id": "123",
            "performance_type": "guitar",
            "song_title": "Sample Song",
            "memo": "Check guitar",
        },
        files={
            "audio_file": ("sample.wav", make_wav_bytes(), "audio/wav"),
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["schema_version"] == 1
    assert body["performance_type"] == "guitar"
    assert body["common"] == {
        "overall_score": body["overall_score"],
        "pitch_score": body["pitch_score"],
        "rhythm_score": body["rhythm_score"],
        "expression_score": body["expression_score"],
    }
    assert set(body["specific"].keys()) == {
        "attack_score",
        "muting_score",
        "stability_score",
    }
    assert all(0 <= body[key] <= 100 for key in body["common"].keys())
    assert all(0 <= value <= 100 for value in body["specific"].values())


def test_create_guitar_diagnosis_with_plucked_audio_returns_stable_specific_scores():
    response = client.post(
        "/diagnoses",
        data={
            "diagnosis_id": "123",
            "performance_type": "guitar",
            "song_title": "Plucked Guitar",
            "memo": "Check guitar articulation",
        },
        files={
            "audio_file": ("plucked.wav", make_plucked_wav_bytes(), "audio/wav"),
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["performance_type"] == "guitar"
    assert set(body["specific"].keys()) == {
        "attack_score",
        "muting_score",
        "stability_score",
    }
    assert all(0 <= value <= 100 for value in body["specific"].values())
    assert body["specific"]["attack_score"] >= 35
    assert body["specific"]["muting_score"] >= 35
    assert body["specific"]["stability_score"] >= 35


def test_guitar_attack_reflects_clear_note_start():
    clear_response = post_performance_diagnosis("guitar", make_plucked_wav_bytes(), "guitar-clear-attack")
    blurred_response = post_performance_diagnosis("guitar", make_blurred_guitar_wav_bytes(), "guitar-blurred-attack")

    assert clear_response.status_code == 200
    assert blurred_response.status_code == 200

    clear_body = clear_response.json()
    blurred_body = blurred_response.json()
    assert_valid_specific_body(clear_body, "guitar", GUITAR_SPECIFIC_KEYS)
    assert_valid_specific_body(blurred_body, "guitar", GUITAR_SPECIFIC_KEYS)
    assert clear_body["specific"]["attack_score"] > blurred_body["specific"]["attack_score"]


def test_guitar_muting_reflects_controlled_decay():
    muted_response = post_performance_diagnosis("guitar", make_plucked_wav_bytes(), "guitar-controlled-muting")
    ringing_response = post_performance_diagnosis("guitar", make_ringing_guitar_wav_bytes(), "guitar-ringing-muting")

    assert muted_response.status_code == 200
    assert ringing_response.status_code == 200

    muted_body = muted_response.json()
    ringing_body = ringing_response.json()
    assert_valid_specific_body(muted_body, "guitar", GUITAR_SPECIFIC_KEYS)
    assert_valid_specific_body(ringing_body, "guitar", GUITAR_SPECIFIC_KEYS)
    assert muted_body["specific"]["muting_score"] > ringing_body["specific"]["muting_score"]


def test_guitar_stability_reflects_even_timing_and_strength():
    stable_response = post_performance_diagnosis("guitar", make_plucked_wav_bytes(), "guitar-stable")
    unstable_response = post_performance_diagnosis("guitar", make_unstable_guitar_wav_bytes(), "guitar-unstable")

    assert stable_response.status_code == 200
    assert unstable_response.status_code == 200

    stable_body = stable_response.json()
    unstable_body = unstable_response.json()
    assert_valid_specific_body(stable_body, "guitar", GUITAR_SPECIFIC_KEYS)
    assert_valid_specific_body(unstable_body, "guitar", GUITAR_SPECIFIC_KEYS)
    assert stable_body["specific"]["stability_score"] > unstable_body["specific"]["stability_score"]


def test_guitar_real_recording_samples_do_not_break_regression():
    sample_paths = sorted(GUITAR_REGRESSION_SAMPLE_DIR.glob("*.wav"))
    if not sample_paths:
        pytest.skip(
            f"No guitar regression .wav samples found in {GUITAR_REGRESSION_SAMPLE_DIR}. "
            "Add short guitar recordings there to enable real-audio regression checks."
        )

    for sample_path in sample_paths:
        response = post_regression_sample_file("guitar", sample_path)

        assert response.status_code == 200, sample_path.name
        body = response.json()
        assert_valid_specific_body(body, "guitar", GUITAR_SPECIFIC_KEYS)
        assert_specific_scores_not_extreme(body)


def test_guitar_real_recording_pairs_keep_expected_direction():
    missing_files = [
        filename
        for pair in GUITAR_REGRESSION_SAMPLE_PAIRS.values()
        for filename in pair
        if not regression_sample(GUITAR_REGRESSION_SAMPLE_DIR, filename).exists()
    ]
    if missing_files:
        pytest.skip(
            "Guitar regression pair samples are incomplete: "
            + ", ".join(sorted(set(missing_files)))
        )

    for score_key, (better_filename, rougher_filename) in GUITAR_REGRESSION_SAMPLE_PAIRS.items():
        better_response = post_regression_sample_file(
            "guitar",
            regression_sample(GUITAR_REGRESSION_SAMPLE_DIR, better_filename),
        )
        rougher_response = post_regression_sample_file(
            "guitar",
            regression_sample(GUITAR_REGRESSION_SAMPLE_DIR, rougher_filename),
        )

        assert better_response.status_code == 200, better_filename
        assert rougher_response.status_code == 200, rougher_filename

        better_body = better_response.json()
        rougher_body = rougher_response.json()
        assert_valid_specific_body(better_body, "guitar", GUITAR_SPECIFIC_KEYS)
        assert_valid_specific_body(rougher_body, "guitar", GUITAR_SPECIFIC_KEYS)
        assert better_body["specific"][score_key] > rougher_body["specific"][score_key]


def test_create_diagnosis_accepts_bass():
    response = client.post(
        "/diagnoses",
        data={
            "diagnosis_id": "123",
            "performance_type": "bass",
            "song_title": "Sample Song",
            "memo": "Check bass",
        },
        files={
            "audio_file": ("sample.wav", make_plucked_wav_bytes(frequency=110.0), "audio/wav"),
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["schema_version"] == 1
    assert body["performance_type"] == "bass"
    assert body["common"] == {
        "overall_score": body["overall_score"],
        "pitch_score": body["pitch_score"],
        "rhythm_score": body["rhythm_score"],
        "expression_score": body["expression_score"],
    }
    assert set(body["specific"].keys()) == {
        "groove_score",
        "note_length_score",
        "stability_score",
    }
    assert all(0 <= body[key] <= 100 for key in body["common"].keys())
    assert all(0 <= value <= 100 for value in body["specific"].values())


def test_bass_groove_reflects_steady_timing():
    steady_response = post_performance_diagnosis("bass", make_steady_bass_wav_bytes(), "bass-steady-groove")
    irregular_response = post_performance_diagnosis("bass", make_irregular_bass_wav_bytes(), "bass-irregular-groove")

    assert steady_response.status_code == 200
    assert irregular_response.status_code == 200

    steady_body = steady_response.json()
    irregular_body = irregular_response.json()
    assert_valid_specific_body(steady_body, "bass", BASS_SPECIFIC_KEYS)
    assert_valid_specific_body(irregular_body, "bass", BASS_SPECIFIC_KEYS)
    assert steady_body["specific"]["groove_score"] > irregular_body["specific"]["groove_score"]


def test_bass_note_length_reflects_even_note_duration():
    even_response = post_performance_diagnosis("bass", make_steady_bass_wav_bytes(), "bass-even-note-length")
    uneven_response = post_performance_diagnosis("bass", make_uneven_note_length_bass_wav_bytes(), "bass-uneven-note-length")

    assert even_response.status_code == 200
    assert uneven_response.status_code == 200

    even_body = even_response.json()
    uneven_body = uneven_response.json()
    assert_valid_specific_body(even_body, "bass", BASS_SPECIFIC_KEYS)
    assert_valid_specific_body(uneven_body, "bass", BASS_SPECIFIC_KEYS)
    assert even_body["specific"]["note_length_score"] > uneven_body["specific"]["note_length_score"]


def test_bass_stability_reflects_even_timing_and_strength():
    stable_response = post_performance_diagnosis("bass", make_steady_bass_wav_bytes(), "bass-stable")
    unstable_response = post_performance_diagnosis("bass", make_unstable_bass_wav_bytes(), "bass-unstable")

    assert stable_response.status_code == 200
    assert unstable_response.status_code == 200

    stable_body = stable_response.json()
    unstable_body = unstable_response.json()
    assert_valid_specific_body(stable_body, "bass", BASS_SPECIFIC_KEYS)
    assert_valid_specific_body(unstable_body, "bass", BASS_SPECIFIC_KEYS)
    assert stable_body["specific"]["stability_score"] > unstable_body["specific"]["stability_score"]


def test_bass_real_recording_samples_do_not_break_regression():
    sample_paths = sorted(BASS_REGRESSION_SAMPLE_DIR.glob("*.wav"))
    if not sample_paths:
        pytest.skip(
            f"No bass regression .wav samples found in {BASS_REGRESSION_SAMPLE_DIR}. "
            "Add short bass recordings there to enable real-audio regression checks."
        )

    for sample_path in sample_paths:
        response = post_regression_sample_file("bass", sample_path)

        assert response.status_code == 200, sample_path.name
        body = response.json()
        assert_valid_specific_body(body, "bass", BASS_SPECIFIC_KEYS)
        assert_specific_scores_not_extreme(body)


def test_bass_real_recording_pairs_keep_expected_direction():
    missing_files = [
        filename
        for pair in BASS_REGRESSION_SAMPLE_PAIRS.values()
        for filename in pair
        if not regression_sample(BASS_REGRESSION_SAMPLE_DIR, filename).exists()
    ]
    if missing_files:
        pytest.skip(
            "Bass regression pair samples are incomplete: "
            + ", ".join(sorted(set(missing_files)))
        )

    for score_key, (better_filename, rougher_filename) in BASS_REGRESSION_SAMPLE_PAIRS.items():
        better_response = post_regression_sample_file(
            "bass",
            regression_sample(BASS_REGRESSION_SAMPLE_DIR, better_filename),
        )
        rougher_response = post_regression_sample_file(
            "bass",
            regression_sample(BASS_REGRESSION_SAMPLE_DIR, rougher_filename),
        )

        assert better_response.status_code == 200, better_filename
        assert rougher_response.status_code == 200, rougher_filename

        better_body = better_response.json()
        rougher_body = rougher_response.json()
        assert_valid_specific_body(better_body, "bass", BASS_SPECIFIC_KEYS)
        assert_valid_specific_body(rougher_body, "bass", BASS_SPECIFIC_KEYS)
        assert better_body["specific"][score_key] > rougher_body["specific"][score_key]


def test_create_diagnosis_accepts_drums():
    response = client.post(
        "/diagnoses",
        data={
            "diagnosis_id": "123",
            "performance_type": "drums",
            "song_title": "Sample Song",
            "memo": "Check drums",
        },
        files={
            "audio_file": ("drums.wav", make_percussive_wav_bytes(), "audio/wav"),
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["schema_version"] == 1
    assert body["performance_type"] == "drums"
    assert body["common"] == {
        "overall_score": body["overall_score"],
        "pitch_score": body["pitch_score"],
        "rhythm_score": body["rhythm_score"],
        "expression_score": body["expression_score"],
    }
    assert set(body["specific"].keys()) == {
        "tempo_stability_score",
        "rhythm_precision_score",
        "dynamics_score",
        "fill_control_score",
    }
    assert all(0 <= body[key] <= 100 for key in body["common"].keys())
    assert all(0 <= value <= 100 for value in body["specific"].values())


def test_create_diagnosis_accepts_keyboard():
    response = client.post(
        "/diagnoses",
        data={
            "diagnosis_id": "123",
            "performance_type": "keyboard",
            "song_title": "Sample Song",
            "memo": "Check keyboard",
        },
        files={
            "audio_file": ("keyboard.wav", make_keyboard_wav_bytes(), "audio/wav"),
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["schema_version"] == 1
    assert body["performance_type"] == "keyboard"
    assert body["common"] == {
        "overall_score": body["overall_score"],
        "pitch_score": body["pitch_score"],
        "rhythm_score": body["rhythm_score"],
        "expression_score": body["expression_score"],
    }
    assert set(body["specific"].keys()) == KEYBOARD_SPECIFIC_KEYS
    assert all(0 <= body[key] <= 100 for key in body["common"].keys())
    assert all(0 <= value <= 100 for value in body["specific"].values())


def test_create_diagnosis_accepts_band():
    response = client.post(
        "/diagnoses",
        data={
            "diagnosis_id": "123",
            "performance_type": "band",
            "song_title": "Sample Song",
            "memo": "Check band",
        },
        files={
            "audio_file": ("band.wav", make_keyboard_wav_bytes(), "audio/wav"),
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["schema_version"] == 1
    assert body["performance_type"] == "band"
    assert body["common"] == {
        "overall_score": body["overall_score"],
        "pitch_score": body["pitch_score"],
        "rhythm_score": body["rhythm_score"],
        "expression_score": body["expression_score"],
    }
    assert set(body["specific"].keys()) == BAND_SPECIFIC_KEYS
    assert_valid_band_analysis_debug(body)
    assert_valid_band_quality(body)
    assert all(0 <= body[key] <= 100 for key in body["common"].keys())
    assert all(0 <= value <= 100 for value in body["specific"].values())


def test_band_balance_reflects_even_volume_distribution():
    balanced_response = post_band_diagnosis(make_keyboard_wav_bytes(), "band-balanced")
    uneven_response = post_band_diagnosis(make_uneven_touch_keyboard_wav_bytes(), "band-uneven-balance")

    assert balanced_response.status_code == 200
    assert uneven_response.status_code == 200

    balanced_body = balanced_response.json()
    uneven_body = uneven_response.json()
    assert_valid_specific_body(balanced_body, "band", BAND_SPECIFIC_KEYS)
    assert_valid_specific_body(uneven_body, "band", BAND_SPECIFIC_KEYS)
    assert_valid_band_analysis_debug(balanced_body)
    assert_valid_band_analysis_debug(uneven_body)
    assert balanced_body["specific"]["balance"] > uneven_body["specific"]["balance"]


def test_band_tightness_reflects_consistent_timing():
    tight_response = post_band_diagnosis(make_keyboard_wav_bytes(), "band-tight")
    loose_response = post_band_diagnosis(make_choppy_keyboard_wav_bytes(), "band-loose")

    assert tight_response.status_code == 200
    assert loose_response.status_code == 200

    tight_body = tight_response.json()
    loose_body = loose_response.json()
    assert_valid_specific_body(tight_body, "band", BAND_SPECIFIC_KEYS)
    assert_valid_specific_body(loose_body, "band", BAND_SPECIFIC_KEYS)
    assert tight_body["specific"]["tightness"] > loose_body["specific"]["tightness"]


def test_band_role_clarity_reflects_arrangement_noise():
    clear_response = post_band_diagnosis(make_keyboard_wav_bytes(), "band-clear-role")
    noisy_response = post_band_diagnosis(make_noisy_keyboard_wav_bytes(), "band-noisy-role")

    assert clear_response.status_code == 200
    assert noisy_response.status_code == 200

    clear_body = clear_response.json()
    noisy_body = noisy_response.json()
    assert_valid_specific_body(clear_body, "band", BAND_SPECIFIC_KEYS)
    assert_valid_specific_body(noisy_body, "band", BAND_SPECIFIC_KEYS)
    assert clear_body["specific"]["role_clarity"] > noisy_body["specific"]["role_clarity"]


def test_band_cohesion_reflects_overall_stability():
    cohesive_response = post_band_diagnosis(make_keyboard_wav_bytes(), "band-cohesive")
    rough_response = post_band_diagnosis(make_wobbly_keyboard_wav_bytes(), "band-rough")

    assert cohesive_response.status_code == 200
    assert rough_response.status_code == 200

    cohesive_body = cohesive_response.json()
    rough_body = rough_response.json()
    assert_valid_specific_body(cohesive_body, "band", BAND_SPECIFIC_KEYS)
    assert_valid_specific_body(rough_body, "band", BAND_SPECIFIC_KEYS)
    assert cohesive_body["specific"]["cohesion"] > rough_body["specific"]["cohesion"]


def test_band_silent_audio_sets_mostly_silent_and_low_confidence():
    response = post_band_diagnosis(make_silent_wav_bytes(), "band-silent")

    assert response.status_code == 200

    body = response.json()
    assert_valid_specific_body(body, "band", BAND_SPECIFIC_KEYS)
    assert_valid_band_analysis_debug(body)
    assert_valid_band_quality(body)
    assert body["quality_flags"]["mostly_silent"] is True
    assert body["quality_flags"]["low_confidence"] is True
    assert body["quality_message"] is not None


def test_band_short_audio_sets_too_short_flag():
    response = post_band_diagnosis(make_keyboard_wav_bytes(duration_seconds=6.0), "band-short")

    assert response.status_code == 200

    body = response.json()
    assert_valid_specific_body(body, "band", BAND_SPECIFIC_KEYS)
    assert_valid_band_quality(body)
    assert body["quality_flags"]["too_short"] is True
    assert body["quality_flags"]["low_confidence"] is True


def test_band_clipped_audio_sets_clipping_flag():
    response = post_band_diagnosis(make_clipped_wav_bytes(), "band-clipped")

    assert response.status_code == 200

    body = response.json()
    assert_valid_specific_body(body, "band", BAND_SPECIFIC_KEYS)
    assert_valid_band_quality(body)
    assert body["quality_flags"]["clipping_detected"] is True
    assert body["quality_flags"]["low_confidence"] is True


def test_keyboard_note_connection_reflects_choppy_audio():
    connected_response = client.post(
        "/diagnoses",
        data={
            "diagnosis_id": "123",
            "performance_type": "keyboard",
            "song_title": "Connected Keyboard",
            "memo": "Check note connection",
        },
        files={
            "audio_file": ("connected_keyboard.wav", make_keyboard_wav_bytes(), "audio/wav"),
        },
    )
    choppy_response = client.post(
        "/diagnoses",
        data={
            "diagnosis_id": "124",
            "performance_type": "keyboard",
            "song_title": "Choppy Keyboard",
            "memo": "Check note connection",
        },
        files={
            "audio_file": ("choppy_keyboard.wav", make_choppy_keyboard_wav_bytes(), "audio/wav"),
        },
    )

    assert connected_response.status_code == 200
    assert choppy_response.status_code == 200

    connected_specific = connected_response.json()["specific"]
    choppy_specific = choppy_response.json()["specific"]

    assert connected_specific["note_connection_score"] > choppy_specific["note_connection_score"]
    assert set(connected_specific.keys()) == KEYBOARD_SPECIFIC_KEYS
    assert all(0 <= value <= 100 for value in connected_specific.values())
    assert all(0 <= value <= 100 for value in choppy_specific.values())


def test_keyboard_touch_reflects_uneven_key_strength():
    even_response = post_keyboard_diagnosis(make_keyboard_wav_bytes(), "keyboard-even-touch")
    uneven_response = post_keyboard_diagnosis(make_uneven_touch_keyboard_wav_bytes(), "keyboard-uneven-touch")

    assert even_response.status_code == 200
    assert uneven_response.status_code == 200

    even_body = even_response.json()
    uneven_body = uneven_response.json()
    assert_valid_keyboard_body(even_body)
    assert_valid_keyboard_body(uneven_body)
    assert even_body["specific"]["touch_score"] > uneven_body["specific"]["touch_score"]


def test_keyboard_chord_stability_reflects_wobbly_chords():
    stable_response = post_keyboard_diagnosis(make_keyboard_wav_bytes(), "keyboard-stable-chord")
    wobbly_response = post_keyboard_diagnosis(make_wobbly_keyboard_wav_bytes(), "keyboard-wobbly-chord")

    assert stable_response.status_code == 200
    assert wobbly_response.status_code == 200

    stable_body = stable_response.json()
    wobbly_body = wobbly_response.json()
    assert_valid_keyboard_body(stable_body)
    assert_valid_keyboard_body(wobbly_body)
    assert stable_body["specific"]["chord_stability_score"] > wobbly_body["specific"]["chord_stability_score"]


def test_keyboard_harmony_reflects_noisy_chords():
    clean_response = post_keyboard_diagnosis(make_keyboard_wav_bytes(), "keyboard-clean-harmony")
    noisy_response = post_keyboard_diagnosis(make_noisy_keyboard_wav_bytes(), "keyboard-noisy-harmony")

    assert clean_response.status_code == 200
    assert noisy_response.status_code == 200

    clean_body = clean_response.json()
    noisy_body = noisy_response.json()
    assert_valid_keyboard_body(clean_body)
    assert_valid_keyboard_body(noisy_body)
    assert clean_body["specific"]["harmony_score"] > noisy_body["specific"]["harmony_score"]


def test_keyboard_real_recording_samples_do_not_break_regression():
    sample_paths = sorted(KEYBOARD_REGRESSION_SAMPLE_DIR.glob("*.wav"))
    if not sample_paths:
        pytest.skip(
            f"No keyboard regression .wav samples found in {KEYBOARD_REGRESSION_SAMPLE_DIR}. "
            "Add short keyboard recordings there to enable real-audio regression checks."
        )

    for sample_path in sample_paths:
        response = post_keyboard_sample_file(sample_path)

        assert response.status_code == 200, sample_path.name
        body = response.json()
        assert_valid_keyboard_body(body)
        assert_keyboard_scores_not_extreme(body)


def test_keyboard_real_recording_pairs_keep_expected_direction():
    missing_files = [
        filename
        for pair in KEYBOARD_REGRESSION_SAMPLE_PAIRS.values()
        for filename in pair
        if not keyboard_regression_sample(filename).exists()
    ]
    if missing_files:
        pytest.skip(
            "Keyboard regression pair samples are incomplete: "
            + ", ".join(sorted(set(missing_files)))
        )

    for score_key, (better_filename, rougher_filename) in KEYBOARD_REGRESSION_SAMPLE_PAIRS.items():
        better_response = post_keyboard_sample_file(keyboard_regression_sample(better_filename))
        rougher_response = post_keyboard_sample_file(keyboard_regression_sample(rougher_filename))

        assert better_response.status_code == 200, better_filename
        assert rougher_response.status_code == 200, rougher_filename

        better_body = better_response.json()
        rougher_body = rougher_response.json()
        assert_valid_keyboard_body(better_body)
        assert_valid_keyboard_body(rougher_body)
        assert better_body["specific"][score_key] > rougher_body["specific"][score_key]


def test_create_diagnosis_accepts_ffmpeg_decodable_audio():
    ffmpeg_pcm = struct.pack("<4f", 0.0, 0.25, -0.25, 0.0)

    with patch("app.services.diagnosis_analyzer.sf.read") as soundfile_read, patch(
        "app.services.diagnosis_analyzer.subprocess.run"
    ) as ffmpeg_run:
        soundfile_read.side_effect = RuntimeError("unsupported")
        ffmpeg_run.return_value.returncode = 0
        ffmpeg_run.return_value.stdout = ffmpeg_pcm

        response = client.post(
            "/diagnoses",
            data={
                "diagnosis_id": "123",
                "song_title": "Sample Song",
                "memo": "Check pitch",
            },
            files={
                "audio_file": ("sample.m4a", b"m4a bytes", "audio/mp4"),
            },
        )

    assert response.status_code == 200
    body = response.json()
    assert body["performance_type"] == "vocal"
    assert body["common"]["overall_score"] == body["overall_score"]
    assert ffmpeg_run.called


def test_create_diagnosis_rejects_invalid_file():
    response = client.post(
        "/diagnoses",
        data={
            "diagnosis_id": "123",
            "song_title": "Sample Song",
            "memo": "Check pitch",
        },
        files={
            "audio_file": ("sample.txt", b"not audio", "text/plain"),
        },
    )

    assert response.status_code == 400
    assert response.json()["detail"].startswith("Unsupported or unreadable audio file.")


def test_create_diagnosis_rejects_empty_file():
    response = client.post(
        "/diagnoses",
        data={
            "diagnosis_id": "123",
            "song_title": "Sample Song",
            "memo": "Check pitch",
        },
        files={
            "audio_file": ("empty.wav", b"", "audio/wav"),
        },
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "Audio file is empty."

from dataclasses import dataclass
from io import BytesIO
import subprocess
import tempfile
from typing import Optional

import numpy as np
import soundfile as sf
from fastapi import HTTPException

from app.schemas import DiagnosisResponse


@dataclass(frozen=True)
class AudioFeatures:
    duration_seconds: float
    rms: float
    rms_std: float
    peak: float
    clipping_ratio: float
    silence_ratio: float
    onset_count: int
    onset_interval_std: float
    pitch_stability: float
    rhythm_regularity: float
    dynamic_range: float
    attack_clarity: float
    muting_control: float
    amplitude_stability: float
    spectral_stability: float
    harmonic_balance: float
    spectral_balance_low: float
    spectral_balance_mid: float
    spectral_balance_high: float
    onset_peak_consistency: float
    note_connection: float
    estimated_bpm: Optional[float]
    estimated_key: Optional[str]


class DiagnosisAnalyzer:
    FFMPEG_SAMPLE_RATE = 16000
    SUPPORTED_PERFORMANCE_TYPES = {"vocal", "guitar", "bass", "drums", "keyboard", "band"}
    KNOWN_PERFORMANCE_TYPES = {"vocal", "guitar", "bass", "drums", "keyboard", "band"}

    def analyze(
        self,
        *,
        audio_bytes: bytes,
        filename: str,
        content_type: str,
        diagnosis_id: str,
        performance_type: str,
        song_title: str,
        memo: str,
        reference_key: str = "",
        reference_bpm: str = "",
    ) -> DiagnosisResponse:
        _ = (filename, content_type, diagnosis_id, song_title, memo)

        normalized_performance_type = self._normalize_performance_type(performance_type)
        if normalized_performance_type not in self.SUPPORTED_PERFORMANCE_TYPES:
            raise HTTPException(
                status_code=400,
                detail=f"Unsupported performance_type: {normalized_performance_type}. Only vocal, guitar, bass, drums, keyboard and band analysis are currently supported.",
            )

        features = self._extract_features(audio_bytes)

        analysis_debug = {}
        quality_flags: dict[str, bool] = {}
        quality_message: Optional[str] = None

        if normalized_performance_type == "guitar":
            pitch_score, rhythm_score, expression_score, specific_scores = self._guitar_scores(features)
            overall_score = self._clamp_score(
                (pitch_score * 0.25) + (rhythm_score * 0.35) + (expression_score * 0.4)
            )
        elif normalized_performance_type == "bass":
            pitch_score, rhythm_score, expression_score, specific_scores = self._bass_scores(features)
            overall_score = self._clamp_score(
                (pitch_score * 0.25) + (rhythm_score * 0.4) + (expression_score * 0.35)
            )
        elif normalized_performance_type == "drums":
            pitch_score, rhythm_score, expression_score, specific_scores = self._drums_scores(features)
            overall_score = self._clamp_score(
                (rhythm_score * 0.5) + (expression_score * 0.25) + (specific_scores["tempo_stability_score"] * 0.25)
            )
        elif normalized_performance_type == "keyboard":
            pitch_score, rhythm_score, expression_score, specific_scores = self._keyboard_scores(features)
            overall_score = self._clamp_score(
                (pitch_score * 0.3)
                + (rhythm_score * 0.25)
                + (expression_score * 0.25)
                + (specific_scores["chord_stability_score"] * 0.2)
            )
        elif normalized_performance_type == "band":
            pitch_score, rhythm_score, expression_score, specific_scores = self._band_scores(features)
            quality_flags = self._band_quality_flags(features)
            pitch_score, rhythm_score, expression_score, specific_scores = self._apply_band_score_adjustments(
                features,
                pitch_score=pitch_score,
                rhythm_score=rhythm_score,
                expression_score=expression_score,
                specific_scores=specific_scores,
                quality_flags=quality_flags,
            )
            overall_score = self._band_overall_score(
                pitch_score=pitch_score,
                rhythm_score=rhythm_score,
                expression_score=expression_score,
                specific_scores=specific_scores,
                quality_flags=quality_flags,
            )
            analysis_debug = self._band_analysis_debug(features, specific_scores)
            quality_message = self._band_quality_message(features, quality_flags)
        else:
            pitch_score = self._score_pitch(features)
            rhythm_score = self._score_rhythm(features)
            expression_score = self._score_expression(features)
            overall_score = self._clamp_score(
                (pitch_score * 0.4) + (rhythm_score * 0.3) + (expression_score * 0.3)
            )
            specific_scores = self._vocal_specific_scores(features)

        common_scores = {
            "overall_score": overall_score,
            "pitch_score": pitch_score,
            "rhythm_score": rhythm_score,
            "expression_score": expression_score,
        }
        reference_comparison = self._reference_comparison(
            features,
            reference_key=reference_key,
            reference_bpm=reference_bpm,
        )

        return DiagnosisResponse(
            overall_score=overall_score,
            pitch_score=pitch_score,
            rhythm_score=rhythm_score,
            expression_score=expression_score,
            schema_version=1,
            performance_type=normalized_performance_type,
            common=common_scores,
            specific=specific_scores,
            reference_comparison=reference_comparison,
            analysis_debug=analysis_debug,
            quality_flags=quality_flags,
            quality_message=quality_message,
        )

    def _vocal_specific_scores(self, features: AudioFeatures) -> dict[str, int]:
        volume_score = self._clamp_score(45 + (self._clamp_unit(features.rms / 0.18) * 45) - (features.silence_ratio * 10))
        relax_score = self._clamp_score(65 + ((1.0 - features.silence_ratio) * 20) - (features.dynamic_range * 20))
        pronunciation_score = self._clamp_score(45 + (features.rhythm_regularity * 25) + ((1.0 - features.silence_ratio) * 25))
        mix_voice_score = self._clamp_score(45 + (features.pitch_stability * 30) + (self._clamp_unit(features.dynamic_range / 0.25) * 20))

        return {
            "volume_score": volume_score,
            "pronunciation_score": pronunciation_score,
            "relax_score": relax_score,
            "mix_voice_score": mix_voice_score,
        }

    def _guitar_scores(self, features: AudioFeatures) -> tuple[int, int, int, dict[str, int]]:
        pitch_score = self._clamp_score(
            45
            + (features.pitch_stability * 30)
            + (features.rhythm_regularity * 10)
            - (features.silence_ratio * 10)
        )
        rhythm_score = self._score_rhythm(features)
        expression_score = self._score_expression(features)

        excess_sustain_control = 1.0 - self._clamp_unit((features.note_connection - 0.68) / 0.32)
        attack_score = self._clamp_score(
            36
            + (features.attack_clarity * 42)
            + (features.onset_peak_consistency * 14)
            + (features.rhythm_regularity * 10)
            + (features.amplitude_stability * 8)
            + (features.spectral_stability * 4)
            - (features.silence_ratio * 8)
        )
        muting_score = self._clamp_score(
            38
            + (features.muting_control * 42)
            + (features.amplitude_stability * 12)
            + (features.rhythm_regularity * 10)
            + (features.onset_peak_consistency * 6)
            + (excess_sustain_control * 6)
            - (features.silence_ratio * 5)
        )
        stability_score = self._clamp_score(
            36
            + (features.amplitude_stability * 34)
            + (features.rhythm_regularity * 22)
            + (features.onset_peak_consistency * 14)
            + (features.pitch_stability * 12)
            + (features.spectral_stability * 6)
            + (self._clamp_unit(features.rms / 0.18) * 6)
            - (features.silence_ratio * 8)
        )

        return (
            pitch_score,
            rhythm_score,
            expression_score,
            {
                "attack_score": attack_score,
                "muting_score": muting_score,
                "stability_score": stability_score,
            },
        )

    def _bass_scores(self, features: AudioFeatures) -> tuple[int, int, int, dict[str, int]]:
        pitch_score = self._clamp_score(
            45
            + (features.pitch_stability * 28)
            + (features.amplitude_stability * 12)
            - (features.silence_ratio * 8)
        )
        rhythm_score = self._score_rhythm(features)
        expression_score = self._score_expression(features)

        note_length_balance = 1.0 - self._clamp_unit(abs(features.note_connection - 0.58) / 0.58)
        groove_score = self._clamp_score(
            38
            + (features.rhythm_regularity * 42)
            + (features.onset_peak_consistency * 14)
            + (features.attack_clarity * 12)
            + (features.amplitude_stability * 10)
            + (features.note_connection * 6)
            - (features.silence_ratio * 8)
        )
        note_length_score = self._clamp_score(
            38
            + (features.muting_control * 32)
            + (note_length_balance * 18)
            + (features.amplitude_stability * 16)
            + (features.rhythm_regularity * 10)
            + (features.onset_peak_consistency * 8)
            - (features.silence_ratio * 6)
        )
        stability_score = self._clamp_score(
            36
            + (features.amplitude_stability * 32)
            + (features.rhythm_regularity * 24)
            + (features.pitch_stability * 16)
            + (features.onset_peak_consistency * 12)
            + (features.spectral_stability * 8)
            - (features.silence_ratio * 8)
        )

        return (
            pitch_score,
            rhythm_score,
            expression_score,
            {
                "groove_score": groove_score,
                "note_length_score": note_length_score,
                "stability_score": stability_score,
            },
        )

    def _drums_scores(self, features: AudioFeatures) -> tuple[int, int, int, dict[str, int]]:
        rhythm_score = self._score_rhythm(features)
        expression_score = self._score_expression(features)

        # Drums do not have a meaningful pitch axis in this initial analyzer.
        # Keep a conservative numeric value for backwards-compatible response shape,
        # while Rails can keep it out of the drums-facing score cards.
        pitch_score = self._clamp_score(
            42
            + (features.rhythm_regularity * 24)
            + (features.amplitude_stability * 18)
            - (features.silence_ratio * 6)
        )

        tempo_stability_score = self._clamp_score(
            40
            + (features.rhythm_regularity * 42)
            + (features.amplitude_stability * 16)
            - (features.silence_ratio * 8)
        )
        rhythm_precision_score = self._clamp_score(
            40
            + (features.rhythm_regularity * 34)
            + (features.attack_clarity * 20)
            + (features.amplitude_stability * 12)
            - (features.silence_ratio * 8)
        )
        dynamics_score = self._clamp_score(
            38
            + (self._clamp_unit(features.dynamic_range / 0.25) * 32)
            + (features.amplitude_stability * 14)
            + (features.rhythm_regularity * 10)
            - (features.silence_ratio * 6)
        )
        fill_control_score = self._clamp_score(
            38
            + (features.attack_clarity * 24)
            + (features.rhythm_regularity * 24)
            + (features.muting_control * 14)
            + (self._clamp_unit(features.dynamic_range / 0.25) * 10)
            - (features.silence_ratio * 8)
        )

        return (
            pitch_score,
            rhythm_score,
            expression_score,
            {
                "tempo_stability_score": tempo_stability_score,
                "rhythm_precision_score": rhythm_precision_score,
                "dynamics_score": dynamics_score,
                "fill_control_score": fill_control_score,
            },
        )

    def _keyboard_scores(self, features: AudioFeatures) -> tuple[int, int, int, dict[str, int]]:
        pitch_score = self._score_pitch(features)
        rhythm_score = self._score_rhythm(features)
        expression_score = self._score_expression(features)

        chord_stability_score = self._clamp_score(
            38
            + (features.spectral_stability * 4)
            + (features.amplitude_stability * 18)
            + (features.pitch_stability * 24)
            + (features.onset_peak_consistency * 8)
            + (features.harmonic_balance * 12)
            - (features.silence_ratio * 8)
        )
        note_connection_score = self._clamp_score(
            38
            + (features.note_connection * 34)
            + (features.rhythm_regularity * 16)
            + (features.amplitude_stability * 12)
            + (features.spectral_stability * 8)
            - (features.silence_ratio * 6)
        )
        touch_score = self._clamp_score(
            38
            + (features.onset_peak_consistency * 32)
            + (features.amplitude_stability * 22)
            + (features.attack_clarity * 10)
            + (self._clamp_unit(features.dynamic_range / 0.25) * 8)
            - (features.silence_ratio * 8)
        )
        harmony_score = self._clamp_score(
            38
            + (features.harmonic_balance * 36)
            + (features.spectral_stability * 4)
            + (features.pitch_stability * 18)
            + (features.amplitude_stability * 10)
            - (features.silence_ratio * 6)
        )

        return (
            pitch_score,
            rhythm_score,
            expression_score,
            {
                "chord_stability_score": chord_stability_score,
                "note_connection_score": note_connection_score,
                "touch_score": touch_score,
                "harmony_score": harmony_score,
            },
        )

    def _band_scores(self, features: AudioFeatures) -> tuple[int, int, int, dict[str, int]]:
        harmony_score = self._clamp_score(
            38
            + (features.harmonic_balance * 30)
            + (features.spectral_stability * 16)
            + (features.pitch_stability * 12)
            + (features.amplitude_stability * 8)
            - (features.silence_ratio * 8)
        )
        tightness_score = self._clamp_score(
            36
            + (features.rhythm_regularity * 34)
            + (features.onset_peak_consistency * 20)
            + (features.attack_clarity * 12)
            + (features.amplitude_stability * 8)
            - (features.silence_ratio * 10)
        )

        dynamics_target = self._target_match(features.dynamic_range, center=0.16, tolerance=0.12)
        connection_support = self._target_match(features.note_connection, center=0.68, tolerance=0.22)
        balance_dynamic_support = self._target_match(features.dynamic_range, center=0.12, tolerance=0.10)
        rms_support = self._target_match(features.rms, center=0.18, tolerance=0.08)

        balance_score = self._clamp_score(
            34
            + (features.amplitude_stability * 32)
            + (features.spectral_stability * 14)
            + (features.harmonic_balance * 10)
            + (balance_dynamic_support * 12)
            + (rms_support * 8)
            - (features.silence_ratio * 8)
        )
        groove_score = self._clamp_score(
            34
            + (features.rhythm_regularity * 24)
            + (features.onset_peak_consistency * 18)
            + (connection_support * 14)
            + (features.attack_clarity * 8)
            + (features.amplitude_stability * 8)
            - (features.silence_ratio * 8)
        )
        role_clarity_score = self._clamp_score(
            34
            + (features.spectral_stability * 18)
            + (features.harmonic_balance * 16)
            + (features.amplitude_stability * 12)
            + (connection_support * 10)
            + (dynamics_target * 8)
            - (features.silence_ratio * 8)
        )
        dynamics_score = self._clamp_score(
            34
            + (dynamics_target * 32)
            + (features.amplitude_stability * 14)
            + (features.rhythm_regularity * 10)
            + (connection_support * 10)
            - (features.silence_ratio * 6)
        )
        cohesion_score = self._clamp_score(
            18
            + (balance_score * 0.2)
            + (tightness_score * 0.2)
            + (groove_score * 0.18)
            + (role_clarity_score * 0.16)
            + (dynamics_score * 0.12)
            + (harmony_score * 0.14)
        )

        return (
            harmony_score,
            tightness_score,
            dynamics_score,
            {
                "balance": balance_score,
                "tightness": tightness_score,
                "groove": groove_score,
                "role_clarity": role_clarity_score,
                "dynamics": dynamics_score,
                "cohesion": cohesion_score,
            },
        )

    def _band_analysis_debug(self, features: AudioFeatures, specific_scores: dict[str, int]) -> dict[str, object]:
        return {
            "rms_mean": round(features.rms, 6),
            "rms_std": round(features.rms_std, 6),
            "peak": round(features.peak, 6),
            "silence_ratio": round(features.silence_ratio, 6),
            "onset_count": int(features.onset_count),
            "onset_interval_std": round(features.onset_interval_std, 6),
            "spectral_balance": {
                "low": round(features.spectral_balance_low, 6),
                "mid": round(features.spectral_balance_mid, 6),
                "high": round(features.spectral_balance_high, 6),
            },
            "dynamics_range": round(features.dynamic_range, 6),
            "cohesion_inputs": {
                "balance": int(specific_scores.get("balance", 0)),
                "tightness": int(specific_scores.get("tightness", 0)),
                "groove": int(specific_scores.get("groove", 0)),
                "role_clarity": int(specific_scores.get("role_clarity", 0)),
                "dynamics": int(specific_scores.get("dynamics", 0)),
            },
        }

    def _band_quality_flags(self, features: AudioFeatures) -> dict[str, bool]:
        too_short = features.duration_seconds < 10.0
        short_confidence_risk = features.duration_seconds < 20.0
        too_quiet = features.rms < 0.018 or features.peak < 0.12
        too_loud = features.rms > 0.34 or features.peak >= 0.985
        clipping_detected = features.peak >= 0.98 or features.clipping_ratio >= 0.01
        mostly_silent = features.silence_ratio >= 0.5
        sparse_onsets = features.onset_count < 6
        low_confidence = any(
            (
                too_short,
                short_confidence_risk,
                too_quiet,
                too_loud,
                clipping_detected,
                mostly_silent,
                sparse_onsets,
            )
        )

        return {
            "too_short": too_short,
            "too_quiet": too_quiet,
            "too_loud": too_loud,
            "clipping_detected": clipping_detected,
            "mostly_silent": mostly_silent,
            "low_confidence": low_confidence,
        }

    def _band_quality_message(self, features: AudioFeatures, quality_flags: dict[str, bool]) -> Optional[str]:
        if not quality_flags.get("low_confidence"):
            return None

        reasons = []
        if quality_flags.get("too_short"):
            reasons.append("音源が少し短め")
        elif features.duration_seconds < 20.0:
            reasons.append("音源がやや短め")
        if quality_flags.get("mostly_silent"):
            reasons.append("無音区間が多め")
        if quality_flags.get("too_quiet"):
            reasons.append("全体の音量が小さめ")
        if quality_flags.get("clipping_detected") or quality_flags.get("too_loud"):
            reasons.append("音量が大きく音割れの影響がありそう")
        if features.onset_count < 6:
            reasons.append("演奏の変化が少なく特徴を拾いにくい")

        lead = "、".join(reasons[:2]) if reasons else "録音条件の影響を受けやすい"
        return (
            f"今回の音源は{lead}ため、診断結果は参考値としてご覧ください。"
            "次回は30秒以上の演奏を、無音を少なめにして録音すると、より安定した診断ができます。"
        )

    def _apply_band_score_adjustments(
        self,
        features: AudioFeatures,
        *,
        pitch_score: int,
        rhythm_score: int,
        expression_score: int,
        specific_scores: dict[str, int],
        quality_flags: dict[str, bool],
    ) -> tuple[int, int, int, dict[str, int]]:
        evidence_strength = self._clamp_unit(
            (self._clamp_unit((features.duration_seconds - 8.0) / 22.0) * 0.28)
            + (self._clamp_unit(features.onset_count / 18.0) * 0.2)
            + ((1.0 - features.silence_ratio) * 0.24)
            + (self._clamp_unit(features.dynamic_range / 0.18) * 0.14)
            + (self._clamp_unit(features.rms / 0.12) * 0.08)
            + ((1.0 - self._clamp_unit(features.clipping_ratio / 0.03)) * 0.06)
        )
        calibration_shift = (evidence_strength - 0.52) * 18.0

        adjusted_specific = {
            key: self._spread_band_score(value, calibration_shift)
            for key, value in specific_scores.items()
        }
        adjusted_pitch = self._spread_band_score(pitch_score, calibration_shift)
        adjusted_rhythm = self._spread_band_score(rhythm_score, calibration_shift)
        adjusted_expression = self._spread_band_score(expression_score, calibration_shift)

        if features.onset_count < 6:
            adjusted_specific["tightness"] = self._apply_penalty(adjusted_specific["tightness"], 12)
            adjusted_specific["groove"] = self._apply_penalty(adjusted_specific["groove"], 14)
            adjusted_rhythm = self._apply_penalty(adjusted_rhythm, 10)

        if quality_flags.get("too_quiet"):
            adjusted_specific["balance"] = self._apply_penalty(adjusted_specific["balance"], 7)
            adjusted_specific["dynamics"] = self._apply_penalty(adjusted_specific["dynamics"], 9)
            adjusted_expression = self._apply_penalty(adjusted_expression, 8)

        if quality_flags.get("too_loud"):
            adjusted_specific["balance"] = self._apply_penalty(adjusted_specific["balance"], 8)
            adjusted_specific["dynamics"] = self._apply_penalty(adjusted_specific["dynamics"], 7)
            adjusted_expression = self._apply_penalty(adjusted_expression, 6)

        if quality_flags.get("clipping_detected"):
            adjusted_specific["balance"] = self._apply_penalty(adjusted_specific["balance"], 12)
            adjusted_specific["dynamics"] = self._apply_penalty(adjusted_specific["dynamics"], 12)
            adjusted_specific["cohesion"] = self._apply_penalty(adjusted_specific["cohesion"], 8)
            adjusted_expression = self._apply_penalty(adjusted_expression, 10)

        if quality_flags.get("mostly_silent"):
            adjusted_specific = {
                key: self._apply_penalty(value, 18 if key in {"tightness", "groove", "cohesion"} else 15)
                for key, value in adjusted_specific.items()
            }
            adjusted_pitch = self._apply_penalty(adjusted_pitch, 14)
            adjusted_rhythm = self._apply_penalty(adjusted_rhythm, 18)
            adjusted_expression = self._apply_penalty(adjusted_expression, 16)

        adjusted_specific["cohesion"] = self._clamp_score(
            20
            + (adjusted_specific["balance"] * 0.22)
            + (adjusted_specific["tightness"] * 0.22)
            + (adjusted_specific["groove"] * 0.18)
            + (adjusted_specific["role_clarity"] * 0.16)
            + (adjusted_specific["dynamics"] * 0.12)
            + (adjusted_pitch * 0.1)
        )

        return adjusted_pitch, adjusted_rhythm, adjusted_expression, adjusted_specific

    def _band_overall_score(
        self,
        *,
        pitch_score: int,
        rhythm_score: int,
        expression_score: int,
        specific_scores: dict[str, int],
        quality_flags: dict[str, bool],
    ) -> int:
        overall_score = self._clamp_score(
            (pitch_score * 0.18)
            + (rhythm_score * 0.22)
            + (expression_score * 0.16)
            + (specific_scores["balance"] * 0.12)
            + (specific_scores["tightness"] * 0.1)
            + (specific_scores["groove"] * 0.1)
            + (specific_scores["role_clarity"] * 0.05)
            + (specific_scores["dynamics"] * 0.03)
            + (specific_scores["cohesion"] * 0.04)
        )

        if quality_flags.get("too_quiet"):
            overall_score = self._apply_penalty(overall_score, 5)
        if quality_flags.get("too_loud"):
            overall_score = self._apply_penalty(overall_score, 4)
        if quality_flags.get("clipping_detected"):
            overall_score = self._apply_penalty(overall_score, 6)
        if quality_flags.get("mostly_silent"):
            overall_score = self._apply_penalty(overall_score, 14)

        return overall_score

    def _spread_band_score(self, score: int, calibration_shift: float) -> int:
        return self._clamp_score(48 + ((score - 48) * 1.18) + calibration_shift)

    def _apply_penalty(self, score: int, penalty: int, *, floor: int = 12) -> int:
        return self._clamp_score(max(floor, score - penalty))

    def _normalize_performance_type(self, performance_type: str) -> str:
        normalized = (performance_type or "vocal").strip().lower()
        if normalized in self.KNOWN_PERFORMANCE_TYPES:
            return normalized

        raise HTTPException(
            status_code=400,
            detail=f"Unknown performance_type: {normalized}.",
        )

    def _reference_comparison(
        self,
        features: AudioFeatures,
        *,
        reference_key: str,
        reference_bpm: str,
    ) -> dict:
        normalized_key = self._normalize_reference_key(reference_key)
        normalized_bpm = self._normalize_reference_bpm(reference_bpm)
        if normalized_key is None and normalized_bpm is None:
            return {}

        comparison = {}
        if normalized_key is not None:
            comparison["reference_key"] = normalized_key
            comparison["estimated_key"] = features.estimated_key
            comparison["key_match_level"] = self._key_match_level(normalized_key, features.estimated_key)

        if normalized_bpm is not None:
            estimated_bpm = features.estimated_bpm
            bpm_diff = round(abs(estimated_bpm - normalized_bpm), 1) if estimated_bpm is not None else None
            comparison["reference_bpm"] = normalized_bpm
            comparison["estimated_bpm"] = estimated_bpm
            comparison["bpm_diff"] = bpm_diff
            comparison["tempo_match_level"] = self._tempo_match_level(bpm_diff)

        return comparison

    def _normalize_reference_key(self, reference_key: str) -> Optional[str]:
        value = (reference_key or "").strip().upper().replace("♯", "#").replace("＃", "#")
        value = value.replace("♭", "B")
        aliases = {
            "DB": "C#",
            "EB": "D#",
            "GB": "F#",
            "AB": "G#",
            "BB": "A#",
        }
        note_names = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
        value = aliases.get(value, value)
        return value if value in note_names else None

    def _normalize_reference_bpm(self, reference_bpm: str) -> Optional[float]:
        try:
            value = float(str(reference_bpm or "").strip())
        except ValueError:
            return None

        if not np.isfinite(value) or value <= 0:
            return None

        return round(value, 1)

    def _key_match_level(self, reference_key: str, estimated_key: Optional[str]) -> str:
        if estimated_key is None:
            return "unknown"

        note_names = ("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")
        reference_index = note_names.index(reference_key)
        estimated_index = note_names.index(estimated_key)
        distance = abs(reference_index - estimated_index)
        distance = min(distance, 12 - distance)
        if distance == 0:
            return "exact"
        if distance <= 1:
            return "close"
        return "far"

    def _tempo_match_level(self, bpm_diff: Optional[float]) -> str:
        if bpm_diff is None:
            return "unknown"
        if bpm_diff <= 3:
            return "close"
        if bpm_diff <= 8:
            return "near"
        return "far"

    def _extract_features(self, audio_bytes: bytes) -> AudioFeatures:
        if not audio_bytes:
            raise HTTPException(status_code=400, detail="Audio file is empty.")

        samples, sample_rate = self._read_audio(audio_bytes)

        if sample_rate <= 0 or samples.size == 0:
            raise HTTPException(status_code=400, detail="Audio file contains no readable samples.")

        mono = samples.mean(axis=1)
        mono = mono[np.isfinite(mono)]

        if mono.size == 0:
            raise HTTPException(status_code=400, detail="Audio file contains no readable samples.")

        duration_seconds = mono.size / float(sample_rate)
        rms = float(np.sqrt(np.mean(np.square(mono))))
        peak = float(np.max(np.abs(mono)))
        clipping_ratio = float(np.mean(np.abs(mono) >= 0.95))

        frame_size = min(2048, max(256, mono.size))
        hop_size = max(128, frame_size // 4)
        frames = self._frames(mono, frame_size=frame_size, hop_size=hop_size)
        frame_rms = np.array([np.sqrt(np.mean(np.square(frame))) for frame in frames], dtype=np.float32)
        rms_std = float(np.std(frame_rms)) if frame_rms.size else 0.0

        silence_threshold = max(0.005, rms * 0.25)
        silence_ratio = float(np.mean(frame_rms < silence_threshold)) if frame_rms.size else 1.0
        onset_positions = self._detect_onsets(frame_rms)
        onset_count = int(onset_positions.size)
        onset_interval_std = self._estimate_onset_interval_std(onset_positions, hop_size, sample_rate)

        voiced_frames = [frame for frame, value in zip(frames, frame_rms) if value >= silence_threshold]
        pitch_stability = self._estimate_pitch_stability(voiced_frames)
        estimated_key = self._estimate_key(voiced_frames, sample_rate)
        rhythm_regularity = self._estimate_rhythm_regularity(frame_rms)
        estimated_bpm = self._estimate_bpm(frame_rms, hop_size, sample_rate)
        dynamic_range = self._estimate_dynamic_range(frame_rms)
        attack_clarity = self._estimate_attack_clarity(frame_rms)
        muting_control = self._estimate_muting_control(frame_rms, silence_threshold)
        amplitude_stability = self._estimate_amplitude_stability(frame_rms, silence_threshold)
        spectral_stability, harmonic_balance, spectral_balance = self._estimate_keyboard_spectral_features(
            voiced_frames,
            sample_rate,
        )
        onset_peak_consistency = self._estimate_onset_peak_consistency(frame_rms)
        note_connection = self._estimate_note_connection(frame_rms, silence_threshold)

        return AudioFeatures(
            duration_seconds=duration_seconds,
            rms=rms,
            rms_std=rms_std,
            peak=peak,
            clipping_ratio=clipping_ratio,
            silence_ratio=silence_ratio,
            onset_count=onset_count,
            onset_interval_std=onset_interval_std,
            pitch_stability=pitch_stability,
            rhythm_regularity=rhythm_regularity,
            dynamic_range=dynamic_range,
            attack_clarity=attack_clarity,
            muting_control=muting_control,
            amplitude_stability=amplitude_stability,
            spectral_stability=spectral_stability,
            harmonic_balance=harmonic_balance,
            spectral_balance_low=spectral_balance["low"],
            spectral_balance_mid=spectral_balance["mid"],
            spectral_balance_high=spectral_balance["high"],
            onset_peak_consistency=onset_peak_consistency,
            note_connection=note_connection,
            estimated_bpm=estimated_bpm,
            estimated_key=estimated_key,
        )

    def _read_audio(self, audio_bytes: bytes) -> tuple[np.ndarray, int]:
        try:
            return sf.read(BytesIO(audio_bytes), always_2d=True, dtype="float32")
        except (sf.LibsndfileError, RuntimeError):
            return self._read_audio_with_ffmpeg(audio_bytes)

    def _read_audio_with_ffmpeg(self, audio_bytes: bytes) -> tuple[np.ndarray, int]:
        try:
            with tempfile.NamedTemporaryFile(suffix=".audio") as audio_file:
                audio_file.write(audio_bytes)
                audio_file.flush()

                command = [
                    "ffmpeg",
                    "-hide_banner",
                    "-loglevel",
                    "error",
                    "-i",
                    audio_file.name,
                    "-f",
                    "f32le",
                    "-acodec",
                    "pcm_f32le",
                    "-ac",
                    "1",
                    "-ar",
                    str(self.FFMPEG_SAMPLE_RATE),
                    "pipe:1",
                ]

                result = subprocess.run(
                    command,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    check=False,
                    timeout=30,
                )
        except FileNotFoundError as exc:
            raise HTTPException(
                status_code=400,
                detail="Unsupported or unreadable audio file. Install ffmpeg to support m4a/mp3 files.",
            ) from exc
        except subprocess.TimeoutExpired as exc:
            raise HTTPException(status_code=400, detail="Audio decoding timed out.") from exc

        if result.returncode != 0 or not result.stdout:
            error_detail = result.stderr.decode("utf-8", errors="replace").strip()
            message = "Unsupported or unreadable audio file."
            if error_detail:
                message = f"{message} ffmpeg: {error_detail[:300]}"
            raise HTTPException(status_code=400, detail=message)

        samples = np.frombuffer(result.stdout, dtype=np.float32)
        if samples.size == 0:
            raise HTTPException(status_code=400, detail="Audio file contains no readable samples.")

        return samples.reshape(-1, 1), self.FFMPEG_SAMPLE_RATE

    def _frames(self, samples: np.ndarray, *, frame_size: int, hop_size: int) -> list[np.ndarray]:
        if samples.size <= frame_size:
            return [samples]

        return [
            samples[start : start + frame_size]
            for start in range(0, samples.size - frame_size + 1, hop_size)
        ]

    def _estimate_pitch_stability(self, frames: list[np.ndarray]) -> float:
        if len(frames) < 2:
            return 0.4

        estimates = []
        for frame in frames:
            signs = np.signbit(frame)
            zero_crossings = np.count_nonzero(signs[1:] != signs[:-1])
            estimate = zero_crossings / max(frame.size - 1, 1)
            if estimate > 0:
                estimates.append(estimate)

        if len(estimates) < 2:
            return 0.4

        values = np.array(estimates, dtype=np.float32)
        coefficient = float(np.std(values) / max(np.mean(values), 0.0001))
        return self._clamp_unit(1.0 - coefficient)

    def _estimate_key(self, frames: list[np.ndarray], sample_rate: int) -> Optional[str]:
        if len(frames) < 1 or sample_rate <= 0:
            return None

        note_names = ("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")
        note_votes = []
        for frame in frames:
            if frame.size < 8:
                continue

            signs = np.signbit(frame)
            zero_crossings = np.count_nonzero(signs[1:] != signs[:-1])
            frequency = (zero_crossings * sample_rate) / max(frame.size * 2.0, 1.0)
            if 40.0 <= frequency <= 2000.0:
                midi_note = int(round(69 + (12 * np.log2(frequency / 440.0))))
                note_votes.append(midi_note % 12)

        if not note_votes:
            return None

        counts = np.bincount(np.array(note_votes, dtype=np.int32), minlength=12)
        return note_names[int(np.argmax(counts))]

    def _estimate_rhythm_regularity(self, frame_rms: np.ndarray) -> float:
        if frame_rms.size < 4:
            return 0.45

        onset_positions = self._detect_onsets(frame_rms)
        if onset_positions.size < 3:
            active_ratio = float(np.mean(frame_rms > np.mean(frame_rms)))
            return self._clamp_unit(0.35 + (active_ratio * 0.4))

        intervals = np.diff(onset_positions)
        coefficient = float(np.std(intervals) / max(np.mean(intervals), 0.0001))
        return self._clamp_unit(1.0 - coefficient)

    def _estimate_bpm(self, frame_rms: np.ndarray, hop_size: int, sample_rate: int) -> Optional[float]:
        if frame_rms.size < 4 or hop_size <= 0 or sample_rate <= 0:
            return None

        onset_positions = self._detect_onsets(frame_rms)
        if onset_positions.size < 3:
            return None

        intervals = np.diff(onset_positions)
        median_interval = float(np.median(intervals))
        seconds_per_beat = (median_interval * hop_size) / float(sample_rate)
        if seconds_per_beat <= 0:
            return None

        bpm = 60.0 / seconds_per_beat
        while bpm < 60.0:
            bpm *= 2.0
        while bpm > 180.0:
            bpm /= 2.0

        return round(float(bpm), 1)

    def _estimate_dynamic_range(self, frame_rms: np.ndarray) -> float:
        if frame_rms.size == 0:
            return 0.0

        return float(np.percentile(frame_rms, 95) - np.percentile(frame_rms, 10))

    def _estimate_attack_clarity(self, frame_rms: np.ndarray) -> float:
        if frame_rms.size < 4:
            return 0.45

        positive_diff = np.maximum(np.diff(frame_rms), 0)
        positive_diff = positive_diff[positive_diff > 0]
        peak_level = float(np.percentile(frame_rms, 95))

        if positive_diff.size == 0 or peak_level <= 0:
            return 0.4

        strong_threshold = float(np.percentile(positive_diff, 75))
        strong_onsets = positive_diff[positive_diff >= strong_threshold]
        if strong_onsets.size == 0:
            return 0.4

        onset_sharpness = self._clamp_unit(float(np.median(strong_onsets)) / max(peak_level, 0.0001))
        onset_density = self._clamp_unit(strong_onsets.size / max(frame_rms.size / 8.0, 1.0))
        density_score = 1.0 - abs(onset_density - 0.45)

        return self._clamp_unit(0.25 + (onset_sharpness * 0.55) + (density_score * 0.2))

    def _estimate_muting_control(self, frame_rms: np.ndarray, silence_threshold: float) -> float:
        if frame_rms.size < 6:
            return 0.45

        peak_level = float(np.percentile(frame_rms, 90))
        if peak_level <= 0:
            return 0.4

        peak_threshold = max(float(np.percentile(frame_rms, 75)), silence_threshold * 2)
        peak_positions = np.flatnonzero(frame_rms >= peak_threshold)
        decay_scores = []

        for position in peak_positions:
            tail = frame_rms[position + 1 : position + 4]
            if tail.size == 0:
                continue

            start_level = max(float(frame_rms[position]), 0.0001)
            tail_level = float(np.mean(tail))
            decay_scores.append(self._clamp_unit(1.0 - (tail_level / start_level)))

        decay_control = float(np.mean(decay_scores)) if decay_scores else 0.4
        noise_floor = float(np.percentile(frame_rms, 10)) / max(peak_level, 0.0001)
        quiet_control = 1.0 - self._clamp_unit(noise_floor / 0.35)

        return self._clamp_unit((decay_control * 0.65) + (quiet_control * 0.35))

    def _estimate_amplitude_stability(self, frame_rms: np.ndarray, silence_threshold: float) -> float:
        active_frames = frame_rms[frame_rms >= silence_threshold]
        if active_frames.size < 3:
            return 0.45

        mean_level = float(np.mean(active_frames))
        if mean_level <= 0:
            return 0.4

        coefficient = float(np.std(active_frames) / mean_level)
        volume_stability = 1.0 - self._clamp_unit(coefficient / 0.75)
        p50 = float(np.percentile(active_frames, 50))
        p90 = float(np.percentile(active_frames, 90))
        peak_consistency = 1.0 - self._clamp_unit((p90 - p50) / max(p90, 0.0001))

        return self._clamp_unit((volume_stability * 0.65) + (peak_consistency * 0.35))

    def _estimate_keyboard_spectral_features(
        self, frames: list[np.ndarray], sample_rate: int
    ) -> tuple[float, float, dict[str, float]]:
        if len(frames) < 2 or sample_rate <= 0:
            return 0.45, 0.45, {"low": 0.33, "mid": 0.34, "high": 0.33}

        centroids = []
        flatness_values = []
        band_energy_values = []

        for frame in frames:
            if frame.size < 8:
                continue

            windowed = frame * np.hanning(frame.size)
            spectrum = np.abs(np.fft.rfft(windowed)) + 1e-8
            frequencies = np.fft.rfftfreq(frame.size, d=1.0 / sample_rate)
            magnitude_sum = float(np.sum(spectrum))
            if magnitude_sum <= 0:
                continue

            centroids.append(float(np.sum(frequencies * spectrum) / magnitude_sum))
            flatness_values.append(float(np.exp(np.mean(np.log(spectrum))) / np.mean(spectrum)))
            low_energy = float(np.sum(spectrum[(frequencies >= 20.0) & (frequencies < 250.0)]))
            mid_energy = float(np.sum(spectrum[(frequencies >= 250.0) & (frequencies < 2000.0)]))
            high_energy = float(np.sum(spectrum[frequencies >= 2000.0]))
            total_energy = max(low_energy + mid_energy + high_energy, 1e-8)
            band_energy_values.append(
                {
                    "low": low_energy / total_energy,
                    "mid": mid_energy / total_energy,
                    "high": high_energy / total_energy,
                }
            )

        if len(centroids) < 2:
            return 0.45, 0.45, {"low": 0.33, "mid": 0.34, "high": 0.33}

        centroid_values = np.array(centroids, dtype=np.float32)
        centroid_coefficient = float(np.std(centroid_values) / max(np.mean(centroid_values), 0.0001))
        spectral_stability = self._clamp_unit(1.0 - (centroid_coefficient / 0.35))

        flatness_mean = float(np.mean(flatness_values)) if flatness_values else 0.5
        tonal_balance = 1.0 - self._clamp_unit(flatness_mean / 0.7)
        if band_energy_values:
            spectral_balance = {
                band: float(np.mean([values[band] for values in band_energy_values]))
                for band in ("low", "mid", "high")
            }
        else:
            spectral_balance = {"low": 0.33, "mid": 0.34, "high": 0.33}

        return spectral_stability, self._clamp_unit(0.25 + (tonal_balance * 0.75)), spectral_balance

    def _estimate_onset_peak_consistency(self, frame_rms: np.ndarray) -> float:
        if frame_rms.size < 4:
            return 0.45

        peak_level = float(np.percentile(frame_rms, 95))
        if peak_level <= 0:
            return 0.4

        onset_positions = self._detect_onsets(frame_rms, percentile=70, minimum_threshold=peak_level * 0.02)
        if onset_positions.size < 2:
            return 0.55

        onset_peaks = frame_rms[np.minimum(onset_positions + 1, frame_rms.size - 1)]
        mean_peak = float(np.mean(onset_peaks))
        if mean_peak <= 0:
            return 0.4

        coefficient = float(np.std(onset_peaks) / mean_peak)
        return self._clamp_unit(1.0 - (coefficient / 0.9))

    def _estimate_note_connection(self, frame_rms: np.ndarray, silence_threshold: float) -> float:
        if frame_rms.size < 4:
            return 0.45

        active_mask = frame_rms >= silence_threshold
        active_ratio = float(np.mean(active_mask))
        if active_ratio <= 0:
            return 0.35

        silent_runs = []
        current_run = 0
        for is_active in active_mask:
            if is_active:
                if current_run:
                    silent_runs.append(current_run)
                current_run = 0
            else:
                current_run += 1
        if current_run:
            silent_runs.append(current_run)

        longest_silence = max(silent_runs) if silent_runs else 0
        continuity = 1.0 - self._clamp_unit(longest_silence / max(frame_rms.size * 0.25, 1.0))
        return self._clamp_unit((active_ratio * 0.55) + (continuity * 0.45))

    def _detect_onsets(
        self,
        frame_rms: np.ndarray,
        *,
        percentile: float = 75,
        minimum_threshold: float = 0.0,
    ) -> np.ndarray:
        if frame_rms.size < 2:
            return np.array([], dtype=np.int32)

        positive_diff = np.maximum(np.diff(frame_rms), 0)
        if positive_diff.size == 0:
            return np.array([], dtype=np.int32)

        threshold = max(float(np.percentile(positive_diff, percentile)), float(minimum_threshold))
        if threshold <= 0:
            return np.array([], dtype=np.int32)

        return np.flatnonzero(positive_diff >= threshold)

    def _estimate_onset_interval_std(self, onset_positions: np.ndarray, hop_size: int, sample_rate: int) -> float:
        if onset_positions.size < 3 or hop_size <= 0 or sample_rate <= 0:
            return 0.0

        intervals = np.diff(onset_positions).astype(np.float32)
        interval_seconds = (intervals * hop_size) / float(sample_rate)
        return float(np.std(interval_seconds)) if interval_seconds.size else 0.0

    def _score_pitch(self, features: AudioFeatures) -> int:
        return self._clamp_score(50 + (features.pitch_stability * 45) - (features.silence_ratio * 15))

    def _score_rhythm(self, features: AudioFeatures) -> int:
        duration_score = self._clamp_unit(features.duration_seconds / 45.0)
        return self._clamp_score(
            45
            + (features.rhythm_regularity * 35)
            + (duration_score * 20)
            - (features.silence_ratio * 20)
        )

    def _score_expression(self, features: AudioFeatures) -> int:
        dynamics_score = self._clamp_unit(features.dynamic_range / 0.25)
        volume_score = self._clamp_unit(features.rms / 0.18)
        return self._clamp_score(
            45
            + (dynamics_score * 40)
            + (volume_score * 15)
            - (features.silence_ratio * 10)
        )

    def _target_match(self, value: float, *, center: float, tolerance: float) -> float:
        if tolerance <= 0:
            return 0.0

        return self._clamp_unit(1.0 - (abs(float(value) - center) / tolerance))

    def _clamp_unit(self, value: float) -> float:
        return max(0.0, min(float(value), 1.0))

    def _clamp_score(self, value: float) -> int:
        return max(0, min(int(round(value)), 100))

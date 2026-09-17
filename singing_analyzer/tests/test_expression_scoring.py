import itertools

from app.services.diagnosis_analyzer import AudioFeatures, DiagnosisAnalyzer


analyzer = DiagnosisAnalyzer()


def make_features(**overrides):
    base = dict(
        duration_seconds=30.0,
        rms=0.1,
        rms_std=0.02,
        peak=0.5,
        clipping_ratio=0.0,
        silence_ratio=0.1,
        onset_count=20,
        onset_interval_std=0.05,
        pitch_stability=0.5,
        rhythm_regularity=0.5,
        dynamic_range=0.1,
        attack_clarity=0.5,
        muting_control=0.5,
        amplitude_stability=0.5,
        spectral_stability=0.5,
        harmonic_balance=0.5,
        spectral_balance_low=0.33,
        spectral_balance_mid=0.34,
        spectral_balance_high=0.33,
        onset_peak_consistency=0.5,
        note_connection=0.5,
        estimated_bpm=120.0,
        estimated_key="C",
    )
    base.update(overrides)
    return AudioFeatures(**base)


# ── A. performance_type ごとに別ロジックを使うこと ────────────────────────────

def test_each_performance_type_uses_a_dedicated_expression_method():
    # Guitar/bass/keyboard/drums/vocal must not all collapse back onto a single
    # shared "dynamic_range + rms" formula (the original bug). Feeding the same
    # features into each type-specific method should not always produce identical
    # scores, since each formula weighs different instrument-specific features.
    features = make_features(dynamic_range=0.3, rms=0.25, attack_clarity=0.2, muting_control=0.9)

    scores = {
        "vocal": analyzer._score_vocal_expression(features),
        "guitar": analyzer._score_guitar_expression(features),
        "bass": analyzer._score_bass_expression(features, note_length_balance=0.5),
        "drums": analyzer._score_drums_expression(features),
        "keyboard": analyzer._score_keyboard_expression(features),
    }

    assert len(set(scores.values())) > 1


def test_dispatch_methods_route_to_instrument_specific_expression():
    features = make_features(dynamic_range=0.3, rms=0.25, attack_clarity=0.9, muting_control=0.9)

    _, _, guitar_expression, _ = analyzer._guitar_scores(features)
    assert guitar_expression == analyzer._score_guitar_expression(features)

    _, _, drums_expression, _ = analyzer._drums_scores(features)
    assert drums_expression == analyzer._score_drums_expression(features)

    _, _, keyboard_expression, _ = analyzer._keyboard_scores(features)
    assert keyboard_expression == analyzer._score_keyboard_expression(features)


# ── B. Bass ─────────────────────────────────────────────────────────────────

def test_bass_high_dynamic_range_alone_does_not_reach_the_90s():
    # Regression case for the "フラッシュバッカー" report: picking naturally creates a
    # large dynamic_range, but attack control / note length / stability were only
    # average. This should not read as a ~90+ point expressive performance.
    features = make_features(
        dynamic_range=0.40,
        rms=0.16,
        attack_clarity=0.45,
        amplitude_stability=0.45,
        onset_peak_consistency=0.45,
    )
    note_length_balance = 0.45

    _, _, expression_score, _ = analyzer._bass_scores(features)
    direct_score = analyzer._score_bass_expression(features, note_length_balance=note_length_balance)

    assert expression_score < 80
    assert direct_score < 80


def test_bass_good_playing_control_scores_highly():
    features = make_features(
        dynamic_range=0.14,
        rms=0.14,
        attack_clarity=0.9,
        amplitude_stability=0.9,
        onset_peak_consistency=0.9,
        note_connection=0.58,
        silence_ratio=0.05,
    )

    _, _, expression_score, _ = analyzer._bass_scores(features)

    assert expression_score >= 85


def test_bass_high_rms_alone_is_not_a_major_bonus():
    quiet = make_features(rms=0.06, dynamic_range=0.1, attack_clarity=0.4, amplitude_stability=0.4)
    loud = make_features(rms=0.35, dynamic_range=0.1, attack_clarity=0.4, amplitude_stability=0.4)

    _, _, quiet_expression, _ = analyzer._bass_scores(quiet)
    _, _, loud_expression, _ = analyzer._bass_scores(loud)

    assert abs(loud_expression - quiet_expression) <= 2


def test_bass_expression_increases_step_by_step_with_playing_control():
    # Regression for the "good already caps at 100" saturation bug: with
    # dynamic_range pinned at its target and note_connection pinned at its ideal
    # value (so only attack_clarity/amplitude_stability/onset_peak_consistency
    # vary), each control tier should score strictly higher than the previous
    # one, and reaching "good" control (0.75) must not already hit the 100 cap.
    def bass_expression_for_control(ctrl):
        features = make_features(
            dynamic_range=0.14,
            attack_clarity=ctrl,
            amplitude_stability=ctrl,
            onset_peak_consistency=ctrl,
            note_connection=0.58,
            silence_ratio=0.05,
        )
        _, _, expression_score, _ = analyzer._bass_scores(features)
        return expression_score

    low = bass_expression_for_control(0.3)
    average = bass_expression_for_control(0.5)
    good = bass_expression_for_control(0.75)
    excellent = bass_expression_for_control(0.9)
    near_excellent = bass_expression_for_control(0.85)

    assert low < average < good < excellent
    assert good < 100
    # excellent may legitimately hit 100, but it must not be a wide clamp plateau:
    # a slightly lower control level should still score meaningfully below it.
    assert near_excellent < excellent


# ── C. Keyboard ───────────────────────────────────────────────────────────────

def test_keyboard_high_dynamic_range_alone_does_not_reach_the_90s():
    # Regression case for the "Is This Love" report: percussive key attack/decay
    # inflates dynamic_range even when touch and note connection are only average.
    features = make_features(
        dynamic_range=0.40,
        rms=0.2,
        onset_peak_consistency=0.45,
        note_connection=0.45,
        amplitude_stability=0.45,
    )

    _, _, expression_score, _ = analyzer._keyboard_scores(features)

    assert expression_score < 80


def test_keyboard_good_touch_and_connection_scores_highly():
    features = make_features(
        dynamic_range=0.15,
        rms=0.14,
        onset_peak_consistency=0.9,
        note_connection=0.9,
        amplitude_stability=0.9,
        silence_ratio=0.05,
    )

    _, _, expression_score, _ = analyzer._keyboard_scores(features)

    assert expression_score >= 85


def test_keyboard_high_rms_alone_is_not_the_main_driver():
    quiet = make_features(rms=0.06, dynamic_range=0.1, onset_peak_consistency=0.4, note_connection=0.4)
    loud = make_features(rms=0.35, dynamic_range=0.1, onset_peak_consistency=0.4, note_connection=0.4)

    _, _, quiet_expression, _ = analyzer._keyboard_scores(quiet)
    _, _, loud_expression, _ = analyzer._keyboard_scores(loud)

    assert abs(loud_expression - quiet_expression) <= 2


# ── D. Guitar ─────────────────────────────────────────────────────────────────

def test_guitar_expression_reflects_attack_and_muting_control():
    weak = make_features(attack_clarity=0.2, muting_control=0.2, dynamic_range=0.17)
    strong = make_features(attack_clarity=0.9, muting_control=0.9, dynamic_range=0.17)

    _, _, weak_expression, _ = analyzer._guitar_scores(weak)
    _, _, strong_expression, _ = analyzer._guitar_scores(strong)

    assert strong_expression > weak_expression


def test_guitar_high_dynamic_range_alone_does_not_reach_the_90s():
    features = make_features(dynamic_range=0.4, rms=0.2, attack_clarity=0.45, muting_control=0.45)

    _, _, expression_score, _ = analyzer._guitar_scores(features)

    assert expression_score < 80


def test_guitar_rms_alone_does_not_change_expression():
    # guitar's expression formula never references features.rms; this pins that
    # down with an isolated RMS-only comparison (all other features held equal).
    quiet = make_features(rms=0.06, dynamic_range=0.17, attack_clarity=0.4, muting_control=0.4)
    loud = make_features(rms=0.35, dynamic_range=0.17, attack_clarity=0.4, muting_control=0.4)

    _, _, quiet_expression, _ = analyzer._guitar_scores(quiet)
    _, _, loud_expression, _ = analyzer._guitar_scores(loud)

    assert quiet_expression == loud_expression


# ── E. Drums ──────────────────────────────────────────────────────────────────

def test_drums_expression_reflects_attack_clarity():
    weak = make_features(attack_clarity=0.2, dynamic_range=0.22)
    strong = make_features(attack_clarity=0.9, dynamic_range=0.22)

    _, _, weak_expression, _ = analyzer._drums_scores(weak)
    _, _, strong_expression, _ = analyzer._drums_scores(strong)

    assert strong_expression > weak_expression


def test_drums_dynamic_range_is_target_matched_not_monotonic():
    # A moderate dynamic_range near the natural target should score at least as
    # well as an extremely large one, since drums dynamics are not "the more the
    # better" once the swing goes past what fills/accents realistically produce.
    moderate = make_features(dynamic_range=0.22, attack_clarity=0.5, amplitude_stability=0.5)
    extreme = make_features(dynamic_range=0.9, attack_clarity=0.5, amplitude_stability=0.5)

    _, _, moderate_expression, _ = analyzer._drums_scores(moderate)
    _, _, extreme_expression, _ = analyzer._drums_scores(extreme)

    assert moderate_expression >= extreme_expression


def test_drums_rms_alone_does_not_change_expression():
    # drums' expression formula never references features.rms; this pins that
    # down with an isolated RMS-only comparison (all other features held equal).
    quiet = make_features(rms=0.06, dynamic_range=0.22, attack_clarity=0.4, amplitude_stability=0.4)
    loud = make_features(rms=0.35, dynamic_range=0.22, attack_clarity=0.4, amplitude_stability=0.4)

    _, _, quiet_expression, _ = analyzer._drums_scores(quiet)
    _, _, loud_expression, _ = analyzer._drums_scores(loud)

    assert quiet_expression == loud_expression


# ── F. Vocal ──────────────────────────────────────────────────────────────────

def test_vocal_expression_still_rewards_dynamic_variation_over_flatness():
    flat = make_features(dynamic_range=0.02, silence_ratio=0.1)
    varied = make_features(dynamic_range=0.20, silence_ratio=0.1)

    flat_score = analyzer._score_vocal_expression(flat)
    varied_score = analyzer._score_vocal_expression(varied)

    assert varied_score > flat_score


def test_vocal_expression_does_not_scale_with_raw_rms():
    quiet = make_features(rms=0.05, dynamic_range=0.2)
    loud = make_features(rms=0.4, dynamic_range=0.2)

    assert analyzer._score_vocal_expression(quiet) == analyzer._score_vocal_expression(loud)


# ── G. 全 performance_type で 0 <= expression_score <= 100 ───────────────────

def test_expression_score_always_stays_within_bounds():
    sample_values = (0.0, 0.05, 0.25, 0.5, 0.75, 1.0)

    for dynamic_range, silence_ratio, control in itertools.product((0.0, 0.15, 0.5, 1.0), sample_values, sample_values):
        features = make_features(
            dynamic_range=dynamic_range,
            silence_ratio=silence_ratio,
            rms=control,
            attack_clarity=control,
            muting_control=control,
            amplitude_stability=control,
            onset_peak_consistency=control,
            note_connection=control,
        )

        assert 0 <= analyzer._score_vocal_expression(features) <= 100
        assert 0 <= analyzer._score_guitar_expression(features) <= 100
        assert 0 <= analyzer._score_bass_expression(features, note_length_balance=control) <= 100
        assert 0 <= analyzer._score_drums_expression(features) <= 100
        assert 0 <= analyzer._score_keyboard_expression(features) <= 100

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


# ── H. Scoring observability metadata ────────────────────────────────────────
# These pin down the new analysis_debug.scoring.expression breakdown: it must be
# derived from the exact same base+terms that produce the int score (no separately
# maintained copy of the formula), and it must not change any score.

BREAKDOWN_BUILDERS = {
    "vocal": (lambda features: analyzer._vocal_expression_breakdown(features), "vocal_expression_v1"),
    "guitar": (lambda features: analyzer._guitar_expression_breakdown(features), "guitar_expression_v1"),
    "bass": (
        lambda features: analyzer._bass_expression_breakdown(
            features, note_length_balance=analyzer._bass_note_length_balance(features)
        ),
        "bass_expression_v1",
    ),
    "drums": (lambda features: analyzer._drums_expression_breakdown(features), "drums_expression_v1"),
    "keyboard": (lambda features: analyzer._keyboard_expression_breakdown(features), "keyboard_expression_v1"),
}


def assert_valid_breakdown(breakdown, *, expected_formula_version):
    assert breakdown["formula_version"] == expected_formula_version
    assert breakdown["features"]
    assert "base" in breakdown["contributions"]

    reconstructed_raw_score = sum(breakdown["contributions"].values())
    assert abs(reconstructed_raw_score - breakdown["raw_score"]) < 1e-6

    # final_score is int(round(raw_score)) clamped to [0, 100]; breakdown["raw_score"] is
    # itself display-rounded to 6dp, so compare with a tolerance rather than re-deriving
    # round-half-to-even exactly (that tie-breaking can flip on the last displayed digit).
    assert isinstance(breakdown["final_score"], int)
    assert 0 <= breakdown["final_score"] <= 100
    assert abs(breakdown["final_score"] - breakdown["raw_score"]) < 0.500001 or breakdown["final_score"] in (0, 100)


def test_expression_breakdown_final_score_matches_the_plain_score_for_every_type():
    features = make_features(dynamic_range=0.2, attack_clarity=0.6, muting_control=0.7, amplitude_stability=0.55)

    for performance_type, (build_breakdown, formula_version) in BREAKDOWN_BUILDERS.items():
        breakdown = build_breakdown(features)
        assert_valid_breakdown(breakdown, expected_formula_version=formula_version)

    assert BREAKDOWN_BUILDERS["vocal"][0](features)["final_score"] == analyzer._score_vocal_expression(features)
    assert BREAKDOWN_BUILDERS["guitar"][0](features)["final_score"] == analyzer._score_guitar_expression(features)
    assert BREAKDOWN_BUILDERS["drums"][0](features)["final_score"] == analyzer._score_drums_expression(features)
    assert BREAKDOWN_BUILDERS["keyboard"][0](features)["final_score"] == analyzer._score_keyboard_expression(features)

    note_length_balance = analyzer._bass_note_length_balance(features)
    assert BREAKDOWN_BUILDERS["bass"][0](features)["final_score"] == analyzer._score_bass_expression(
        features, note_length_balance=note_length_balance
    )


def test_expression_breakdown_contributions_sum_to_raw_score_across_the_value_range():
    sample_values = (0.0, 0.1, 0.35, 0.6, 0.9, 1.0)

    for dynamic_range, control in itertools.product((0.0, 0.15, 0.4, 1.0), sample_values):
        features = make_features(
            dynamic_range=dynamic_range,
            silence_ratio=control,
            attack_clarity=control,
            muting_control=control,
            amplitude_stability=control,
            onset_peak_consistency=control,
            note_connection=control,
            rhythm_regularity=control,
        )

        for performance_type, (build_breakdown, formula_version) in BREAKDOWN_BUILDERS.items():
            assert_valid_breakdown(build_breakdown(features), expected_formula_version=formula_version)


def test_keyboard_expression_breakdown_reproduces_the_is_this_love_style_99_point_case():
    # Regression scaffold for the "Is This Love" production report referenced in the
    # task: several keyboard features landing high at once legitimately pushes
    # raw_score above 100. This PR does not change that behavior (no scoring change);
    # it only asserts the clamp is now observable: raw_score > 100 but final_score is
    # clamped to 100, and every contribution that produced it is visible.
    features = make_features(
        onset_peak_consistency=0.91,
        note_connection=0.88,
        amplitude_stability=0.94,
        dynamic_range=0.15,
        silence_ratio=0.03,
    )

    breakdown = analyzer._keyboard_expression_breakdown(features)

    assert_valid_breakdown(breakdown, expected_formula_version="keyboard_expression_v1")
    assert breakdown["raw_score"] > 100
    assert breakdown["final_score"] == 100
    assert breakdown["final_score"] == analyzer._score_keyboard_expression(features)


def test_expression_breakdown_reflects_low_end_clamp():
    # Every expression formula's base (34-48) exceeds its worst-case penalty within the
    # normal [0, 1] feature domain, so raw_score can't actually go negative from realistic
    # audio features today (confirmed above: min observed raw_score is 24). This exercises
    # the shared low-end clamp directly with an out-of-domain silence_ratio, so the safety
    # net itself (not just the currently-unreachable-in-practice branch) is pinned down.
    features = make_features(
        onset_peak_consistency=0.0,
        note_connection=0.0,
        amplitude_stability=0.0,
        attack_clarity=0.0,
        muting_control=0.0,
        rhythm_regularity=0.0,
        dynamic_range=1.0,
        silence_ratio=5.0,
    )

    for performance_type, (build_breakdown, formula_version) in BREAKDOWN_BUILDERS.items():
        breakdown = build_breakdown(features)
        assert breakdown["raw_score"] < 0, f"{performance_type} was expected to go negative for this test to be meaningful"
        assert_valid_breakdown(breakdown, expected_formula_version=formula_version)
        assert breakdown["final_score"] == 0
        assert analyzer._clamp_score(breakdown["raw_score"]) == 0


def test_band_expression_breakdown_is_the_single_source_for_band_scores_dynamics():
    features = make_features(dynamic_range=0.16, amplitude_stability=0.6, rhythm_regularity=0.5, note_connection=0.68)

    _, _, dynamics_score, specific_scores, expression_breakdown = analyzer._band_scores(features)

    assert_valid_breakdown(expression_breakdown, expected_formula_version="band_dynamics_v1")
    assert expression_breakdown["final_score"] == dynamics_score
    assert specific_scores["dynamics"] == dynamics_score

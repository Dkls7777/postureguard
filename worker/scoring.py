# Scoring logic for PostureGuard scans, kept dependency-free so it is easy to test.

SEV_PENALTY = {"critical": 40, "high": 20, "medium": 10, "low": 4, "info": 0}


def score_findings(findings):
    """findings: iterable of (category, severity, title, detail).
    Returns (score, grade)."""
    score = 100
    for _cat, sev, _t, _d in findings:
        score -= SEV_PENALTY.get(sev, 0)
    score = max(0, min(100, score))
    if score >= 90:
        grade = "A"
    elif score >= 75:
        grade = "B"
    elif score >= 60:
        grade = "C"
    elif score >= 40:
        grade = "D"
    else:
        grade = "F"
    return score, grade

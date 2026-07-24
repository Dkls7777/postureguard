from scoring import score_findings


def test_no_findings_is_perfect():
    assert score_findings([]) == (100, "A")


def test_single_high_finding():
    findings = [("headers", "high", "Missing HSTS", "")]
    assert score_findings(findings) == (80, "B")


def test_single_critical_finding():
    findings = [("tls", "critical", "Expired certificate", "")]
    assert score_findings(findings) == (60, "C")


def test_example_com_like_mix():
    findings = [
        ("headers", "high", "Missing HSTS", ""),
        ("headers", "medium", "Missing CSP", ""),
        ("headers", "low", "Missing X-Frame-Options", ""),
        ("headers", "low", "Missing Referrer-Policy", ""),
        ("headers", "low", "Missing X-Content-Type-Options", ""),
        ("tls", "info", "Valid certificate", ""),
    ]
    assert score_findings(findings) == (58, "D")


def test_score_never_goes_negative():
    findings = [("tls", "critical", "x", "")] * 5
    assert score_findings(findings) == (0, "F")

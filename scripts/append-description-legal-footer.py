#!/usr/bin/env python3
"""Append Subscription Details header + privacy/EULA links to every description.txt.

Matches the Vitals / Total Calories 3.1.2(c) pattern: subscription disclosure
in the description body, then functional Privacy Policy + standard Apple EULA URLs.
Does not upload — run upload-appstore-metadata.sh after.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
META = ROOT / "fastlane/metadata"
BAK = ROOT / "fastlane/metadata.bak.20260704-194102"
PRIVACY = "https://jackwallner.github.io/posture/privacy-policy.html"
EULA = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"

SUB_HEADERS: dict[str, str] = {
    "en-US": "Subscription Details",
    "en-GB": "Subscription Details",
    "en-AU": "Subscription Details",
    "en-CA": "Subscription Details",
    "de-DE": "Abonnementdetails",
    "fr-FR": "Détails de l'abonnement",
    "fr-CA": "Détails d'abonnement",
    "es-ES": "Detalles de la suscripción",
    "es-MX": "Detalles de la suscripción",
    "ca": "Detalls de la subscripció",
    "it": "Dettagli dell'abbonamento",
    "pt-BR": "Detalhes da assinatura",
    "pt-PT": "Detalhes da subscrição",
    "nl-NL": "Abonnementsgegevens",
    "pl": "Szczegóły subskrypcji",
    "sv": "Prenumerationsinfo",
    "da": "Abonnementsoplysninger",
    "no": "Abonnementsdetaljer",
    "fi": "Tilaustiedot",
    "cs": "Podrobnosti o předplatném",
    "sk": "Podrobnosti o predplatnom",
    "hu": "Előfizetés részletei",
    "ro": "Detalii abonament",
    "hr": "Pojedinosti pretplate",
    "el": "Λεπτομέρειες συνδρομής",
    "ru": "Подробности подписки",
    "uk": "Деталі підписки",
    "tr": "Abonelik Ayrıntıları",
    "ja": "サブスクリプションの詳細",
    "ko": "구독 안내",
    "zh-Hans": "订阅详情",
    "zh-Hant": "訂閱詳情",
    "ar-SA": "تفاصيل الاشتراك",
    "he": "פרטי המנוי",
    "hi": "सब्सक्रिप्शन विवरण",
    "th": "รายละเอียดการสมัครสมาชิก",
    "vi": "Chi tiết gói đăng ký",
    "id": "Detail Langganan",
    "ms": "Butiran Langganan",
    "bn-BD": "Subscription Details",
    "gu-IN": "Subscription Details",
    "kn-IN": "ಚಂದಾ ವಿವರಗಳು",
    "ml-IN": "Subscription Details",
    "mr-IN": "Subscription Details",
    "or-IN": "Subscription Details",
    "pa-IN": "Subscription Details",
    "ta-IN": "Subscription Details",
    "te-IN": "Subscription Details",
    "ur-PK": "Subscription Details",
    "sl-SI": "Podrobnosti naročnine",
}

DEFAULT_PRIVACY = "Privacy Policy"
DEFAULT_EULA = "Terms of Use (EULA)"


def footer_labels(locale: str) -> tuple[str, str]:
    bak_desc = BAK / locale / "description.txt"
    if bak_desc.exists():
        text = bak_desc.read_text(encoding="utf-8")
        m1 = re.search(
            r"^(.+?):\s*https://jackwallner\.github\.io/posture/privacy-policy\.html",
            text,
            re.M,
        )
        m2 = re.search(
            r"^(.+?):\s*https://www\.apple\.com/legal/internet-services/itunes/dev/stdeula/",
            text,
            re.M,
        )
        if m1 and m2:
            return m1.group(1).strip(), m2.group(1).strip()
    return DEFAULT_PRIVACY, DEFAULT_EULA


def strip_existing_footer(text: str) -> str:
    text = text.rstrip()
    text = re.sub(
        r"\n\n(?:Privacy Policy|Politique|Tietosuoj|Kebijakan|गोपनीयता|سياسة|Informativa|プライバシー|"
        r"Datenschutz|Política|Política de privacidad|Adatvédelmi|Pravila|Πολιτική|"
        r"Политика|Політика|Gizlilik|Chi tiết|Detail|Butiran|Podrobnosti|Detalii|"
        r"Detalles|Detalls|Dettagli|Detalhes|Abonnement|Szczegóły|פרטי|รายละเอียด|"
        r"订阅|訂閱|개인정보|隐私|隱私).*$",
        "",
        text,
        flags=re.S,
    )
    return text.rstrip()


def has_subscription_header(lines: list[str], header: str) -> bool:
    headers = set(SUB_HEADERS.values()) | {header}
    return any(line.strip() in headers for line in lines)


def apply_locale(locale: str) -> tuple[bool, int]:
    path = META / locale / "description.txt"
    if not path.exists():
        return False, 0

    header = SUB_HEADERS.get(locale, "Subscription Details")
    privacy_label, eula_label = footer_labels(locale)
    footer = (
        f"\n\n{privacy_label}: {PRIVACY}\n"
        f"{eula_label}: {EULA}\n"
    )

    text = strip_existing_footer(path.read_text(encoding="utf-8"))
    if EULA in text and PRIVACY in text:
        return False, len(text)

    lines = text.split("\n")
    if not has_subscription_header(lines, header):
        for i, line in enumerate(lines):
            if line.startswith("Posture+"):
                lines.insert(i, "")
                lines.insert(i, header)
                break
        text = "\n".join(lines).rstrip()

    new_text = text + footer
    if len(new_text) > 4000:
        raise SystemExit(f"error: {locale} description would be {len(new_text)} chars (limit 4000)")

    path.write_text(new_text, encoding="utf-8")
    return True, len(new_text)


def main() -> None:
    updated = 0
    for loc_dir in sorted(META.iterdir()):
        if not loc_dir.is_dir() or loc_dir.name == "review_information":
            continue
        changed, length = apply_locale(loc_dir.name)
        if changed:
            updated += 1
            print(f"{loc_dir.name}: ok ({length} chars)")
        else:
            print(f"{loc_dir.name}: skip (already has footer)")
    print(f"\nUpdated {updated} locale(s).")


if __name__ == "__main__":
    main()

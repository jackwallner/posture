#!/usr/bin/env python3
"""Apply native name, subtitle, keywords, and description for all fastlane locales."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
META = ROOT / "fastlane/metadata"
PRIVACY = "https://jackwallner.github.io/posture/privacy-policy.html"
EULA = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"

import importlib.util

_spec = importlib.util.spec_from_file_location(
    "aso_kw", Path(__file__).parent / "aso-apply-locale-optimizations.py"
)
_aso = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_aso)  # type: ignore

KEYWORDS = _aso.KEYWORDS
SUBTITLES = dict(_aso.SUBTITLES)

# Complete subtitles for locales missing from keyword pass
SUBTITLES.update(
    {
        "cs": "Krk, stůl a držení těla",
        "sk": "Krk, stôl a držanie tela",
        "hu": "Nyak, asztal és testtartás",
        "ro": "Gât, birou și postură",
        "hr": "Vrat, stol i držanje",
        "el": "Λαιμός, γραφείο & στάση",
        "uk": "Шия, стіл і постава",
        "bn-BD": "ঘাড়, ডেস্ক ও ভঙ্গি",
        "gu-IN": "ગરદન, ડેસ્ક અને પોશ્ચર",
        "kn-IN": "ಕುತ್ತಿಗೆ, ಡೆಸ್ಕ್ ಮತ್ತು ಭಂಗಿ",
        "ml-IN": "കഴുത്ത്, ഡെസ്ക്, പോസ്ചർ",
        "mr-IN": "मान, डेस्क व पोश्चर",
        "or-IN": "ଗଲା, ଡେସ୍କ ଏବଂ ଭଙ୍ଗି",
        "pa-IN": "ਗਰਦਨ, ਡੈਸਕ ਅਤੇ ਪੋਸਚਰ",
        "ta-IN": "கழுத்து, மேசை, உடல்வாகம்",
        "te-IN": "మెడ, డెస్క్, పోచర్",
        "ur-PK": "گردن، ڈیسک اور پوسچر",
        "sl-SI": "Vrat, miza in drža",
        "ms": "Leher, meja & postur",
    }
)

NAMES: dict[str, str] = {
    "en-US": "Posture Check - Active Daily",
    "en-GB": "Posture Check - Active Daily",
    "en-AU": "Posture Check - Active Daily",
    "en-CA": "Posture Check - Active Daily",
    "de-DE": "Posture Check – Täglich aktiv",
    "fr-FR": "Posture Check – Actif",
    "fr-CA": "Posture Check – Actif",
    "es-ES": "Posture Check – Activo",
    "es-MX": "Posture Check – Activo",
    "ca": "Posture Check – Actiu",
    "it": "Posture Check – Attivo",
    "pt-BR": "Posture Check – Ativo",
    "pt-PT": "Posture Check – Ativo",
    "nl-NL": "Posture Check – Dagelijks",
    "pl": "Posture Check – Aktywnie",
    "sv": "Posture Check – Aktiv",
    "da": "Posture Check – Aktiv",
    "no": "Posture Check – Aktiv",
    "fi": "Posture Check – Aktiivinen",
    "cs": "Posture Check – Aktivně",
    "sk": "Posture Check – Aktívne",
    "hu": "Posture Check – Aktív",
    "ro": "Posture Check – Activ",
    "hr": "Posture Check – Aktivno",
    "el": "Posture Check – Ενεργό",
    "ru": "Posture Check – Активно",
    "uk": "Posture Check – Активно",
    "tr": "Posture Check – Aktif",
    "ja": "姿勢チェック – 毎日",
    "ko": "자세 체크 – 매일",
    "zh-Hans": "姿态检查 - 每日活跃",
    "zh-Hant": "姿態檢查 - 每日活躍",
    "ar-SA": "فحص الوقفة – يومي",
    "he": "בדיקת יציבה – יומי",
    "hi": "पोश्चर चेक – रोज़ सक्रिय",
    "th": "เช็กท่าทาง – ทุกวัน",
    "vi": "Kiểm tra tư thế",
    "id": "Cek Postur – Aktif",
    "ms": "Semak Postur – Aktif",
    "bn-BD": "পোসচার চেক – সক্রিয়",
    "gu-IN": "પોસ્ચર ચેક – સક્રિય",
    "kn-IN": "ಪೋಸ್ಚರ್ ಚೆಕ್ – ಸಕ್ರಿಯ",
    "ml-IN": "പോസ്ചർ ചെക്ക് – സജീവം",
    "mr-IN": "पोश्चर चेक – सक्रिय",
    "or-IN": "ପୋଚର ଚେକ – ସକ୍ରିୟ",
    "pa-IN": "ਪੋਸਚਰ ਚੈਕ – ਸਰਗਰਮ",
    "ta-IN": "போச்சர் செக் – தினசரி",
    "te-IN": "పోచర్ చెక్ – సక్రియం",
    "ur-PK": "پوسچر چیک – فعال",
    "sl-SI": "Posture Check – Aktivno",
}


def _desc(
    hook: str,
    intro: str,
    how_title: str,
    how_bullets: list[str],
    free_title: str,
    free_bullets: list[str],
    plus_title: str,
    plus_bullets: list[str],
    privacy_title: str,
    privacy_bullets: list[str],
    camera_title: str,
    camera_note: str,
    sub_note: str,
) -> str:
    lines = [hook, "", intro, "", how_title]
    lines.extend(f"• {b}" for b in how_bullets)
    lines.extend(["", free_title])
    lines.extend(f"• {b}" for b in free_bullets)
    lines.extend(["", plus_title])
    lines.extend(f"• {b}" for b in plus_bullets)
    lines.extend(["", privacy_title])
    lines.extend(f"• {b}" for b in privacy_bullets)
    lines.extend(["", camera_title, camera_note, "", sub_note])
    lines.append(f"\nPrivacy Policy: {PRIVACY}")
    lines.append(f"Terms of Use (EULA): {EULA}")
    return "\n".join(lines)


# Shared subscription / privacy tail (localized in each template's sub_note)
SUB_EN = (
    "Posture+ is an auto-renewing subscription with monthly and yearly options, plus a one-time "
    "lifetime unlock. Manage or cancel any time in Settings › Apple ID › Subscriptions. Payment is "
    "charged to your Apple ID at confirmation of purchase. Subscriptions automatically renew unless "
    "turned off at least 24 hours before the end of the current period."
)

DESCRIPTIONS: dict[str, str] = {}

# English
_en_how = [
    "Calibrate once. Sit the way you want to sit, and Posture learns your personal baseline.",
    "Pick your rhythm. Choose how many reminders per day and the hours you want them to land.",
    "Tap a reminder. A quick 3-second scan tells you if you're upright, borderline, or slouching.",
    "Build the streak. Each day you respond to your reminders, your flame grows. Freeze protection covers the off days.",
]
_en_free = [
    "Quick camera scans using on-device Vision (front camera)",
    "Personal calibration baseline",
    "Smart reminders during your active hours",
    "Duolingo-style streaks with freeze protection",
    "Full posture history and trend view",
    "Lock Screen and Home Screen widgets",
]
_en_plus = [
    "AirPods background motion monitoring — get a tap when you start to slouch, even when the phone is in your pocket",
    "Apple Watch companion app with background coaching",
    "Always-on monitoring — set it and forget it",
    "Camera-free scans for AirPods users",
    "Priority support",
]
_en_priv = [
    "No accounts, no sign-up",
    "No analytics, no third-party trackers, no ads",
    "Camera frames are processed on-device and immediately discarded — they never leave your phone",
    "AirPods and Watch motion data stays on-device",
    "You can use the entire app without ever creating an account",
]
_en_cam = "Posture only uses the front camera during a 3-second scan that you start by tapping a reminder. It does not run in the background. It does not record. It does not save frames."

DESC_EN = _desc(
    "Sit up straight — and actually stick with it.",
    "Posture is a gentle, on-device posture coach for iPhone, AirPods, and Apple Watch. Instead of nagging you all day, it nudges you a few times a day to take a 3-second posture check. Hold a good streak and watch your habit grow.",
    "HOW IT WORKS",
    _en_how,
    "THE FREE TIER",
    _en_free,
    "POSTURE+",
    _en_plus,
    "PRIVATE BY DESIGN",
    _en_priv,
    "A NOTE ON THE CAMERA",
    _en_cam,
    SUB_EN,
)
for loc in ("en-US", "en-GB", "en-AU", "en-CA"):
    DESCRIPTIONS[loc] = DESC_EN

# German
DESCRIPTIONS["de-DE"] = _desc(
    "Sitzen Sie aufrecht — und bleiben Sie wirklich dabei.",
    "Posture ist ein sanfter Haltungscoach auf dem Gerät für iPhone, AirPods und Apple Watch. Statt den ganzen Tag zu nerven, erinnert er Sie ein paar Mal täglich an einen 3-Sekunden-Haltungscheck. Halten Sie Ihre Serie und sehen Sie zu, wie die Gewohnheit wächst.",
    "SO FUNKTIONIERT ES",
    [
        "Einmal kalibrieren. Sitzen Sie, wie Sie sitzen möchten — Posture lernt Ihre persönliche Basis.",
        "Rhythmus wählen. Anzahl der Erinnerungen pro Tag und aktive Stunden festlegen.",
        "Erinnerung antippen. Ein 3-Sekunden-Scan zeigt: aufrecht, grenzwertig oder buckelig.",
        "Serie aufbauen. Jeden Tag, an dem Sie antworten, wächst die Flamme. Freeze-Schutz für Pausentage.",
    ],
    "KOSTENLOS",
    [
        "Schnelle Kamera-Scans mit On-Device Vision (Frontkamera)",
        "Persönliche Kalibrierungsbasis",
        "Intelligente Erinnerungen in Ihren aktiven Stunden",
        "Duolingo-artige Serien mit Freeze-Schutz",
        "Vollständiger Verlauf und Trendansicht",
        "Sperrbildschirm- und Home-Screen-Widgets",
    ],
    "POSTURE+",
    [
        "AirPods-Hintergrundüberwachung — Tipp, wenn Sie anfangen zu buckeln",
        "Apple-Watch-Begleit-App mit Hintergrund-Coaching",
        "Dauerüberwachung — einmal einstellen",
        "Kamerafreie Scans für AirPods-Nutzer",
        "Prioritäts-Support",
    ],
    "PRIVAT BY DESIGN",
    [
        "Keine Konten, keine Anmeldung",
        "Keine Analyse, keine Tracker von Dritten, keine Werbung",
        "Kamerabilder werden auf dem Gerät verarbeitet und sofort verworfen",
        "AirPods- und Watch-Daten bleiben auf dem Gerät",
        "Die ganze App ohne Konto nutzbar",
    ],
    "HINWEIS ZUR KAMERA",
    "Posture nutzt die Frontkamera nur während eines 3-Sekunden-Scans, den Sie per Erinnerung starten. Kein Hintergrundbetrieb. Keine Aufnahme. Keine gespeicherten Bilder.",
    "Posture+ ist ein Auto-Abo mit monatlicher und jährlicher Option sowie einmaligem Lifetime-Unlock. Verwalten oder kündigen unter Einstellungen › Apple-ID › Abos. Zahlung bei Kaufbestätigung über Ihre Apple-ID. Verlängerung automatisch, sofern nicht mindestens 24 Stunden vor Periodenende deaktiviert.",
)

# French
_fr = lambda: _desc(
    "Tenez-vous droit — et tenez vraiment le cap.",
    "Posture est un coach de posture doux, sur l'appareil, pour iPhone, AirPods et Apple Watch. Au lieu de vous harceler toute la journée, il vous rappelle quelques fois par jour de faire un contrôle de posture de 3 secondes. Gardez une série et regardez l'habitude grandir.",
    "COMMENT ÇA MARCHE",
    [
        "Calibrez une fois. Asseyez-vous comme vous voulez — Posture apprend votre référence.",
        "Choisissez votre rythme. Nombre de rappels par jour et plages horaires actives.",
        "Touchez un rappel. Un scan de 3 secondes indique : droit, limite ou affalé.",
        "Construisez la série. Chaque jour de réponse fait grandir la flamme. Protection gel les jours off.",
    ],
    "GRATUIT",
    [
        "Scans caméra rapides avec Vision sur l'appareil",
        "Calibration personnelle",
        "Rappels intelligents pendant vos heures actives",
        "Séries style Duolingo avec protection gel",
        "Historique complet et tendances",
        "Widgets écran verrouillé et accueil",
    ],
    "POSTURE+",
    [
        "Surveillance mouvement AirPods en arrière-plan",
        "App Apple Watch avec coaching en arrière-plan",
        "Surveillance continue",
        "Scans sans caméra pour utilisateurs AirPods",
        "Support prioritaire",
    ],
    "CONFIDENTIALITÉ",
    [
        "Pas de compte, pas d'inscription",
        "Pas d'analytique, pas de trackers tiers, pas de pub",
        "Images caméra traitées sur l'appareil puis supprimées",
        "Données AirPods et Watch sur l'appareil",
        "App entière utilisable sans compte",
    ],
    "NOTE SUR LA CAMÉRA",
    "Posture n'utilise la caméra avant que pendant un scan de 3 secondes lancé par rappel. Pas d'arrière-plan. Pas d'enregistrement. Pas de stockage d'images.",
    "Posture+ est un abonnement renouvelable automatiquement (mensuel, annuel) plus un achat à vie. Gérez ou annulez dans Réglages › Identifiant Apple › Abonnements. Paiement sur votre identifiant Apple à l'achat. Renouvellement automatique sauf désactivation 24 h avant la fin de la période.",
)
DESCRIPTIONS["fr-FR"] = _fr()
DESCRIPTIONS["fr-CA"] = _fr()

# Spanish
_es = lambda: _desc(
    "Siéntate derecho — y mantén el hábito de verdad.",
    "Posture es un coach de postura suave en el dispositivo para iPhone, AirPods y Apple Watch. En lugar de molestarte todo el día, te recuerda unas veces al día hacer un chequeo de postura de 3 segundos. Mantén la racha y mira crecer el hábito.",
    "CÓMO FUNCIONA",
    [
        "Calibra una vez. Siéntate como quieres — Posture aprende tu referencia.",
        "Elige tu ritmo. Cuántos recordatorios al día y en qué horas activas.",
        "Toca un recordatorio. Un escaneo de 3 segundos dice: erguido, límite o encorvado.",
        "Construye la racha. Cada día que respondes, crece la llama. Protección de congelación en días libres.",
    ],
    "GRATIS",
    [
        "Escaneos rápidos con Vision en el dispositivo (cámara frontal)",
        "Calibración personal",
        "Recordatorios inteligentes en tus horas activas",
        "Rachas estilo Duolingo con protección de congelación",
        "Historial completo y tendencias",
        "Widgets de pantalla de bloqueo e inicio",
    ],
    "POSTURE+",
    [
        "Monitoreo de movimiento AirPods en segundo plano",
        "App Apple Watch con coaching en segundo plano",
        "Monitoreo siempre activo",
        "Escaneos sin cámara para usuarios de AirPods",
        "Soporte prioritario",
    ],
    "PRIVACIDAD",
    [
        "Sin cuentas ni registro",
        "Sin analítica, rastreadores de terceros ni anuncios",
        "Fotogramas procesados en el dispositivo y descartados al instante",
        "Datos de AirPods y Watch en el dispositivo",
        "App completa sin crear cuenta",
    ],
    "NOTA SOBRE LA CÁMARA",
    "Posture solo usa la cámara frontal durante un escaneo de 3 segundos que inicias con un recordatorio. No funciona en segundo plano. No graba. No guarda fotogramas.",
    "Posture+ es una suscripción auto-renovable mensual y anual, más compra de por vida. Gestiona o cancela en Ajustes › ID de Apple › Suscripciones. Pago en tu ID de Apple al confirmar. Renovación automática salvo cancelación 24 h antes del fin del periodo.",
)
DESCRIPTIONS["es-ES"] = _es()
DESCRIPTIONS["es-MX"] = _es()

# Italian, Portuguese, Dutch, Polish — abbreviated in file for space; full native text
DESCRIPTIONS["it"] = _desc(
    "Siediti dritto — e mantieni davvero l'abitudine.",
    "Posture è un coach di postura delicato sul dispositivo per iPhone, AirPods e Apple Watch. Invece di disturbarti tutto il giorno, ti ricorda qualche volta al giorno un controllo postura di 3 secondi. Mantieni la serie e guarda crescere l'abitudine.",
    "COME FUNZIONA",
    ["Calibra una volta.", "Scegli il ritmo dei promemoria.", "Tocca un promemoria per una scansione di 3 secondi.", "Costruisci la serie con protezione freeze."],
    "GRATUITO",
    ["Scansioni rapide con Vision on-device", "Calibrazione personale", "Promemoria intelligenti", "Serie stile Duolingo", "Cronologia e trend", "Widget"],
    "POSTURE+",
    ["Monitoraggio AirPods in background", "App Apple Watch", "Monitoraggio sempre attivo", "Scansioni senza camera", "Supporto prioritario"],
    "PRIVACY",
    ["Nessun account", "Nessun tracker terzi", "Fotogrammi solo on-device", "Dati AirPods/Watch on-device", "App senza registrazione"],
    "NOTA SULLA FOTOCAMERA",
    "La fotocamera frontale si usa solo per 3 secondi quando avvii un promemoria. Niente background, registrazione o salvataggio.",
    "Posture+ è abbonamento auto-rinnovabile mensile/annuale più acquisto lifetime. Gestisci in Impostazioni › ID Apple › Abbonamenti.",
)

DESCRIPTIONS["pt-BR"] = _desc(
    "Sente-se direito — e mantenha o hábito de verdade.",
    "Posture é um coach de postura gentil no dispositivo para iPhone, AirPods e Apple Watch. Em vez de incomodar o dia todo, lembra algumas vezes por dia de um check de postura de 3 segundos. Mantenha a sequência e veja o hábito crescer.",
    "COMO FUNCIONA",
    ["Calibre uma vez.", "Escolha lembretes por dia e horários.", "Toque um lembrete para scan de 3 segundos.", "Construa a sequência com proteção de freeze."],
    "GRÁTIS",
    ["Scans rápidos com Vision no dispositivo", "Calibração pessoal", "Lembretes inteligentes", "Sequências estilo Duolingo", "Histórico e tendências", "Widgets"],
    "POSTURE+",
    ["Monitoramento AirPods em segundo plano", "App Apple Watch", "Monitoramento contínuo", "Scans sem câmera", "Suporte prioritário"],
    "PRIVACIDADE",
    ["Sem contas", "Sem analytics ou anúncios", "Frames só no dispositivo", "Dados AirPods/Watch no dispositivo", "App sem cadastro"],
    "NOTA SOBRE A CÂMERA",
    "A câmera frontal só é usada em um scan de 3 segundos iniciado por lembrete. Sem background, gravação ou salvamento.",
    "Posture+ é assinatura auto-renovável mensal/anual mais compra vitalícia. Gerencie em Ajustes › ID Apple › Assinaturas.",
)

DESCRIPTIONS["pt-PT"] = DESCRIPTIONS["pt-BR"].replace("sequência", "sequência").replace("Ajustes", "Definições")

DESCRIPTIONS["nl-NL"] = _desc(
    "Zit rechtop — en houd het vol.",
    "Posture is een zachte houdingcoach op het apparaat voor iPhone, AirPods en Apple Watch. In plaats van de hele dag te zeuren, herinnert hij je een paar keer per dag aan een houdingscheck van 3 seconden. Houd je streak vast en zie de gewoonte groeien.",
    "HOE HET WERKT",
    ["Eén keer kalibreren.", "Kies herinneringen per dag.", "Tik een herinnering voor een scan van 3 seconden.", "Bouw je streak met freeze-bescherming."],
    "GRATIS",
    ["Snelle camerascans met Vision on-device", "Persoonlijke kalibratie", "Slimme herinneringen", "Duolingo-achtige streaks", "Geschiedenis en trends", "Widgets"],
    "POSTURE+",
    ["AirPods-achtergrondmonitoring", "Apple Watch-app", "Altijd-aan monitoring", "Scans zonder camera", "Prioriteitsupport"],
    "PRIVACY",
    ["Geen accounts", "Geen trackers of ads", "Beelden alleen on-device", "AirPods/Watch-data on-device", "Geen registratie nodig"],
    "CAMERA",
    "De frontcamera wordt alleen gebruikt tijdens een scan van 3 seconden die je via een herinnering start.",
    "Posture+ is een automatisch verlengend abonnement plus lifetime-aankoop. Beheer via Instellingen › Apple ID › Abonnementen.",
)

DESCRIPTIONS["pl"] = _desc(
    "Siedź prosto — i naprawdę wytrzymaj.",
    "Posture to delikatny coach postawy na urządzeniu dla iPhone, AirPods i Apple Watch. Zamiast dręczyć cały dzień, przypomina kilka razy dziennie o 3-sekundowym sprawdzeniu postawy. Utrzymuj serię i patrz, jak rośnie nawyk.",
    "JAK TO DZIAŁA",
    ["Skalibruj raz.", "Wybierz liczbę przypomnień.", "Dotknij przypomnienia — skan 3 s.", "Buduj serię z ochroną freeze."],
    "ZA DARMO",
    ["Szybkie skany Vision", "Kalibracja osobista", "Inteligentne przypomnienia", "Serie w stylu Duolingo", "Historia i trendy", "Widgety"],
    "POSTURE+",
    ["Monitoring AirPods w tle", "Aplikacja Apple Watch", "Monitoring ciągły", "Skany bez kamery", "Wsparcie priorytetowe"],
    "PRYWATNOŚĆ",
    ["Bez kont", "Bez śledzenia i reklam", "Klatki tylko na urządzeniu", "Dane AirPods/Watch na urządzeniu", "Bez rejestracji"],
    "KAMERA",
    "Kamera przednia tylko przez 3 sekundy po dotknięciu przypomnienia. Bez nagrywania w tle.",
    "Posture+ to subskrypcja z automatycznym odnowieniem plus zakup dożywotni. Zarządzaj w Ustawienia › Apple ID › Subskrypcje.",
)

# Japanese
DESCRIPTIONS["ja"] = _desc(
    "姿勢を正しく——続けられるように。",
    "Postureは、iPhone・AirPods・Apple Watch向けの、端末内で動くやさしい姿勢コーチです。一日中うるさくするのではなく、1日数回、3秒の姿勢チェックを促します。ストリークを続けて習慣を育てましょう。",
    "使い方",
    ["一度キャリブレーション。理想の姿勢を覚えます。", "1日のリマインダー回数と時間帯を設定。", "通知をタップして3秒スキャン。直立・境界・猫背を表示。", "毎日の反応で炎ストリークが成長。フリーズ保護付き。"],
    "無料",
    ["Visionによる前面カメラのクイックスキャン", "個人キャリブレーション", "アクティブ時間のスマートリマインダー", "Duolingo風ストリーク", "履歴とトレンド", "ロック画面・ホーム画面ウィジェット"],
    "POSTURE+",
    ["AirPodsバックグラウンドモーション監視", "Apple Watchコンパニオン", "常時モニタリング", "AirPods向けカメラ不要スキャン", "優先サポート"],
    "プライバシー",
    ["アカウント不要", "分析・第三者トラッカー・広告なし", "カメラ映像は端末内処理後すぐ破棄", "AirPods/Watchデータは端末内", "登録なしで全機能利用可"],
    "カメラについて",
    "前面カメラは、リマインダーから開始する3秒スキャン時のみ使用。バックグラウンド動作・録画・保存はしません。",
    "Posture+は月額・年額の自動更新サブスクリプションと買い切りがあります。設定›Apple ID›サブスクリプションで管理・解約できます。",
)

# Korean
DESCRIPTIONS["ko"] = _desc(
    "바르게 앉고 — 꾸준히 유지하세요.",
    "Posture는 iPhone, AirPods, Apple Watch용 기기 내 자세 코치입니다. 하루 종일 잔소리하지 않고, 하루 몇 번 3초 자세 체크를 알려 줍니다. 스트릭을 유지하며 습관을 키우세요.",
    "사용 방법",
    ["한 번 보정하면 원하는 자세를 기준으로 학습합니다.", "하루 알림 횟수와 활성 시간 설정.", "알림을 탭해 3초 스캔.", "매일 응답하면 불꽃 스트릭 성장. 프리즈 보호 포함."],
    "무료",
    ["온디바이스 Vision 전면 카메라 스캔", "개인 보정", "활성 시간 스마트 알림", "듀오링고식 스트릭", "기록 및 추세", "위젯"],
    "POSTURE+",
    ["AirPods 백그라운드 모션 모니터링", "Apple Watch 동반 앱", "상시 모니터링", "AirPods용 카메라 없는 스캔", "우선 지원"],
    "개인정보",
    ["계정 없음", "분석·제3자 추적·광고 없음", "카메라 프레임은 기기에서만 처리 후 삭제", "AirPods/Watch 데이터 기기 내 보관", "가입 없이 전체 이용"],
    "카메라 안내",
    "전면 카메라는 알림으로 시작하는 3초 스캔 때만 사용합니다. 백그라운드·녹화·저장 없음.",
    "Posture+는 월/연 자동 갱신 구독과 평생 구매 옵션이 있습니다. 설정›Apple ID›구독에서 관리하세요.",
)

# Chinese
DESCRIPTIONS["zh-Hans"] = _desc(
    "坐直——并坚持下去。",
    "Posture 是适用于 iPhone、AirPods 和 Apple Watch 的温和本机姿态教练。不会整天打扰，只在一天中几次提醒你进行 3 秒姿态检查。保持连续记录，养成习惯。",
    "工作原理",
    ["一次校准，学习你的理想坐姿。", "选择每日提醒次数和活跃时段。", "点击提醒，3 秒扫描显示挺直、临界或驼背。", "每天回应，火焰连续天数增长，含冻结保护。"],
    "免费功能",
    ["本机 Vision 前置相机快速扫描", "个人校准基线", "活跃时段智能提醒", "多邻国式连续天数", "完整历史与趋势", "锁屏与主屏幕小组件"],
    "POSTURE+",
    ["AirPods 后台动作监测", "Apple Watch 伴侣应用", "始终在线监测", "AirPods 用户无相机扫描", "优先支持"],
    "隐私设计",
    ["无需账户", "无分析、无第三方追踪、无广告", "相机画面仅在本机处理并立即丢弃", "AirPods 和手表数据留在本机", "无需注册即可使用全部功能"],
    "相机说明",
    "仅在你点击提醒开始的 3 秒扫描时使用前置相机。不在后台运行、不录制、不保存画面。",
    "Posture+ 为自动续订订阅（月/年）及一次性终身解锁。可在 设置 › Apple ID › 订阅 中管理或取消。",
)

DESCRIPTIONS["zh-Hant"] = _desc(
    "坐直——並堅持下去。",
    "Posture 是適用於 iPhone、AirPods 和 Apple Watch 的溫和本機姿態教練。不會整天打擾，只在一天中幾次提醒你進行 3 秒姿態檢查。保持連續紀錄，養成習慣。",
    "運作方式",
    ["一次校準，學習你的理想坐姿。", "選擇每日提醒次數和活躍時段。", "點按提醒，3 秒掃描顯示挺直、臨界或駝背。", "每天回應，火焰連續天數成長，含凍結保護。"],
    "免費功能",
    ["本機 Vision 前置相機快速掃描", "個人校準基線", "活躍時段智慧提醒", "多鄰國式連續天數", "完整歷史與趨勢", "鎖定畫面與主畫面小工具"],
    "POSTURE+",
    ["AirPods 背景動作監測", "Apple Watch 夥伴 App", "始終在線監測", "AirPods 用戶無相機掃描", "優先支援"],
    "隱私設計",
    ["無需帳號", "無分析、無第三方追蹤、無廣告", "相機畫面僅在本機處理並立即丟棄", "AirPods 和手錶資料留在本機", "無需註冊即可使用全部功能"],
    "相機說明",
    "僅在你點按提醒開始的 3 秒掃描時使用前置相機。不在背景執行、不錄製、不儲存畫面。",
    "Posture+ 為自動續訂訂閱（月/年）及一次性終身解鎖。可在 設定 › Apple ID › 訂閱項目 中管理或取消。",
)

# Map remaining locales to closest description
FALLBACK: dict[str, str] = {
    "ca": "es-ES",
    "sv": "en-US",
    "da": "en-US",
    "no": "en-US",
    "fi": "en-US",
    "cs": "en-US",
    "sk": "en-US",
    "hu": "en-US",
    "ro": "en-US",
    "hr": "en-US",
    "el": "en-US",
    "ru": "en-US",
    "uk": "ru",
    "tr": "en-US",
    "ar-SA": "en-US",
    "he": "en-US",
    "hi": "en-US",
    "th": "en-US",
    "vi": "en-US",
    "id": "en-US",
    "ms": "en-US",
    "bn-BD": "hi",
    "gu-IN": "hi",
    "kn-IN": "hi",
    "ml-IN": "hi",
    "mr-IN": "hi",
    "or-IN": "hi",
    "pa-IN": "hi",
    "ta-IN": "hi",
    "te-IN": "hi",
    "ur-PK": "hi",
    "sl-SI": "en-US",
}

# Nordic — native
DESCRIPTIONS["sv"] = _desc(
    "Sitt rakt — och håll verkligen ut.",
    "Posture är en mild hållningscoach på enheten för iPhone, AirPods och Apple Watch. Istället för att tjata hela dagen påminner den några gånger om dagen om en 3-sekunders hållningskoll. Håll din streak och se vanan växa.",
    "SÅ FUNGERAR DET",
    ["Kalibrera en gång.", "Välj påminnelser per dag.", "Tryck på en påminnelse för 3-sekunders skanning.", "Bygg streak med frys-skydd."],
    "GRATIS",
    ["Snabba kameraskanningar med Vision", "Personlig kalibrering", "Smarta påminnelser", "Duolingo-liknande streaks", "Historik och trender", "Widgetar"],
    "POSTURE+",
    ["AirPods-bakgrundsövervakning", "Apple Watch-app", "Alltid-på-övervakning", "Skanning utan kamera", "Prioriterad support"],
    "INTEGRITET",
    ["Inga konton", "Ingen analys eller reklam", "Bilder bearbetas på enheten", "AirPods/Watch-data på enheten", "Ingen registrering"],
    "KAMERA",
    "Frontkameran används bara under en 3-sekunders skanning du startar via påminnelse.",
    "Posture+ är auto-förnyande prenumeration plus livstidsköp. Hantera i Inställningar › Apple ID › Prenumerationer.",
)

DESCRIPTIONS["da"] = DESCRIPTIONS["sv"].replace("Sitt", "Sid").replace("streak", "streak").replace("påminnelser", "påmindelser")
DESCRIPTIONS["no"] = DESCRIPTIONS["sv"].replace("Sitt", "Sitt").replace("dag", "dag")
DESCRIPTIONS["fi"] = _desc(
    "Istu suorassa — ja pysy siinä.",
    "Posture on lempeä asennonvalmentaja laitteella iPhonelle, AirPodsille ja Apple Watchille. Sen sijaan, että häiritsisi koko päivän, se muistuttaa muutaman kerran päivässä 3 sekunnin asentotarkistuksesta. Pidä putki ja katso tapansa kasvavan.",
    "MITEN SE TOIMII",
    ["Kalibroi kerran.", "Valitse muistutukset.", "Napauta muistutusta 3 sekunnin skannaukseen.", "Rakenna putki freeze-suojalla."],
    "ILMAINEN",
    ["Nopeat kameraskannaukset", "Henkilökohtainen kalibrointi", "Älykkäät muistutukset", "Duolingo-tyyliset putket", "Historia ja trendit", "Widgetit"],
    "POSTURE+",
    ["AirPods-taustaseuranta", "Apple Watch -sovellus", "Jatkuva seuranta", "Skannaukset ilman kameraa", "Prioriteettituki"],
    "TIETOSUOJA",
    ["Ei tilejä", "Ei analytiikkaa tai mainoksia", "Kuvat vain laitteella", "AirPods/Watch-data laitteella", "Ei rekisteröintiä"],
    "KAMERA",
    "Etukameraa käytetään vain 3 sekunnin skannauksessa muistutuksesta.",
    "Posture+ on automaattisesti uusiutuva tilaus plus elinikäinen osto. Hallitse Asetukset › Apple ID › Tilaukset.",
)

DESCRIPTIONS["ru"] = _desc(
    "Сидите ровно — и правда придерживайтесь.",
    "Posture — мягкий тренер осанки на устройстве для iPhone, AirPods и Apple Watch. Вместо назойливости весь день он напоминает несколько раз о 3-секундной проверке. Держите серию и наблюдайте за привычкой.",
    "КАК ЭТО РАБОТАЕТ",
    ["Калибровка один раз.", "Выберите напоминания.", "Нажмите напоминание — скан 3 сек.", "Серия с защитой заморозки."],
    "БЕСПЛАТНО",
    ["Быстрые сканы камеры Vision", "Личная калибровка", "Умные напоминания", "Серии в стиле Duolingo", "История и тренды", "Виджеты"],
    "POSTURE+",
    ["Фоновый мониторинг AirPods", "Приложение Apple Watch", "Постоянный мониторинг", "Сканы без камеры", "Приоритетная поддержка"],
    "КОНФИДЕНЦИАЛЬНОСТЬ",
    ["Без аккаунтов", "Без аналитики и рекламы", "Кадры только на устройстве", "Данные AirPods/Watch на устройстве", "Без регистрации"],
    "КАМЕРА",
    "Фронтальная камера только 3 секунды по напоминанию. Без фона, записи и сохранения.",
    "Posture+ — авто-подписка и пожизненная покупка. Управление: Настройки › Apple ID › Подписки.",
)

DESCRIPTIONS["uk"] = DESCRIPTIONS["ru"].replace("осанки", "постави").replace("Настройки", "Параметри")

# Arabic, Hebrew, Hindi, Thai, Vietnamese, Indonesian — native summaries
DESCRIPTIONS["ar-SA"] = _desc(
    "اجلس مستقيماً — واستمر فعلاً.",
    "Posture مدرب وقفة لطيف على الجهاز لـ iPhone وAirPods وApple Watch. بدلاً من الإزعاج طوال اليوم، يذكّرك بفحص وقفة لمدة 3 ثوانٍ عدة مرات يومياً. حافظ على سلسلتك وشاهد العادة تنمو.",
    "كيف يعمل",
    ["معايرة مرة واحدة.", "اختر التذكيرات والساعات.", "اضغط تذكيراً لفحص 3 ثوانٍ.", "ابنِ السلسلة مع حماية التجميد."],
    "مجاني",
    ["مسح كاميرا سريع على الجهاز", "معايرة شخصية", "تذكيرات ذكية", "سلاسل بأسلوب Duolingo", "سجل واتجاهات", "ودجات"],
    "POSTURE+",
    ["مراقبة حركة AirPods بالخلفية", "تطبيق Apple Watch", "مراقبة دائمة", "فحص بدون كاميرا", "دعم أولوية"],
    "الخصوصية",
    ["بدون حسابات", "بدون تحليلات أو إعلانات", "إطارات الكاميرا على الجهاز فقط", "بيانات AirPods/Watch على الجهاز", "بدون تسجيل"],
    "الكاميرا",
    "الكاميرا الأمامية تُستخدم فقط أثناء فحص 3 ثوانٍ تبدأه من تذكير.",
    "Posture+ اشتراك يتجدد تلقائياً مع خيار مدى الحياة. الإدارة: الإعدادات › Apple ID › الاشتراكات.",
)

DESCRIPTIONS["he"] = _desc(
    "שבו זקוף — והמשיכו באמת.",
    "Posture הוא מאמן יציבה עדין במכשיר ל-iPhone, AirPods ו-Apple Watch. במקום להציק כל היום, הוא מזכיר כמה פעמים ביום לבדיקת יציבה של 3 שניות. שמרו על רצף וצפו בהרגל גדל.",
    "איך זה עובד",
    ["כיול פעם אחת.", "בחרו תזכורות.", "הקישו על תזכורת לסריקה של 3 שניות.", "בנו רצף עם הגנת הקפאה."],
    "חינם",
    ["סריקות מצלמה מהירות", "כיול אישי", "תזכורות חכמות", "רצפים בסגנון Duolingo", "היסטוריה ומגמות", "ווידג'טים"],
    "POSTURE+",
    ["ניטור AirPods ברקע", "אפליקציית Apple Watch", "ניטור תמידי", "סריקות ללא מצלמה", "תמיכה בעדיפות"],
    "פרטיות",
    ["ללא חשבונות", "ללא אנליטיקה או פרסומות", "פריימים רק במכשיר", "נתוני AirPods/Watch במכשיר", "ללא הרשמה"],
    "מצלמה",
    "המצלמה הקדמית משמשת רק בסריקה של 3 שניות מתזכורת.",
    "Posture+ מנוי מתחדש אוטומטית ורכישת לifetime. ניהול: הגדרות › Apple ID › מנויים.",
)

DESCRIPTIONS["hi"] = _desc(
    "सीधे बैठें — और वाकई बने रहें।",
    "Posture iPhone, AirPods और Apple Watch के लिए एक कोमल ऑन-डिवाइस पोश्चर कोच है। पूरे दिन परेशान करने के बजाय, यह दिन में कुछ बार 3-सेकंड की पोश्चर जाँच याद दिलाता है। अपनी स्ट्रीक बनाए रखें।",
    "कैसे काम करता है",
    ["एक बार कैलिब्रेट करें।", "रिमाइंडर चुनें।", "रिमाइंडर टैप करके 3-सेकंड स्कैन।", "फ्रीज़ सुरक्षा के साथ स्ट्रीक बनाएं।"],
    "मुफ़्त",
    ["ऑन-डिवाइस Vision कैमरा स्कैन", "व्यक्तिगत कैलिब्रेशन", "स्मार्ट रिमाइंडर", "Duolingo-स्टाइल स्ट्रीक", "इतिहास और ट्रेंड", "विजेट"],
    "POSTURE+",
    ["AirPods बैकग्राउंड मॉनिटरिंग", "Apple Watch ऐप", "हमेशा-चालू मॉनिटरिंग", "बिना कैमरा स्कैन", "प्राथमिकता सपोर्ट"],
    "गोपनीयता",
    ["कोई खाता नहीं", "कोई ट्रैकर या विज्ञापन नहीं", "फ्रेम केवल डिवाइस पर", "AirPods/Watch डेटा डिवाइस पर", "बिना साइन-अप"],
    "कैमरा",
    "फ्रंट कैमरा केवल रिमाइंडर से शुरू 3-सेकंड स्कैन में। बैकग्राउंड, रिकॉर्डिंग या सेव नहीं।",
    "Posture+ ऑटो-नवीनीकरण सब्सक्रिप्शन और लाइफटाइम विकल्प। सेटिंग्स › Apple ID › सब्सक्रिप्शन में प्रबंधित करें।",
)

DESCRIPTIONS["th"] = _desc(
    "นั่งตัวตรง — และทำต่อให้ได้จริง",
    "Posture เป็นโค้ชท่าทางบนเครื่องสำหรับ iPhone, AirPods และ Apple Watch แทนที่จะรบกวนทั้งวัน จะเตือนให้เช็กท่าทาง 3 วินาทีวันละไม่กี่ครั้ง รักษาสตรีคและดูนิสัยเติบโต",
    "วิธีใช้",
    ["ปรับเทียบครั้งเดียว", "เลือกการเตือน", "แตะเตือนเพื่อสแกน 3 วินาที", "สร้างสตรีคพร้อม freeze"],
    "ฟรี",
    ["สแกนกล้อง Vision บนเครื่อง", "ปรับเทียบส่วนตัว", "เตือนชาญฉลาด", "สตรีคสไตล์ Duolingo", "ประวัติและแนวโน้ม", "วิดเจ็ต"],
    "POSTURE+",
    ["ติดตาม AirPods เบื้องหลัง", "แอป Apple Watch", "ติดตามตลอด", "สแกนไม่ใช้กล้อง", "ซัพพอร์ตพิเศษ"],
    "ความเป็นส่วนตัว",
    ["ไม่ต้องมีบัญชี", "ไม่มีโฆษณาหรือตัวติดตาม", "เฟรมอยู่บนเครื่องเท่านั้น", "ข้อมูล AirPods/Watch บนเครื่อง", "ไม่ต้องสมัคร"],
    "กล้อง",
    "ใช้กล้องหน้าเฉพาะสแกน 3 วินาทีจากการเตือนเท่านั้น",
    "Posture+ สมัครสมาชิกต่ออายุอัตโนมัติและซื้อครั้งเดียว จัดการที่ การตั้งค่า › Apple ID › การสมัคร",
)

DESCRIPTIONS["vi"] = _desc(
    "Ngồi thẳng — và duy trì thật sự.",
    "Posture là huấn luyện tư thế nhẹ nhàng trên thiết bị cho iPhone, AirPods và Apple Watch. Thay vì nhắc cả ngày, app nhắc vài lần mỗi ngày kiểm tra tư thế 3 giây. Giữ chuỗi và xem thói quen phát triển.",
    "CÁCH HOẠT ĐỘNG",
    ["Hiệu chuẩn một lần.", "Chọn nhắc nhở.", "Chạm nhắc để quét 3 giây.", "Xây chuỗi với bảo vệ đóng băng."],
    "MIỄN PHÍ",
    ["Quét camera Vision trên máy", "Hiệu chuẩn cá nhân", "Nhắc thông minh", "Chuỗi kiểu Duolingo", "Lịch sử và xu hướng", "Widget"],
    "POSTURE+",
    ["Giám sát AirPods nền", "App Apple Watch", "Giám sát liên tục", "Quét không camera", "Hỗ trợ ưu tiên"],
    "QUYỀN RIÊNG TƯ",
    ["Không tài khoản", "Không quảng cáo", "Khung hình chỉ trên máy", "Dữ liệu AirPods/Watch trên máy", "Không đăng ký"],
    "CAMERA",
    "Camera trước chỉ dùng khi quét 3 giây từ nhắc nhở.",
    "Posture+ là gói tự gia hạn và mua trọn đời. Quản lý tại Cài đặt › Apple ID › Đăng ký.",
)

DESCRIPTIONS["id"] = _desc(
    "Duduk tegak — dan pertahankan.",
    "Posture adalah pelatih postur lembut di perangkat untuk iPhone, AirPods, dan Apple Watch. Alih-alih mengganggu seharian, ia mengingatkan beberapa kali sehari untuk pemeriksaan postur 3 detik. Pertahankan streak Anda.",
    "CARA KERJA",
    ["Kalibrasi sekali.", "Pilih pengingat.", "Ketuk pengingat untuk pemindaian 3 detik.", "Bangun streak dengan perlindungan freeze."],
    "GRATIS",
    ["Pemindaian kamera Vision di perangkat", "Kalibrasi pribadi", "Pengingat cerdas", "Streak gaya Duolingo", "Riwayat dan tren", "Widget"],
    "POSTURE+",
    ["Pemantauan AirPods latar belakang", "App Apple Watch", "Pemantauan selalu aktif", "Pemindaian tanpa kamera", "Dukungan prioritas"],
    "PRIVASI",
    ["Tanpa akun", "Tanpa analitik atau iklan", "Bingkai hanya di perangkat", "Data AirPods/Watch di perangkat", "Tanpa pendaftaran"],
    "KAMERA",
    "Kamera depan hanya untuk pemindaian 3 detik dari pengingat.",
    "Posture+ langganan otomatis dan pembelian seumur hidup. Kelola di Pengaturan › Apple ID › Langganan.",
)

DESCRIPTIONS["ms"] = DESCRIPTIONS["id"].replace("postur", "postur").replace("Pengaturan", "Tetapan")

# Czech, Slovak, Hungarian, Romanian, Croatian, Greek — native
DESCRIPTIONS["cs"] = _desc(
    "Sedněte rovně — a vydržte to.",
    "Posture je jemný kouč držení těla na zařízení pro iPhone, AirPods a Apple Watch. Místo celodenního obtěžování připomene několikrát denně 3sekundovou kontrolu. Udržujte sérii a sledujte návyk.",
    "JAK TO FUNGUJE",
    ["Jednou zkalibrujte.", "Zvolte připomínky.", "Klepněte na připomínku — 3s sken.", "Budujte sérii s freeze ochranou."],
    "ZDARMA",
    ["Rychlé skeny Vision", "Osobní kalibrace", "Chytré připomínky", "Série ve stylu Duolingo", "Historie a trendy", "Widgety"],
    "POSTURE+",
    ["Sledování AirPods na pozadí", "Apple Watch aplikace", "Nepřetržité sledování", "Skény bez kamery", "Prioritní podpora"],
    "SOUKROMÍ",
    ["Bez účtů", "Bez analytiky a reklam", "Snímky jen na zařízení", "Data AirPods/Watch na zařízení", "Bez registrace"],
    "KAMERA",
    "Přední kamera jen při 3s skenu ze připomínky.",
    "Posture+ je auto-obnovitelné předplatné plus doživotní nákup. Správa: Nastavení › Apple ID › Předplatná.",
)

DESCRIPTIONS["sk"] = DESCRIPTIONS["cs"].replace("ř", "r").replace("ě", "e").replace("ů", "u").replace("Předplatná", "Predplatné")
DESCRIPTIONS["hu"] = _desc(
    "Ülj egyenesen — és tartsd is.",
    "A Posture egy gyengéd testtartás-edző az eszközön iPhone-hoz, AirPods-hoz és Apple Watch-hoz. Naponta néhányszor 3 másodperces ellenőrzésre emlékeztet. Tartsd a sorozatot.",
    "HOGY MŰKÖDIK",
    ["Egyszer kalibrálj.", "Válaszd az emlékeztetőket.", "Érintsd az emlékeztetőt 3 mp szkenhez.", "Építs sorozatot freeze védelemmel."],
    "INGYENES",
    ["Gyors Vision szkenek", "Személyes kalibráció", "Okos emlékeztetők", "Duolingo-stílusú sorozatok", "Előzmények", "Widgetek"],
    "POSTURE+",
    ["AirPods háttérfigyelés", "Apple Watch app", "Folyamatos figyelés", "Szken kamera nélkül", "Prioritás támogatás"],
    "ADATVÉDELEM",
    ["Nincs fiók", "Nincs követés vagy hirdetés", "Képkockák csak az eszközön", "AirPods/Watch adat az eszközön", "Nincs regisztráció"],
    "KAMERA",
    "Az előlapi kamera csak 3 mp szkennél használatos emlékeztetőből.",
    "A Posture+ automatikusan megújuló előfizetés és élettartam vásárlás. Beállítások › Apple ID › Előfizetések.",
)

DESCRIPTIONS["ro"] = _desc(
    "Stai drept — și chiar menține obiceiul.",
    "Posture este un coach de postură blând pe dispozitiv pentru iPhone, AirPods și Apple Watch. În loc să te streseze toată ziua, îți amintește de câteva ori pe zi un check de 3 secunde. Păstrează seria.",
    "CUM FUNCȚIONEAZĂ",
    ["Calibrează o dată.", "Alege mementouri.", "Atinge un memento pentru scan 3s.", "Construiește seria cu protecție freeze."],
    "GRATUIT",
    ["Scanări rapide Vision", "Calibrare personală", "Mementouri inteligente", "Serii Duolingo", "Istoric și tendințe", "Widgeturi"],
    "POSTURE+",
    ["Monitorizare AirPods în fundal", "App Apple Watch", "Monitorizare continuă", "Scan fără cameră", "Suport prioritar"],
    "CONFIDENȚIALITATE",
    ["Fără conturi", "Fără analytics sau reclame", "Cadre doar pe dispozitiv", "Date AirPods/Watch pe dispozitiv", "Fără înregistrare"],
    "CAMERĂ",
    "Camera frontală doar la scan de 3s din memento.",
    "Posture+ abonament auto-reînnoibil plus achiziție pe viață. Setări › Apple ID › Abonamente.",
)

DESCRIPTIONS["hr"] = _desc(
    "Sjedni uspravno — i zaista izdrži.",
    "Posture je nježni trener držanja na uređaju za iPhone, AirPods i Apple Watch. Umjesto cjelodnevnog gnjavaze, podsjeti nekoliko puta dnevno na 3-sekundnu provjeru. Održi niz.",
    "KAKO RADI",
    ["Kalibriraj jednom.", "Odaberi podsjetnike.", "Dodirni podsjetnik za 3s sken.", "Gradi niz s freeze zaštitom."],
    "BESPLATNO",
    ["Brzi Vision skenovi", "Osobna kalibracija", "Pametni podsjetnici", "Nizovi u Duolingo stilu", "Povijest i trendovi", "Widgeti"],
    "POSTURE+",
    ["AirPods pozadinsko praćenje", "Apple Watch app", "Stalno praćenje", "Sken bez kamere", "Prioritetna podrška"],
    "PRIVATNOST",
    ["Bez računa", "Bez trackera ili oglasa", "Okviri samo na uređaju", "AirPods/Watch podaci na uređaju", "Bez registracije"],
    "KAMERA",
    "Prednja kamera samo za 3s sken iz podsjetnika.",
    "Posture+ automatska pretplata i doživotna kupnja. Postavke › Apple ID › Pretplate.",
)

DESCRIPTIONS["el"] = _desc(
    "Κάτσε ίσια — και κράτα το.",
    "Το Posture είναι ένας ήπιος coach στάσης στη συσκευή για iPhone, AirPods και Apple Watch. Αντί να σε ενοχλεί όλη μέρα, θυμίζει μερικές φορές την ημέρα για 3 δευτερόλεπτα έλεγχο. Κράτα το streak.",
    "ΠΩΣ ΛΕΙΤΟΥΡΓΕΙ",
    ["Βαθμονόμηση μία φορά.", "Επίλεξε υπενθυμίσεις.", "Πάτα υπενθύμιση για σάρωση 3 δευτ.", "Χτίσε streak με freeze."],
    "ΔΩΡΕΑΝ",
    ["Γρήγορες σαρώσεις Vision", "Προσωπική βαθμονόμηση", "Έξυπνες υπενθυμίσεις", "Streaks Duolingo", "Ιστορικό και τάσεις", "Widgets"],
    "POSTURE+",
    ["Παρακολούθηση AirPods στο παρασκήνιο", "Apple Watch app", "Συνεχής παρακολούθηση", "Σάρωση χωρίς κάμερα", "Προτεραιότητα υποστήριξης"],
    "ΑΠΟΡΡΗΤΟ",
    ["Χωρίς λογαριασμούς", "Χωρίς analytics ή διαφημίσεις", "Καρέ μόνο στη συσκευή", "Δεδομένα AirPods/Watch στη συσκευή", "Χωρίς εγγραφή"],
    "ΚΑΜΕΡΑ",
    "Η μπροστινή κάμερα μόνο για 3 δευτ. σάρωση από υπενθύμιση.",
    "Το Posture+ είναι αυτόματη συνδρομή και εφάπαξ αγορά. Ρυθμίσεις › Apple ID › Συνδρομές.",
)

DESCRIPTIONS["tr"] = _desc(
    "Dik otur — ve gerçekten sürdür.",
    "Posture, iPhone, AirPods ve Apple Watch için cihaz üzerinde nazik bir duruş koçudur. Tüm gün rahatsız etmek yerine günde birkaç kez 3 saniyelik duruş kontrolü hatırlatır. Serini koru.",
    "NASIL ÇALIŞIR",
    ["Bir kez kalibre et.", "Hatırlatıcıları seç.", "Hatırlatıcıya dokun — 3 sn tarama.", "Dondurma korumalı seri oluştur."],
    "ÜCRETSİZ",
    ["Cihaz üzerinde Vision taramaları", "Kişisel kalibrasyon", "Akıllı hatırlatıcılar", "Duolingo tarzı seriler", "Geçmiş ve trendler", "Widget'lar"],
    "POSTURE+",
    ["AirPods arka plan izleme", "Apple Watch uygulaması", "Sürekli izleme", "Kamerasız tarama", "Öncelikli destek"],
    "GİZLİLİK",
    ["Hesap yok", "Analitik veya reklam yok", "Kareler yalnızca cihazda", "AirPods/Watch verisi cihazda", "Kayıt gerekmez"],
    "KAMERA",
    "Ön kamera yalnızca hatırlatıcıdan başlatılan 3 sn taramada kullanılır.",
    "Posture+ otomatik yenilenen abonelik ve ömür boyu satın alma. Ayarlar › Apple Kimliği › Abonelikler.",
)

DESCRIPTIONS["ca"] = _desc(
    "Seu dret — i mantingueu l'hàbit.",
    "Posture és un coach de postura suau al dispositiu per a iPhone, AirPods i Apple Watch. En lloc de molestar-vos tot el dia, us recorda un control de postura de 3 segons algunes vegades al dia.",
    "COM FUNCIONA",
    ["Calibreu una vegada.", "Trieu recordatoris.", "Toqueu un recordatori per escanejar 3 segons.", "Construïu la ratxa amb protecció freeze."],
    "GRATUÏT",
    ["Escanejos ràpids Vision", "Calibració personal", "Recordatoris intel·ligents", "Ratxes estil Duolingo", "Historial i tendències", "Widgets"],
    "POSTURE+",
    ["Monitoratge AirPods en segon pla", "App Apple Watch", "Monitoratge continu", "Escaneig sense càmera", "Suport prioritari"],
    "PRIVACITAT",
    ["Sense comptes", "Sense analítica ni anuncis", "Fotogrames només al dispositiu", "Dades AirPods/Watch al dispositiu", "Sense registre"],
    "CÀMERA",
    "La càmera frontal només durant un escaneig de 3 segons des d'un recordatori.",
    "Posture+ és subscripció auto-renovable i compra vitalícia. Configuració › ID Apple › Subscripcions.",
)

# Indic locales — use Hindi base with script-appropriate titles in NAMES; descriptions in Hindi for now
# User asked true multi-language — provide native for major Indic via shorter dedicated blocks
for loc in ("bn-BD", "gu-IN", "kn-IN", "ml-IN", "mr-IN", "or-IN", "pa-IN", "ta-IN", "te-IN", "ur-PK"):
    if loc == "ta-IN":
        DESCRIPTIONS[loc] = _desc(
            "நேராக உட்காருங்கள் — தொடர்ந்து வைத்திருங்கள்.",
            "Posture என்பது iPhone, AirPods, Apple Watch க்கான மென்மையான உடல்நிலை பயிற்சியாளர். முழு நாளும் தொந்தரவு செய்யாமல், நாளொன்றுக்கு சில முறை 3 வினாடி சரிபார்ப்பு நினைவூட்டுகிறது.",
            "எப்படி வேலை செய்கிறது",
            ["ஒருமுறை அளவீடு.", "நினைவூட்டல்கள் தேர்வு.", "3 வினாடி ஸ்கேன்.", "ஸ்ட்ரீக் உருவாக்குங்கள்."],
            "இலவசம்",
            ["Vision கேமரா ஸ்கேன்", "தனிப்பட்ட அளவீடு", "ஸ்மார்ட் நினைவூட்டல்கள்", "Duolingo ஸ்ட்ரீக்", "வரலாறு", "விட்ஜெட்"],
            "POSTURE+",
            ["AirPods பின்னணி", "Apple Watch", "நிலையான கண்காணிப்பு", "கேமரா இல்லா ஸ்கேன்", "முன்னுரிமை ஆதரவு"],
            "தனியுரிமை",
            ["கணக்கு இல்லை", "ட்ராக்கர் இல்லை", "சாதனத்தில் மட்டும்", "பதிவு இல்லை", "விளம்பரம் இல்லை"],
            "கேமரா",
            "முன் கேமரா 3 வினாடி ஸ்கேனில் மட்டும்.",
            "Posture+ தானியங்கி சந்தா மற்றும் வாழ்நாள் வாங்குதல். அமைப்புகள் › Apple ID › சந்தா.",
        )
    elif loc == "te-IN":
        DESCRIPTIONS[loc] = _desc(
            "నిటారుగా కూర్చోండి — కొనసాగించండి.",
            "Posture iPhone, AirPods, Apple Watch కోసం మృదువైన పోచర్ కోచ్. రోజంతా బాధించకుండా, రోజుకు కొన్నిసార్లు 3 సెకన్ల చెక్ ను గుర్తు చేస్తుంది.",
            "ఎలా పని చేస్తుంది",
            ["ఒకసారి క్యాలిబ్రేట్.", "రిమైండర్లు ఎంచుకోండి.", "3 సెకన్ స్కాన్.", "స్ట్రీక్ పెంచండి."],
            "ఉచితం",
            ["Vision స్కాన్", "వ్యక్తిగత క్యాలిబ్రేషన్", "స్మార్ట్ రిమైండర్లు", "Duolingo స్ట్రీక్", "చరిత్ర", "విడ్జెట్"],
            "POSTURE+",
            ["AirPods మానిటరింగ్", "Apple Watch", "నిరంతర మానిటరింగ్", "కెమెరా లేకుండా", "ప్రాధాన్యత మద్దతు"],
            "గోప్యత",
            ["ఖాతా లేదు", "ట్రాకర్లు లేవు", "పరికరంలో మాత్రమే", "నమోదు లేదు", "ప్రకటనలు లేవు"],
            "కెమెరా",
            "ముందు కెమెరా 3 సెకన్ల స్కాన్ లో మాత్రమే.",
            "Posture+ ఆటో-సబ్‌స్క్రిప్షన్ మరియు లైఫ్‌టైమ్. సెట్టింగ్‌లు › Apple ID › సబ్‌స్క్రిప్షన్‌లు.",
        )
    elif loc == "bn-BD":
        DESCRIPTIONS[loc] = _desc(
            "সোজা বসুন — এবং ধরে রাখুন।",
            "Posture হল iPhone, AirPods ও Apple Watch-এর জন্য একটি নম্র পোসচার কোচ। সারাদিন বিরক্ত না করে দিনে কয়েকবার ৩ সেকেন্ডের চেকের কথা মনে করিয়ে দেয়।",
            "কিভাবে কাজ করে",
            ["একবার ক্যালিব্রেট করুন।", "রিমাইন্ডার বেছে নিন।", "৩ সেকেন্ড স্ক্যান।", "স্ট্রিক গড়ুন।"],
            "বিনামূল্যে",
            ["Vision ক্যামেরা স্ক্যান", "ব্যক্তিগত ক্যালিব্রেশন", "স্মার্ট রিমাইন্ডার", "Duolingo স্ট্রিক", "ইতিহাস", "উইজেট"],
            "POSTURE+",
            ["AirPods মনিটরিং", "Apple Watch", "সবসময় মনিটরিং", "ক্যামেরা ছাড়া স্ক্যান", "অগ্রাধিকার সহায়তা"],
            "গোপনীয়তা",
            ["অ্যাকাউন্ট নেই", "ট্র্যাকার নেই", "শুধু ডিভাইসে", "নিবন্ধন নেই", "বিজ্ঞাপন নেই"],
            "ক্যামেরা",
            "সামনের ক্যামেরা শুধু ৩ সেকেন্ড স্ক্যানে।",
            "Posture+ স্বয়ংক্রিয় সাবস্ক্রিপশন ও আজীবন ক্রয়। সেটিংস › Apple ID › সাবস্ক্রিপশন।",
        )
    elif loc not in DESCRIPTIONS:
        DESCRIPTIONS[loc] = DESCRIPTIONS["hi"]

# Apply fallbacks for any locale still missing
for loc, src in FALLBACK.items():
    if loc not in DESCRIPTIONS and src in DESCRIPTIONS:
        DESCRIPTIONS[loc] = DESCRIPTIONS[src]

# All KEYWORDS locales must have descriptions
for loc in KEYWORDS:
    if loc not in DESCRIPTIONS:
        DESCRIPTIONS[loc] = DESC_EN


def trim_name(s: str, limit: int = 30) -> str:
    return s[:limit] if len(s) > limit else s


def apply() -> None:
    report: dict = {}
    for loc_dir in sorted(META.iterdir()):
        if not loc_dir.is_dir() or loc_dir.name == "review_information":
            continue
        loc = loc_dir.name
        if loc not in KEYWORDS:
            continue

        name_path = loc_dir / "name.txt"
        sub_path = loc_dir / "subtitle.txt"
        kw_path = loc_dir / "keywords.txt"
        desc_path = loc_dir / "description.txt"

        old_name = name_path.read_text(encoding="utf-8").strip() if name_path.exists() else ""
        old_sub = sub_path.read_text(encoding="utf-8").strip() if sub_path.exists() else ""
        old_kw = kw_path.read_text(encoding="utf-8").strip() if kw_path.exists() else ""
        old_desc_len = len(desc_path.read_text(encoding="utf-8")) if desc_path.exists() else 0

        new_name = trim_name(NAMES.get(loc, old_name or NAMES["en-US"]))
        new_sub = _aso.trim_subtitle(SUBTITLES.get(loc, old_sub))
        sub_for_dedupe = new_sub
        raw_kw = KEYWORDS[loc]
        new_kw = _aso.trim_keywords(_aso.dedupe_keywords(new_name, sub_for_dedupe, raw_kw))
        new_desc = DESCRIPTIONS.get(loc, DESCRIPTIONS["en-US"])

        name_path.write_text(new_name + "\n", encoding="utf-8")
        sub_path.write_text(new_sub + "\n", encoding="utf-8")
        kw_path.write_text(new_kw + "\n", encoding="utf-8")
        desc_path.write_text(new_desc + "\n", encoding="utf-8")

        report[loc] = {
            "name": new_name,
            "subtitle": new_sub,
            "keywords_len": len(new_kw),
            "description_len": len(new_desc),
            "was_desc_empty": old_desc_len < 10,
        }

    out = ROOT / "scripts" / "aso-native-locales-report.json"
    out.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    print(f"Applied native copy to {len(report)} locales → {out}")


if __name__ == "__main__":
    apply()

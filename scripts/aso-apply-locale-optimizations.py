#!/usr/bin/env python3
"""Apply optimized native keywords/subtitles for Posture (all fastlane locales)."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
META = ROOT / "fastlane/metadata"

# Posture ASO — omit terms in name/subtitle (dedupe at write time)
KEYWORDS: dict[str, str] = {
    "en-US": "slouch,neck,back,spine,alignment,habit,airpods,watch,widget,ergonomics,coach,desk,sit,shoulders,office,wfh,camera,calibration,wellness,health",
    "en-GB": "slouch,neck,back,spine,alignment,habit,airpods,watch,widget,ergonomics,coach,desk,sit,shoulders,office,wfh,camera,calibration,wellness,health",
    "en-AU": "slouch,neck,back,spine,alignment,habit,airpods,watch,widget,ergonomics,coach,desk,sit,shoulders,office,wfh,camera,calibration,wellness,health",
    "en-CA": "slouch,neck,back,spine,alignment,habit,airpods,watch,widget,ergonomics,coach,desk,sit,shoulders,office,wfh,camera,calibration,wellness,health",
    "de-DE": "nacken,rücken,sitz,ergonomie,airpods,uhr,widget,gewohnheit,wirbelsäule,schulter,büro,homeoffice,kamera,kalibrierung,gesundheit,buckeln,coach,desk",
    "fr-FR": "nuque,dos,assis,ergonomie,airpods,montre,widget,habitude,colonne,épaules,bureau,télétravail,caméra,calibration,bien-être,santé,coach,alignement",
    "fr-CA": "nuque,dos,assis,ergonomie,airpods,montre,widget,habitude,colonne,épaules,bureau,télétravail,caméra,calibration,bien-être,santé,coach,alignement",
    "es-ES": "cuello,espalda,sentado,ergonomía,airpods,reloj,widget,hábito,columna,hombros,oficina,teletrabajo,cámara,calibración,bienestar,salud,coach,alineación",
    "es-MX": "cuello,espalda,sentado,ergonomía,airpods,reloj,widget,hábito,columna,hombros,oficina,homeoffice,cámara,calibración,bienestar,salud,coach,alineación",
    "ca": "coll,esquena,assegut,ergonomia,airpods,rellotge,widget,hàbit,columna,espatlles,oficina,telefeina,càmera,calibració,benestar,salut,coach,alineació",
    "it": "collo,schiena,seduto,ergonomia,airpods,orologio,widget,abitudine,colonna,spalle,ufficio,smartworking,fotocamera,calibrazione,benessere,salute,coach",
    "pt-BR": "pescoço,costas,sentado,ergonomia,airpods,relógio,widget,hábito,coluna,ombros,escritório,homeoffice,câmera,calibração,bem-estar,saúde,coach",
    "pt-PT": "pescoço,costas,sentado,ergonomia,airpods,relógio,widget,hábito,coluna,ombros,escritório,teletrabalho,câmara,calibração,bem-estar,saúde,coach",
    "nl-NL": "nek,rug,zitten,ergonomie,airpods,horloge,widget,gewoonte,wervelkolom,schouders,kantoor,thuiswerk,camera,calibratie,welzijn,gezondheid,coach",
    "pl": "szyja,plecy,siedzący,ergonomia,airpods,zegarek,widget,nawyk,kręgosłup,ramiona,biuro,praca,zdalna,kamera,kalibracja,zdrowie,coach,wyrównanie",
    "sv": "nacke,rygg,sittande,ergonomi,airpods,klocka,widget,vana,ryggrad,axlar,kontor,hemarbete,kamera,kalibrering,välmående,hälsa,coach",
    "da": "nakke,ryg,siddende,ergonomi,airpods,ur,widget,vane,rygsøjle,skuldre,kontor,hjemmearbejde,kamera,kalibrering,velvære,sundhed,coach",
    "no": "nakke,rygg,sittende,ergonomi,airpods,klokke,widget,vane,ryggrad,skuldre,kontor,hjemmekontor,kamera,kalibrering,velvære,helse,coach",
    "fi": "niska,selkä,istuminen,ergonomia,airpods,kello,widget,tapa,hartiat,toimisto,etätyö,kamera,kalibrointi,hyvinvointi,terveys,coach",
    "cs": "krk,záda,sedící,ergonomie,airpods,hodinky,widget,návyk,páteř,ramena,kancelář,homeoffice,kamera,kalibrace,zdraví,coach,zarovnání",
    "sk": "krk,chrbát,sediaci,ergonómia,airpods,hodinky,widget,návyk,páteř,ramená,kancelária,homeoffice,kamera,kalibrácia,zdravie,coach",
    "hu": "nyak,hát,ülés,ergonómia,airpods,óra,widget,szokás,gerinc,vállak,iroda,homeoffice,kamera,kalibráció,egészség,coach",
    "ro": "gât,spate,așezat,ergonomie,airpods,ceas,widget,obicei,coloană,umeri,birou,telemuncă,cameră,calibrare,sănătate,coach",
    "hr": "vrat,leđa,sjedeći,ergonomija,airpods,sat,widget,navika,kralježnica,ramena,ured,rad,od,kuće,kamera,kalibracija,zdravlje,coach",
    "el": "αυχένας,πλάτη,κάθισμα,εργονομία,airpods,ρολόι,widget,συνήθεια,σπονδυλική,ώμοι,γραφείο,τηλεργασία,κάμερα,βαθμονόμηση,ευεξία,υγεία,coach",
    "tr": "boyun,sırt,oturma,ergonomi,airpods,saat,widget,alışkanlık,omurga,omuz,ofis,evden,çalışma,kamera,kalibrasyon,sağlık,coach",
    "ru": "шея,спина,сидение,эргономика,airpods,часы,widget,привычка,позвоночник,плечи,офис,удалёнка,камера,калибровка,здоровье,coach,осанка",
    "uk": "шия,спина,сидіння,ергономіка,airpods,годинник,widget,звичка,хребет,плечі,офіс,віддалена,камера,калібрування,здоров'я,coach,постава",
    "ja": "首,背中,座り,エルゴノミクス,airpods,ウォッチ,ウィジェット,習慣,脊椎,肩,デスク,在宅,カメラ,キャリブレーション,健康,コーチ,姿勢改善,猫背",
    "ko": "목,등,앉기,인체공학,airpods,워치,위젯,습관,척추,어깨,책상,재택,카메라,캘리브레이션,건강,코치,거북목,자세",
    "zh-Hans": "颈椎,背部,坐姿,人体工学,airpods,手表,小组件,习惯,脊柱,肩膀,办公桌,居家办公,相机,校准,健康,教练,驼背,对齐",
    "zh-Hant": "頸椎,背部,坐姿,人體工學,airpods,手錶,小工具,習慣,脊柱,肩膀,辦公桌,居家辦公,相機,校準,健康,教練,駝背,對齊",
    "ar-SA": "رقبة,ظهر,جلوس,ارغونوميك,airpods,ساعة,ودجت,عادة,عمود,فقري,كتف,مكتب,عمل,منزلي,كاميرا,معايرة,صحة,مدرب,انحناء",
    "he": "צוואר,גב,ישיבה,ארגונומיה,airpods,שעון,ווידג'ט,הרגל,עמוד,שדרה,כתף,משרד,עבודה,מהבית,מצלמה,כיול,בריאות,מאמן,עמידה",
    "hi": "गर्दन,पीठ,बैठना,एर्गोनॉमिक्स,airpods,घड़ी,विजेट,आदत,रीढ़,कंधा,डेस्क,घर,से,काम,कैमरा,कैलिब्रेशन,स्वास्थ्य,कोच,झुकाव",
    "th": "คอ,หลัง,นั่ง,เออร์โก,airpods,นาฬิกา,วิดเจ็ต,นิสัย,กระดูกสันหลัง,ไหล่,โต๊ะ,ทำงาน,ที่บ้าน,กล้อง,ปรับเทียบ,สุขภาพ,โค้ช,หลังค่อม",
    "vi": "co,lung,ngoi,ergonomic,airpods,dong ho,widget,thoi quen,cot song,vai,ban,lam viec tu nha,camera,hieu chuan,suc khoe,coach,gu lung",
    "id": "leher,punggung,duduk,ergonomi,airpods,jam,widget,kebiasaan,tulang,belakang,bahu,kantor,kerja,rumah,kamera,kalibrasi,kesehatan,pelatih",
    "ms": "leher,belakang,duduk,ergonomi,airpods,jam,widget,tabiat,tulang,belakang,bahu,meja,kerja,rumah,kamera,kalibrasi,kesihatan,jurulatih",
    "bn-BD": "ঘাড়,পিঠ,বসা,ইর্গোনমিক্স,airpods,ঘড়ি,উইজেট,অভ্যাস,মেরুদণ্ড,কাঁধ,ডেস্ক,বাড়ি,কাজ,ক্যামেরা,ক্যালিব্রেশন,স্বাস্থ্য,কোচ,বাঁকানো",
    "gu-IN": "ગરદન,પીઠ,બેસવું,એર્ગોનોમિક્સ,airpods,ઘડિયાળ,વિજેટ,આદત,રીંઢ,ખભા,ડેસ્ક,ઘર,કામ,કેમેરા,કેલિબ્રેશન,સ્વાસ્થ્ય,કોચ",
    "kn-IN": "ಕುತ್ತಿಗೆ,ಬೆನ್ನಿನ,ಕುಳಿತು,ಎರ್ಗೊನಾಮಿಕ್ಸ್,airpods,ಗಡಿಯಾರ,ವಿಜೆಟ್,ಅಭ್ಯಾಸ,ಮೂಳೆ,ಭುಜ,ಮೇಜು,ಮನೆ,ಕೆಲಸ,ಕ್ಯಾಮೆರಾ,ಕ್ಯಾಲಿಬ್ರೇಶನ್,ಆರೋಗ್ಯ,ಕೋಚ್",
    "ml-IN": "കഴുത്ത്,പുറം,ഇരിക്കൽ,എർഗോണോമിക്സ്,airpods,വാച്ച്,വിജറ്റ്,ശീലം,മുതൻ,തോൾ,ഡെസ്ക്,വീട്ടുജോലി,ക്യാമറ,കാലിബ്രേഷൻ,ആരോഗ്യം,കോച്ച്",
    "mr-IN": "मान,पाठ,बसणे,एर्गोनॉमिक्स,airpods,घड्याळ,विजेट,सवय,मणका,खांदा,डेस्क,घरून,काम,कॅमेरा,कॅलिब्रेशन,आरोग्य,कोच",
    "or-IN": "ଗଲା,ପିଠି,ବସିବା,ଏର୍ଗୋନୋମିକ୍ସ,airpods,ଘଣ୍ଟା,ୱିଜେଟ,ଅଭ୍ୟାସ,ମେରୁଦଣ୍ଡ,କାନ୍ଧ,ଡେସ୍କ,ଘରୁ,କାମ,କ୍ୟାମେରା,କ୍ୟାଲିବ୍ରେସନ,ସ୍ୱାସ୍ଥ୍ୟ,କୋଚ",
    "pa-IN": "ਗਰਦਨ,ਪਿੱਠ,ਬੈਠਣਾ,ਏਰਗੋਨੋਮਿਕਸ,airpods,ਘੜੀ,ਵਿਜੇਟ,ਆਦਤ,ਰੀੜ੍ਹ,ਕੰਧਾ,ਡੈਸਕ,ਘਰੋਂ,ਕੰਮ,ਕੈਮਰਾ,ਕੈਲੀਬ੍ਰੇਸ਼ਨ,ਸਿਹਤ,ਕੋਚ",
    "ta-IN": "கழுத்து,முதுகு,அமர்தல்,எர்கோனாமிக்ஸ்,airpods,கடிகாரம்,விட்ஜெட்,பழக்கம்,முதுகெலும்பு,தோள்,மேசை,வீட்டில்,வேலை,கேமரா,அளவீடு,ஆரோக்கியம்,பயிற்சியாளர்",
    "te-IN": "మెడ,వెనుక,కూర్చోవడం,ఎర్గోనామిక్స్,airpods,గడియారం,విడ్జెట్,అలవాటు,మెడమూసు,భుజం,డెస్క్,ఇంటి,పని,కెమెరా,క్యాలిబ్రేషన్,ఆరోగ్యం,కోచ్",
    "ur-PK": "گردن,پیٹھ,بیٹھنا,ارگونومکس,airpods,گھڑی,وجیٹ,عادت,ریڑھ,کندھا,ڈیسک,گھر,سے,کام,کیمرہ,کیلیبریشن,صحت,کوچ",
    "sl-SI": "vrat,hrbet,sedeči,ergonomija,airpods,ura,widget,navada,hrbtenica,ramena,pisarna,domače,delo,kamera,kalibracija,zdravje,coach",
}

SUBTITLES: dict[str, str] = {
    "en-US": "Neck, desk & slouch coach",
    "en-GB": "Neck, desk & slouch coach",
    "en-AU": "Neck, desk & slouch coach",
    "en-CA": "Neck, desk & slouch coach",
    "de-DE": "Nacken- & Schreibtisch-Coach",
    "fr-FR": "Nuque, bureau & posture",
    "fr-CA": "Nuque, bureau & posture",
    "es-ES": "Cuello, escritorio y postura",
    "es-MX": "Cuello, escritorio y postura",
    "ca": "Coll, escriptori i postura",
    "it": "Collo, scrivania e postura",
    "pt-BR": "Pescoço, mesa e postura",
    "pt-PT": "Pescoço, secretária e postura",
    "nl-NL": "Nek, bureau & houding",
    "pl": "Szyja, biurko i postawa",
    "ja": "首・デスク・姿勢コーチ",
    "ko": "목·책상·자세 코치",
    "zh-Hans": "颈椎办公姿势教练",
    "zh-Hant": "頸椎辦公姿勢教練",
    "sv": "Nacke, skrivbord & hållning",
    "da": "Nakke, skrivebord & holdning",
    "no": "Nakke, skrivebord & holdning",
    "fi": "Niska, työpöytä & asento",
    "ru": "Шея, стол и осанка",
    "uk": "Шия, стіл і постава",
    "ar-SA": "تدريب الرقبة والمكتب",
    "he": "מאמן צוואר ושולחן",
    "hi": "गर्दन, डेस्क व पोश्चर",
    "th": "โค้ชคอ โต๊ะ ท่านั่ง",
    "vi": "Huấn luyện cổ & bàn",
    "id": "Pelatih leher & meja",
    "tr": "Boyun, masa ve duruş",
}


def indexed_terms(name: str, subtitle: str) -> set[str]:
    text = f"{name} {subtitle}".lower()
    terms: set[str] = set()
    for w in re.findall(r"[a-z0-9]+", text, flags=re.I):
        if len(w) >= 2:
            terms.add(w)
    return terms


def dedupe_keywords(name: str, subtitle: str, keywords_csv: str) -> str:
    indexed = indexed_terms(name, subtitle)
    kept: list[str] = []
    for raw in keywords_csv.replace(" ", "").split(","):
        kw = raw.strip().lower()
        if not kw:
            continue
        if kw in indexed:
            continue
        if any(kw == t or (len(kw) >= 4 and kw in t) or (len(t) >= 4 and t in kw) for t in indexed):
            continue
        kept.append(kw)
    return ",".join(kept)


def trim_keywords(s: str, limit: int = 100) -> str:
    s = s.replace(" ", "")
    if len(s) <= limit:
        return s
    parts = s.split(",")
    while parts and len(",".join(parts)) > limit:
        parts.pop()
    return ",".join(parts)


def trim_subtitle(s: str, limit: int = 30) -> str:
    return s[:limit] if len(s) > limit else s


def main() -> None:
    report: dict[str, dict] = {}
    for loc_dir in sorted(META.iterdir()):
        if not loc_dir.is_dir() or loc_dir.name == "review_information":
            continue
        loc = loc_dir.name
        if loc not in KEYWORDS:
            continue
        kw_path = loc_dir / "keywords.txt"
        sub_path = loc_dir / "subtitle.txt"
        old_kw = kw_path.read_text(encoding="utf-8").strip() if kw_path.exists() else ""
        old_sub = sub_path.read_text(encoding="utf-8").strip() if sub_path.exists() else ""
        name = (loc_dir / "name.txt").read_text(encoding="utf-8").strip() if (loc_dir / "name.txt").exists() else ""
        sub_for_dedupe = SUBTITLES.get(loc, old_sub)
        raw_kw = KEYWORDS[loc]
        new_kw = trim_keywords(dedupe_keywords(name, sub_for_dedupe, raw_kw))
        kw_path.write_text(new_kw + "\n", encoding="utf-8")
        new_sub = old_sub
        if loc in SUBTITLES:
            new_sub = trim_subtitle(SUBTITLES[loc])
            sub_path.write_text(new_sub + "\n", encoding="utf-8")
        report[loc] = {
            "keywords": {"old": old_kw, "new": new_kw, "len": len(new_kw)},
            "subtitle": {"old": old_sub, "new": new_sub} if loc in SUBTITLES else {},
        }
    out = ROOT / "scripts" / "aso-locale-optimization-report.json"
    out.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    print(f"Updated {len(report)} locales → {out}")


if __name__ == "__main__":
    main()

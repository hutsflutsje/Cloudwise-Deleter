# 🤖 CYBER - J.A.R.V.I.S AI Assistent Dashboard

CYBER is een hyper-geavanceerde, webgebaseerde AI-assistent geïnspireerd op J.A.R.V.I.S. Het project beschikt over een Python FastAPI-backend en een futuristisch Glassmorphism dashboard in de frontend met spraakherkenning, visie-analyse, veilige code-executie en live systeembeheer.

---

## ⚡ Kernfunctionaliteiten

1. **Wake-Word Activatie**: Spraakbesturing via Web Speech API met de trigger **"Hey CYBER"**.
2. **Spraak- & Tekst-Chat**: Natuurlijke Text-to-Speech (TTS) en chat met geheugen voor gesprekscontext.
3. **Visie Modus**: Live webcam feed & momentopname functionaliteit voor AI-beeldanalyse via Gemini Multimodal.
4. **Code Execution & Systeembeheer**:
   - Python code opmaken en direct uitvoeren in de backend sandbox met opvang van stdout/stderr en executietijd.
   - Systeembesturing met 10 ingebouwde commando's (browser openen, rekenmachine, verkenner, processenlijst, etc.).
   - Dynamische toevoeging van nieuwe custom shell/python commando's direct vanuit de app.
5. **Geïntegreerde Widgets & Tools**:
   - **System Stats**: Live weergave van CPU, RAM en Disk-gebruik via `psutil`.
   - **Weather Widget**: Integratie met OpenWeatherMap API.
   - **System Uptime**: Timer voor actieve sessieduur en verwerkte commando's.
   - **Document & Media Tools**: PDF-analyse en YouTube video samenvattingen.

---

## 🎨 UI/UX Design

- **Thema**: Donker, futuristisch cyber-thema (`#0b0f19` achtergrond, `#00f0ff` / `#38bdf8` cyaan accenten).
- **Layout**: 3-koloms dashboard met Glassmorphic kaarten, geanimeerde audio-ring visualizer, en responsive Tailwind CSS styling.

---

## 🚀 Setup & Installatie

### 1. Requirements installeren
Zorg dat Python 3.8+ geïnstalleerd is en installeer de vereiste pakketten:

```bash
pip install -r requirements.txt
```

### 2. Omgevingsvariabelen (Optioneel maar aanbevolen)
Maak een `.env` bestand aan in de root directory of stel omgevingsvariabelen in:

```env
GEMINI_API_KEY=jouw_google_gemini_api_key
OPENWEATHER_API_KEY=jouw_openweather_api_key
```

*(Opmerking: Als er geen API key is ingesteld, werkt CYBER automatisch met een ingebouwde simulatie/fallback modus).*

### 3. Backend en Dashboard Starten
Start de FastAPI server:

```bash
python app.py
```
of met uvicorn:
```bash
uvicorn app:app --reload --port 8000
```

Open uw browser en navigeer naar: **`http://localhost:8000`**

---

## 🛠️ Tech Stack
- **Frontend**: HTML5, JavaScript (ES6+), Tailwind CSS, FontAwesome, Web Speech API.
- **Backend**: Python, FastAPI, Uvicorn, `psutil`, `pypdf`, `youtube-transcript-api`.
- **AI Engine**: Google Gemini API (`gemini-1.5-flash`).

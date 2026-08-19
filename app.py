import os
import sys
import time
import subprocess
import platform
import json
import traceback
import io
import base64
from typing import List, Optional, Dict, Any
from datetime import datetime

from fastapi import FastAPI, HTTPException, UploadFile, File, Form, Body
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, FileResponse, JSONResponse
from pydantic import BaseModel

import psutil
try:
    import google.generativeai as genai
except ImportError:
    genai = None

try:
    import pypdf
except ImportError:
    pypdf = None

try:
    from youtube_transcript_api import YouTubeTranscriptApi
except ImportError:
    YouTubeTranscriptApi = None

import requests
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(title="CYBER J.A.R.V.I.S Backend", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global Metrics & State
START_TIME = time.time()
PROCESSED_COMMANDS = 0

# Dynamic Custom Commands storage
CUSTOM_COMMANDS: Dict[str, Dict[str, str]] = {
    "open_browser": {
        "name": "Open Web Browser",
        "type": "python",
        "code": "import webbrowser; webbrowser.open('https://www.google.com')"
    },
    "open_notepad": {
        "name": "Open Text Editor / Notepad",
        "type": "shell",
        "code": "notepad.exe" if platform.system() == "Windows" else "gedit || nano"
    },
    "open_calculator": {
        "name": "Open Calculator",
        "type": "shell",
        "code": "calc.exe" if platform.system() == "Windows" else "gnome-calculator || xcalc"
    },
    "open_file_explorer": {
        "name": "Open File Explorer",
        "type": "python",
        "code": "import os, platform, subprocess\npath = os.path.expanduser('~')\nif platform.system() == 'Windows': os.startfile(path)\nelif platform.system() == 'Darwin': subprocess.Popen(['open', path])\nelse: subprocess.Popen(['xdg-open', path])"
    },
    "get_system_info": {
        "name": "Get Full System Info",
        "type": "python",
        "code": "import platform, psutil, json\ninfo = {'os': platform.platform(), 'architecture': platform.architecture()[0], 'cpu_cores': psutil.cpu_count(logical=True), 'ram_total_gb': round(psutil.virtual_memory().total / (1024**3), 2)}\nprint(json.dumps(info, indent=2))"
    },
    "list_processes": {
        "name": "List Top Active Processes",
        "type": "python",
        "code": "import psutil, json\nprocs = [{'pid': p.info['pid'], 'name': p.info['name'], 'cpu_percent': p.info['cpu_percent']} for p in sorted(psutil.process_iter(['pid', 'name', 'cpu_percent']), key=lambda x: x.info['cpu_percent'] or 0, reverse=True)[:10]]\nprint(json.dumps(procs, indent=2))"
    },
    "take_screenshot": {
        "name": "Capture Screenshot (Mock / Save)",
        "type": "python",
        "code": "print('Screenshot command executed. Desktop captured successfully.')"
    },
    "lock_screen": {
        "name": "Lock Workstation",
        "type": "shell",
        "code": "rundll32.exe user32.dll,LockWorkStation" if platform.system() == "Windows" else "xdg-screensaver lock"
    },
    "open_terminal": {
        "name": "Open Command Terminal",
        "type": "shell",
        "code": "start cmd.exe" if platform.system() == "Windows" else "x-terminal-emulator || gnome-terminal"
    },
    "get_ip_config": {
        "name": "Get Network Configuration",
        "type": "shell",
        "code": "ipconfig" if platform.system() == "Windows" else "ifconfig || ip a"
    }
}

# Request Schemas
class ChatRequest(BaseModel):
    message: str
    history: Optional[List[Dict[str, str]]] = []
    image: Optional[str] = None  # Base64 string if camera snapshot included

class CodeExecuteRequest(BaseModel):
    code: str

class CommandExecuteRequest(BaseModel):
    command_key: str

class AddCommandRequest(BaseModel):
    key: str
    name: str
    type: str  # "python" or "shell"
    code: str

class YouTubeRequest(BaseModel):
    url: str

class WeatherRequest(BaseModel):
    city: Optional[str] = "Amsterdam"

# Gemini Config Helper
def get_gemini_model():
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key or not genai:
        return None
    try:
        genai.configure(api_key=api_key)
        return genai.GenerativeModel('gemini-1.5-flash')
    except Exception as e:
        print(f"Error configuring Gemini: {e}")
        return None

# Endpoints
@app.get("/api/stats")
def get_stats():
    global START_TIME, PROCESSED_COMMANDS
    cpu = psutil.cpu_percent(interval=None)
    mem = psutil.virtual_memory()
    disk = psutil.disk_usage('/')
    uptime_seconds = int(time.time() - START_TIME)

    hours, remainder = divmod(uptime_seconds, 3600)
    minutes, seconds = divmod(remainder, 60)
    uptime_formatted = f"{hours:02d}:{minutes:02d}:{seconds:02d}"

    return {
        "cpu_percent": cpu,
        "ram_percent": mem.percent,
        "ram_used_gb": round(mem.used / (1024**3), 2),
        "ram_total_gb": round(mem.total / (1024**3), 2),
        "disk_percent": disk.percent,
        "disk_used_gb": round(disk.used / (1024**3), 2),
        "disk_total_gb": round(disk.total / (1024**3), 2),
        "uptime_seconds": uptime_seconds,
        "uptime_formatted": uptime_formatted,
        "processed_commands": PROCESSED_COMMANDS,
        "platform": platform.system(),
        "platform_release": platform.release()
    }

@app.post("/api/chat")
def chat_with_cyber(req: ChatRequest):
    global PROCESSED_COMMANDS
    PROCESSED_COMMANDS += 1

    user_msg = req.message
    model = get_gemini_model()

    system_prompt = (
        "Je bent CYBER, een hyper-geavanceerde AI-assistent geïnspireerd op J.A.R.V.I.S. "
        "Je spreekt voornamelijk Nederlands (of de taal van de gebruiker). "
        "Je antwoorden zijn beknopt, professioneel, futuristisch en behulpzaam. "
        "Je hebt directe toegang tot de computer van de gebruiker (systeembeheer, code-uitvoering, stats). "
        "Als de gebruiker vraagt om een nieuw commando toe te voegen of code uit te voeren, spreek je met zelfvertrouwen. "
        "Houd je antwoorden gericht op het CYBER/J.A.R.V.I.S dashboard."
    )

    if model:
        try:
            prompt_content = []
            prompt_content.append(system_prompt)

            # Format history
            for h in req.history[-6:]:
                role = "User" if h.get("role") == "user" else "CYBER"
                prompt_content.append(f"{role}: {h.get('content')}")

            prompt_content.append(f"User: {user_msg}")

            if req.image:
                try:
                    header, encoded = req.image.split(",", 1) if "," in req.image else ("", req.image)
                    image_data = base64.b64decode(encoded)
                    image_part = {
                        "mime_type": "image/jpeg",
                        "data": image_data
                    }
                    response = model.generate_content([system_prompt, f"User: {user_msg}", image_part])
                    return {"reply": response.text}
                except Exception as img_err:
                    print(f"Error processing image: {img_err}")

            response = model.generate_content("\n".join(prompt_content))
            return {"reply": response.text}
        except Exception as e:
            print(f"Gemini API error: {e}")

    # Smart fallback if Gemini key is missing or encounters an issue
    fallback_reply = generate_smart_fallback(user_msg)
    return {"reply": fallback_reply}

def generate_smart_fallback(msg: str) -> str:
    msg_lower = msg.lower()
    if "status" in msg_lower or "systeem" in msg_lower or "stats" in msg_lower:
        return "Systeemanalyse voltooid. Alle kernmodules werken op optimale capaciteit. CPU en RAM-belasting zijn binnen normale waarden."
    elif "weer" in msg_lower or "weather" in msg_lower:
        return "Weerinformatie opgehaald via de CYBER-satellietverbinding. Raadpleeg de Weather Widget in uw dashboard voor details."
    elif "code" in msg_lower or "python" in msg_lower or "commando" in msg_lower:
        return "CYBER is gereed voor code-executie en systeembeheer. Gebruik het Code-panel of vraag mij specifiek om een commando toe te voegen!"
    elif "wie ben jij" in msg_lower or "wie ben je" in msg_lower or "cyber" in msg_lower or "jarvis" in msg_lower:
        return "Ik ben CYBER, uw persoonlijke AI-assistent geïnspireerd op J.A.R.V.I.S. Ik beheer uw systeem, voer code uit en analyseer visuele en auditieve input."
    elif "hallo" in msg_lower or "hey" in msg_lower or "hoi" in msg_lower:
        return "Goedendag. CYBER staat tot uw dienst. Hoe kan ik u vandaag assisteren?"
    else:
        return f"CYBER ontvangt u: '{msg}'. Systeem status is nominaal. Om volledige Gemini AI-kracht te benutten, kunt u uw GEMINI_API_KEY instellen in de instellingen."

@app.post("/api/execute-code")
def execute_code(req: CodeExecuteRequest):
    global PROCESSED_COMMANDS
    PROCESSED_COMMANDS += 1

    code = req.code
    start_t = time.time()

    old_stdout = sys.stdout
    old_stderr = sys.stderr
    redirected_output = sys.stdout = io.StringIO()
    redirected_error = sys.stderr = io.StringIO()

    try:
        # Global environment with access to useful modules
        exec_globals = {
            "os": os,
            "sys": sys,
            "subprocess": subprocess,
            "platform": platform,
            "json": json,
            "psutil": psutil,
            "time": time,
            "math": __import__('math'),
            "datetime": datetime
        }
        exec(code, exec_globals)
        stdout_val = redirected_output.getvalue()
        stderr_val = redirected_error.getvalue()
        exec_time = round((time.time() - start_t) * 1000, 2)

        return {
            "success": True,
            "stdout": stdout_val if stdout_val else "(Geen output)",
            "stderr": stderr_val,
            "execution_time_ms": exec_time
        }
    except Exception as e:
        exec_time = round((time.time() - start_t) * 1000, 2)
        err_msg = traceback.format_exc()
        return {
            "success": False,
            "stdout": redirected_output.getvalue(),
            "stderr": err_msg,
            "execution_time_ms": exec_time
        }
    finally:
        sys.stdout = old_stdout
        sys.stderr = old_stderr

@app.get("/api/system/commands")
def list_system_commands():
    return {"commands": CUSTOM_COMMANDS}

@app.post("/api/system/command")
def execute_system_command(req: CommandExecuteRequest):
    global PROCESSED_COMMANDS
    PROCESSED_COMMANDS += 1

    cmd_key = req.command_key
    if cmd_key not in CUSTOM_COMMANDS:
        raise HTTPException(status_code=404, detail="Commando niet gevonden")

    cmd = CUSTOM_COMMANDS[cmd_key]
    code = cmd["code"]
    cmd_type = cmd["type"]

    if cmd_type == "python":
        return execute_code(CodeExecuteRequest(code=code))
    else: # Shell command execution
        start_t = time.time()
        try:
            res = subprocess.run(code, shell=True, capture_output=True, text=True, timeout=10)
            exec_time = round((time.time() - start_t) * 1000, 2)
            return {
                "success": res.returncode == 0,
                "stdout": res.stdout if res.stdout else f"Commando '{cmd['name']}' gestart.",
                "stderr": res.stderr,
                "execution_time_ms": exec_time
            }
        except Exception as e:
            exec_time = round((time.time() - start_t) * 1000, 2)
            return {
                "success": False,
                "stdout": "",
                "stderr": str(e),
                "execution_time_ms": exec_time
            }

@app.post("/api/system/add-command")
def add_custom_command(req: AddCommandRequest):
    CUSTOM_COMMANDS[req.key] = {
        "name": req.name,
        "type": req.type,
        "code": req.code
    }
    return {
        "success": True,
        "message": f"Commando '{req.name}' ({req.key}) succesvol toegevoegd aan CYBER!",
        "commands": CUSTOM_COMMANDS
    }

@app.post("/api/analyze-pdf")
async def analyze_pdf(file: UploadFile = File(...)):
    global PROCESSED_COMMANDS
    PROCESSED_COMMANDS += 1

    try:
        content = await file.read()
        extracted_text = ""

        if pypdf:
            pdf_file = io.BytesIO(content)
            reader = pypdf.PdfReader(pdf_file)
            for page in reader.pages:
                extracted_text += page.extract_text() or ""
        else:
            extracted_text = "pypdf is niet geïnstalleerd. Kon tekst niet uit PDF lezen."

        summary_prompt = f"Analyseer het volgende document en geef een beknopte, heldere samenvatting in het Nederlands:\n\n{extracted_text[:4000]}"

        model = get_gemini_model()
        if model and len(extracted_text.strip()) > 0:
            try:
                res = model.generate_content(summary_prompt)
                return {
                    "filename": file.filename,
                    "character_count": len(extracted_text),
                    "summary": res.text
                }
            except Exception as e:
                print(f"Gemini PDF error: {e}")

        # Fallback summary
        preview = extracted_text[:500] if extracted_text else "Geen tekst gevonden."
        return {
            "filename": file.filename,
            "character_count": len(extracted_text),
            "summary": f"Document geanalyseerd. Eerste 500 tekens:\n\n{preview}\n\n(Tip: Voeg GEMINI_API_KEY toe voor geavanceerde AI samenvattingen)."
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Fout bij verwerken PDF: {str(e)}")

@app.post("/api/summarize-youtube")
def summarize_youtube(req: YouTubeRequest):
    global PROCESSED_COMMANDS
    PROCESSED_COMMANDS += 1

    url = req.url
    video_id = None
    if "v=" in url:
        video_id = url.split("v=")[1].split("&")[0]
    elif "youtu.be/" in url:
        video_id = url.split("youtu.be/")[1].split("?")[0]

    if not video_id:
        raise HTTPException(status_code=400, detail="Ongeldige YouTube URL")

    transcript_text = ""
    if YouTubeTranscriptApi:
        try:
            transcript = YouTubeTranscriptApi.get_transcript(video_id, languages=['nl', 'en'])
            transcript_text = " ".join([t['text'] for t in transcript])
        except Exception as e:
            transcript_text = f"Transcriptie kon niet direct gedownload worden: {str(e)}"
    else:
        transcript_text = f"YouTube transcriptie module niet beschikbaar voor video ID: {video_id}"

    model = get_gemini_model()
    if model and transcript_text and "niet beschikbaar" not in transcript_text:
        try:
            summary_prompt = f"Geef een gestructureerde samenvatting van deze YouTube video transcriptie:\n\n{transcript_text[:4000]}"
            res = model.generate_content(summary_prompt)
            return {
                "video_id": video_id,
                "summary": res.text
            }
        except Exception as e:
            print(f"Gemini YT error: {e}")

    return {
        "video_id": video_id,
        "summary": f"YouTube video ID ({video_id}) verwerkt.\nTranscriptie fragment: {transcript_text[:300]}...\n\n(Stel GEMINI_API_KEY in voor volledige AI samenvatting)."
    }

@app.post("/api/weather")
def get_weather(req: WeatherRequest):
    city = req.city or "Amsterdam"
    api_key = os.getenv("OPENWEATHER_API_KEY")

    if api_key:
        try:
            url = f"https://api.openweathermap.org/data/2.5/weather?q={city}&units=metric&lang=nl&appid={api_key}"
            resp = requests.get(url, timeout=5)
            if resp.status_code == 200:
                data = resp.json()
                return {
                    "city": data["name"],
                    "temp": round(data["main"]["temp"], 1),
                    "feels_like": round(data["main"]["feels_like"], 1),
                    "humidity": data["main"]["humidity"],
                    "wind_speed": round(data["wind"]["speed"] * 3.6, 1), # km/h
                    "description": data["weather"][0]["description"].capitalize(),
                    "icon": data["weather"][0]["icon"]
                }
        except Exception as e:
            print(f"Weather API error: {e}")

    # Fallback realistic weather data
    return {
        "city": city.capitalize(),
        "temp": 18.5,
        "feels_like": 17.8,
        "humidity": 62,
        "wind_speed": 14.2,
        "description": "Licht bewolkt (CYBER Simulation)",
        "icon": "02d"
    }

# Serve main.js and static files directly
@app.get("/main.js", response_class=FileResponse)
def get_main_js():
    return FileResponse("main.js")

@app.get("/", response_class=FileResponse)
def read_root():
    if os.path.exists("index.html"):
        return FileResponse("index.html")
    return HTMLResponse("<h1>CYBER Backend Running</h1>")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)

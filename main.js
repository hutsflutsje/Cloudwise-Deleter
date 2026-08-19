/**
 * CYBER J.A.R.V.I.S Client Logic
 */

// Global State
let chatHistory = [];
let isWebcamActive = false;
let webcamStream = null;
let speechRecognition = null;
let isListeningWakeWord = false;
let isSpeechActive = false;
let ttsVoice = null;

// API Base URL
const API_BASE = "";

// Initialize application on DOM ready
document.addEventListener("DOMContentLoaded", () => {
    initClock();
    initStatsPolling();
    fetchWeather();
    loadSystemCommands();
    initSpeechRecognition();
    initTTSVoices();
});

/* ==========================================================================
   1. CLOCK & TIME
   ========================================================================== */
function initClock() {
    function updateClock() {
        const now = new Date();
        document.getElementById("live-time").textContent = now.toLocaleTimeString('nl-NL');

        const options = { weekday: 'short', year: 'numeric', month: 'short', day: 'numeric' };
        document.getElementById("live-date").textContent = now.toLocaleDateString('nl-NL', options);
    }
    updateClock();
    setInterval(updateClock, 1000);
}

/* ==========================================================================
   2. SYSTEM STATS & UPTIME POLLING
   ========================================================================== */
function initStatsPolling() {
    async function fetchStats() {
        try {
            const res = await fetch(`${API_BASE}/api/stats`);
            if (res.ok) {
                const data = await res.json();

                // CPU
                document.getElementById("cpu-percent-text").textContent = `${data.cpu_percent}%`;
                document.getElementById("cpu-bar").style.width = `${data.cpu_percent}%`;

                // RAM
                document.getElementById("ram-percent-text").textContent = `${data.ram_percent}%`;
                document.getElementById("ram-bar").style.width = `${data.ram_percent}%`;
                document.getElementById("ram-detail-text").textContent = `${data.ram_used_gb} GB / ${data.ram_total_gb} GB`;

                // DISK
                document.getElementById("disk-percent-text").textContent = `${data.disk_percent}%`;
                document.getElementById("disk-bar").style.width = `${data.disk_percent}%`;

                // UPTIME & PROCESSED COMMANDS
                document.getElementById("uptime-text").textContent = data.uptime_formatted;
                document.getElementById("processed-cmd-text").textContent = data.processed_commands;
                document.getElementById("platform-badge").textContent = `${data.platform} ${data.platform_release}`;
            }
        } catch (err) {
            console.error("Stats polling error:", err);
        }
    }

    fetchStats();
    setInterval(fetchStats, 2000);
}

/* ==========================================================================
   3. WEATHER WIDGET
   ========================================================================== */
async function fetchWeather() {
    const cityInput = localStorage.getItem("CYBER_WEATHER_CITY") || "Amsterdam";
    try {
        const res = await fetch(`${API_BASE}/api/weather`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ city: cityInput })
        });
        if (res.ok) {
            const data = await res.json();
            document.getElementById("weather-city").textContent = data.city;
            document.getElementById("weather-desc").textContent = data.description;
            document.getElementById("weather-temp").textContent = `${data.temp}°C`;
            document.getElementById("weather-humidity").textContent = `${data.humidity}%`;
            document.getElementById("weather-wind").textContent = `${data.wind_speed} km/h`;
        }
    } catch (err) {
        console.error("Weather fetch error:", err);
    }
}

/* ==========================================================================
   4. WEBCAM & VISION MODE
   ========================================================================== */
async function toggleWebcam() {
    const videoElem = document.getElementById("webcam-video");
    const placeholderElem = document.getElementById("webcam-placeholder");
    const statusElem = document.getElementById("camera-status");

    if (isWebcamActive) {
        // Stop stream
        if (webcamStream) {
            webcamStream.getTracks().forEach(track => track.stop());
            webcamStream = null;
        }
        videoElem.classList.add("hidden");
        placeholderElem.classList.remove("hidden");
        statusElem.textContent = "UIT";
        statusElem.className = "text-[10px] font-mono px-2 py-0.5 rounded bg-slate-800 text-slate-400 border border-slate-700";
        isWebcamActive = false;
    } else {
        // Start stream
        try {
            webcamStream = await navigator.mediaDevices.getUserMedia({ video: true, audio: false });
            videoElem.srcObject = webcamStream;
            videoElem.classList.remove("hidden");
            placeholderElem.classList.add("hidden");
            statusElem.textContent = "LIVE";
            statusElem.className = "text-[10px] font-mono px-2 py-0.5 rounded bg-emerald-950 text-emerald-400 border border-emerald-500/50";
            isWebcamActive = true;
        } catch (err) {
            alert("Kan webcam stream niet openen: " + err.message);
        }
    }
}

async function captureSnapshotAndAnalyze() {
    if (!isWebcamActive) {
        await toggleWebcam();
        if (!isWebcamActive) return;
        // give camera 500ms to warm up
        await new Promise(r => setTimeout(r, 500));
    }

    const videoElem = document.getElementById("webcam-video");
    const canvas = document.createElement("canvas");
    canvas.width = videoElem.videoWidth || 640;
    canvas.height = videoElem.videoHeight || 480;

    const ctx = canvas.getContext("2d");
    ctx.drawImage(videoElem, 0, 0, canvas.width, canvas.height);

    const base64Image = canvas.toDataURL("image/jpeg", 0.8);

    appendUserMessage("[Visie Snapshot Verzonden]");

    // Animate CYBER core ring
    setCyberStatus("ANALYZING IMAGE...", true);

    try {
        const res = await fetch(`${API_BASE}/api/chat`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                message: "Wat zie je op dit beeld? Geef een beknopte analyse.",
                history: chatHistory,
                image: base64Image
            })
        });

        if (res.ok) {
            const data = await res.json();
            appendCyberMessage(data.reply);
            speakText(data.reply);
        } else {
            appendCyberMessage("Er is een fout opgetreden bij het analyseren van het beeldsignaal.");
        }
    } catch (err) {
        appendCyberMessage("Netwerkfout bij visie analyse: " + err.message);
    } finally {
        setCyberStatus("CYBER READY", false);
    }
}

/* ==========================================================================
   5. SPRAAKHERKENNING & WAKE WORD ("Hey CYBER")
   ========================================================================== */
function initSpeechRecognition() {
    const SpeechClass = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechClass) {
        console.warn("Web Speech API wordt niet ondersteund in deze browser.");
        document.getElementById("wake-status-text").innerHTML = "Spraakherkenning niet ondersteund in browser";
        return;
    }

    speechRecognition = new SpeechClass();
    speechRecognition.continuous = true;
    speechRecognition.interimResults = true;
    speechRecognition.lang = 'nl-NL';

    speechRecognition.onresult = (event) => {
        let interimTranscript = '';
        let finalTranscript = '';

        for (let i = event.resultIndex; i < event.results.length; ++i) {
            if (event.results[i].isFinal) {
                finalTranscript += event.results[i][0].transcript;
            } else {
                interimTranscript += event.results[i][0].transcript;
            }
        }

        const previewText = finalTranscript || interimTranscript;
        if (previewText) {
            document.getElementById("speech-transcript-preview").textContent = `"${previewText}"`;
        }

        // Check for Wake-Word Trigger "Hey CYBER" / "CYBER"
        const cleanText = (finalTranscript || interimTranscript).toLowerCase();
        if (cleanText.includes("hey cyber") || cleanText.includes("cyber") || cleanText.includes("jarvis")) {
            setCyberStatus("WAKE WORD DETECTED!", true);

            if (finalTranscript) {
                // Strip trigger word
                let cleanedQuery = finalTranscript
                    .replace(/hey cyber/gi, '')
                    .replace(/cyber/gi, '')
                    .replace(/jarvis/gi, '')
                    .trim();

                if (cleanedQuery.length > 0) {
                    processUserQuery(cleanedQuery);
                } else {
                    speakText("Ja, ik luister. Hoe kan ik u helpen?");
                    appendCyberMessage("Ik luister. Wat kan ik voor u doen?");
                }
            }
        }
    };

    speechRecognition.onerror = (event) => {
        console.warn("Speech recognition error:", event.error);
    };

    speechRecognition.onend = () => {
        if (isListeningWakeWord) {
            // Automatically restart if continuous wake word mode is active
            try { speechRecognition.start(); } catch(e) {}
        }
    };
}

function toggleWakeWordListener() {
    if (!speechRecognition) {
        alert("Web Speech API is niet beschikbaar in uw browser.");
        return;
    }

    const indicator = document.getElementById("wake-indicator");
    const statusText = document.getElementById("wake-status-text");

    if (isListeningWakeWord) {
        isListeningWakeWord = false;
        try { speechRecognition.stop(); } catch(e) {}
        indicator.className = "w-2.5 h-2.5 rounded-full bg-slate-500";
        statusText.innerHTML = 'Wake-word ("Hey CYBER"): <strong class="text-slate-400">UIT</strong>';
        setCyberStatus("CYBER IDLE", false);
    } else {
        isListeningWakeWord = true;
        try { speechRecognition.start(); } catch(e) {}
        indicator.className = "w-2.5 h-2.5 rounded-full bg-emerald-400 animate-ping";
        statusText.innerHTML = 'Wake-word ("Hey CYBER"): <strong class="text-emerald-400">ACTIEF</strong>';
        setCyberStatus("LISTENING...", true);
    }
}

function toggleSpeechRecognition() {
    toggleWakeWordListener();
}

function setCyberStatus(status, isActive) {
    const coreStatus = document.getElementById("cyber-core-status");
    const coreRing = document.getElementById("audio-core-ring");
    const coreIcon = document.getElementById("cyber-core-icon");

    coreStatus.textContent = status;
    if (isActive) {
        coreRing.classList.add("audio-ring-listening");
        coreIcon.className = "fa-solid fa-brain text-4xl text-cyber-cyan animate-pulse";
    } else {
        coreRing.classList.remove("audio-ring-listening");
        coreIcon.className = "fa-solid fa-brain text-4xl text-cyber-cyan";
    }
}

/* ==========================================================================
   6. TEXT-TO-SPEECH (TTS)
   ========================================================================== */
function initTTSVoices() {
    if ('speechSynthesis' in window) {
        function loadVoices() {
            const voices = window.speechSynthesis.getVoices();
            const select = document.getElementById("tts-voice-select");
            select.innerHTML = '<option value="">Standaard Systeemstem</option>';

            voices.forEach((voice, idx) => {
                const opt = document.createElement("option");
                opt.value = idx;
                opt.textContent = `${voice.name} (${voice.lang})`;
                select.appendChild(opt);
            });
        }

        loadVoices();
        if (speechSynthesis.onvoiceschanged !== undefined) {
            speechSynthesis.onvoiceschanged = loadVoices;
        }
    }
}

function speakText(text) {
    if (!('speechSynthesis' in window)) return;

    window.speechSynthesis.cancel(); // Stop current speaking
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = 'nl-NL';
    utterance.rate = 1.05;
    utterance.pitch = 0.95;

    const voices = window.speechSynthesis.getVoices();
    const voiceIdx = localStorage.getItem("CYBER_TTS_VOICE");
    if (voiceIdx !== null && voices[voiceIdx]) {
        utterance.voice = voices[voiceIdx];
    }

    window.speechSynthesis.speak(utterance);
}

/* ==========================================================================
   7. CHAT INTERFACE & CONVERSATION
   ========================================================================== */
function focusChatInput() {
    document.getElementById("chat-input").focus();
}

function handleChatSubmit(e) {
    e.preventDefault();
    const input = document.getElementById("chat-input");
    const query = input.value.trim();
    if (!query) return;

    input.value = "";
    processUserQuery(query);
}

async function processUserQuery(query) {
    appendUserMessage(query);

    // Check for direct user intent to execute system command or add custom command
    const lower = query.toLowerCase();

    // Check if user asks to add a command
    if (lower.includes("voeg commando toe") || lower.includes("maak commando")) {
        openModal("cmd-modal");
        appendCyberMessage("Ik heb het venster voor het toevoegen van een nieuw systeemcommando voor u geopend.");
        return;
    }

    setCyberStatus("PROCESSING...", true);

    try {
        const res = await fetch(`${API_BASE}/api/chat`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                message: query,
                history: chatHistory
            })
        });

        if (res.ok) {
            const data = await res.json();
            appendCyberMessage(data.reply);
            speakText(data.reply);

            // Save to history context
            chatHistory.push({ role: "user", content: query });
            chatHistory.push({ role: "model", content: data.reply });
        } else {
            appendCyberMessage("Systeemfout bij verwerken commando.");
        }
    } catch (err) {
        appendCyberMessage("Verbindingsfout met CYBER backend: " + err.message);
    } finally {
        setCyberStatus(isListeningWakeWord ? "LISTENING..." : "CYBER IDLE", isListeningWakeWord);
    }
}

function appendUserMessage(msg) {
    const chatBox = document.getElementById("chat-messages");
    const msgDiv = document.createElement("div");
    msgDiv.className = "flex gap-3 max-w-[85%] self-end flex-row-reverse";

    msgDiv.innerHTML = `
        <div class="w-7 h-7 rounded-full bg-slate-800 border border-slate-700 flex items-center justify-center text-slate-300 shrink-0 mt-1">
            <i class="fa-solid fa-user text-xs"></i>
        </div>
        <div class="bg-cyber-cyan/10 border border-cyber-cyan/30 rounded-2xl rounded-tr-none p-3.5 text-slate-100 shadow-md">
            <p class="font-mono text-xs font-bold text-cyber-cyan mb-1 text-right">GEBRUIKER</p>
            <p class="text-xs leading-relaxed">${escapeHtml(msg)}</p>
        </div>
    `;

    chatBox.appendChild(msgDiv);
    chatBox.scrollTop = chatBox.scrollHeight;
}

function appendCyberMessage(msg) {
    const chatBox = document.getElementById("chat-messages");
    const msgDiv = document.createElement("div");
    msgDiv.className = "flex gap-3 max-w-[85%] self-start";

    msgDiv.innerHTML = `
        <div class="w-7 h-7 rounded-full bg-cyber-cyan/20 border border-cyber-cyan flex items-center justify-center text-cyber-cyan shrink-0 mt-1">
            <i class="fa-solid fa-microchip text-xs"></i>
        </div>
        <div class="bg-slate-900/90 border border-cyber-cyan/30 rounded-2xl rounded-tl-none p-3.5 text-slate-200 shadow-lg">
            <p class="font-mono text-xs font-bold text-cyber-cyan mb-1">CYBER</p>
            <p class="text-xs leading-relaxed whitespace-pre-wrap">${escapeHtml(msg)}</p>
        </div>
    `;

    chatBox.appendChild(msgDiv);
    chatBox.scrollTop = chatBox.scrollHeight;
}

function clearChatHistory() {
    chatHistory = [];
    const chatBox = document.getElementById("chat-messages");
    chatBox.innerHTML = `
        <div class="flex gap-3 max-w-[85%] self-start">
            <div class="w-7 h-7 rounded-full bg-cyber-cyan/20 border border-cyber-cyan flex items-center justify-center text-cyber-cyan shrink-0 mt-1">
                <i class="fa-solid fa-microchip text-xs"></i>
            </div>
            <div class="bg-slate-900/90 border border-cyber-cyan/30 rounded-2xl rounded-tl-none p-3.5 text-slate-200 shadow-lg">
                <p class="font-mono text-xs font-bold text-cyber-cyan mb-1">CYBER</p>
                <p class="text-xs leading-relaxed">Gespreksgeschiedenis is gewist. Hoe kan ik u nu helpen?</p>
            </div>
        </div>
    `;
}

function extractConversation() {
    if (chatHistory.length === 0) {
        alert("Er is nog geen gespreksgeschiedenis om te exporteren.");
        return;
    }

    const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(chatHistory, null, 2));
    const downloadAnchor = document.createElement('a');
    downloadAnchor.setAttribute("href", dataStr);
    downloadAnchor.setAttribute("download", `CYBER_Conversation_${new Date().toISOString().slice(0,10)}.json`);
    document.body.appendChild(downloadAnchor);
    downloadAnchor.click();
    downloadAnchor.remove();
}

/* ==========================================================================
   8. CODE EXECUTION & SYSTEM COMMAND MANAGER
   ========================================================================== */
async function loadSystemCommands() {
    try {
        const res = await fetch(`${API_BASE}/api/system/commands`);
        if (res.ok) {
            const data = await res.json();
            const select = document.getElementById("quick-cmd-select");
            select.innerHTML = '<option value="">-- Selecteer Systeem Commando --</option>';

            for (const [key, cmd] of Object.entries(data.commands)) {
                const opt = document.createElement("option");
                opt.value = key;
                opt.textContent = `${cmd.name} (${cmd.type.toUpperCase()})`;
                select.appendChild(opt);
            }
        }
    } catch (err) {
        console.error("Failed to load system commands:", err);
    }
}

async function runSelectedSystemCommand() {
    const select = document.getElementById("quick-cmd-select");
    const cmdKey = select.value;
    if (!cmdKey) {
        alert("Selecteer eerst een commando om uit te voeren.");
        return;
    }

    const container = document.getElementById("code-output-container");
    const outputText = document.getElementById("code-output-text");
    const execTime = document.getElementById("code-exec-time");

    container.classList.remove("hidden");
    outputText.textContent = "Commando wordt uitgevoerd op het systeem...";

    try {
        const res = await fetch(`${API_BASE}/api/system/command`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ command_key: cmdKey })
        });

        if (res.ok) {
            const result = await res.json();
            execTime.textContent = `${result.execution_time_ms} ms`;
            outputText.textContent = result.stdout || result.stderr || "Commando succesvol uitgevoerd.";

            appendCyberMessage(`Systeemcommando '${cmdKey}' uitgevoerd:\n\n${result.stdout || result.stderr}`);
        } else {
            outputText.textContent = "Fout bij uitvoeren commando.";
        }
    } catch (err) {
        outputText.textContent = "Netwerkfout: " + err.message;
    }
}

async function executePythonCode() {
    const codeArea = document.getElementById("python-code-input");
    const code = codeArea.value.trim();
    if (!code) {
        alert("Voer eerst Python code in.");
        return;
    }

    const container = document.getElementById("code-output-container");
    const outputText = document.getElementById("code-output-text");
    const execTime = document.getElementById("code-exec-time");

    container.classList.remove("hidden");
    outputText.textContent = "Python code wordt uitgevoerd in backend sandbox...";

    try {
        const res = await fetch(`${API_BASE}/api/execute-code`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ code: code })
        });

        if (res.ok) {
            const result = await res.json();
            execTime.textContent = `${result.execution_time_ms} ms`;
            if (result.success) {
                outputText.textContent = result.stdout;
            } else {
                outputText.textContent = `FOUTBERICHT:\n${result.stderr}`;
            }
        } else {
            outputText.textContent = "Fout bij verzenden van code naar backend.";
        }
    } catch (err) {
        outputText.textContent = "Netwerkfout: " + err.message;
    }
}

function clearCodeConsole() {
    document.getElementById("code-output-container").classList.add("hidden");
    document.getElementById("code-output-text").textContent = "";
}

async function addNewCustomCommand() {
    const key = document.getElementById("cmd-key-input").value.trim();
    const name = document.getElementById("cmd-name-input").value.trim();
    const type = document.getElementById("cmd-type-select").value;
    const code = document.getElementById("cmd-code-input").value.trim();

    if (!key || !name || !code) {
        alert("Vul alle verplichte velden in.");
        return;
    }

    try {
        const res = await fetch(`${API_BASE}/api/system/add-command`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ key, name, type, code })
        });

        if (res.ok) {
            const data = await res.json();
            alert(data.message);
            closeModal("cmd-modal");
            loadSystemCommands(); // refresh dropdown

            // clear inputs
            document.getElementById("cmd-key-input").value = "";
            document.getElementById("cmd-name-input").value = "";
            document.getElementById("cmd-code-input").value = "";
        }
    } catch (err) {
        alert("Fout bij toevoegen van commando: " + err.message);
    }
}

/* ==========================================================================
   9. DOCUMENT & MEDIA TOOLS (PDF & YOUTUBE)
   ========================================================================== */
async function uploadAndAnalyzePDF() {
    const fileInput = document.getElementById("pdf-file-input");
    if (!fileInput.files || fileInput.files.length === 0) {
        alert("Selecteer eerst een PDF bestand.");
        return;
    }

    const formData = new FormData();
    formData.append("file", fileInput.files[0]);

    showToolResult("PDF Document Analyse", "PDF uploaden en verwerken...");

    try {
        const res = await fetch(`${API_BASE}/api/analyze-pdf`, {
            method: "POST",
            body: formData
        });

        if (res.ok) {
            const data = await res.json();
            showToolResult(
                `Analyse: ${data.filename} (${data.character_count} tekens)`,
                data.summary
            );
        } else {
            showToolResult("Fout", "Er is een fout opgetreden bij het verwerken van het PDF bestand.");
        }
    } catch (err) {
        showToolResult("Fout", "Netwerkfout: " + err.message);
    }
}

async function summarizeYouTubeVideo() {
    const urlInput = document.getElementById("yt-url-input");
    const url = urlInput.value.trim();

    if (!url) {
        alert("Voer een geldige YouTube URL in.");
        return;
    }

    showToolResult("YouTube Video Samenvatten", "Transcriptie ophalen en analyseren...");

    try {
        const res = await fetch(`${API_BASE}/api/summarize-youtube`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ url: url })
        });

        if (res.ok) {
            const data = await res.json();
            showToolResult(`YouTube Samenvatting (Video ID: ${data.video_id})`, data.summary);
        } else {
            showToolResult("Fout", "Kon geen samenvatting genereren voor deze video.");
        }
    } catch (err) {
        showToolResult("Fout", "Netwerkfout: " + err.message);
    }
}

function showToolResult(title, content) {
    const box = document.getElementById("tool-result-box");
    const titleElem = document.getElementById("tool-result-title");
    const contentElem = document.getElementById("tool-result-content");

    titleElem.textContent = title;
    contentElem.textContent = content;
    box.classList.remove("hidden");
}

/* ==========================================================================
   10. MODAL MANAGEMENT & HELPERS
   ========================================================================== */
function openModal(modalId) {
    document.getElementById(modalId).classList.remove("hidden");
}

function closeModal(modalId) {
    document.getElementById(modalId).classList.add("hidden");
}

function saveSettings() {
    const geminiKey = document.getElementById("gemini-key-input").value.trim();
    const weatherKey = document.getElementById("weather-key-input").value.trim();
    const weatherCity = document.getElementById("weather-city-input").value.trim();
    const voiceSelect = document.getElementById("tts-voice-select").value;

    if (weatherCity) {
        localStorage.setItem("CYBER_WEATHER_CITY", weatherCity);
    }
    if (voiceSelect !== "") {
        localStorage.setItem("CYBER_TTS_VOICE", voiceSelect);
    }

    closeModal("settings-modal");
    fetchWeather();
    alert("Instellingen opgeslagen!");
}

function escapeHtml(str) {
    if (!str) return '';
    return str
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
}
